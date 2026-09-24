import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/history_entry.dart';
import '../services/history_service.dart';

/// Holds the list of previously-deblurred photos, loaded from and persisted
/// to on-device storage via [HistoryService].
class HistoryProvider extends ChangeNotifier {
  final HistoryService _service;

  HistoryProvider({HistoryService? service})
    : _service = service ?? HistoryService();

  List<HistoryEntry> entries = [];
  bool isLoading = false;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    entries = await _service.loadHistory();
    isLoading = false;
    notifyListeners();
  }

  Future<void> addEntry({
    required File original,
    required Uint8List deblurredBytes,
    int? processingTimeMs,
  }) async {
    final entry = await _service.saveEntry(
      original: original,
      deblurredBytes: deblurredBytes,
      processingTimeMs: processingTimeMs,
    );
    entries = [entry, ...entries];
    notifyListeners();
  }

  Future<void> deleteEntry(HistoryEntry entry) async {
    await _service.deleteEntry(entry);
    entries = entries.where((e) => e.id != entry.id).toList();
    notifyListeners();
  }
}
