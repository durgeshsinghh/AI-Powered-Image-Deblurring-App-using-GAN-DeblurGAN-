import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/server_status_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/before_after_slider.dart';
import '../widgets/ui.dart';
import 'main_shell.dart';

/// Three-step intro shown on first launch.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();

  void _go(int page) => _pages.animateToPage(
    page,
    duration: const Duration(milliseconds: 380),
    curve: Curves.easeOutCubic,
  );

  Future<void> _finish() async {
    await context.read<SettingsProvider>().completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) => const MainShell(),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: PageView(
        controller: _pages,
        children: [
          _IntroPage(onNext: () => _go(1), onSkip: _finish),
          _OfflinePage(onNext: () => _go(2), onBack: () => _go(0), onSkip: _finish),
          _PermissionsPage(onBack: () => _go(1), onDone: _finish),
        ],
      ),
    );
  }
}

class _NextRow extends StatelessWidget {
  final String label;
  final VoidCallback onNext;
  final VoidCallback? onLabelTap;

  const _NextRow({required this.label, required this.onNext, this.onLabelTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: onLabelTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(label, style: AppText.mono(13, color: AppColors.textMuted)),
          ),
        ),
        AccentCircleButton(
          icon: LucideIcons.arrowRight,
          size: 68,
          onTap: onNext,
          semanticLabel: 'Next',
        ),
      ],
    );
  }
}

class _SkipButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool glass;

  const _SkipButton({required this.onTap, this.glass = false});

  @override
  Widget build(BuildContext context) {
    final text = Text('Skip', style: AppText.sans(14, weight: FontWeight.w500));
    return Pressable(
      onTap: onTap,
      child: glass
          ? Glass.dark(
              radius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: text,
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.textA(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: text,
            ),
    );
  }
}

