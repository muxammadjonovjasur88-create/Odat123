import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Zen Kinetic Daily Quests — glassmorphism quest cards with neon lime/cyan
/// telemetry accents. Each quest card features glowing borders, icon halos,
/// and a premium pill badge — the Stitch "Zen Kinetic" design system.
class DailyQuestsWidget extends StatelessWidget {
  const DailyQuestsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 12),
          child: Row(
            children: [
              // Section label caps — JetBrains Mono telemetry style
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.neonLime.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.neonLime.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Text(
                  'daily_quests_title'.tr().toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neonLime,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        _ZenQuestCard(
          title: 'quest_running'.tr(),
          subtitle: '3.0 KM TARGET',
          icon: Icons.directions_run_rounded,
          accentColor: AppColors.cyanAccent,
          onTap: () => context.push(AppRoutes.running),
        ),
        const SizedBox(height: 10),
        _ZenQuestCard(
          title: 'Kamera Vision Mashqlari',
          subtitle: 'SQUAT · PUSHUP · PLANK',
          icon: Icons.fitness_center_rounded,
          accentColor: AppColors.neonLime,
          onTap: () => context.push(AppRoutes.exerciseSelect),
        ),
        const SizedBox(height: 10),
        _ZenQuestCard(
          title: 'quest_reading'.tr(),
          subtitle: 'KUTUBXONA',
          icon: Icons.menu_book_rounded,
          accentColor: const Color(0xFFB388FF),
          onTap: () => context.push(AppRoutes.library),
        ),
      ],
    );
  }
}

/// A premium glassmorphism quest card — Zen Kinetic design language.
///
/// Visual anatomy (Stitch spec):
/// - Level-1 glass surface: semi-transparent dark slate with 1px inner glow border
/// - Icon halo: round gradient container with atmospheric underglow
/// - Title: Inter semibold white
/// - Subtitle: JetBrains Mono caps — telemetry label style
/// - Arrow: faint right chevron
/// - Atmospheric underglow shadow tinted by accent colour
class _ZenQuestCard extends StatelessWidget {
  const _ZenQuestCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: accentColor.withValues(alpha: 0.10),
        highlightColor: accentColor.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            // Glassmorphism Level-1 surface
            color: const Color(0xB3122131),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.glassEdge,
              width: 1,
            ),
            boxShadow: [
              // Accent underglow — Stitch Zen Kinetic atmospheric glow
              BoxShadow(
                color: accentColor.withValues(alpha: 0.14),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
              const BoxShadow(
                color: Color(0x40000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon halo — circular gradient container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.30),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              // Title + Telemetry label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.h3.copyWith(
                        color: const Color(0xFFD4E4FA),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // JetBrains Mono telemetry label
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: accentColor.withValues(alpha: 0.8),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Arrow indicator
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.20),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: accentColor.withValues(alpha: 0.8),
                  size: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

