import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/router/nav_helpers.dart';
import '../../../core/services/user_repository.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../gamification/data/gamification_repository.dart';
import '../../gamification/domain/daily_stats.dart';
import '../../growth/presentation/level_card.dart';
import '../../growth/presentation/self_growth_card.dart';
import '../../premium/data/premium_providers.dart';
import '../../premium/presentation/ai_coach_card.dart';
import '../../premium/presentation/premium_badge.dart';

/// Screen 20 — personal progress: daily points ring, streak, totals, the weekly
/// activity chart, and a mindfulness summary.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final profile = ref.watch(userProfileProvider).asData?.value;
    final today = ref.watch(todayStatsProvider).asData?.value;
    final week = ref.watch(weekStatsProvider).asData?.value ?? const [];

    final deepToday = today?.deepSessions ?? 0;
    final premiumOn = ref.watch(premiumEnabledProvider);
    final isPremium = ref.watch(isPremiumProvider);

    return Scaffold(
      bottomNavigationBar: AppBottomNav(
        current: AppNavTab.stats,
        onSelected: (tab) => goToTab(context, tab),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            Row(
              children: [
                const BrandLogo(),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'progress.growth_circle'.tr(),
                      icon: Icon(
                        Icons.groups_outlined,
                        color: colors.textSecondary,
                      ),
                      onPressed: () => context.push(AppRoutes.community),
                    ),
                    IconButton(
                      tooltip: 'progress.how_points_work'.tr(),
                      icon: Icon(
                        Icons.help_outline_rounded,
                        color: colors.textSecondary,
                      ),
                      onPressed: () => context.push(AppRoutes.pointSystem),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => context.push(AppRoutes.profile),
                      child: Builder(
                        builder: (context) {
                          final user = profile;
                          if (user != null) {
                            debugPrint(
                              'Header avatar: photoUrl=${user.photoUrl}, '
                              'photoBase64 length=${user.photoBase64?.length}',
                            );
                          }
                          return AvatarCircle(
                            avatarKey: profile?.avatar ?? 'leaf',
                            size: 40,
                            photoBase64: profile?.photoBase64,
                            photoUrl: profile?.photoUrl,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Self-growth is the hero; points sit quietly below.
            const SelfGrowthCard(),
            const SizedBox(height: 16),
            _LeaderboardCard(),
            const SizedBox(height: 20),
            if (premiumOn && isPremium) ...[
              const AiCoachCard(),
              const SizedBox(height: 20),
            ],

            // ── Level card — sits between daily ring and detail stats ──
            const LevelCard(),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.schedule_rounded,
                    label: 'progress.total_focus'.tr(),
                    value: 'progress.hours'.tr(
                      namedArgs: {
                        'hours': (profile?.focusHours ?? 0).toStringAsFixed(1),
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _StatCard(
                    icon: Icons.bolt_outlined,
                    label: 'progress.deep_sessions'.tr(),
                    value: 'progress.count_today'.tr(
                      namedArgs: {'count': '$deepToday'},
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _WeeklyActivityCard(week: week),

            if (premiumOn) ...[
              const SizedBox(height: 14),
              const _DeepStatsEntry(),
            ],
          ],
        ),
      ),
    );
  }
}

/// Entry to the premium Deep Stats screen. Free users see it too (with the
/// Premium badge) and reach a calm upsell when they tap.
class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      onTap: () => context.push(AppRoutes.leaderboard),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.tintSage,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              size: 22,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'leaderboard.title'.tr(),
                  style: AppTextStyles.label.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'leaderboard.subtitle'.tr(),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
        ],
      ),
    );
  }
}

class _DeepStatsEntry extends StatelessWidget {
  const _DeepStatsEntry();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      onTap: () => context.push(AppRoutes.premiumStats),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.insights_rounded,
              size: 20,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'progress.deep_monthly_stats'.tr(),
                    style: AppTextStyles.label.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const PremiumBadge(),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
        ],
      ),
    );
  }
}


class _StatCard extends StatelessWidget {
  const _StatCard({
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.tintSage,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: colors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: AppTextStyles.h2.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyActivityCard extends StatelessWidget {
  const _WeeklyActivityCard({required this.week});

  final List<DailyStats> week;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final now = DateTime.now();
    final monday = DateUtils.dateOnly(
      now.subtract(Duration(days: now.weekday - 1)),
    );

    // Map each weekday (0=Mon) to its focus minutes.
    final values = List<int>.filled(7, 0);
    for (final d in week) {
      final i = DateUtils.dateOnly(d.date).difference(monday).inDays;
      if (i >= 0 && i < 7) values[i] = d.focusMinutes;
    }
    final maxVal = (values.fold<int>(
      0,
      (m, v) => v > m ? v : m,
    )).clamp(1, 99999);
    final todayIndex = now.weekday - 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'progress.weekly_activity'.tr(),
            style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (values[i] > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${values[i]}m',
                              style: AppTextStyles.caption.copyWith(
                                color: i == todayIndex ? colors.primary : colors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        // Bar fills a fraction of the available column height,
                        // so it can never overflow the chart area.
                        Expanded(
                          child: FractionallySizedBox(
                            alignment: Alignment.bottomCenter,
                            heightFactor: (0.1 + 0.9 * (values[i] / maxVal))
                                .clamp(0.08, 1.0),
                            child: Container(
                              width: 24,
                              decoration: BoxDecoration(
                                color: i == todayIndex
                                    ? colors.primary
                                    : colors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          labels[i],
                          style: AppTextStyles.caption.copyWith(
                            color: i == todayIndex
                                ? colors.primary
                                : colors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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



