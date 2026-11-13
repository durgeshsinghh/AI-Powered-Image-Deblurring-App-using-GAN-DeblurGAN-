import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_theme.dart';

/// Plays the Deblur launch animation once (ring sweeps in, snaps sharp,
/// expands off-screen), then fades into [next]. The native launch screen is
/// the same plain dark colour, so the hand-off is seamless.
class SplashScreen extends StatefulWidget {
  final Widget next;

  const SplashScreen({super.key, required this.next});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // Never get stuck on the splash if the animation fails to load.
    Future.delayed(const Duration(seconds: 8), _finish);
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, _, _) => widget.next,
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  /// Starts the animation only once frames are actually reaching the screen
  /// (app start-up can stall the first few frames, which would otherwise
  /// swallow most of the 1.6 s animation).
  Future<void> _play() async {
    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(const Duration(milliseconds: 250));
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _c.forward();
    _finish();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Lottie.asset(
          'assets/lottie/deblur_splash.json',
          controller: _c,
          width: MediaQuery.sizeOf(context).width * 0.9,
          errorBuilder: (_, _, _) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
            return const SizedBox.shrink();
          },
          onLoaded: (comp) {
            _c.duration = comp.duration;
            _play();
          },
        ),
      ),
    );
  }
}
