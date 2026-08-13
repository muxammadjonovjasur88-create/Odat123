import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/router/nav_helpers.dart';
import '../../../core/services/firebase_providers.dart';
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
  bool _moodShown = false;

  GoalReachedArgs? get args => widget.args;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[GoalReached] ========== SCREEN OPENED ==========\n'
      '[GoalReached] args == null? ${args == null}\n'
      '[GoalReached] args.points=${args?.points}\n'
      '[GoalReached] args.awardedPoints=${args?.awardedPoints}\n'
      '[GoalReached] args.streak=${args?.streak}\n'
      '[GoalReached] args.verdict=${args?.verdict}\n'
      '[GoalReached] args.counted=${args?.counted}\n'
      '[GoalReached] args.taskTitle=${args?.taskTitle}\n'
      '[GoalReached] args.completionPercent=${args?.completionPercent}\n'
      '[GoalReached] args.fullCompletion=${args?.fullCompletion}\n'
      '[GoalReached] args.integrityPercent=${args?.integrityPercent}\n'
      '[GoalReached] args.focusSeconds=${args?.focusSeconds}\n'
      '[GoalReached] args.isSport=${args?.isSport}\n'
      '[GoalReached] args.pointsError=${args?.pointsError}\n'
      '[GoalReached] args.errorMessage=${args?.errorMessage}\n'
      '[GoalReached] ====================================',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // If this completion crossed a streak milestone, celebrate it once.
      final badge = args?.milestone == null
          ? null
          : streakBadgeFor(args!.milestone!);
      if (badge != null && !_milestoneShown) {
        _milestoneShown = true;
        showStreakMilestone(context, badge);
      }

      // Auto-show mood check-in after a brief delay so the screen animates
      // in first. Guard against being called twice (e.g. hot-reload).
      if (!_moodShown) {
        _moodShown = true;
        Future.delayed(const Duration(milliseconds: 650), () {
          if (!mounted) return;
          try {
            showSessionMoodSheet(
              context,
              ref: ref,
              taskId: args?.taskTitle ?? '',
              taskTitle: args?.taskTitle,
            );
          } catch (e, st) {
            debugPrint('[GoalReached] ❌ showSessionMoodSheet exception: $e\n$st');
          }
        });
      }
    });
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
        current: AppNavTab.dashboard,
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
              if (args != null && args!.pointsError) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryPressed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.primaryPressed.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        color: colors.primaryPressed,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          args!.errorMessage ??
                              'Ochko saqlashda xato yuz berdi, internetni tekshiring',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (args != null && args!.integrityPercent < 1.0 && counted) ...[
                const SizedBox(height: 16),
                Container(
                   padding: const EdgeInsets.all(12),
                   decoration: BoxDecoration(color: colors.surfaceMuted, borderRadius: BorderRadius.circular(12)),
                   child: Text(
                     'goal.integrity_reduced'.tr(
                       namedArgs: {
                         'basePoints': '${args!.points}',
                         'awardedPoints': '$awardedPoints',
                       },
                     ),
                     textAlign: TextAlign.center,
                     style: AppTextStyles.caption.copyWith(color: colors.textPrimary),
                   ),
                ),
              ],
              if (args != null && args!.integrityPercent == 1.0 && counted) ...[
                const SizedBox(height: 16),
                Container(
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                   decoration: BoxDecoration(color: colors.surfaceMuted, borderRadius: BorderRadius.circular(20)),
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                        Icon(Icons.star_rounded, color: colors.primary, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'goal.honest_session'.tr(),
                          style: AppTextStyles.caption.copyWith(color: colors.primary, fontWeight: FontWeight.bold),
                        ),
                     ],
                   ),
                ),
              ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Post-session mood check-in sheet
// ─────────────────────────────────────────────────────────────────────────────

/// Mood value constants matching the backend format used in proofSessions.
const _kMoodGreat = 'great';
const _kMoodHard = 'hard';
const _kMoodMissed = 'missed';

class _MoodOption {
  const _MoodOption({
    required this.value,
    required this.emoji,
    required this.labelKey,
    required this.color,
  });

  final String value;
  final String emoji;
  final String labelKey;
  final Color color;
}

const _kMoodOptions = [
  _MoodOption(
    value: _kMoodGreat,
    emoji: '😊',
    labelKey: 'goal.mood_great',
    color: Color(0xFF22C55E),
  ),
  _MoodOption(
    value: _kMoodHard,
    emoji: '😐',
    labelKey: 'goal.mood_hard',
    color: Color(0xFFEAB308),
  ),
  _MoodOption(
    value: _kMoodMissed,
    emoji: '😔',
    labelKey: 'goal.mood_missed',
    color: Color(0xFFEF4444),
  ),
];

