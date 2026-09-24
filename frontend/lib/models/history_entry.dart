/// A single saved deblur result: paths to the original (blurred) and
/// deblurred images on disk, plus metadata. Persisted locally on-device via
/// [HistoryService] -- there is no server-side history (the backend is
/// stateless by design, see docs/API_CONTRACT.md).
class HistoryEntry {
  final String id;
  final String originalPath;
  final String deblurredPath;
  final DateTime createdAt;
  final int? processingTimeMs;

  const HistoryEntry({
    required this.id,
    required this.originalPath,
    required this.deblurredPath,
    required this.createdAt,
    this.processingTimeMs,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'originalPath': originalPath,
    'deblurredPath': deblurredPath,
    'createdAt': createdAt.toIso8601String(),
    'processingTimeMs': processingTimeMs,
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    id: json['id'] as String,
    originalPath: json['originalPath'] as String,
    deblurredPath: json['deblurredPath'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    processingTimeMs: json['processingTimeMs'] as int?,
  );
}
