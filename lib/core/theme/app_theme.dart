import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Builds Flowa's light and dark [ThemeData] from [AppColors] and
/// [AppTextStyles], and exposes the semantic [AppColorScheme] via a theme
/// extension so widgets read colors with `context.colors`.
abstract final class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light, AppColors.light);
  static ThemeData get dark => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColorScheme c) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      secondary: c.secondary,
      onSecondary: c.onPrimary,
      surface: c.surface,
      onSurface: c.textPrimary,
      error: const Color(0xFFFF5252),
      onError: Colors.white,
    );

    final textTheme = _textTheme(c.textPrimary, c.textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.background,
      colorScheme: colorScheme,
      textTheme: textTheme,
      primaryColor: c.primary,
      splashFactory: InkRipple.splashFactory,
      // Calm, consistent screen transitions across platforms.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      extensions: [AppColorsExtension(c)],
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: c.textPrimary,
        titleTextStyle: AppTextStyles.h2.copyWith(color: c.textPrimary),
      ),
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) {
    TextStyle p(TextStyle s) => s.copyWith(color: primary);
    TextStyle s(TextStyle style) => style.copyWith(color: secondary);
    return TextTheme(
      displayLarge: p(AppTextStyles.display),
      headlineLarge: p(AppTextStyles.h1),
      headlineMedium: p(AppTextStyles.h2),
      titleLarge: p(AppTextStyles.h3),
      bodyLarge: p(AppTextStyles.body),
      bodyMedium: s(AppTextStyles.body),
      bodySmall: s(AppTextStyles.bodySmall),
      labelLarge: p(AppTextStyles.label),
      labelMedium: s(AppTextStyles.caption),
      labelSmall: s(AppTextStyles.overline),
    );
  }
}

/// Convenience access to the active semantic palette: `context.colors.primary`.
extension ThemeColorsX on BuildContext {
  AppColorScheme get colors =>
      Theme.of(this).extension<AppColorsExtension>()!.scheme;
}
