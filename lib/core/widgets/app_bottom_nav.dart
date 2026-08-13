import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_text_styles.dart';

/// The five primary destinations matching the Zen Kinetic dark theme:
/// Dashboard (0), Eslatma (1), AI (2 - Center), Leaderboard (3), Profile (4).
enum AppNavTab {
  dashboard('Dashboard', 'nav.dashboard', Icons.dashboard_rounded),
  zametka('Eslatma', 'nav_note', Icons.edit_note_rounded),
  ai('AI', 'nav.ai', Icons.auto_awesome_rounded),
  leaderboard('Leaderboard', 'nav.leaderboard', Icons.emoji_events_rounded),
  profile('Profile', 'nav.profile', Icons.person_rounded);

  const AppNavTab(this.defaultLabel, this.translationKey, this.icon);

  final String defaultLabel;
  final String translationKey;
  final IconData icon;

  String get label => translationKey.tr();
}

/// Floating glassmorphism 5-tab bottom nav — Zen Kinetic design system.
/// Active state: Neon Lime icon + label + small glowing dot underneath.
/// Inactive state: muted slate-blue icon, no label color.
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            // Glassmorphism: semi-transparent dark base
            color: const Color(0xE6051424),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: AppColors.glassEdge,
              width: 1,
            ),
            boxShadow: [
              // Cyan underglow — Zen Kinetic atmospheric glow
              BoxShadow(
                color: AppColors.cyanAccent.withValues(alpha: 0.12),
                blurRadius: 32,
                spreadRadius: 0,
                offset: const Offset(0, 0),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final tab in AppNavTab.values)
                Expanded(
                  child: tab == AppNavTab.ai
                      ? _CenterAiNavItem(
                          active: tab == current,
                          onTap: () => onSelected(tab),
                        )
                      : _NavItem(
                          tab: tab,
                          active: tab == current,
                          onTap: () => onSelected(tab),
                        ),
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
    // Zen Kinetic: Neon Lime for active, muted slate for inactive
    const activeColor = AppColors.neonLime;
    const inactiveColor = Color(0xFF5A6A7A);

    final color = active ? activeColor : inactiveColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: activeColor.withValues(alpha: 0.08),
      highlightColor: activeColor.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with optional active glow
            AnimatedContainer(
              duration: AppMotion.subtle,
              padding: const EdgeInsets.all(4),
              decoration: active
                  ? BoxDecoration(
                      color: AppColors.neonLime.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    )
                  : null,
              child: Icon(tab.icon, size: 22, color: color),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tab.label,
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  letterSpacing: active ? 0.3 : 0,
                ),
              ),
            ),
            const SizedBox(height: 3),
            // Neon dot — Zen Kinetic active indicator
            AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: context.reduceMotion ? Duration.zero : AppMotion.subtle,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.neonLime,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonLime.withValues(alpha: 0.8),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterAiNavItem extends StatelessWidget {
  const _CenterAiNavItem({
    required this.active,
    required this.onTap,
  });

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.cyanAccent, AppColors.neonLime],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyanAccent.withValues(alpha: active ? 0.7 : 0.35),
                  blurRadius: active ? 20 : 10,
                  spreadRadius: active ? 3 : 0,
                ),
              ],
              border: active
                  ? Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2)
                  : null,
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 22,
              color: Color(0xFF051424),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'AI',
            style: AppTextStyles.caption.copyWith(
              color: active ? AppColors.cyanAccent : const Color(0xFF5A6A7A),
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

