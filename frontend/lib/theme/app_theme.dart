import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens from the Deblur AI design spec: dark, warm off-white text,
/// one acid-lime accent.
class AppColors {
  AppColors._();

  static const bg = Color(0xFF0A0A0B);
  static const surface = Color(0xFF141416);
  static const surfaceHigh = Color(0xFF1A1A1D);
  static const text = Color(0xFFF4F1EA);
  static const textMuted = Color(0xFFA19C93);
  static const textFaint = Color(0xFF6E6A63);
  static const textChip = Color(0xFFC9C4BA);
  static const textOnLightMuted = Color(0xFF55524C);
  static const accent = Color(0xFFD7FF3D);
  static const onAccent = Color(0xFF0A0A0B);
  static const danger = Color(0xFFFF8A73);
  static const dangerBorder = Color(0x66FF7A63);
  static const shake = Color(0xFFFF9A85);

  /// `text` colour at the given opacity: fills (0.06–0.08), hairlines
  /// (0.10–0.14), glass borders, inactive tracks.
  static Color textA(double alpha) => text.withValues(alpha: alpha);

  /// `bg` colour at the given opacity: dark glass over photos.
  static Color bgA(double alpha) => bg.withValues(alpha: alpha);

  static Color accentA(double alpha) => accent.withValues(alpha: alpha);
}

/// Typography: Geist (UI), Geist Mono (labels), Instrument Serif italic
/// (accent words and big numbers).
class AppText {
  AppText._();

  static TextStyle display(double size, {Color color = AppColors.text}) =>
      GoogleFonts.geist(
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.042 * size,
        height: 1.02,
        color: color,
      );

  static TextStyle serif(double size, {Color color = AppColors.text}) =>
      GoogleFonts.instrumentSerif(
        fontSize: size,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.01 * size,
        height: 1.0,
        color: color,
      );

  static TextStyle sans(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.text,
    double? height,
    double letterSpacing = 0,
  }) => GoogleFonts.geist(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  static TextStyle body(double size, {Color color = AppColors.textMuted}) =>
      sans(size, color: color, height: 1.5);

  static TextStyle title(double size, {Color color = AppColors.text}) =>
      sans(size, weight: FontWeight.w600, color: color, letterSpacing: -0.01 * size);

  static TextStyle button(double size, {Color color = AppColors.text}) =>
      sans(size, weight: FontWeight.w600, color: color);

  static TextStyle mono(
    double size, {
    Color color = AppColors.text,
    double spacing = 0.08,
  }) => GoogleFonts.geistMono(
    fontSize: size,
    fontWeight: FontWeight.w500,
    letterSpacing: spacing * size,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

class AppTheme {
  AppTheme._();

  static const overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static ThemeData get dark {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        onPrimary: AppColors.onAccent,
        surface: AppColors.bg,
        onSurface: AppColors.text,
        error: AppColors.danger,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
    return base.copyWith(
      textTheme: GoogleFonts.geistTextTheme(base.textTheme).apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: AppText.sans(14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.textA(0.10)),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.accent,
      ),
    );
  }
}

/// Builds the recurring headline pattern: a sans line, then an Instrument
/// Serif italic word, optionally followed by a lime full stop.
class Headline extends StatelessWidget {
  final List<InlineSpan> spans;

  const Headline(this.spans, {super.key});

  static InlineSpan sans(String text, double size) =>
      TextSpan(text: text, style: AppText.display(size));

  static InlineSpan serif(String text, double size, {bool dot = true}) =>
      TextSpan(
        text: text,
        style: AppText.serif(size),
        children: [
          if (dot)
            TextSpan(text: '.', style: AppText.serif(size, color: AppColors.accent)),
        ],
      );

  @override
  Widget build(BuildContext context) => Text.rich(TextSpan(children: spans));
}
