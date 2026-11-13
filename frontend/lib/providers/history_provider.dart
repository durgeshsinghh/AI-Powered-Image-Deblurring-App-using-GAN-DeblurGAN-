import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/history_entry.dart';
import '../services/history_service.dart';

/// Holds the list of previously-deblurred photos, loaded from and persisted
/// to on-device storage via [HistoryService]. Also serves as the result
/// cache, looked up by image hash.
class HistoryProvider extends ChangeNotifier {
  final HistoryService _service;

  HistoryProvider({HistoryService? service})
    : _service = service ?? HistoryService();

  List<HistoryEntry> entries = [];
  bool isLoading = false;
  bool _loaded = false;
  int totalBytes = 0;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    try {
      entries = await _service.loadHistory();
      totalBytes = await _service.totalBytes(entries);
    } catch (_) {
      entries = [];
    }
    _loaded = true;
    isLoading = false;
    notifyListeners();
  }

  Future<void> ensureLoaded() async {
    if (!_loaded && !isLoading) await load();
  }

  HistoryEntry? findByHash(String hash, String mode) {
    for (final e in entries) {
      if (e.hash == hash && e.mode == mode && File(e.deblurredPath).existsSync()) {
        return e;
      }
    }
    return null;
  }

  Future<HistoryEntry> addEntry({
    required File original,
    required Uint8List deblurredBytes,
    int? processingTimeMs,
    String? hash,
    String mode = 'server',
    String? name,
  }) async {
    final entry = await _service.saveEntry(
      original: original,
      deblurredBytes: deblurredBytes,
      processingTimeMs: processingTimeMs,
      hash: hash,
      mode: mode,
      name: name,
    );
    entries = [entry, ...entries];
    totalBytes = await _service.totalBytes(entries);
    notifyListeners();
    return entry;
  }

  Future<void> deleteEntry(HistoryEntry entry) async {
    await _service.deleteEntry(entry);
    entries = entries.where((e) => e.id != entry.id).toList();
    totalBytes = await _service.totalBytes(entries);
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _service.clearAll();
    entries = [];
    totalBytes = 0;
    notifyListeners();
  }
}
