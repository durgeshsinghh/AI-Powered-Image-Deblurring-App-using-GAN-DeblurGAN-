import 'package:flutter/material.dart';

/// The app's bottom bar: a rounded pill on the left holding Gallery and
/// History (the currently active one highlighted), and a separate circular
/// dark camera button detached at the right edge.
class BottomActionBar extends StatelessWidget {
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final VoidCallback onHistory;
  final bool historySelected;

  const BottomActionBar({
    super.key,
    required this.onGallery,
    required this.onCamera,
    required this.onHistory,
    required this.historySelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _PillItem(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      selected: !historySelected,
                      onTap: onGallery,
                    ),
                    _PillItem(
                      icon: Icons.history_rounded,
                      label: 'History',
                      selected: historySelected,
                      onTap: onHistory,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            _CameraButton(onTap: onCamera),
          ],
        ),
      ),
    );
  }
}

class _PillItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PillItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onSurface : scheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? scheme.surfaceContainerHighest : null,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: fg,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CameraButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.camera_alt_rounded,
          color: scheme.onInverseSurface,
          size: 26,
        ),
      ),
    );
  }
}
