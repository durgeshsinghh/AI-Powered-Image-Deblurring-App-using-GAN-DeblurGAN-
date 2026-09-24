import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';

/// Holds the state of the pick -> submit -> result workflow for the home
/// screen and notifies listeners as it changes.
class DeblurProvider extends ChangeNotifier {
  final ApiService _apiService;
  final ImagePicker _imagePicker;

  DeblurProvider({ApiService? apiService, ImagePicker? imagePicker})
    : _apiService = apiService ?? ApiService(),
      _imagePicker = imagePicker ?? ImagePicker();

  File? pickedImage;
  Uint8List? resultImage;
  int? processingTimeMs;
  bool isLoading = false;
  String? errorMessage;

  /// Picks an image from [source] (gallery or camera), clearing any previous
  /// result/error, and stores it in [pickedImage].
  Future<void> pickImage(ImageSource source) async {
    final XFile? picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
    );
    if (picked == null) return;

    pickedImage = File(picked.path);
    resultImage = null;
    processingTimeMs = null;
    errorMessage = null;
    notifyListeners();
  }

  /// Submits [pickedImage] to the backend for deblurring.
  Future<void> submitForDeblur() async {
    if (pickedImage == null) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final result = await _apiService.deblurImage(pickedImage!);

    if (result.success) {
      resultImage = result.deblurredImageBytes;
      processingTimeMs = result.processingTimeMs;
      errorMessage = null;
    } else {
      errorMessage = result.error ?? 'Failed to deblur image.';
    }

    isLoading = false;
    notifyListeners();
  }

  /// Clears all state back to the initial (empty) state.
  void reset() {
    pickedImage = null;
    resultImage = null;
    processingTimeMs = null;
    isLoading = false;
    errorMessage = null;
    notifyListeners();
  }
}
