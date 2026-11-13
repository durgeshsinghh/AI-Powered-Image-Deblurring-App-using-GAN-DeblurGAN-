import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// In-app camera shown as a ~3/4-height bottom sheet (instead of jumping to
/// the full-screen system camera). Returns the captured photo, or null.
class CameraSheet extends StatefulWidget {
  const CameraSheet({super.key});

  static Future<File?> show(BuildContext context) {
    return showModalBottomSheet<File>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x9E050506),
      builder: (_) => const CameraSheet(),
    );
  }

  @override
  State<CameraSheet> createState() => _CameraSheetState();
}

class _CameraSheetState extends State<CameraSheet> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  int _camIndex = 0;
  CameraController? _controller;
  FlashMode _flash = FlashMode.off;
  File? _shot;
  bool _busy = false;
  bool _starting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    if (mounted) setState(() => _error = null);
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = 'No camera found on this device.');
        return;
      }
      final back = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      _camIndex = back >= 0 ? back : 0;
      await _start();
    } on CameraException catch (e) {
      _handle(e);
    }
  }

  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    try {
      await _startInner();
    } finally {
      _starting = false;
    }
  }

  Future<void> _startInner() async {
    final old = _controller;
    _controller = null;
    if (mounted) setState(() {});
    await old?.dispose();

    final c = CameraController(
      _cameras[_camIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await c.initialize();
      await c.setFlashMode(_flash).catchError((_) {});
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _error = null;
      });
    } on CameraException catch (e) {
      await c.dispose();
      _handle(e);
    }
  }

  void _handle(CameraException e) {
    if (!mounted) return;
    final denied = e.code.contains('AccessDenied') || e.code.contains('Restricted');
    setState(() {
      _error = denied
          ? 'Camera access is off. Allow it in system settings to take photos here.'
          : 'The camera could not start.';
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (state == AppLifecycleState.inactive) {
      _controller = null;
      c?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && c == null && _shot == null) {
      // Also covers the first-run permission prompt: starting the camera
      // while that dialog is up fails, so retry once we're back in focus.
      _error = null;
      _cameras.isEmpty ? _init() : _start();
    }
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final x = await c.takePicture();
      if (mounted) setState(() => _shot = File(x.path));
    } on CameraException catch (e) {
      _handle(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _flip() async {
    if (_cameras.length < 2 || _busy) return;
    _camIndex = (_camIndex + 1) % _cameras.length;
    await _start();
  }

  Future<void> _toggleFlash() async {
    final next = switch (_flash) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    try {
      await _controller?.setFlashMode(next);
      setState(() => _flash = next);
    } catch (_) {
      if (mounted) showAppSnack(context, 'Flash is not available on this camera.');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 8 + bottom),
      child: Container(
        height: size.height * 0.78,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: AppColors.textA(0.10)),
          boxShadow: const [
            BoxShadow(color: Color(0x80000000), blurRadius: 60, offset: Offset(0, -20)),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.textA(0.22),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Headline([
                      Headline.sans(_shot == null ? 'Take a ' : 'Use this ', 30),
                      Headline.serif(_shot == null ? 'photo' : 'shot', 36),
                    ]),
                  ),
                  IconCircleButton(
                    icon: LucideIcons.x,
                    semanticLabel: 'Close camera',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _viewport()),
            const SizedBox(height: 18),
            _shot == null ? _captureControls() : _reviewControls(),
          ],
        ),
      ),
    );
  }

  Widget _viewport() {
    final c = _controller;
    Widget content;
    if (_shot != null) {
      content = Image.file(_shot!, fit: BoxFit.cover);
    } else if (_error != null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.camera, size: 32, color: AppColors.textFaint),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: AppText.body(14)),
              const SizedBox(height: 16),
              SoftButton(label: 'Try again', icon: LucideIcons.refreshCw, height: 44, onTap: _init),
            ],
          ),
        ),
      );
    } else if (c == null || !c.value.isInitialized) {
      content = const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
        ),
      );
    } else {
      // Fill the frame (cover), keeping the preview's aspect ratio.
      content = FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: c.value.previewSize?.height ?? 1080,
          height: c.value.previewSize?.width ?? 1920,
          child: CameraPreview(c),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            if (_shot == null && _error == null)
              const Padding(
                padding: EdgeInsets.all(18),
                child: ViewfinderBrackets(size: 20),
              ),
            if (_shot == null && _error == null)
              Positioned(
                top: 18,
                left: 0,
                right: 0,
                child: Center(
                  child: MonoChip(
                    'HOLD STILL · OR DON\'T',
                    glass: true,
                    fontSize: 10,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _captureControls() {
    final flashIcon = switch (_flash) {
      FlashMode.off => LucideIcons.zapOff,
      FlashMode.auto => LucideIcons.zap,
      _ => LucideIcons.zap,
    };
    final flashLabel = switch (_flash) {
      FlashMode.off => 'OFF',
      FlashMode.auto => 'AUTO',
      _ => 'ON',
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _SideButton(
          icon: flashIcon,
          label: flashLabel,
          active: _flash != FlashMode.off,
          onTap: _controller == null ? null : _toggleFlash,
        ),
        Pressable(
          semanticLabel: 'Take photo',
          onTap: _controller == null ? null : _capture,
          child: Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent, width: 3),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _busy ? AppColors.accentA(0.5) : AppColors.accent,
              ),
            ),
          ),
        ),
        _SideButton(
          icon: LucideIcons.switchCamera,
          label: 'FLIP',
          onTap: _cameras.length > 1 && _controller != null ? _flip : null,
        ),
      ],
    );
  }

  Widget _reviewControls() {
    return Row(
      children: [
        Expanded(
          child: SoftButton(
            label: 'Retake',
            icon: LucideIcons.refreshCw,
            outlined: true,
            height: 58,
            fontSize: 15,
            onTap: () {
              setState(() => _shot = null);
              if (_controller == null) _start();
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AccentButton(
            label: 'Use photo',
            icon: LucideIcons.check,
            onTap: () => Navigator.of(context).pop(_shot),
          ),
        ),
      ],
    );
  }
}

class _SideButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _SideButton({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.textA(0.08),
              ),
              child: Icon(icon, size: 20, color: active ? AppColors.accent : AppColors.text),
            ),
            const SizedBox(height: 6),
            Text(label, style: AppText.mono(10, color: active ? AppColors.accent : AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
