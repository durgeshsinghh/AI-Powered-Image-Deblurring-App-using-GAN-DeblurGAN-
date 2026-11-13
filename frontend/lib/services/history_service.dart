import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/history_entry.dart';

/// Persists deblur results on-device: copies the original and deblurred
/// images into the app's documents directory and keeps a JSON index of
/// [HistoryEntry] in [SharedPreferences]. Purely local -- nothing is sent
/// to the backend, which stays stateless.
class HistoryService {
  static const _indexKey = 'history_index_v1';

  Future<Directory> _historyDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final historyDir = Directory('${dir.path}/deblur_history');
    if (!await historyDir.exists()) {
      await historyDir.create(recursive: true);
    }
    return historyDir;
  }

  Future<List<HistoryEntry>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_indexKey);
    if (raw == null || raw.isEmpty) return [];

    final list = (jsonDecode(raw) as List)
        .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
        // Drop entries whose files were removed outside the app.
        .where((e) => File(e.deblurredPath).existsSync())
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<HistoryEntry> saveEntry({
    required File original,
    required Uint8List deblurredBytes,
    int? processingTimeMs,
    String? hash,
    String mode = 'server',
    String? name,
  }) async {
    final historyDir = await _historyDir();

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final originalCopy = await original.copy(
      '${historyDir.path}/${id}_original.jpg',
    );
    final deblurredFile = File('${historyDir.path}/${id}_deblurred.png');
    await deblurredFile.writeAsBytes(deblurredBytes);

    final entry = HistoryEntry(
      id: id,
      originalPath: originalCopy.path,
      deblurredPath: deblurredFile.path,
      createdAt: DateTime.now(),
      processingTimeMs: processingTimeMs,
      hash: hash,
      mode: mode,
      name: name ?? 'IMG_${id.substring(id.length - 4)}',
    );

    final current = await loadHistory();
    current.insert(0, entry);
    await _persist(current);
    return entry;
  }

  Future<void> deleteEntry(HistoryEntry entry) async {
    await _deleteFiles(entry);
    final current = await loadHistory();
    current.removeWhere((e) => e.id == entry.id);
    await _persist(current);
  }

  Future<void> clearAll() async {
    for (final e in await loadHistory()) {
      await _deleteFiles(e);
    }
    await _persist([]);
  }

  /// Total bytes used by saved originals + results.
  Future<int> totalBytes(List<HistoryEntry> entries) async {
    var total = 0;
    for (final e in entries) {
      for (final path in [e.originalPath, e.deblurredPath]) {
        final f = File(path);
        if (await f.exists()) total += await f.length();
      }
    }
    return total;
  }

  Future<void> _deleteFiles(HistoryEntry entry) async {
    for (final path in [entry.originalPath, entry.deblurredPath]) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _persist(List<HistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _indexKey,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }
}
