import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Scales its child down slightly while pressed — the tap feedback used by
/// every button in the design (there are no Material ripples).
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: enabled ? 1 : 0.45,
            duration: const Duration(milliseconds: 150),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Frosted glass: backdrop blur + translucent fill + 1px hairline, with an
/// optional drop shadow drawn outside the clip.
class Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final double blur;
  final Color color;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? shadows;
  final bool topHighlight;

  const Glass({
    super.key,
    required this.child,
    this.radius = 24,
    this.blur = 24,
    this.color = const Color(0xC71E1E20), // rgba(30,30,32,0.78)
    this.borderColor,
    this.padding,
    this.shadows,
    this.topHighlight = true,
  });

  /// Dark glass chips/buttons over photos: rgba(10,10,11,0.45–0.6), blur 12–14.
  const Glass.dark({
    super.key,
    required this.child,
    this.radius = 22,
    this.blur = 14,
    this.color = const Color(0x730A0A0B),
    this.borderColor,
    this.padding,
    this.shadows,
    this.topHighlight = true,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: r, boxShadow: shadows),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color,
              borderRadius: r,
              border: Border.all(color: borderColor ?? AppColors.textA(0.12)),
              gradient: topHighlight
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, 0.08, 0.08],
                      colors: [
                        Color.alphaBlend(const Color(0x12FFFFFF), color),
                        color,
                        color,
                      ],
                    )
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

const _accentShadows = [
  BoxShadow(color: Color(0x29D7FF3D), blurRadius: 28, offset: Offset(0, 10)),
];

/// Inner top highlight + bottom shade used on lime and light buttons.
BoxDecoration _litPill({
  required Color color,
  required double radius,
  List<BoxShadow>? shadows,
  double highlight = 0.55,
}) => BoxDecoration(
  borderRadius: BorderRadius.circular(radius),
  boxShadow: shadows,
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: const [0, 0.03, 0.04, 0.95, 0.96, 1],
    colors: [
      Color.lerp(color, Colors.white, highlight)!,
      Color.lerp(color, Colors.white, highlight)!,
      color,
      color,
      Color.lerp(color, Colors.black, 0.12)!,
      Color.lerp(color, Colors.black, 0.12)!,
    ],
  ),
);

/// Full-width lime call-to-action (58–60 tall).
class AccentButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool iconAfter;
  final VoidCallback? onTap;
  final double height;

  const AccentButton({
    super.key,
    required this.label,
    this.icon,
    this.iconAfter = false,
    this.onTap,
    this.height = 58,
  });

  @override
  Widget build(BuildContext context) {
    final iconW = icon == null
        ? null
        : Icon(icon, size: 20, color: AppColors.onAccent);
    return Pressable(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: _litPill(
          color: AppColors.accent,
          radius: height / 2,
          shadows: _accentShadows,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconW != null && !iconAfter) ...[iconW, const SizedBox(width: 10)],
            Text(label, style: AppText.button(16, color: AppColors.onAccent)),
            if (iconW != null && iconAfter) ...[const SizedBox(width: 10), iconW],
          ],
        ),
      ),
    );
  }
}

/// Round lime button: onboarding "next" (68) and the nav FAB (64).
class AccentCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final String? semanticLabel;

  const AccentCircleButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 64,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Container(
        width: size,
        height: size,
        decoration: _litPill(
          color: AppColors.accent,
          radius: size / 2,
          shadows: _accentShadows,
        ),
        child: Icon(icon, size: size * 0.38, color: AppColors.onAccent),
      ),
    );
  }
}

/// Off-white pill with dark text (Gallery button, Allow buttons).
class LightButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const LightButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.height = 52,
    this.fontSize = 15,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: height,
        padding: padding,
        decoration: _litPill(color: AppColors.text, radius: height / 2, highlight: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.onAccent),
              const SizedBox(width: 8),
            ],
            Text(label, style: AppText.button(fontSize, color: AppColors.onAccent)),
          ],
        ),
      ),
    );
  }
}

/// Secondary pill: translucent fill or hairline outline.
class SoftButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;
  final bool outlined;
  final bool glass;
  final Color? color;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;

  const SoftButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.height = 50,
    this.fontSize = 14,
    this.outlined = false,
    this.glass = false,
    this.color,
    this.borderColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AppColors.text;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
        ],
        Text(label, style: AppText.button(fontSize, color: fg)),
      ],
    );
    final Widget body;
    if (glass) {
      body = Glass(
        radius: height / 2,
        blur: 16,
        color: AppColors.textA(0.16),
        borderColor: AppColors.textA(0.2),
        topHighlight: false,
        child: SizedBox(height: height - 2, child: Center(child: content)),
      );
    } else {
      body = Container(
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          color: outlined ? Colors.transparent : AppColors.textA(0.08),
          border: outlined
              ? Border.all(color: borderColor ?? AppColors.textA(0.14))
              : null,
        ),
        child: Center(child: content),
      );
    }
    return Pressable(onTap: onTap, child: body);
  }
}

