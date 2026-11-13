import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/process_mode.dart';
import '../providers/settings_provider.dart';
import 'camera_sheet.dart';
import 'processing_screen.dart';

/// Shared navigation helpers for the pick → process → result flow.
class DeblurFlow {
  DeblurFlow._();

  static final _picker = ImagePicker();

  static Future<File?> pickOne(ImageSource source) async {
    final x = await _picker.pickImage(source: source, imageQuality: 90);
    return x == null ? null : File(x.path);
  }

  static Future<List<File>> pickMany() async {
    final xs = await _picker.pickMultiImage(imageQuality: 90);
    return xs.map((x) => File(x.path)).toList();
  }

  /// Opens the in-app camera sheet (3/4 height, not the full-screen system
  /// camera). Returns the captured photo, or null if cancelled.
  static Future<File?> takePhoto(BuildContext context) => CameraSheet.show(context);

  /// Picks one photo and goes straight to Processing (Home buttons).
  static Future<void> pickAndRun(BuildContext context, ImageSource source) async {
    final file = source == ImageSource.camera
        ? await takePhoto(context)
        : await pickOne(source);
    if (file == null || !context.mounted) return;
    await run(context, [file]);
  }

  static Future<void> run(
    BuildContext context,
    List<File> files, {
    ProcessMode? mode,
  }) async {
    if (files.isEmpty) return;
    final m = mode ?? context.read<SettingsProvider>().mode;
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => ProcessingScreen(files: files, mode: m),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child),
      ),
    );
  }
}
