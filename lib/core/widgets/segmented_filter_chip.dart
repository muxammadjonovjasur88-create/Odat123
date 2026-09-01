import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// A reusable segmented filter chip widget matching Flowa's design system.
///
/// Used for filter tabs in ShopScreen, MyPurchasesScreen, and segmented controls.
/// Supports smooth animated transitions (`Curves.easeInOutCubic`, ~250ms),
/// pill gradient active fill with cyan glow, and muted/transparent inactive states.
class SegmentedFilterChip extends StatelessWidget {
  const SegmentedFilterChip({
    super.key,
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
    this.padding,
    this.expanded = false,
    this.transparentInactive = false,
  });

  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  /// If true, expands the chip to fill available horizontal space in a [Row].
  final bool expanded;

  /// If true, inactive state uses a transparent background and border.
  /// Ideal when placed inside a pre-styled segmented control container.
  final bool transparentInactive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    const activeGradient = LinearGradient(
      colors: [AppColors.cyanAccent, Color(0xFF0099CC)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final inactiveBg = transparentInactive ? Colors.transparent : colors.surfaceMuted;
    final inactiveBorder = transparentInactive
        ? Colors.transparent
        : colors.border.withValues(alpha: 0.6);

    final chipContent = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: isSelected ? activeGradient : null,
        color: isSelected ? null : inactiveBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppColors.cyanAccent : inactiveBorder,
          width: 1.2,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.cyanAccent.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                )
              ]
            : (transparentInactive
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.black : colors.textSecondary,
            ),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: isSelected ? Colors.black : colors.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13.5,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

    Widget result = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: chipContent,
    );

    if (expanded) {
      result = Expanded(child: result);
    }

    return result;
  }
}
