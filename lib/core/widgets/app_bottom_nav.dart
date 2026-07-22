import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// The four primary destinations, matching the floating bottom bar in the
/// design (Calendar · Focus · Stats · Profile).
enum AppNavTab {
  calendar('Calendar', Icons.calendar_today_rounded),
  focus('Focus', Icons.self_improvement_rounded),
  stats('Stats', Icons.bar_chart_rounded),
  profile('Profile', Icons.person_outline_rounded);

  const AppNavTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Floating, pill-shaped bottom navigation bar. The active tab is tinted
/// forest-green with a small dot beneath it.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.current,
    required this.onSelected,
  });

  final AppNavTab current;
  final ValueChanged<AppNavTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final tab in AppNavTab.values)
                _NavItem(
                  tab: tab,
                  active: tab == current,
                  onTap: () => onSelected(tab),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final AppNavTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = active ? colors.primary : colors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tab.icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              tab.label,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: context.reduceMotion ? Duration.zero : AppMotion.subtle,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