/// 1 — full-bleed before/after photo.
class _IntroPage extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _IntroPage({required this.onNext, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, c) {
        final photoH = c.maxHeight * 0.70;
        double y(double designY) => photoH * designY / 590;
        return Stack(
          children: [
            SizedBox(
              height: photoH,
              width: double.infinity,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: BeforeAfterSlider(
                      before: AssetImage('assets/images/city-blur.jpg'),
                      after: AssetImage('assets/images/city.jpg'),
                      initial: 180 / 390,
                      knobY: 322 / 590,
                    ),
                  ),
                  const Positioned(left: 0, right: 0, bottom: 0, child: BottomFade(height: 200)),
                  Positioned(
                    left: 24,
                    right: 24,
                    top: y(108),
                    height: y(382),
                    child: const ViewfinderBrackets(size: 20),
                  ),
                  Positioned(
                    left: 36,
                    top: y(420),
                    child: const IgnorePointer(child: MonoChip('BLUR · 45PX', glass: true)),
                  ),
                  Positioned(
                    right: 36,
                    top: y(420),
                    child: const IgnorePointer(
                      child: MonoChip('RESTORED', glass: true, color: AppColors.accent),
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
                children: [
                  const Expanded(child: StepBars(step: 1)),
                  const SizedBox(width: 16),
                  _SkipButton(onTap: onSkip, glass: true),
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: pad.bottom + 32,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Headline([Headline.sans('Shaky shot?\n', 46), Headline.serif('Make it sharp', 52)]),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      'A GAN trained on motion blur pulls real detail back out of photos you thought were ruined.',
                      style: AppText.body(16),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _NextRow(label: '01 / 03', onNext: onNext),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 2 — server + on-phone cache.
class _OfflinePage extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  const _OfflinePage({required this.onNext, required this.onBack, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(0, pad.top + 12, 0, pad.bottom + 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Expanded(child: StepBars(step: 2)),
                const SizedBox(width: 16),
                _SkipButton(onTap: onSkip),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('assets/images/skyline.jpg', fit: BoxFit.cover),
                    const Positioned(
                      left: 14,
                      right: 14,
                      top: 14,
                      child: _ModeTile(
                        icon: LucideIcons.cloud,
                        overline: 'ONLINE',
                        title: 'Server · full model',
                        trailing: 'MAX',
                      ),
                    ),
                    const Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: _ModeTile(
                        icon: LucideIcons.smartphone,
                        overline: 'CACHED',
                        title: 'On your phone',
                        trailing: 'NO NET',
                        highlighted: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Headline([Headline.sans('Online, or\n', 42), Headline.serif('off the grid', 48)]),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 310),
                  child: Text(
                    'Every result is cached on your phone, so the same photo is never processed twice.',
                    style: AppText.body(15),
                  ),
                ),
                const SizedBox(height: 28),
                _NextRow(label: '← 02 / 03', onNext: onNext, onLabelTap: onBack),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final IconData icon;
  final String overline;
  final String title;
  final String trailing;
  final bool highlighted;

  const _ModeTile({
    required this.icon,
    required this.overline,
    required this.title,
    required this.trailing,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Glass.dark(
      radius: 22,
      blur: 20,
      color: AppColors.bgA(0.58),
      borderColor: highlighted ? AppColors.accent : AppColors.textA(0.12),
      topHighlight: false,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: highlighted ? AppColors.accent : AppColors.textA(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: highlighted ? AppColors.onAccent : AppColors.text),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(overline, style: AppText.mono(11, color: highlighted ? AppColors.accent : AppColors.textChip)),
                const SizedBox(height: 3),
                Text(title, style: AppText.title(16)),
              ],
            ),
          ),
          Text(trailing, style: AppText.mono(11, color: AppColors.textChip, spacing: 0)),
        ],
      ),
    );
  }
}

/// 3 — three quick things.
class _PermissionsPage extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onDone;

  const _PermissionsPage({required this.onBack, required this.onDone});

  @override
  State<_PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<_PermissionsPage> {
  bool _photos = true;
  bool _camera = false;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final server = context.watch<ServerStatusProvider>().status;
    final (serverBtn, serverOn) = switch (server) {
      ServerStatus.online => ('Ready', true),
      ServerStatus.checking => ('Waking…', false),
      ServerStatus.offline => ('Retry', false),
    };

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, pad.top + 12, 24, pad.bottom + 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height - pad.top - pad.bottom - 44,
        ),
        child: IntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconCircleButton(icon: LucideIcons.chevronLeft, onTap: widget.onBack, semanticLabel: 'Back'),
                  const SizedBox(width: 16),
                  const Expanded(child: StepBars(step: 3)),
                ],
              ),
              const SizedBox(height: 36),
              Headline([Headline.sans('Three quick\n', 46), Headline.serif('things', 52)]),
              const SizedBox(height: 14),
              Text(
                'We only read photos you choose, and results are stored on your phone.',
                style: AppText.body(15),
              ),
              const SizedBox(height: 36),
              _PermRow(
                num: '01',
                title: 'Photo library',
                sub: 'Pick shots, save results',
                button: _photos ? 'Allowed' : 'Allow',
                on: _photos,
                onTap: () => setState(() => _photos = !_photos),
              ),
              _PermRow(
                num: '02',
                title: 'Camera',
                sub: 'Shoot and fix instantly',
                button: _camera ? 'Allowed' : 'Allow',
                on: _camera,
                onTap: () => setState(() => _camera = !_camera),
              ),
              _PermRow(
                num: '03',
                title: 'Deblur server',
                sub: 'Wake the model up now',
                button: serverBtn,
                on: serverOn,
                onTap: serverOn ? null : context.read<ServerStatusProvider>().check,
              ),
              const Spacer(),
              const SizedBox(height: 24),
              AccentButton(
                label: 'Start deblurring',
                icon: LucideIcons.arrowRight,
                iconAfter: true,
                height: 60,
                onTap: widget.onDone,
              ),
              const SizedBox(height: 10),
              Center(
                child: GestureDetector(
                  onTap: widget.onDone,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text('Maybe later', style: AppText.sans(14, color: AppColors.textMuted)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermRow extends StatelessWidget {
  final String num;
  final String title;
  final String sub;
  final String button;
  final bool on;
  final VoidCallback? onTap;

  const _PermRow({
    required this.num,
    required this.title,
    required this.sub,
    required this.button,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.textA(0.12))),
      ),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(num, style: AppText.serif(34, color: AppColors.textFaint))),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.title(17)),
                const SizedBox(height: 4),
                Text(sub, style: AppText.sans(14, color: AppColors.textMuted)),
              ],
            ),
          ),
          Pressable(
            onTap: onTap ?? () {},
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 40,
              constraints: const BoxConstraints(minWidth: 84),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? Colors.transparent : AppColors.text,
                borderRadius: BorderRadius.circular(20),
                border: on ? Border.all(color: AppColors.accent) : null,
              ),
              child: Text(
                button,
                style: AppText.button(13, color: on ? AppColors.accent : AppColors.onAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
