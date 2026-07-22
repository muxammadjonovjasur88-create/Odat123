import 'package:flutter/material.dart';

/// Flowa's Zen palette, extracted from the Figma design PNGs in `design/`.
///
/// The aesthetic is calm: warm cream backgrounds, soft white cards, and a
/// grounded sage / forest green primary. Category accents are muted pastels.
///
/// Colors are grouped into [light] and [dark] schemes; widgets should read
/// from the active [AppColorScheme] (via `context` / theme) rather than
/// referencing raw constants, so light/dark stay consistent.
abstract final class AppColors {
  AppColors._();

  // ---- Brand / accent (shared across light & dark) -------------------------

  /// Deep forest green — primary buttons, progress rings, active states.
  static const Color forest = Color(0xFF4F6F4E);

  /// Darker forest, used for pressed states and ring strokes.
  static const Color forestDark = Color(0xFF3C5538);

  /// Soft sage — secondary accents, subtle highlights.
  static const Color sage = Color(0xFF8FA98A);

  // ---- Category accents (muted pastels from the chips) ---------------------
  // Each has a soft fill + a readable foreground.

  static const Color studyFill = Color(0xFFC6DBEF); // blue
  static const Color studyText = Color(0xFF3A5A78);

  static const Color sportFill = Color(0xFFC7DDC0); // green
  static const Color sportText = Color(0xFF3E5C3A);

  static const Color workFill = Color(0xFFE4E3DC); // neutral grey
  static const Color workText = Color(0xFF5A584F);

  static const Color personalFill = Color(0xFFF4CFAD); // peach
  static const Color personalText = Color(0xFF8A5A36);

  static const Color wellnessFill = Color(0xFFCBE3C5); // light green
  static const Color wellnessText = Color(0xFF3E5C3A);

  // ---- Light scheme --------------------------------------------------------

  static const AppColorScheme light = AppColorScheme(
    background: Color(0xFFF4F1EA), // warm cream
    surface: Color(0xFFFFFFFF), // white cards
    surfaceMuted: Color(0xFFEFEDE6), // input fills, inactive chips
    primary: forest,
    primaryPressed: forestDark,
    onPrimary: Color(0xFFFDFDFB),
    textPrimary: Color(0xFF2D2D2A), // charcoal
    textSecondary: Color(0xFF8A887F), // warm grey
    textTertiary: Color(0xFFB5B2A8), // hint / placeholder
    border: Color(0xFFE6E3DB),
    shadow: Color(0x14000000),
    tintSage: Color(0xFFDDEAD6), // soft sage highlight surface
    tintBlue: Color(0xFFD8E6F2), // soft blue info surface
  );

  // ---- Dark scheme (from 21_dark_mode.png) ---------------------------------

  static const AppColorScheme dark = AppColorScheme(
    background: Color(0xFF181C18), // dark green-black
    surface: Color(0xFF242823), // elevated olive card
    surfaceMuted: Color(0xFF2E332D),
    primary: Color(0xFF5C7C54), // slightly lifted for contrast
    primaryPressed: forest,
    onPrimary: Color(0xFFF3F5F0),
    textPrimary: Color(0xFFECEAE3),
    textSecondary: Color(0xFF9A988F),
    textTertiary: Color(0xFF6E6F68),
    border: Color(0xFF343A33),
    shadow: Color(0x40000000),
    tintSage: Color(0xFF2A332A), // dark green-tinted surface
    tintBlue: Color(0xFF263039), // dark blue-tinted surface
  );
}

/// A semantic set of colors for one brightness. Resolved from [AppColors.light]
/// or [AppColors.dark] and exposed on the theme via [AppColorsExtension].
@immutable
class AppColorScheme {
  const AppColorScheme({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.primary,
    required this.primaryPressed,
    required this.onPrimary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.shadow,
    required this.tintSage,
    required this.tintBlue,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color primary;
  final Color primaryPressed;
  final Color onPrimary;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;
  final Color shadow;

  /// Soft positive/highlight surface (sage in light, dark-green in dark).
  final Color tintSage;

  /// Soft informational surface (blue in light, dark-blue in dark).
  final Color tintBlue;
}

/// Theme extension so widgets can read the active [AppColorScheme] with
/// `Theme.of(context).extension<AppColorsExtension>()` — wrapped by the
/// `context.colors` getter in `app_theme.dart`.
@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  const AppColorsExtension(this.scheme);

  final AppColorScheme scheme;

  @override
  AppColorsExtension copyWith({AppColorScheme? scheme}) =>
      AppColorsExtension(scheme ?? this.scheme);

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    final a = scheme;
    final b = other.scheme;
    return AppColorsExtension(
      AppColorScheme(
        background: Color.lerp(a.background, b.background, t)!,
        surface: Color.lerp(a.surface, b.surface, t)!,
        surfaceMuted: Color.lerp(a.surfaceMuted, b.surfaceMuted, t)!,
        primary: Color.lerp(a.primary, b.primary, t)!,
        primaryPressed: Color.lerp(a.primaryPressed, b.primaryPressed, t)!,
        onPrimary: Color.lerp(a.onPrimary, b.onPrimary, t)!,
        textPrimary: Color.lerp(a.textPrimary, b.textPrimary, t)!,
        textSecondary: Color.lerp(a.textSecondary, b.textSecondary, t)!,
        textTertiary: Color.lerp(a.textTertiary, b.textTertiary, t)!,
        border: Color.lerp(a.border, b.border, t)!,
        shadow: Color.lerp(a.shadow, b.shadow, t)!,
        tintSage: Color.lerp(a.tintSage, b.tintSage, t)!,
        tintBlue: Color.lerp(a.tintBlue, b.tintBlue, t)!,
      ),
    );
  }
}