/// Round icon button: plain fill (40) or dark glass over photos (44).
class IconCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool glass;
  final String? semanticLabel;

  const IconCircleButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 40,
    this.glass = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final iconW = Icon(icon, size: size * 0.45, color: AppColors.text);
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: glass
          ? Glass.dark(
              radius: size / 2,
              child: SizedBox(width: size - 2, height: size - 2, child: Center(child: iconW)),
            )
          : Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.textA(0.08),
              ),
              child: iconW,
            ),
    );
  }
}

/// Small uppercase Geist Mono label, optionally on glass or a fill.
class MonoChip extends StatelessWidget {
  final String text;
  final Color color;
  final Color? dotColor;
  final bool glass;
  final Color? background;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final double radius;

  const MonoChip(
    this.text, {
    super.key,
    this.color = AppColors.text,
    this.dotColor,
    this.glass = false,
    this.background,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dotColor != null) ...[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
        ],
        Text(text, style: AppText.mono(fontSize, color: color)),
      ],
    );
    if (glass) {
      return Glass.dark(
        radius: radius,
        blur: 12,
        color: AppColors.bgA(0.55),
        borderColor: AppColors.textA(0.10),
        topHighlight: false,
        padding: padding,
        child: label,
      );
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: label,
    );
  }
}

/// Section label, e.g. RECENT, PROCESSING.
class MonoLabel extends StatelessWidget {
  final String text;
  final Color color;

  const MonoLabel(this.text, {super.key, this.color = AppColors.textMuted});

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppText.mono(11, color: color, spacing: 0.1));
}

/// Four L-shaped viewfinder corners filling the parent.
class ViewfinderBrackets extends StatelessWidget {
  final double size;
  final bool bottom;

  const ViewfinderBrackets({super.key, this.size = 20, this.bottom = true});

  @override
  Widget build(BuildContext context) {
    Widget corner(Alignment a) => Align(
      alignment: a,
      child: CustomPaint(size: Size(size, size), painter: _BracketPainter(a)),
    );
    return IgnorePointer(
      child: Stack(
        children: [
          corner(Alignment.topLeft),
          corner(Alignment.topRight),
          if (bottom) ...[
            corner(Alignment.bottomLeft),
            corner(Alignment.bottomRight),
          ],
        ],
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  final Alignment corner;

  _BracketPainter(this.corner);

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = AppColors.text
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final left = corner.x < 0;
    final top = corner.y < 0;
    final x = left ? 1.0 : s.width - 1;
    final y = top ? 1.0 : s.height - 1;
    final path = Path()
      ..moveTo(x, top ? s.height : 0)
      ..lineTo(x, y)
      ..lineTo(left ? s.width : 0, y);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_BracketPainter old) => old.corner != corner;
}

/// Pill segmented control; the active segment is the light pill.
class Segmented<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool compact;

  const Segmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final h = compact ? 36.0 : 44.0;
    final items = [
      for (final (v, label) in options)
        _segment(v, label, h, expand: !compact),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.textA(0.06),
        borderRadius: BorderRadius.circular(h / 2 + 4),
        border: compact ? null : Border.all(color: AppColors.textA(0.08)),
      ),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            items[i],
          ],
        ],
      ),
    );
  }

  Widget _segment(T v, String label, double h, {required bool expand}) {
    final on = v == value;
    final w = Pressable(
      onTap: () => onChanged(v),
      semanticLabel: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: h,
        padding: EdgeInsets.symmetric(horizontal: expand ? 0 : 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.text : Colors.transparent,
          borderRadius: BorderRadius.circular(h / 2),
          boxShadow: on && expand
              ? const [BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4))]
              : null,
        ),
        child: Text(
          label,
          style: AppText.button(
            expand ? 14 : 13,
            color: on ? AppColors.onAccent : AppColors.textMuted,
          ),
        ),
      ),
    );
    return expand ? Expanded(child: w) : w;
  }
}

/// 52×32 switch: lime track + dark knob when on.
class AppToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? semanticLabel;

  const AppToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: semanticLabel,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 52,
          height: 32,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: value ? AppColors.accent : AppColors.textA(0.16),
            borderRadius: BorderRadius.circular(16),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value ? AppColors.onAccent : AppColors.text,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Story-style step indicator (3 bars).
class StepBars extends StatelessWidget {
  final int step;
  final int total;

  const StepBars({super.key, required this.step, this.total = 3});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step $step of $total',
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 3,
                decoration: BoxDecoration(
                  color: i < step ? AppColors.text : AppColors.textA(0.28),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Transparent → background fade laid over the bottom of photos.
class BottomFade extends StatelessWidget {
  final double height;
  final double startOpacity;
  final double endOpacity;

  const BottomFade({
    super.key,
    required this.height,
    this.startOpacity = 0,
    this.endOpacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgA(startOpacity), AppColors.bgA(endOpacity)],
          ),
        ),
      ),
    );
  }
}

void showAppSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}
