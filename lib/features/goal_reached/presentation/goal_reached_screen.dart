import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/router/nav_helpers.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../growth/presentation/reflection_prompt.dart';
import '../../honest_focus/domain/honest_focus.dart';
import '../../streak/domain/streak_badge.dart';
import '../../streak/presentation/streak_milestone_overlay.dart';
import '../../workout/domain/workout.dart';
import '../domain/goal_reached_args.dart';

/// Screen 14 — celebratory completion screen shown after a focus session.
class GoalReachedScreen extends ConsumerStatefulWidget {
  const GoalReachedScreen({super.key, this.args});

  final GoalReachedArgs? args;

  @override
  ConsumerState<GoalReachedScreen> createState() => _GoalReachedScreenState();
}

class _GoalReachedScreenState extends ConsumerState<GoalReachedScreen> {
  bool _milestoneShown = false;

  GoalReachedArgs? get args => widget.args;

  @override
  void initState() {
    super.initState();
    // If this completion crossed a streak milestone, celebrate it once.
    final badge = args?.milestone == null
        ? null
        : streakBadgeFor(args!.milestone!);
    if (badge != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _milestoneShown) return;
        _milestoneShown = true;
        showStreakMilestone(context, badge);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final profile = ref.watch(userProfileProvider).asData?.value;

    final verdict = args?.verdict ?? FocusVerdict.full;
    final counted = args?.counted ?? true;
    final points = args?.points ?? (counted ? 20 : 0);
    final streak = args?.streak ?? profile?.streak ?? 0;
    final isSport = args?.isSport ?? false;
    final nextTitle = args?.nextTaskTitle;
    final focusSeconds = args?.focusSeconds ?? 0;
    final distractions = args?.distractions ?? 0;
    final completionPercent = args?.completionPercent ?? 1.0;
    final awardedPoints = args?.awardedPoints ?? points;
    final fullCompletion = args?.fullCompletion ?? true;

    final title = switch (verdict) {
      FocusVerdict.full => 'goal.title_full'.tr(),
      FocusVerdict.partial => 'goal.title_partial'.tr(),
      FocusVerdict.incomplete => 'goal.title_incomplete'.tr(),
    };
    final message = switch (verdict) {
      FocusVerdict.full =>
        isSport
            ? 'goal.message_full_sport'.tr()
            : 'goal.message_full_focus'.tr(),
      FocusVerdict.partial => 'goal.message_partial'.tr(),
      FocusVerdict.incomplete => 'goal.message_incomplete'.tr(),
    };
    final accent = counted ? colors.primary : colors.textTertiary;

    return Scaffold(
      bottomNavigationBar: AppBottomNav(
        current: AppNavTab.focus,
        onSelected: (tab) => goToTab(context, tab),
      ),
      body: SafeArea(
        bottom: false,
        child: FitOrScroll(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              Row(
                children: [
                  const BrandLogo(),
                  const Spacer(),
                  AvatarCircle(
                    avatarKey: profile?.avatar ?? 'leaf',
                    size: 40,
                    photoBase64: profile?.photoBase64,
                    photoUrl: profile?.photoUrl,
                  ),
                ],
              ),
              const Spacer(),
              // Points badge + medallion (gentle for sessions that didn't count).
              PopIn(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: counted
                            ? AppColors.personalText
                            : colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: counted
                          ? AnimatedCount(
                              value: points,
                              prefix: '+',
                              suffix: ' ${'common.pts'.tr()}',
                              style: AppTextStyles.label.copyWith(
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'goal.didnt_count'.tr(),
                              style: AppTextStyles.label.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.border, width: 2),
                      ),
                      child: Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            counted ? Icons.check_rounded : Icons.spa_rounded,
                            color: colors.onPrimary,
                            size: 34,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                title,
                style: AppTextStyles.h2.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: colors.textSecondary),
              ),
              if (!fullCompletion && counted) ...[
                const SizedBox(height: 8),
                Text(
                  'goal.partial_progress'.tr(
                    namedArgs: {
                      'percent': '${(completionPercent * 100).round()}',
                      'points': '$awardedPoints',
                      'fullPoints': '${args?.points ?? 0}',
                    },
                  ),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (args?.workout != null)
                _WorkoutSummaryCard(result: args!.workout!)
              else
                _SessionSummaryCard(
                  focusSeconds: focusSeconds,
                  distractions: distractions,
                  counted: counted,
                  points: points,
                ),
              if (counted) ...[
                const SizedBox(height: 14),
                _StreakPill(streak: streak),
              ],
              const SizedBox(height: 16),
              // Gentle, optional post-session reflection (skippable).
              ReflectionPrompt(
                taskTitle: args?.taskTitle ?? 'goal.your_session'.tr(),
              ),
              const Spacer(),
              AppButton(
                label: 'goal.finish_session'.tr(),
                onPressed: () => context.go(AppRoutes.dailyPlan),
              ),
              const SizedBox(height: 14),
              if (nextTitle != null)
                AppCard(
                  onTap: () => context.go(AppRoutes.deepFocus),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'goal.up_next'.tr(),
                              style: AppTextStyles.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              nextTitle,
                              style: AppTextStyles.h3.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Calm end-of-session summary: focus time, redirects, whether it counted, and
/// points earned.
class _SessionSummaryCard extends StatelessWidget {
  const _SessionSummaryCard({
    required this.focusSeconds,
    required this.distractions,
    required this.counted,
    required this.points,
  });

  final int focusSeconds;
  final int distractions;
  final bool counted;
  final int points;

  String get _focusLabel {
    final m = focusSeconds ~/ 60;
    final s = focusSeconds % 60;
    if (m == 0) return '${s}s';
    return s == 0 ? '${m}m' : '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        children: [
          _SummaryRow(
            icon: Icons.timer_outlined,
            label: 'goal.focus_time'.tr(),
            value: _focusLabel,
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            icon: Icons.spa_outlined,
            label: 'goal.times_redirected'.tr(),
            value: '$distractions',
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            icon: counted ? Icons.verified_outlined : Icons.refresh_rounded,
            label: 'goal.counted'.tr(),
            value: counted ? 'goal.counted_yes'.tr() : 'goal.counted_no'.tr(),
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            icon: Icons.eco_outlined,
            label: 'goal.points_earned'.tr(),
            value: counted ? '+$points' : '0',
          ),
        ],
      ),
    );
  }
}

/// End-of-workout summary: per-exercise reps completed, totals, and time.
class _WorkoutSummaryCard extends StatelessWidget {
  const _WorkoutSummaryCard({required this.result});

  final WorkoutResult result;

  String get _timeLabel {
    final m = result.totalSeconds ~/ 60;
    final s = result.totalSeconds % 60;
    return m == 0 ? '${s}s' : '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in result.exercises) ...[
            _SummaryRow(
              icon: Icons.fitness_center_rounded,
              label: e.name,
              value: 'goal.reps'.tr(
                namedArgs: {
                  'done': '${e.repsCompleted}',
                  'total': '${e.totalReps}',
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
          Divider(height: 1, color: colors.border),
          const SizedBox(height: 12),
          _SummaryRow(
            icon: Icons.numbers_rounded,
            label: 'goal.total_reps'.tr(),
            value: '${result.totalReps}',
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            icon: Icons.timer_outlined,
            label: 'goal.total_time'.tr(),
            value: _timeLabel,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
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
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(color: colors.textSecondary),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.label.copyWith(color: colors.textPrimary),
        ),
      ],
    );
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            color: Color(0xFFE08A4B),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'common.days_streak'.tr(namedArgs: {'count': '$streak'}),
            style: AppTextStyles.label.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(width: 10),
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i < (streak.clamp(0, 5))
                      ? colors.primary
                      : colors.border,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