/// Shows the post-session mood check-in as a modal bottom sheet.
///
/// Saves the selected mood to `proofSessions` collection in Firestore using the
/// existing `moodResponse` format ('great' / 'hard' / 'missed') so the weekly
/// AI analysis backend can pick it up without any changes.
///
/// The sheet is non-blocking: swiping it away, tapping outside, or pressing
/// "Skip" leaves the session result intact — only [moodResponse] is omitted.
Future<void> showSessionMoodSheet(
  BuildContext context, {
  required WidgetRef ref,
  required String taskId,
  String? taskTitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SessionMoodSheet(
      firestoreInstance: ref.read(firestoreProvider),
      uid: FirebaseAuth.instance.currentUser?.uid,
      taskId: taskId,
      taskTitle: taskTitle,
    ),
  );
}

class _SessionMoodSheet extends StatefulWidget {
  const _SessionMoodSheet({
    required this.firestoreInstance,
    required this.uid,
    required this.taskId,
    this.taskTitle,
  });

  final FirebaseFirestore firestoreInstance;
  final String? uid;
  final String taskId;
  final String? taskTitle;

  @override
  State<_SessionMoodSheet> createState() => _SessionMoodSheetState();
}

class _SessionMoodSheetState extends State<_SessionMoodSheet> {
  String? _selected;
  bool _saving = false;

  Future<void> _pickMood(_MoodOption option) async {
    if (_saving || _selected != null) return;
    setState(() {
      _selected = option.value;
      _saving = true;
    });

    try {
      await widget.firestoreInstance.collection('proofSessions').add({
        'userId': widget.uid ?? '',
        'taskId': widget.taskId,
        'taskTitle': widget.taskTitle ?? widget.taskId,
        'moodResponse': option.value,   // 'great' | 'hard' | 'missed'
        'status': 'completed',
        'source': 'focus_session',      // distinguishes from random-proof entries
        'scheduledTime': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[SessionMood] Firestore write failed: $e');
      // Silently ignore — session result is already persisted; mood is optional.
    }

    // Brief visual confirmation before auto-closing.
    await Future.delayed(const Duration(milliseconds: 550));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Text(
            'goal.mood_sheet_title'.tr(),
            textAlign: TextAlign.center,
            style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'goal.mood_sheet_subtitle'.tr(),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          // Emoji row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _kMoodOptions.map((option) {
              final isSelected = _selected == option.value;
              final isAnySelected = _selected != null;
              final isDimmed = isAnySelected && !isSelected;

              return AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: isDimmed ? 0.28 : 1.0,
                child: GestureDetector(
                  onTap: _saving ? null : () => _pickMood(option),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 380),
                    scale: isSelected ? 1.25 : 1.0,
                    curve: Curves.elasticOut,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? option.color.withValues(alpha: 0.18)
                                : colors.surfaceMuted,
                            border: Border.all(
                              color: isSelected
                                  ? option.color
                                  : colors.border.withValues(alpha: 0.5),
                              width: isSelected ? 2.5 : 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: option.color.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 18,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : const [],
                          ),
                          child: Center(
                            child: Text(
                              option.emoji,
                              style: const TextStyle(fontSize: 36),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          option.labelKey.tr(),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            color: isSelected
                                ? option.color
                                : colors.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          // Loading indicator or Skip button
          if (_saving)
            const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'goal.mood_skip'.tr(),
                style: AppTextStyles.body.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 4),
        ],
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

/// Whether this streak count is a badge milestone.
bool _isMilestoneStreak(int s) => s == 7 || s == 30 || s == 100;

/// Streak pill shown on the Goal Reached screen with an optional one-shot
/// celebration burst when a milestone streak is reached.
class _StreakPill extends StatefulWidget {
  const _StreakPill({required this.streak});

  final int streak;

  @override
  State<_StreakPill> createState() => _StreakPillState();
}

class _StreakPillState extends State<_StreakPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  static const _flameColor = Color(0xFFE08A4B);
  static const _numParticles = 6;
  static final _random = math.Random(42); // fixed seed for determinism
  static final _angles = List.generate(
    _numParticles,
    (i) => 2 * math.pi * i / _numParticles + _random.nextDouble() * 0.4,
  );

  @override
  void initState() {
    super.initState();
    if (_isMilestoneStreak(widget.streak)) {
      // Small delay so the screen entrance animation completes first.
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) _c.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final streak = widget.streak;
    final isMilestone = _isMilestoneStreak(streak);

    final pill = Container(
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
            color: _flameColor,
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

    if (!isMilestone) return pill;

    // Milestone: wrap in particle burst animation.
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final radius = 36.0 * Curves.easeOut.transform(t);
        final opacity = t < 0.5 ? 1.0 : 1.0 - (t - 0.5) / 0.5;

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            child!,
            if (t > 0)
              ...List.generate(_numParticles, (i) {
                final angle = _angles[i];
                final dx = math.cos(angle) * radius;
                final dy = math.sin(angle) * radius;
                return Positioned(
                  // Anchor near the flame icon (left edge of pill).
                  left: 20 + dx,
                  top: 18 + dy,
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
      child: pill,
    );
  }
}
