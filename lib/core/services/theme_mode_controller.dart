import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the app's [ThemeMode]. Defaults to following the system; the demo
/// screen (and later, Settings) can flip it explicitly.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void set(ThemeMode mode) => state = mode;

  /// Toggles between light and dark (resolving "system" to its opposite).
  void toggle(Brightness platformBrightness) {
    final isDark =
        state == ThemeMode.dark ||
        (state == ThemeMode.system && platformBrightness == Brightness.dark);
    state = isDark ? ThemeMode.light : ThemeMode.dark;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
