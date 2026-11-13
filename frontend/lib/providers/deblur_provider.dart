import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/history_entry.dart';
import '../models/process_mode.dart';
import '../services/api_service.dart';
import 'history_provider.dart';

enum DeblurStage { idle, upload, inference, cache, done, failed, cancelled }

/// Runs a deblur job for one or more photos: checks the on-device result
/// cache, uploads to the backend, saves to history. Exposes stage/progress
/// for the Processing screen.
class DeblurProvider extends ChangeNotifier {
  final ApiService _apiService;
  final Future<bool> Function() _isOnWifi;

  DeblurProvider({ApiService? apiService, Future<bool> Function()? isOnWifi})
    : _apiService = apiService ?? ApiService(),
      _isOnWifi = isOnWifi ?? _defaultIsOnWifi;

  static Future<bool> _defaultIsOnWifi() async {
    final r = await Connectivity().checkConnectivity();
    return r.contains(ConnectivityResult.wifi) ||
        r.contains(ConnectivityResult.ethernet);
  }

  List<File> files = [];
  int index = 0;
  DeblurStage stage = DeblurStage.idle;

  /// Progress of the current photo, 0..1.
  double progress = 0;

  /// True while the current photo is being served from the result cache.
  bool cacheHit = false;
  String? error;
  final List<HistoryEntry> results = [];
  final List<bool> cachedFlags = [];
  DateTime? startedAt;

  CancelToken? _cancelToken;
  Timer? _creep;
  int _runId = 0;

  bool get isRunning =>
      stage == DeblurStage.upload ||
      stage == DeblurStage.inference ||
      stage == DeblurStage.cache;

  File? get currentFile => files.isEmpty ? null : files[index.clamp(0, files.length - 1)];

  /// Overall progress across the batch, 0..1.
  double get overall =>
      files.isEmpty ? 0 : ((index + progress) / files.length).clamp(0.0, 1.0);

  Future<void> run(
    List<File> input, {
    required ProcessMode mode,
    required HistoryProvider history,
    required bool useCache,
    required bool wifiOnly,
  }) async {
    final runId = ++_runId;
    files = List.of(input);
    index = 0;
    results.clear();
    cachedFlags.clear();
    error = null;
    startedAt = DateTime.now();
    final resolvedMode = mode.resolved;
    await history.ensureLoaded();

    for (var i = 0; i < files.length; i++) {
      if (runId != _runId) return;
      index = i;
      cacheHit = false;
      _setStage(DeblurStage.upload, 0);
      final file = files[i];

      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();

      if (useCache) {
        final hit = history.findByHash(hash, resolvedMode);
        if (hit != null) {
          cacheHit = true;
          _setStage(DeblurStage.cache, 0.9);
          await Future.delayed(const Duration(milliseconds: 450));
          if (runId != _runId) return;
          results.add(hit);
          cachedFlags.add(true);
          _setStage(DeblurStage.cache, 1);
          continue;
        }
      }

      if (wifiOnly && !await _isOnWifi()) {
        _fail('Server mode is set to Wi-Fi only. Connect to Wi-Fi or turn '
            'off "Server only on Wi-Fi" in Settings.');
        return;
      }

      _cancelToken = CancelToken();
      final result = await _apiService.deblurImage(
        file,
        cancelToken: _cancelToken,
        onSendProgress: (sent, total) {
          if (runId != _runId || total <= 0) return;
          final f = sent / total;
          if (f >= 1) {
            _startInference();
          } else {
            _setStage(DeblurStage.upload, 0.15 * f);
          }
        },
      );
      _creep?.cancel();
      if (runId != _runId) return;

      if (!result.success || result.deblurredImageBytes == null) {
        if (stage == DeblurStage.cancelled) return;
        _fail(result.error ?? 'Failed to deblur image.');
        return;
      }

      _setStage(DeblurStage.cache, 0.95);
      final entry = await history.addEntry(
        original: file,
        deblurredBytes: result.deblurredImageBytes!,
        processingTimeMs: result.processingTimeMs,
        hash: hash,
        mode: resolvedMode,
        name: _displayName(file),
      );
      if (runId != _runId) return;
      results.add(entry);
      cachedFlags.add(false);
      _setStage(DeblurStage.cache, 1);
    }

    _setStage(DeblurStage.done, 1);
  }

  /// No server-side progress is available, so ease towards ~92% while
  /// waiting for the response.
  void _startInference() {
    if (stage == DeblurStage.inference) return;
    _setStage(DeblurStage.inference, 0.15);
    _creep?.cancel();
    _creep = Timer.periodic(const Duration(milliseconds: 120), (_) {
      progress += (0.92 - progress) * 0.025;
      notifyListeners();
    });
  }

  void cancel() {
    _runId++;
    _creep?.cancel();
    _cancelToken?.cancel();
    stage = DeblurStage.cancelled;
    notifyListeners();
  }

  void _fail(String message) {
    _creep?.cancel();
    error = message;
    stage = DeblurStage.failed;
    notifyListeners();
  }

  void _setStage(DeblurStage s, double p) {
    stage = s;
    progress = p;
    notifyListeners();
  }

  static String _displayName(File f) {
    final base = f.uri.pathSegments.isEmpty ? 'IMG' : f.uri.pathSegments.last;
    final dot = base.lastIndexOf('.');
    var name = dot > 0 ? base.substring(0, dot) : base;
    // image_picker uses long scaled_/uuid names; keep it short and tidy.
    name = name.replaceFirst('scaled_', '');
    if (name.length > 14) name = 'IMG_${name.substring(name.length - 4)}';
    return name.toUpperCase();
  }

  @override
  void dispose() {
    _creep?.cancel();
    _cancelToken?.cancel();
    super.dispose();
  }
}
