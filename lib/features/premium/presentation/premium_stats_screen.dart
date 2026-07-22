import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/premium_providers.dart';
import '../domain/premium.dart';
import 'premium_badge.dart';

/// Premium "Deep Stats" — monthly focus trends, most productive time, growth vs
/// last month, and streak history. Gated: a free user (while the system is on)
/// sees a calm upsell instead of the data.
class PremiumStatsScreen extends ConsumerWidget {
  const PremiumStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(premiumEnabledProvider);
    final isPremium = ref.watch(isPremiumProvider);
    final locked = enabled && !isPremium;

    return Scaffold(
      appBar: AppBar(
        title: Text('premium.deep_stats'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: locked
            ? _LockedUpsell(onUpgrade: () => context.push(AppRoutes.paywall))
            : const _Stats(),
      ),
    );
  }
}

class _Stats extends ConsumerWidget {
  const _Stats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final profile = ref.watch(userProfileProvider).asData?.value;
    final thisMonth =
        ref.watch(thisMonthStatsProvider).asData?.value ?? const [];
    final lastMonth =
        ref.watch(lastMonthStatsProvider).asData?.value ?? const [];

    final thisMinutes = totalFocusMinutes(thisMonth);
    final lastMinutes = totalFocusMinutes(lastMonth);
    final growth = growthPercent(thisMinutes, lastMinutes);
    final productive = mostProductiveLabel(thisMonth);

    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final byDay = List<int>.filled(daysInMonth, 0);
    for (final d in thisMonth) {
      final i = d.date.day - 1;
      if (i >= 0 && i < daysInMonth) byDay[i] = d.focusMinutes;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Row(
          children: [
            Text(
              'premium.this_month'.tr(),
              style: AppTextStyles.h2.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(width: 10),
            const PremiumBadge(showLabel: true),
          ],
        ),
        const SizedBox(height: 16),
        _BigFocusCard(minutes: thisMinutes),
        const SizedBox(height: 14),
        _MonthlyChartCard(byDay: byDay, today: now.day),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _MiniStat(
                icon: Icons.trending_up_rounded,
                label: 'premium.vs_last_month'.tr(),
                value: growth == null
                    ? '—'
                    : '${growth >= 0 ? '+' : ''}$growth%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniStat(
                icon: Icons.wb_twilight_rounded,
                label: 'premium.most_productive'.tr(),
                value: productive == null ? '—' : _capitalize(productive.tr()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _StreakHistoryCard(
          streak: profile?.streak ?? 0,
          longest: profile?.longestStreak ?? 0,
          freezes: profile?.freezes ?? 0,
        ),
      ],
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _BigFocusCard extends StatelessWidget {
  const _BigFocusCard({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hours = (minutes / 60);
    return AppCard(
      color: colors.tintSage,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.schedule_rounded,
              color: colors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'premium.hours_value'.tr(
                  namedArgs: {'hours': hours.toStringAsFixed(1)},
                ),
                style: AppTextStyles.display.copyWith(
                  color: colors.textPrimary,
                  fontSize: 34,
                ),
              ),
              Text(
                'premium.focused_month'.tr(),
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthlyChartCard extends StatelessWidget {
  const _MonthlyChartCard({required this.byDay, required this.today});

  final List<int> byDay;
  final int today;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxVal = byDay.fold<int>(0, (m, v) => v > m ? v : m).clamp(1, 99999);
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'premium.daily_focus_minutes'.tr(),
            style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < byDay.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: FractionallySizedBox(
                        alignment: Alignment.bottomCenter,
                        heightFactor: (0.04 + 0.96 * (byDay[i] / maxVal)).clamp(
                          0.02,
                          1.0,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: (i + 1) == today
                                ? colors.primary
                                : AppColors.sportFill,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'premium.day_n'.tr(namedArgs: {'n': '1'}),
                style: AppTextStyles.caption.copyWith(
                  color: colors.textTertiary,
                ),
              ),
              Text(
                'premium.day_n'.tr(namedArgs: {'n': '${byDay.length}'}),
                style: AppTextStyles.caption.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StreakHistoryCard extends StatelessWidget {
  const _StreakHistoryCard({
    required this.streak,
    required this.longest,
    required this.freezes,
  });

  final int streak;
  final int longest;
  final int freezes;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget tile(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.h2.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'premium.streak_history'.tr(),
            style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              tile('$streak', 'premium.current'.tr()),
              tile('$longest', 'premium.longest'.tr()),
              tile('$freezes', 'premium.freezes'.tr()),
            ],
          ),
        ],
      ),
    );
  }
}

class _LockedUpsell extends StatelessWidget {
  const _LockedUpsell({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: kPremiumGoldSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.insights_rounded,
                size: 36,
                color: kPremiumGold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'premium.locked_title'.tr(),
              textAlign: TextAlign.center,
              style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'premium.locked_body'.tr(),
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'premium.unlock'.tr(),
              icon: Icons.workspace_premium_rounded,
              expand: false,
              onPressed: onUpgrade,
            ),
          ],
        ),
      ),
    );
  }
}
