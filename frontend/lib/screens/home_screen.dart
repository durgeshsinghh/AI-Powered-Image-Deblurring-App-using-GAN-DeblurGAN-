import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/process_mode.dart';
import '../providers/history_provider.dart';
import '../providers/server_status_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';
import 'flow.dart';
import 'result_screen.dart';

/// Home tab: wordmark + server status, hero card with Gallery/Camera,
/// processing mode, and a strip of recent results.
class HomeScreen extends StatelessWidget {
  final VoidCallback onSeeAll;

  const HomeScreen({super.key, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final settings = context.watch<SettingsProvider>();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, top + 12, 0, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: 'deblur',
                          style: AppText.sans(22, weight: FontWeight.w700, letterSpacing: -0.88),
                          children: [
                            TextSpan(text: '.', style: AppText.sans(22, weight: FontWeight.w700, color: AppColors.accent)),
                          ],
                        ),
                      ),
                      const _ServerChip(),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Headline([
                  Headline.sans('What are we\n', 36),
                  Headline.serif('fixing', 42, dot: false),
                  Headline.sans(' tonight?', 36),
                ]),
                const SizedBox(height: 20),
                const _HeroCard(),
                const SizedBox(height: 20),
                Segmented<ProcessMode>(
                  value: settings.mode,
                  onChanged: settings.setMode,
                  options: [for (final m in ProcessMode.values) (m, m.label)],
                ),
                if (settings.mode == ProcessMode.device) ...[
                  const SizedBox(height: 10),
                  const Center(
                    child: MonoLabel('ON-DEVICE MODEL COMING SOON · RUNS ON SERVER', color: AppColors.textFaint),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const MonoLabel('RECENT'),
                    Pressable(
                      onTap: onSeeAll,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text('See all →', style: AppText.sans(14, weight: FontWeight.w500)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          const _RecentStrip(),
        ],
      ),
    );
  }
}

class _ServerChip extends StatelessWidget {
  const _ServerChip();

  @override
  Widget build(BuildContext context) {
    final status = context.watch<ServerStatusProvider>();
    final (label, dot) = switch (status.status) {
      ServerStatus.online => ('SERVER ONLINE', AppColors.accent),
      ServerStatus.checking => ('WAKING SERVER', AppColors.textMuted),
      ServerStatus.offline => ('SERVER OFFLINE', AppColors.shake),
    };
    return Pressable(
      onTap: status.check,
      semanticLabel: '$label. Tap to check again.',
      child: MonoChip(
        label,
        dotColor: dot,
        background: AppColors.textA(0.08),
        radius: 999,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: SizedBox(
        height: 250,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/road-blur.jpg', fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.35, 1],
                  colors: [AppColors.bgA(0), AppColors.bgA(0.75)],
                ),
              ),
            ),
            const Positioned(
              top: 18,
              left: 18,
              right: 18,
              height: 16,
              child: ViewfinderBrackets(size: 16, bottom: false),
            ),
            Positioned(
              top: 20,
              left: 46,
              right: 46,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'ƒ/1.8 · 1/15S · ISO 3200',
                      overflow: TextOverflow.ellipsis,
                      style: AppText.mono(10, color: const Color(0xFFE6E1D8)),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: AppColors.shake, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text('SHAKE', style: AppText.mono(10, color: AppColors.shake)),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Row(
                children: [
                  Expanded(
                    child: LightButton(
                      label: 'Gallery',
                      icon: LucideIcons.image,
                      onTap: () => DeblurFlow.pickAndRun(context, ImageSource.gallery),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SoftButton(
                      label: 'Camera',
                      icon: LucideIcons.camera,
                      glass: true,
                      height: 52,
                      fontSize: 15,
                      onTap: () => DeblurFlow.pickAndRun(context, ImageSource.camera),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentStrip extends StatelessWidget {
  const _RecentStrip();

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<HistoryProvider>().entries.take(8).toList();
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(right: 24),
        child: Container(
          height: 120,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.textA(0.10)),
            color: AppColors.textA(0.03),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.image, color: AppColors.textFaint, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Nothing here yet. Your deblurred photos will show up here.',
                  style: AppText.body(14),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 24),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final e = entries[i];
          return Pressable(
            semanticLabel: 'Open ${e.name}',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ResultScreen(entry: e, cached: true)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 140,
                height: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(e.deblurredPath), fit: BoxFit.cover, cacheWidth: 420),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: MonoChip(
                        Fmt.ago(e.createdAt),
                        fontSize: 10,
                        background: AppColors.bgA(0.6),
                        radius: 6,
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
