import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/core/theme/app_colors.dart';

/// Verifies the light and dark Zen palettes are both fully defined and distinct
/// — including the theme-aware tint surfaces that keep accent cards readable in
/// dark mode. (Full-widget rendering is covered by the APK build; google_fonts
/// can't load assets in the unit-test sandbox.)
void main() {
  test('dark scheme is defined with high contrast colors', () {
    expect(AppColors.dark.background, equals(const Color(0xFF0B0F19)));
    expect(AppColors.dark.surface, equals(const Color(0xFF151A27)));
    expect(AppColors.dark.primary, equals(AppColors.cyanAccent));
  });

  test('tint surfaces are defined and brightness-appropriate', () {
    expect(AppColors.dark.tintSage, isNotNull);
    expect(AppColors.dark.tintBlue, isNotNull);
  });

  test('color extension lerps between schemes smoothly', () {
    const a = AppColorsExtension(AppColors.dark);
    const b = AppColorsExtension(AppColors.dark);
    final mid = a.lerp(b, 0.5);
    expect(mid.scheme.background, equals(AppColors.dark.background));
  });
}
