import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_text_styles.dart';
import 'bouncy_scale.dart';

/// The five primary destinations matching the Phoenix dark theme:
/// Dashboard (0), Eslatma (1), AI (2 - Center), Leaderboard (3), Profile (4).
enum AppNavTab {
  dashboard('Bosh sahifa', 'nav.dashboard', Icons.dashboard_rounded),
  zametka('Eslatma', 'nav_note', Icons.alarm_rounded),
  ai('Odat AI', 'nav.ai', Icons.auto_awesome_rounded),
  leaderboard('Reyting', 'nav.leaderboard', Icons.emoji_events_rounded),
  profile('Profil', 'nav.profile', Icons.person_rounded);

  const AppNavTab(this.defaultLabel, this.translationKey, this.icon);

  final String defaultLabel;
  final String translationKey;
  final IconData icon;

  String get label => translationKey.tr();
}

/// Floating glassmorphism 5-tab bottom nav — Phoenix design system.
/// Active state: Electric Blue icon + label + small glowing dot underneath.
/// Inactive state: muted cool gray icon, no label color.
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
          height: 70,
          decoration: BoxDecoration(
            color: const Color(0xF0121826),
            borderRadius: BorderRadius.circular(35),
            border: Border.all(
              color: const Color(0xFF1E283D),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x4D000000),
                blurRadius: 24,
                offset: Offset(0, 8),
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
    const activeColor = Color(0xFF38BDF8);
    const inactiveColor = Color(0xFF64748B);

    final color = active ? activeColor : inactiveColor;

    return BouncyScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppMotion.subtle,
              padding: const EdgeInsets.all(6),
              decoration: active
                  ? BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    )
                  : null,
              child: Icon(tab.icon, size: 21, color: color),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tab.label,
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: active ? 0.2 : 0,
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
    return BouncyScale(
      onTap: onTap,
      scaleFactor: 0.90,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF38BDF8), Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'AI',
            style: AppTextStyles.caption.copyWith(
              color: active ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

