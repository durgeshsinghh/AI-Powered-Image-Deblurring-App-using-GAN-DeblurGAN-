import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/process_mode.dart';
import '../providers/deblur_provider.dart';
import '../providers/history_provider.dart';
import '../providers/server_status_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'result_screen.dart';

/// Full-screen photo with a lime scan line sweeping over it while the
/// server works; when the result arrives, a final sweep reveals the sharp
/// image before moving on to the Result screen.
class ProcessingScreen extends StatefulWidget {
  final List<File> files;
  final ProcessMode mode;

  const ProcessingScreen({super.key, required this.files, required this.mode});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final DeblurProvider _job = context.read<DeblurProvider>();
  Timer? _clock;
  ImageProvider? _sharp;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _job.addListener(_onJob);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    final settings = context.read<SettingsProvider>();
    _sharp = null;
    _reveal.reset();
    if (!_scan.isAnimating) _scan.repeat();
    _job.run(
      widget.files,
      mode: widget.mode,
      history: context.read<HistoryProvider>(),
      useCache: settings.cacheResults,
      wifiOnly: settings.wifiOnly,
    );
  }

  Future<void> _onJob() async {
    if (!mounted || _navigated) return;
    if (_job.stage == DeblurStage.done && _job.results.isNotEmpty) {
      _navigated = true;
      if (_job.cachedFlags.contains(false)) {
        context.read<ServerStatusProvider>().markOnline();
      }
      final last = _job.results.last;
      final sharp = FileImage(File(last.deblurredPath));
      await precacheImage(sharp, context).catchError((_) {});
      if (!mounted) return;
      setState(() => _sharp = sharp);
      _scan.stop();
      await _reveal.forward();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, _, _) => ResultScreen(
            entry: last,
            cached: _job.cachedFlags.last,
            batchCount: _job.results.length,
          ),
          transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
        ),
      );
    } else if (_job.stage == DeblurStage.failed) {
      _scan.stop();
    }
  }

  void _cancel() {
    if (_job.isRunning) _job.cancel();
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _job.removeListener(_onJob);
    if (_job.isRunning) _job.cancel();
    _clock?.cancel();
    _scan.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final job = context.watch<DeblurProvider>();
    final file = job.currentFile ?? widget.files.first;
    final pad = MediaQuery.paddingOf(context);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _job.isRunning) _job.cancel();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: LayoutBuilder(
          builder: (context, c) {
            final h = c.maxHeight;
            return Stack(
              children: [
                Positioned.fill(child: _ScanImage(
                  blurred: FileImage(file),
                  sharp: _sharp,
                  scan: _scan,
                  reveal: _reveal,
                )),
                // Viewfinder brackets.
                Positioned(
                  left: 24,
                  right: 24,
                  top: h * 0.142,
                  bottom: h - h * 0.618,
                  child: const ViewfinderBrackets(size: 22),
                ),
                // PASS / PHOTO tag riding the scan line.
                AnimatedBuilder(
                  animation: Listenable.merge([_scan, _reveal]),
                  builder: (context, _) {
                    final y = _lineY(h);
                    return Positioned(
                      top: y - 13,
                      right: 32,
                      child: _AccentTag(_tagText(job)),
                    );
                  },
                ),
                // Top bar.
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
                        onTap: _cancel,
                        semanticLabel: 'Back',
                      ),
                      MonoChip(
                        'SERVER · CLOUD',
                        glass: true,
                        dotColor: AppColors.accent,
                        radius: 999,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ],
                  ),
                ),
                // Bottom panel.
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: pad.bottom + 20,
                  child: job.stage == DeblurStage.failed
                      ? _FailedPanel(
                          message: job.error ?? 'Something went wrong.',
                          onRetry: _start,
                          onBack: _cancel,
                        )
                      : _ProgressPanel(job: job, onCancel: _cancel),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  double _lineY(double h) {
    if (_sharp != null) return h * _reveal.value;
    // Sweep the upper ~75% of the screen so the line stays above the panel.
    return h * 0.75 * Curves.easeInOut.transform(_scan.value);
  }

  String _tagText(DeblurProvider job) {
    if (job.files.length > 1) return 'PHOTO ${job.index + 1}/${job.files.length}';
    final pass = (job.progress * 4).ceil().clamp(1, 4);
    return 'PASS $pass/4';
  }
}

class _ScanImage extends StatelessWidget {
  final ImageProvider blurred;
  final ImageProvider? sharp;
  final Animation<double> scan;
  final Animation<double> reveal;

