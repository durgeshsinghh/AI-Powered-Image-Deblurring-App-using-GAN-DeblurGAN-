import 'dart:convert';
import 'dart:typed_data';

/// Result of a call to the backend's `POST /api/v1/deblur` endpoint.
///
/// Mirrors the JSON shape documented in `../../docs/API_CONTRACT.md`:
/// ```json
/// {
///   "success": true,
///   "originalFilename": "photo.jpg",
///   "processingTimeMs": 842,
///   "deblurredImageBase64": "iVBORw0KGgoAAAANSUhEUgAA..."
/// }
/// ```
/// or, on failure:
/// ```json
/// { "success": false, "error": "..." }
/// ```
class DeblurResult {
  final bool success;
  final String? originalFilename;
  final int? processingTimeMs;
  final Uint8List? deblurredImageBytes;
  final String? error;

  const DeblurResult({
    required this.success,
    this.originalFilename,
    this.processingTimeMs,
    this.deblurredImageBytes,
    this.error,
  });

  /// Builds a [DeblurResult] from the backend's JSON response, base64-decoding
  /// `deblurredImageBase64` into [deblurredImageBytes] when present.
  factory DeblurResult.fromJson(Map<String, dynamic> json) {
    final String? base64Image = json['deblurredImageBase64'] as String?;
    return DeblurResult(
      success: json['success'] as bool? ?? false,
      originalFilename: json['originalFilename'] as String?,
      processingTimeMs: json['processingTimeMs'] as int?,
      deblurredImageBytes:
          base64Image != null && base64Image.isNotEmpty
              ? base64Decode(base64Image)
              : null,
      error: json['error'] as String?,
    );
  }
}
