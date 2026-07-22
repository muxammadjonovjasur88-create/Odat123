import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

/// Screen 17 — explains the points rules (base rate, deep work, consistency).
class PointSystemScreen extends StatelessWidget {
  const PointSystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      body: SafeArea(
        child: FitOrScroll(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                  onPressed: () => context.pop(),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.sportFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.eco_rounded,
                  color: AppColors.forest,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'points.how_it_works'.tr(),
                style: AppTextStyles.h1.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                'points.intro'.tr(),
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 28),
              _RuleCard(
                icon: Icons.schedule_rounded,
                tint: AppColors.studyFill,
                label: 'points.base_rate'.tr(),
                detail: 'points.base_rate_detail'.tr(),
              ),
              const SizedBox(height: 14),
              _RuleCard(
                icon: Icons.eco_rounded,
                tint: AppColors.sportFill,
                label: 'points.deep_work'.tr(),
                detail: 'points.deep_work_detail'.tr(),
              ),
              const SizedBox(height: 14),
              _RuleCard(
                icon: Icons.bolt_rounded,
                tint: AppColors.personalFill,
                label: 'points.consistency'.tr(),
                detail: 'points.consistency_detail'.tr(),
              ),
              const Spacer(),
              AppButton(
                label: 'points.got_it'.tr(),
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.icon,
    required this.tint,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final Color tint;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: AppColors.forest),
          ),
          const SizedBox(width: 14),
          // Expanded so the detail text wraps within the card instead of
          // overflowing to the right (longer in Uzbek/Russian).
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.overline.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: AppTextStyles.label.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
