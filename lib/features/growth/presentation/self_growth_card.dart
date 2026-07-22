import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../gamification/data/gamification_repository.dart';
import '../data/growth_providers.dart';

/// The user's OWN growth — the primary motivator. Shows this week's focus in
/// absolute hours and a gentle self-comparison vs last week (never shame: a
/// dip is reframed, never shown as a negative rank or "you fell behind"), plus
/// a small personal 6-week growth chart.
class SelfGrowthCard extends ConsumerWidget {
  const SelfGrowthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final thisWeek = ref.watch(weekStatsProvider).asData?.value ?? const [];
    final lastWeek = ref.watch(lastWeekStatsProvider).asData?.value ?? const [];
    final recent =
        ref.watch(recentWeeksStatsProvider).asData?.value ?? const [];

    final thisMin = weekFocusMinutes(thisWeek);
    final lastMin = weekFocusMinutes(lastWeek);
    final hours = (thisMin / 60).toStringAsFixed(1);
    final growth = weeklyGrowthPercent(thisMin, lastMin);
    final buckets = weeklyFocusBuckets(recent);

    // Always-positive comparison copy.
    final String comparison;
    if (growth != null && growth > 0) {
      comparison = 'growth.more_than_last_week'.tr(
        namedArgs: {'percent': '$growth'},
      );
    } else if (growth != null && growth == 0) {
      comparison = 'growth.on_pace_last_week'.tr();
    } else if (lastMin > 0) {
      // A dip: reframe gently, never as a loss.
      comparison = 'growth.every_session_counts'.tr();
    } else {
      comparison = 'growth.calm_strong_start'.tr();
    }

    return AppCard(
      color: colors.tintSage,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'growth.your_growth'.tr(),
                style: AppTextStyles.label.copyWith(color: colors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hours,
                style: AppTextStyles.display.copyWith(
                  color: colors.textPrimary,
                  fontSize: 40,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              // Flexible so long Russian/Uzbek labels wrap instead of overflowing.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'growth.hours_focused_this_week'.tr(),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            comparison,
            style: AppTextStyles.body.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 18),
          _GrowthChart(buckets: buckets),
        ],
      ),
    );
  }
}

class _GrowthChart extends StatelessWidget {
  const _GrowthChart({required this.buckets});

  final List<int> buckets;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxVal = buckets
        .fold<int>(0, (m, v) => v > m ? v : m)
        .clamp(1, 1 << 30);
    final n = buckets.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 72,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FractionallySizedBox(
                      alignment: Alignment.bottomCenter,
                      heightFactor: (0.06 + 0.94 * (buckets[i] / maxVal)).clamp(
                        0.04,
                        1.0,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: i == n - 1
                              ? colors.primary
                              : AppColors.sportFill,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'growth.weeks_ago'.tr(namedArgs: {'count': '${n - 1}'}),
              style: AppTextStyles.caption.copyWith(color: colors.textTertiary),
            ),
            Text(
              'growth.this_week'.tr(),
              style: AppTextStyles.caption.copyWith(color: colors.primary),
            ),
          ],
        ),
      ],
    );
  }
}
