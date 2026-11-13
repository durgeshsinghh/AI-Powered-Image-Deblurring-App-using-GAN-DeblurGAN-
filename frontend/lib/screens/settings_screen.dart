import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../models/process_mode.dart';
import '../providers/history_provider.dart';
import '../providers/server_status_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';
import 'history_screen.dart' show showConfirmSheet;

/// "Tune it.": model status, processing preferences and storage.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final history = context.watch<HistoryProvider>();
    final top = MediaQuery.paddingOf(context).top;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, top + 20, 24, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Headline([Headline.sans('Tune ', 44), Headline.serif('it', 50)]),
          const SizedBox(height: 22),
          const _ModelCard(),
          const SizedBox(height: 22),
          const MonoLabel('PROCESSING'),
          const SizedBox(height: 6),
          _Row(
            onTap: () => _pickMode(context, settings),
            child: Row(
              children: [
                Expanded(child: Text('Default mode', style: AppText.sans(16))),
                Text('${settings.mode.label} →', style: AppText.sans(15, color: AppColors.textMuted)),
              ],
            ),
          ),
          _ToggleRow(
            label: 'Server only on Wi-Fi',
            sub: 'Save mobile data',
            value: settings.wifiOnly,
            onChanged: settings.setWifiOnly,
          ),
          _ToggleRow(
            label: 'Cache results',
            sub: 'Never process a photo twice',
            value: settings.cacheResults,
            onChanged: settings.setCacheResults,
          ),
          const SizedBox(height: 22),
          const MonoLabel('STORAGE'),
          const SizedBox(height: 6),
          _Row(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cached results', style: AppText.sans(16)),
                      const SizedBox(height: 2),
                      Text(
                        '${Fmt.bytes(history.totalBytes)} · ${history.entries.length} photos',
                        style: AppText.sans(13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                SoftButton(
                  label: 'Clear',
                  height: 38,
                  fontSize: 13,
                  outlined: true,
                  color: AppColors.danger,
                  borderColor: AppColors.dangerBorder,
                  onTap: history.entries.isEmpty
                      ? null
                      : () async {
                          final ok = await showConfirmSheet(
                            context,
                            title: 'Clear all results?',
                            body: 'Every saved original and deblurred photo is removed from this phone.',
                            action: 'Clear all',
                          );
                          if (ok == true) await history.clearAll();
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const MonoLabel('ABOUT'),
          const SizedBox(height: 6),
          const _AboutSection(),
        ],
      ),
    );
  }

  Future<void> _pickMode(BuildContext context, SettingsProvider settings) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x9E050506),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(8, 0, 8, 8 + MediaQuery.paddingOf(ctx).bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppColors.textA(0.10)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Default mode', style: AppText.title(20)),
              const SizedBox(height: 6),
              Text(
                'The on-device model is coming soon; until then every mode runs on the server.',
                style: AppText.body(14),
              ),
              const SizedBox(height: 18),
              Segmented<ProcessMode>(
                value: settings.mode,
                onChanged: (m) {
                  settings.setMode(m);
                  Navigator.of(ctx).pop();
                },
                options: [for (final m in ProcessMode.values) (m, m.label)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Server model card: ring shows whether the backend is reachable.
class _ModelCard extends StatelessWidget {
  const _ModelCard();

  @override
  Widget build(BuildContext context) {
    final status = context.watch<ServerStatusProvider>();
    final (label, color, ring) = switch (status.status) {
      ServerStatus.online => ('SERVER MODEL · ONLINE', AppColors.accent, 1.0),
      ServerStatus.checking => ('SERVER MODEL · WAKING', AppColors.textMuted, 0.35),
      ServerStatus.offline => ('SERVER MODEL · OFFLINE', AppColors.shake, 0.0),
    };
    final host = Uri.tryParse(ApiConfig.baseUrl)?.host ?? ApiConfig.baseUrl;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surfaceHigh, AppColors.surface],
        ),
        border: Border.all(color: AppColors.textA(0.10)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: ring),
                    duration: const Duration(milliseconds: 600),
                    builder: (_, v, _) => CircularProgressIndicator(
                      value: v,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                      color: color,
                      backgroundColor: AppColors.textA(0.12),
                    ),
                  ),
                ),
                const Icon(LucideIcons.cloud, size: 26, color: AppColors.text),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.mono(10, color: color, spacing: 0.1)),
                const SizedBox(height: 4),
                Text('DeblurGAN', style: AppText.title(17)),
                const SizedBox(height: 4),
                Text(
                  host,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.sans(13, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          IconCircleButton(
            icon: LucideIcons.refreshCw,
            semanticLabel: 'Check server again',
            onTap: status.check,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _Row({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.textA(0.10))),
      ),
      child: child,
    );
    return onTap == null
        ? body
        : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: body);
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Row(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.sans(16)),
                const SizedBox(height: 2),
                Text(sub, style: AppText.sans(13, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AppToggle(value: value, onChanged: onChanged, semanticLabel: label),
        ],
      ),
    );
  }
}

/// App version, model, backend and project details.
class _AboutSection extends StatelessWidget {
  const _AboutSection();

  static const _repoUrl =
      'https://github.com/durgeshsinghh/AI-Powered-Image-Deblurring-App-using-GAN-DeblurGAN-';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snap) {
            final info = snap.data;
            return _InfoRow(
              label: 'Version',
              value: info == null ? '—' : '${info.version} (build ${info.buildNumber})',
            );
          },
        ),
        const _InfoRow(label: 'Model', value: 'DeblurGAN · Kupyn et al., CVPR 2018'),
        _Row(
          onTap: () async {
            final ok = await launchUrl(Uri.parse(_repoUrl), mode: LaunchMode.externalApplication);
            if (!ok && context.mounted) showAppSnack(context, 'Could not open the link.');
          },
          child: Row(
            children: [
              Expanded(child: Text('Source code', style: AppText.sans(16))),
              Text('GitHub →', style: AppText.sans(15, color: AppColors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return _Row(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 96, child: Text(label, style: AppText.sans(16))),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppText.sans(14, color: AppColors.textMuted).copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
