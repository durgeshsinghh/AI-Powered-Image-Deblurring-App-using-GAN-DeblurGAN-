import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';
import 'ui.dart';

/// Glass pill with Home / History / Settings plus the lime FAB that opens
/// the New Deblur sheet. The active slot expands to an icon + label pill.
class FloatingNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onFab;

  const FloatingNav({
    super.key,
    required this.index,
    required this.onSelect,
    required this.onFab,
  });

  static const _items = [
    (LucideIcons.house, 'Home'),
    (LucideIcons.layoutDashboard, 'History'),
    (LucideIcons.slidersHorizontal, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Glass(
            radius: 32,
            blur: 24,
            borderColor: AppColors.textA(0.10),
            shadows: const [
              BoxShadow(color: Color(0x8C000000), blurRadius: 48, offset: Offset(0, 18)),
            ],
            padding: const EdgeInsets.all(6),
            child: SizedBox(
              height: 50,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _items.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      flex: i == index ? 16 : 10,
                      child: _NavSlot(
                        icon: _items[i].$1,
                        label: _items[i].$2,
                        active: i == index,
                        onTap: () => onSelect(i),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        AccentCircleButton(
          icon: LucideIcons.aperture,
          size: 64,
          onTap: onFab,
          semanticLabel: 'New deblur',
        ),
      ],
    );
  }
}

class _NavSlot extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavSlot({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: active ? AppColors.text : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: active ? 20 : 22,
              color: active ? AppColors.onAccent : AppColors.textMuted,
            ),
            if (active) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: AppText.button(14, color: AppColors.onAccent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