  const _ScanImage({
    required this.blurred,
    required this.sharp,
    required this.scan,
    required this.reveal,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        return AnimatedBuilder(
          animation: Listenable.merge([scan, reveal]),
          builder: (context, _) {
            final y = sharp != null
                ? h * reveal.value
                : h * 0.75 * Curves.easeInOut.transform(scan.value);
            return Stack(
              fit: StackFit.expand,
              children: [
                Image(image: blurred, fit: BoxFit.cover, gaplessPlayback: true),
                if (sharp != null)
                  ClipRect(
                    clipper: _TopClipper(y),
                    child: Image(image: sharp!, fit: BoxFit.cover, gaplessPlayback: true),
                  ),
                // Lime band trailing above the line.
                Positioned(
                  top: y - 120,
                  left: 0,
                  right: 0,
                  height: 120,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.accentA(0), AppColors.accentA(0.16)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: y - 1,
                  left: 0,
                  right: 0,
                  height: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      boxShadow: [
                        BoxShadow(color: AppColors.accentA(0.45), blurRadius: 24, spreadRadius: 6),
                      ],
                    ),
                  ),
                ),
                // Readability scrim.
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, 0.2, 0.5, 0.78],
                        colors: [
                          AppColors.bgA(0.45),
                          AppColors.bgA(0),
                          AppColors.bgA(0),
                          AppColors.bgA(0.9),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TopClipper extends CustomClipper<Rect> {
  final double height;

  _TopClipper(this.height);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width, height);

  @override
  bool shouldReclip(_TopClipper old) => old.height != height;
}

class _AccentTag extends StatelessWidget {
  final String text;

  const _AccentTag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [BoxShadow(color: AppColors.accentA(0.16), blurRadius: 28, offset: const Offset(0, 10))],
      ),
      child: Text(text, style: AppText.mono(10, color: AppColors.onAccent)),
    );
  }
}

const _panelColor = Color(0xB8161618); // rgba(22,22,24,0.72)
const _panelShadow = [
  BoxShadow(color: Color(0x99000000), blurRadius: 60, offset: Offset(0, 24)),
];

class _ProgressPanel extends StatelessWidget {
  final DeblurProvider job;
  final VoidCallback onCancel;

  const _ProgressPanel({required this.job, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final pct = (job.overall * 100).round().clamp(0, 100);
    final filled = (job.overall * 20).floor();
    final elapsed = job.startedAt == null
        ? Duration.zero
        : DateTime.now().difference(job.startedAt!);
    final cacheHit = job.cacheHit;
    final waking = !cacheHit &&
        (job.stage == DeblurStage.upload || job.stage == DeblurStage.inference) &&
        elapsed.inSeconds >= 12;

    final title = cacheHit
        ? 'Found in cache'
        : waking
            ? 'Waking the server'
            : 'Restoring detail';
    final label = waking ? 'FIRST RUN CAN TAKE ~1 MIN' : 'DEBLURGAN';

    return Glass(
      radius: 32,
      blur: 28,
      color: _panelColor,
      borderColor: AppColors.textA(0.10),
      shadows: _panelShadow,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MonoLabel(label),
                    const SizedBox(height: 4),
                    Text(title, style: AppText.sans(20, weight: FontWeight.w600, letterSpacing: -0.4)),
                  ],
                ),
              ),
              Text('$pct%', style: AppText.serif(64, color: AppColors.accent).copyWith(height: 0.8)),
            ],
          ),
          const SizedBox(height: 18),
          Semantics(
            label: 'Deblurring progress',
            value: '$pct%',
            child: Row(
              children: [
                for (var i = 0; i < 20; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 18,
                      decoration: BoxDecoration(
                        color: i < filled ? AppColors.accent : AppColors.textA(0.12),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _step('UPLOAD', 0, job.stage),
              _step('INFERENCE', 1, job.stage),
              _step('CACHE', 2, job.stage),
            ],
          ),
          const SizedBox(height: 18),
          SoftButton(label: 'Cancel', height: 48, fontSize: 15, onTap: onCancel),
        ],
      ),
    );
  }

  Widget _step(String name, int i, DeblurStage stage) {
    final current = switch (stage) {
      DeblurStage.upload => 0,
      DeblurStage.inference => 1,
      DeblurStage.cache => 2,
      DeblurStage.done => 3,
      _ => 0,
    };
    final (mark, color) = i < current
        ? ('✓', AppColors.textMuted)
        : i == current
            ? ('●', AppColors.accent)
            : ('○', AppColors.textFaint);
    return Text('$mark $name', style: AppText.mono(11, color: color, spacing: 0.06));
  }
}

class _FailedPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _FailedPanel({required this.message, required this.onRetry, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 32,
      blur: 28,
      color: _panelColor,
      borderColor: AppColors.textA(0.10),
      shadows: _panelShadow,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MonoLabel('SOMETHING WENT WRONG', color: AppColors.danger),
          const SizedBox(height: 6),
          Text("Couldn't deblur", style: AppText.sans(20, weight: FontWeight.w600, letterSpacing: -0.4)),
          const SizedBox(height: 8),
          Text(message, style: AppText.body(14)),
          const SizedBox(height: 20),
          AccentButton(label: 'Try again', icon: LucideIcons.refreshCw, height: 52, onTap: onRetry),
          const SizedBox(height: 10),
          SoftButton(label: 'Back', height: 48, fontSize: 15, onTap: onBack),
        ],
      ),
    );
  }
}
