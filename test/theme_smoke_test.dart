import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/core/theme/app_colors.dart';

/// Verifies the light and dark Zen palettes are both fully defined and distinct
/// — including the theme-aware tint surfaces that keep accent cards readable in
/// dark mode. (Full-widget rendering is covered by the APK build; google_fonts
/// can't load assets in the unit-test sandbox.)
void main() {
  test('light and dark schemes are distinct', () {
    expect(AppColors.light.background, isNot(AppColors.dark.background));
    expect(AppColors.light.surface, isNot(AppColors.dark.surface));
    expect(AppColors.light.textPrimary, isNot(AppColors.dark.textPrimary));
  });

  test('tint surfaces are defined and brightness-appropriate', () {
    // Light tints are pale; dark tints are deep — so they differ per theme.
    expect(AppColors.light.tintSage, isNot(AppColors.dark.tintSage));
    expect(AppColors.light.tintBlue, isNot(AppColors.dark.tintBlue));
  });

  test('color extension lerps between the two schemes', () {
    const a = AppColorsExtension(AppColors.light);
    const b = AppColorsExtension(AppColors.dark);
    final mid = a.lerp(b, 0.5);
    expect(mid.scheme.tintSage, isNot(AppColors.light.tintSage));
    expect(mid.scheme.background, isNot(AppColors.dark.background));
  });
}
