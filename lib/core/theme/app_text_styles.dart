import 'package:flutter/material.dart';
// Using bundled local fonts (Poppins, Inter) for offline reliability.

/// Typography for Flowa.
///
/// The design pairs a calm geometric sans for headings/display (Poppins) with
/// a highly legible sans for body & UI (Inter). Both ship via `google_fonts`,
/// so no font binaries are bundled.
///
/// These are *un-colored* styles; color is applied by the theme's [TextTheme]
/// (see `app_theme.dart`) so the same styles work in light and dark.
abstract final class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _heading => const TextStyle(fontFamily: 'Poppins');
  static TextStyle get _body => const TextStyle(fontFamily: 'Inter');

  // ---- Display / headings (Poppins) ----------------------------------------

  /// Large hero numerals & wordmark, e.g. the "24:56" focus timer.
  static TextStyle get display => _heading.copyWith(
    fontSize: 44,
    fontWeight: FontWeight.w600,
    height: 1.05,
    letterSpacing: -0.5,
  );

  /// Screen titles, e.g. "Your Phone Number", "Thursday, Oct 24".
  static TextStyle get h1 => _heading.copyWith(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.2,
  );

  /// Section / card titles, e.g. "Morning Ritual", "Growth Circle".
  static TextStyle get h2 => _heading.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  /// Card item titles, e.g. a task name.
  static TextStyle get h3 =>
      _heading.copyWith(fontSize: 17, fontWeight: FontWeight.w600, height: 1.3);

  // ---- Body & UI (Inter) ---------------------------------------------------

  /// Default reading text.
  static TextStyle get body =>
      _body.copyWith(fontSize: 15, fontWeight: FontWeight.w400, height: 1.45);

  /// Slightly smaller supporting text.
  static TextStyle get bodySmall =>
      _body.copyWith(fontSize: 13, fontWeight: FontWeight.w400, height: 1.4);

  /// Button & emphasized inline labels.
  static TextStyle get label =>
      _body.copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.2);

  /// Chip / small pill text.
  static TextStyle get chip =>
      _body.copyWith(fontSize: 13, fontWeight: FontWeight.w500, height: 1.1);

  /// Uppercase eyebrow labels, e.g. "MOBILE NUMBER", "CURRENT TASK".
  static TextStyle get overline => _body.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 1.4,
  );

  /// Captions, timestamps, secondary metadata.
  static TextStyle get caption =>
      _body.copyWith(fontSize: 12, fontWeight: FontWeight.w400, height: 1.3);
}
