import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../app_keys.dart';
import '../models/history_entry.dart';
import '../theme/app_theme.dart';
import '../widgets/before_after_slider.dart';
import '../widgets/ui.dart';
import 'new_deblur_sheet.dart';

/// Full-bleed draggable before/after comparison plus save/share actions.
class ResultScreen extends StatefulWidget {
  final HistoryEntry entry;
  final bool cached;
  final int batchCount;

  const ResultScreen({
    super.key,
    required this.entry,
    this.cached = false,
    this.batchCount = 1,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _saving = false;

  HistoryEntry get e => widget.entry;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final bytes = await File(e.deblurredPath).readAsBytes();
      await Gal.putImageBytes(bytes, name: 'deblur_${e.id}');
      if (mounted) showAppSnack(context, 'Saved to your gallery.');
    } on GalException catch (err) {
      if (mounted) {
        showAppSnack(
          context,
          err.type == GalExceptionType.permissionDenied
              ? 'Allow photo access in system settings to save.'
              : 'Could not save the photo.',
        );
      }
    } catch (_) {
      if (mounted) showAppSnack(context, 'Could not save the photo.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share() async {
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(e.deblurredPath, mimeType: 'image/png')]),
      );
    } catch (_) {
      if (mounted) showAppSnack(context, 'Sharing is not available here.');
    }
  }

  void _newPhoto() {
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst);
    final ctx = appNavigatorKey.currentContext;
    if (ctx != null) NewDeblurSheet.show(ctx);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);
    // Keep at least ~300px below the photo for the chips, headline and buttons.
    final photoH = (size.height * 0.71).clamp(0.0, size.height - pad.bottom - 300);
    final seconds = e.processingTimeMs == null ? null : e.processingTimeMs! / 1000;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          SizedBox(
            height: photoH,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: BeforeAfterSlider(
                    before: FileImage(File(e.originalPath)),
                    after: FileImage(File(e.deblurredPath)),
                    knobY: 300 / 600,
                  ),
                ),
                const Positioned(left: 0, right: 0, bottom: 0, child: BottomFade(height: 140)),
                Positioned(
                  left: 20,
                  top: photoH * 0.78,
                  child: const IgnorePointer(child: MonoChip('BEFORE', glass: true)),
                ),
                Positioned(
                  right: 20,
                  top: photoH * 0.78,
                  child: const IgnorePointer(
                    child: MonoChip('AFTER', glass: true, color: AppColors.accent),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: pad.top + 12,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconCircleButton(
                  icon: LucideIcons.chevronLeft,
                  size: 44,
                  glass: true,
                  semanticLabel: 'Back',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                MonoChip(
                  'DRAG TO COMPARE',
                  glass: true,
                  radius: 999,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                IconCircleButton(
                  icon: LucideIcons.share,
                  size: 44,
                  glass: true,
                  semanticLabel: 'Share',
                  onTap: _share,
                ),
              ],
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            top: photoH - 60,
            bottom: pad.bottom + 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    MonoChip(
                      e.isOnDevice ? 'ON-DEVICE MODEL' : 'SERVER MODEL',
                      background: AppColors.textA(0.08),
                    ),
                    if (widget.cached)
                      MonoChip('⚡ CACHED', color: AppColors.accent, background: AppColors.accentA(0.12))
                    else if (seconds != null)
                      MonoChip(
                        '${seconds.toStringAsFixed(1)} S',
                        color: AppColors.accent,
                        background: AppColors.accentA(0.12),
                      ),
                    if (widget.batchCount > 1)
                      MonoChip('${widget.batchCount} PHOTOS SAVED', background: AppColors.textA(0.08)),
                  ],
                ),
                const SizedBox(height: 14),
                Headline([Headline.sans('Looking ', 36), Headline.serif('sharp', 42)]),
                const Spacer(),
                AccentButton(
                  label: _saving ? 'Saving…' : 'Save to gallery',
                  icon: LucideIcons.download,
                  onTap: _saving ? null : _save,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SoftButton(
                        label: 'Try on-device',
                        outlined: true,
                        onTap: () => showAppSnack(
                          context,
                          "The on-device model isn't available yet — results come from the server.",
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: SoftButton(label: 'New photo', outlined: true, onTap: _newPhoto)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
