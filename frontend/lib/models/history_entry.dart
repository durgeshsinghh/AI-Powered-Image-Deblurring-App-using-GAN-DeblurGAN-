/// A single saved deblur result: paths to the original (blurred) and
/// deblurred images on disk, plus metadata. Persisted locally on-device via
/// [HistoryService] -- there is no server-side history (the backend is
/// stateless by design, see docs/API_CONTRACT.md).
///
/// [hash] (SHA-256 of the original image bytes) doubles as the result-cache
/// key, so the same photo is never sent to the server twice.
class HistoryEntry {
  final String id;
  final String originalPath;
  final String deblurredPath;
  final DateTime createdAt;
  final int? processingTimeMs;
  final String? hash;

  /// Where the photo was processed: `server` or `device`.
  final String mode;

  /// Display name, usually the picked file's name without extension.
  final String name;

  const HistoryEntry({
    required this.id,
    required this.originalPath,
    required this.deblurredPath,
    required this.createdAt,
    this.processingTimeMs,
    this.hash,
    this.mode = 'server',
    this.name = 'IMG',
  });

  bool get isOnDevice => mode == 'device';

  Map<String, dynamic> toJson() => {
    'id': id,
    'originalPath': originalPath,
    'deblurredPath': deblurredPath,
    'createdAt': createdAt.toIso8601String(),
    'processingTimeMs': processingTimeMs,
    'hash': hash,
    'mode': mode,
    'name': name,
  };

  /// Tolerates entries written by older app versions (no hash/mode/name).
  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    return HistoryEntry(
      id: id,
      originalPath: json['originalPath'] as String,
      deblurredPath: json['deblurredPath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      processingTimeMs: json['processingTimeMs'] as int?,
      hash: json['hash'] as String?,
      mode: json['mode'] as String? ?? 'server',
      name: json['name'] as String? ??
          'IMG_${id.substring(id.length > 4 ? id.length - 4 : 0)}',
    );
  }
}
