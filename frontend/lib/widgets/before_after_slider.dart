import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

/// Before/after split: the sharp image fills the frame and the blurred image
/// is clipped to the left of the divider. When [interactive], dragging or
/// tapping anywhere moves the divider.
class BeforeAfterSlider extends StatefulWidget {
  final ImageProvider before;
  final ImageProvider after;
  final double initial;
  final bool interactive;

  /// Vertical centre of the knob as a fraction of the height.
  final double knobY;

  const BeforeAfterSlider({
    super.key,
    required this.before,
    required this.after,
    this.initial = 0.48,
    this.interactive = true,
    this.knobY = 0.5,
  });

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  late double _t = widget.initial;

  void _move(double dx, double width) {
    setState(() => _t = (dx / width).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final x = w * _t;
        final stack = Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: Image(image: widget.after, fit: BoxFit.cover, gaplessPlayback: true),
            ),
            Positioned.fill(
              child: ClipRect(
                clipper: _LeftClipper(x),
                child: Image(image: widget.before, fit: BoxFit.cover, gaplessPlayback: true),
              ),
            ),
            Positioned(
              left: x - 1,
              top: 0,
              bottom: 0,
              child: Container(width: 2, color: AppColors.accent),
            ),
            Positioned(
              left: x - 22,
              top: h * widget.knobY - 22,
              child: const _Knob(),
            ),
          ],
        );
        if (!widget.interactive) return stack;
        return Semantics(
          slider: true,
          label: 'Compare before and after',
          value: '${(_t * 100).round()}%',
          increasedValue: '${((_t + 0.05).clamp(0, 1) * 100).round()}%',
          decreasedValue: '${((_t - 0.05).clamp(0, 1) * 100).round()}%',
          onIncrease: () => setState(() => _t = (_t + 0.05).clamp(0, 1)),
          onDecrease: () => setState(() => _t = (_t - 0.05).clamp(0, 1)),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) => _move(d.localPosition.dx, w),
            onTapDown: (d) => _move(d.localPosition.dx, w),
            child: stack,
          ),
        );
      },
    );
  }
}

class _Knob extends StatelessWidget {
  const _Knob();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: AppColors.accentA(0.18), spreadRadius: 6),
          const BoxShadow(color: Color(0x73000000), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: const Icon(LucideIcons.chevronsLeftRight, size: 20, color: AppColors.onAccent),
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  final double width;

  _LeftClipper(this.width);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, width, size.height);

  @override
  bool shouldReclip(_LeftClipper old) => old.width != width;
}
