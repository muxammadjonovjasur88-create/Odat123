import 'package:flutter/material.dart';

import '../constants/app_category.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// A small rounded pill. Two ways to use it:
///
/// * [AppChip.category] — a category tag (study / sport / work …) using the
///   category's own pastel colors, as seen on the daily plan and add-goal
///   screens.
/// * [AppChip] (default) — a neutral selectable filter pill; when [selected]
///   it gains the forest-green outline used for the chosen option.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.fill,
    this.foreground,
  });

  /// Builds a chip styled for a [AppCategory].
  factory AppChip.category(
    AppCategory category, {
    Key? key,
    bool selected = false,
    VoidCallback? onTap,
  }) => AppChip(
    key: key,
    label: category.label,
    selected: selected,
    onTap: onTap,
    fill: category.fill,
    foreground: category.foreground,
  );

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Custom background; defaults to the muted surface for neutral chips.
  final Color? fill;

  /// Custom foreground; defaults to secondary text for neutral chips.
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final bg = fill ?? colors.surfaceMuted;
    final fg = foreground ?? colors.textSecondary;
    final border = selected
        ? Border.all(color: colors.primary, width: 1.6)
        : Border.all(color: Colors.transparent, width: 1.6);

    final pill = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 6),
          ],
          Text(label, style: AppTextStyles.chip.copyWith(color: fg)),
        ],
      ),
    );

    if (onTap == null) return pill;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: pill,
    );
  }
}
