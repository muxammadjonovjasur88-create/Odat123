import 'package:flutter/material.dart';

/// Odat app **brand** color system — extracted directly from the ODAT intro
/// video and Phoenix logo artwork.
///
/// Palette — extracted from Phoenix logo & intro animation:
///  • Background    : #04050D  (deep cosmic black-blue, video bg)
///  • Sky Cyan      : #4AADDC  (phoenix wing tip highlight / logo ring top)
///  • Ocean Blue    : #3A7FCC  (ring gradient mid)
///  • Deep Violet   : #6B25CC  (phoenix body / gradient anchor)
///  • Mystic Purple : #9B4FE8  (wing glow, dominant brand tone)
///  • Magenta Glow  : #C44DE8  (inner wing accent, energy spark)
///  • Silver-White  : #E2E8F0  (wordmark "ODAT")
///  • Smoke Blue    : #6EA8C8  (subtitle / "HAR KUNI YAXSHIROQ")
abstract final class AppColors {
  AppColors._();

  // ── ODAT Brand Palette ─────────────────────────────────────────────────────

  /// Sky Cyan — logo clock top highlight
  static const Color odatCyan = Color(0xFF38BDF8);

  /// Ocean Blue — ring gradient mid-stop
  static const Color odatBlue = Color(0xFF3B82F6);

  /// Deep Violet — gradient anchor
  static const Color odatViolet = Color(0xFF6366F1);

  /// Mystic Purple — logo clock violet glow
  static const Color odatPurple = Color(0xFF8B5CF6);

  /// Magenta Glow — inner energy spark / accent
  static const Color odatMagenta = Color(0xFFA855F7);

  /// Silver — "ODAT" wordmark
  static const Color odatSilver = Color(0xFFF8FAFC);

  /// Smoke Blue — subtitle / muted tone
  static const Color odatSubtitle = Color(0xFF94A3B8);

  // ── Backwards-compatible aliases ───────────────────────────────────────────
  static const Color electricBlue     = odatCyan;
  static const Color neonPurple       = odatViolet;
  static const Color brightCyan       = odatBlue;
  static const Color violetHighlight  = odatPurple;
  static const Color neonLime         = odatCyan;
  static const Color cyanAccent       = odatCyan;
  static const Color purpleAccent     = odatPurple;
  static const Color forest           = odatCyan;
  static const Color forestDark       = Color(0xFF2A6BAA);
  static const Color sage             = odatCyan;

  // ── Brand Gradients ────────────────────────────────────────────────────────

  /// Main brand gradient: Cyan → Indigo → Violet (matching Flowa logo)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF38BDF8), Color(0xFF6366F1), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Glow / AI gradient — two-stop signature
  static const LinearGradient glowGradient = LinearGradient(
    colors: [Color(0xFF38BDF8), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle subtitle / accent gradient
  static const LinearGradient subtitleGradient = LinearGradient(
    colors: [Color(0xFF94A3B8), Color(0xFF38BDF8)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ── Glassmorphism Surface Tokens ───────────────────────────────────────────

  static const Color glassSurfaceDark  = Color(0xF0121826);
  static const Color glassBorderDark   = Color(0xFF1E283D);
  static const Color glassEdgeDark     = Color(0xFF222B40);

  static const Color glassSurfaceLight = Color(0xCCF1F5F9);
  static const Color glassBorderLight  = Color(0x1A3A7FCC);
  static const Color glassEdgeLight    = Color(0x294AADDC);

  static const Color glassSurface = glassSurfaceDark;
  static const Color glassBorder  = glassBorderDark;
  static const Color glassEdge    = glassEdgeDark;

  // ── Category Accents ───────────────────────────────────────────────────────

  static const Color studyFill    = Color(0x2638BDF8);
  static const Color studyText    = Color(0xFF38BDF8);

  static const Color sportFill    = Color(0x268B5CF6);
  static const Color sportText    = Color(0xFF8B5CF6);

  static const Color workFill     = Color(0x26F8FAFC);
  static const Color workText     = Color(0xFFE2E8F0);

  static const Color personalFill = Color(0x263B82F6);
  static const Color personalText = Color(0xFF60A5FA);

  static const Color wellnessFill = Color(0x26A855F7);
  static const Color wellnessText = Color(0xFFA855F7);

  // ── Dark Scheme ───────────────────────────────────────────────────────────
  // Deep obsidian slate background matching premium mobile design standards.
  static const AppColorScheme dark = AppColorScheme(
    background:      Color(0xFF0A0E17),   // Deep obsidian slate
    surface:         Color(0xFF121826),   // Elevated card surface
    surfaceMuted:    Color(0xFF1B2335),   // Muted surface (chips, inputs)
    primary:         Color(0xFF38BDF8),   // Flowa Cyan — dominant brand tone
    secondary:       Color(0xFF8B5CF6),   // Flowa Violet — secondary highlight
    primaryPressed:  Color(0xFF0284C7),   // Pressed cyan
    onPrimary:       Color(0xFF000000),   // Black on cyan
    textPrimary:     Color(0xFFF8FAFC),   // Crisp off-white
    textSecondary:   Color(0xFF94A3B8),   // Muted neutral slate
    textTertiary:    Color(0xFF64748B),   // Dark slate caption
    border:          Color(0xFF1E283D),   // Subtle modern border
    shadow:          Color(0x33000000),   // Soft shadow
    tintSage:        Color(0x1A8B5CF6),   // Violet tint overlay
    tintBlue:        Color(0x1A38BDF8),   // Cyan tint overlay
    primaryGradient: primaryGradient,
  );

  // ── Light Scheme ──────────────────────────────────────────────────────────
  // Brand accents preserved; surfaces flip to clean whites.
  static const AppColorScheme light = AppColorScheme(
    background:      Color(0xFFF0F4FA),   // Very light blue-gray
    surface:         Color(0xFFFFFFFF),   // White card
    surfaceMuted:    Color(0xFFE8EDF5),   // Light silver
    primary:         odatViolet,          // Deep violet as primary on light
    secondary:       odatCyan,            // Cyan secondary
    primaryPressed:  Color(0xFF531BAA),   // Darker violet pressed
    onPrimary:       Color(0xFFFFFFFF),   // White on violet
    textPrimary:     Color(0xFF04050D),   // Near-black text
    textSecondary:   Color(0xFF3B4A72),   // Dark slate-blue
    textTertiary:    Color(0xFF64748B),   // Muted gray
    border:          Color(0xFFD1D9E9),   // Light border
    shadow:          Color(0x1A000000),
    tintSage:        Color(0x1A6B25CC),   // Violet tint
    tintBlue:        Color(0x1A3A7FCC),   // Blue tint
    primaryGradient: primaryGradient,
  );
}

/// A semantic set of colors for one brightness.
@immutable
class AppColorScheme {
  const AppColorScheme({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.primary,
    this.secondary = AppColors.neonPurple,
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
  final Color tintSage;
  final Color tintBlue;
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
