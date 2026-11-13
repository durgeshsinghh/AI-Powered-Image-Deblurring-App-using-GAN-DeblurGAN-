import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/process_mode.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'flow.dart';

/// Modal sheet from the FAB: pick one or more photos from the gallery or
/// camera, choose where to run, then deblur them all.
class NewDeblurSheet extends StatefulWidget {
  final void Function(List<File> files, ProcessMode mode) onRun;

  const NewDeblurSheet({super.key, required this.onRun});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x9E050506), // rgba(5,5,6,0.62)
      builder: (sheetContext) => NewDeblurSheet(
        onRun: (files, mode) {
          Navigator.of(sheetContext).pop();
          DeblurFlow.run(context, files, mode: mode);
        },
      ),
    );
  }

  @override
  State<NewDeblurSheet> createState() => _NewDeblurSheetState();
}

class _NewDeblurSheetState extends State<NewDeblurSheet> {
  final List<File> _picked = [];
  final Set<int> _selected = {};
  late ProcessMode _mode = context.read<SettingsProvider>().mode;

  List<File> get _selectedFiles => [
    for (var i = 0; i < _picked.length; i++)
      if (_selected.contains(i)) _picked[i],
  ];

  void _add(List<File> files) {
    if (files.isEmpty) return;
    setState(() {
      for (final f in files) {
        _picked.add(f);
        _selected.add(_picked.length - 1);
      }
    });
  }

  Future<void> _gallery() async => _add(await DeblurFlow.pickMany());

  Future<void> _camera() async {
    final f = await DeblurFlow.takePhoto(context);
    if (f != null) _add([f]);
  }

  void _go() {
    final files = _selectedFiles;
    if (files.isEmpty) {
      _gallery();
      return;
    }
    widget.onRun(files, _mode);
  }

  @override
  Widget build(BuildContext context) {
    final n = _selected.length;
    final cta = n > 1 ? 'Deblur $n photos' : n == 1 ? 'Deblur photo' : 'Pick a photo';
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 8 + bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: AppColors.textA(0.10)),
          boxShadow: const [
            BoxShadow(color: Color(0x80000000), blurRadius: 60, offset: Offset(0, -20)),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.textA(0.22),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Headline([Headline.sans('New ', 32), Headline.serif('deblur', 38)])),
                  IconCircleButton(
                    icon: LucideIcons.x,
                    semanticLabel: 'Close',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _SourceTile(
                      icon: LucideIcons.image,
                      title: 'Gallery',
                      sub: 'BROWSE PHOTOS',
                      light: true,
                      onTap: _gallery,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SourceTile(
                      icon: LucideIcons.camera,
                      title: 'Camera',
                      sub: 'SHOOT NOW',
                      onTap: _camera,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const MonoLabel('YOUR PICKS'),
                  if (n > 0) MonoLabel('$n SELECTED', color: AppColors.accent),
                ],
              ),
              const SizedBox(height: 10),
              _grid(),
              const SizedBox(height: 20),
              Row(
                children: [
                  const MonoLabel('RUN ON'),
                  const Spacer(),
                  Segmented<ProcessMode>(
                    compact: true,
                    value: _mode,
                    onChanged: (m) => setState(() => _mode = m),
                    options: const [
                      (ProcessMode.auto, 'Auto'),
                      (ProcessMode.server, 'Server'),
                      (ProcessMode.device, 'Device'),
                    ],
                  ),
                ],
              ),
              if (_mode == ProcessMode.device) ...[
                const SizedBox(height: 10),
                const MonoLabel('ON-DEVICE MODEL COMING SOON · RUNS ON SERVER', color: AppColors.textFaint),
              ],
              const SizedBox(height: 20),
              AccentButton(label: cta, icon: LucideIcons.aperture, onTap: _go),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid() {
    final count = _picked.isEmpty ? 4 : _picked.length;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 80,
      ),
      itemBuilder: (context, i) {
        if (_picked.isEmpty) {
          return Pressable(
            onTap: _gallery,
            semanticLabel: 'Add photos',
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppColors.textA(0.04),
                border: Border.all(color: AppColors.textA(0.10)),
              ),
              child: i == 0
                  ? const Icon(LucideIcons.plus, size: 20, color: AppColors.textMuted)
                  : null,
            ),
          );
        }
        final on = _selected.contains(i);
        return Pressable(
          semanticLabel: on ? 'Deselect photo' : 'Select photo',
          onTap: () => setState(() => on ? _selected.remove(i) : _selected.add(i)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF222222),
              border: Border.all(color: on ? AppColors.accent : Colors.transparent, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(_picked[i], fit: BoxFit.cover, cacheWidth: 240),
                  if (on)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                        child: const Icon(LucideIcons.check, size: 12, color: AppColors.onAccent),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final bool light;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = light ? AppColors.onAccent : AppColors.text;
    return Pressable(
      onTap: onTap,
      semanticLabel: title,
      child: Container(
        height: 132,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: light ? AppColors.text : AppColors.textA(0.07),
          borderRadius: BorderRadius.circular(24),
          border: light ? null : Border.all(color: AppColors.textA(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, size: 26, color: fg),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.title(17, color: fg)),
                const SizedBox(height: 3),
                Text(
                  sub,
                  style: AppText.mono(10, color: light ? AppColors.textOnLightMuted : AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
