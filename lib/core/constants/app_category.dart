import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Task categories shown as colored pills (see `09_add_goal.png` and the chips
/// on `06_daily_plan_full.png`). Each carries its own soft fill + readable
/// foreground so [AppChip] can render a category consistently everywhere.
enum AppCategory {
  study(
    'Study',
    AppColors.studyFill,
    AppColors.studyText,
    Icons.menu_book_rounded,
  ),
  sport(
    'Sport',
    AppColors.sportFill,
    AppColors.sportText,
    Icons.directions_run_rounded,
  ),
  work(
    'Work',
    AppColors.workFill,
    AppColors.workText,
    Icons.work_outline_rounded,
  ),
  personal(
    'Personal',
    AppColors.personalFill,
    AppColors.personalText,
    Icons.favorite_outline_rounded,
  ),
  wellness(
    'Wellness',
    AppColors.wellnessFill,
    AppColors.wellnessText,
    Icons.spa_rounded,
  );

  const AppCategory(this.label, this.fill, this.foreground, this.icon);

  /// Human-readable label, e.g. "Study".
  final String label;

  /// Soft pastel background for the pill.
  final Color fill;

  /// Readable text/icon color on top of [fill].
  final Color foreground;

  /// Leading icon used in task cards.
  final IconData icon;

  /// Parses a stored category name back to its enum (defaults to [study]).
  static AppCategory fromName(String? name) =>
      values.firstWhere((c) => c.name == name, orElse: () => AppCategory.study);
}
