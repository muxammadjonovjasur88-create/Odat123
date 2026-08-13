import 'package:flutter/material.dart';

/// Flowa's **Zen Kinetic** color system — deep navy dark mode with
/// Neon Lime (#39FF14) and Electric Cyan (#00F3FF) accents.
///
/// Generated from the Stitch "Zen Kinetic" design system.
abstract final class AppColors {
  AppColors._();

  // ── Neon Brand Accents ────────────────────────────────────────────────────

  /// Primary Accent — Neon Lime (movement / completion / actions)
  static const Color neonLime = Color(0xFF39FF14);

  /// Secondary Accent — Electric Cyan (telemetry / flow / data)
  static const Color cyanAccent = Color(0xFF00F3FF);

  /// Legacy alias for compatibility
  static const Color purpleAccent = Color(0xFFAA00FF);

  /// Primary gradient: Cyan → Neon Lime (left to right)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [cyanAccent, neonLime],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Zen glow gradient — used on progress rings and active indicators
  static const LinearGradient zenGlowGradient = LinearGradient(
    colors: [Color(0xFF00F3FF), Color(0xFF39FF14)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Glassmorphism Surface Tokens ──────────────────────────────────────────

  /// Glass card surface — semi-transparent slate
  static const Color glassSurface = Color(0xCC122131);

  /// Glass card border — subtle inner glow
  static const Color glassBorder = Color(0x1AFFFFFF);

  /// Glass card top/left edge highlight — light hitting glass
  static const Color glassEdge = Color(0x29FFFFFF);

  // ── Category Accents ──────────────────────────────────────────────────────
  static const Color studyFill     = Color(0x2600F3FF);
  static const Color studyText     = Color(0xFF00F3FF);

  static const Color sportFill     = Color(0x2639FF14);
  static const Color sportText     = Color(0xFF39FF14);

  static const Color workFill      = Color(0x269E9E9E);
  static const Color workText      = Color(0xFFE0E0E0);

  static const Color personalFill  = Color(0x26FF9100);
  static const Color personalText  = Color(0xFFFFB74D);

  static const Color wellnessFill  = Color(0x2600E676);
  static const Color wellnessText  = Color(0xFF69F0AE);

  // ── Zen Kinetic Dark Scheme ───────────────────────────────────────────────

  static const AppColorScheme dark = AppColorScheme(
    background:      Color(0xFF051424),  // Deep Slate Navy void
    surface:         Color(0xFF0D1C2D),  // surface-container-low
    surfaceMuted:    Color(0xFF122131),  // surface-container
    primary:         neonLime,           // Neon Lime — movement / CTA
    secondary:       cyanAccent,         // Electric Cyan — telemetry
    primaryPressed:  Color(0xFF2AE500),  // primary-fixed-dim
    onPrimary:       Color(0xFF053900),  // on-primary (dark for contrast)
    textPrimary:     Color(0xFFD4E4FA),  // on-surface
    textSecondary:   Color(0xFFBACCB0),  // on-surface-variant
    textTertiary:    Color(0xFF85967C),  // outline
    border:          Color(0xFF273647),  // surface-variant
    shadow:          Color(0x80000000),
    tintSage:        Color(0x1A39FF14),  // Lime tint
    tintBlue:        Color(0x1A00F3FF),  // Cyan tint
    primaryGradient: primaryGradient,
  );

  /// Light is mapped to dark (global dark mode).
  static const AppColorScheme light = dark;

  // ── Legacy aliases (keep so existing code compiles) ──────────────────────
  static const Color forest     = cyanAccent;
  static const Color forestDark = Color(0xFF00B2CC);
  static const Color sage       = neonLime;
}

/// A semantic set of colors for one brightness.
@immutable
class AppColorScheme {
  const AppColorScheme({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.primary,
    this.secondary = AppColors.cyanAccent,
    required this.primaryPressed,
    required this.onPrimary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.shadow,
    required this.tintSage,
    required this.tintBlue,
    this.primaryGradient = AppColors.primaryGradient,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color primary;
  final Color secondary;
  final Color primaryPressed;
  final Color onPrimary;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;
  final Color shadow;

  /// Lime/green highlight tint
  final Color tintSage;

  /// Cyan informational tint
  final Color tintBlue;

  /// Gradient from cyan to lime
  final LinearGradient primaryGradient;
}

/// Theme extension so widgets can read the active [AppColorScheme] with
/// `Theme.of(context).extension<AppColorsExtension>()` — via `context.colors`.
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
        background:      Color.lerp(a.background, b.background, t)!,
        surface:         Color.lerp(a.surface, b.surface, t)!,
        surfaceMuted:    Color.lerp(a.surfaceMuted, b.surfaceMuted, t)!,
        primary:         Color.lerp(a.primary, b.primary, t)!,
        secondary:       Color.lerp(a.secondary, b.secondary, t)!,
        primaryPressed:  Color.lerp(a.primaryPressed, b.primaryPressed, t)!,
        onPrimary:       Color.lerp(a.onPrimary, b.onPrimary, t)!,
        textPrimary:     Color.lerp(a.textPrimary, b.textPrimary, t)!,
        textSecondary:   Color.lerp(a.textSecondary, b.textSecondary, t)!,
        textTertiary:    Color.lerp(a.textTertiary, b.textTertiary, t)!,
        border:          Color.lerp(a.border, b.border, t)!,
        shadow:          Color.lerp(a.shadow, b.shadow, t)!,
        tintSage:        Color.lerp(a.tintSage, b.tintSage, t)!,
        tintBlue:        Color.lerp(a.tintBlue, b.tintBlue, t)!,
        primaryGradient: LinearGradient.lerp(
            a.primaryGradient, b.primaryGradient, t)!,
      ),
    );
  }
}

