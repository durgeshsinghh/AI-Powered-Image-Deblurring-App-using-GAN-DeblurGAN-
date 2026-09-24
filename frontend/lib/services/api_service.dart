import 'dart:io';

import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../models/deblur_result.dart';

/// Thin wrapper around [Dio] for talking to the Spring Boot backend's
/// `/api/v1/*` routes (see `../../docs/API_CONTRACT.md`). The frontend never
/// calls the Python ML service directly.
class ApiService {
  final Dio _dio;

  ApiService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              // Both the backend and the ML service it calls can be hosted
              // on Render's free tier, which spins down after 15 minutes
              // idle -- a cold request can take up to ~1 minute per hop to
              // wake up, on top of actual inference time. Keep the connect
              // timeout tighter (just for establishing the TCP connection)
              // but allow a generous receive timeout for the worst case.
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 150),
            ),
          );

  /// Uploads [imageFile] to `POST /api/v1/deblur` and returns the parsed
  /// result. Never throws: any network failure or non-2xx response is
  /// captured and returned as a [DeblurResult] with `success: false` and a
  /// user-friendly [DeblurResult.error] message.
  Future<DeblurResult> deblurImage(File imageFile) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.uri.pathSegments.last,
        ),
      });

      final response = await _dio.post('/api/v1/deblur', data: formData);

      return DeblurResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      String message = 'Could not reach the server. Please try again.';
      if (data is Map<String, dynamic> && data['error'] is String) {
        message = data['error'] as String;
      } else if (data is String && data.isNotEmpty) {
        message = data;
      }
      return DeblurResult(success: false, error: message);
    } catch (e) {
      return DeblurResult(
        success: false,
        error: 'Something went wrong while processing the image.',
      );
    }
  }

  /// Checks `GET /api/v1/health`. Returns true only on an HTTP 200 response.
  Future<bool> checkBackendHealth() async {
    try {
      final response = await _dio.get('/api/v1/health');
      return response.statusCode == 200;
    } on DioException {
      return false;
    }
  }
}
