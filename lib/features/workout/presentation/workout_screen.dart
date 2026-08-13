import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/task.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/router/nav_helpers.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/widgets.dart';
import '../../ambient/data/ambient_sound_controller.dart';
import '../../ambient/presentation/ambient_sound_bar.dart';
import '../../deep_focus/data/focus_providers.dart';
import '../../goal_reached/domain/goal_reached_args.dart';
import '../../honest_focus/domain/honest_focus.dart';
import 'workout_session_controller.dart';

/// Screen 13 (workout variant) — structured set-based workout: sets per
/// exercise with timed rests between. Reuses the Zen interval-timer style.
class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key, required this.task});

  final Task task;

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  static const _work = Color(0xFFD49A6A); // warm sport accent
  static const _rest = AppColors.forest;

  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(workoutSessionProvider.notifier).ensureStarted(widget.task);
      ref.read(ambientSoundProvider.notifier).resumeIfSelected();
    });
  }

  WorkoutSessionController get _controller =>
      ref.read(workoutSessionProvider.notifier);

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    final session = ref.read(workoutSessionProvider);
    final result = session?.result();
    GoalReachedArgs? args;
    try {
      args = await completeFocusSession(
        ref,
        widget.task,
        signals: FocusSignals(
          timerCompleted: true,
          totalSeconds: result?.totalSeconds ?? 0,
        ),
        workout: result,
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () => GoalReachedArgs(
          points: widget.task.points > 0 ? widget.task.points : 20,
          taskTitle: widget.task.title,
          streak: 0,
          isSport: true,
          verdict: FocusVerdict.full,
          workout: result,
          focusSeconds: result?.totalSeconds ?? 0,
          awardedPoints: widget.task.points,
        ),
      );
    } catch (e) {
      args = GoalReachedArgs(
        points: widget.task.points > 0 ? widget.task.points : 20,
        taskTitle: widget.task.title,
        streak: 0,
        isSport: true,
        verdict: FocusVerdict.full,
        workout: result,
        focusSeconds: result?.totalSeconds ?? 0,
        awardedPoints: widget.task.points,
      );
    }
    _controller.clear();
    if (mounted) context.go(AppRoutes.goalReached, extra: args);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final profile = ref.watch(userProfileProvider).asData?.value;
    final session = ref.watch(workoutSessionProvider);

    if (session == null || session.taskId != widget.task.id) {
      return const FlowaLoadingScreen();
    }

    // When the last set is done, finish + show the summary.
    ref.listen(workoutSessionProvider, (_, next) {
      if (next != null && next.isFinished && !_finishing) _finish();
    });

    if (session.isFinished && !_finishing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_finishing) _finish();
      });
    }

    final accent = session.isRest ? _rest : _work;

    return Scaffold(
      bottomNavigationBar: AppBottomNav(
        current: AppNavTab.dashboard,
        onSelected: (tab) => goToTab(context, tab),
      ),
      body: SafeArea(
        bottom: false,
        child: FitOrScroll(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Column(
            children: [
              Row(
                children: [
                  const BrandLogo(),
                  const Spacer(),
                  AvatarCircle(avatarKey: profile?.avatar ?? 'leaf', size: 40),
                ],
              ),
              const SizedBox(height: 20),
              _Pill(
                label: session.isRest
                    ? 'workout.rest'.tr()
                    : 'workout.set_based'.tr(),
                color: accent,
              ),
              const SizedBox(height: 14),
              Text(
                session.exercise.name,
                textAlign: TextAlign.center,
                style: AppTextStyles.h1.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'workout.set_of'.tr(
                      namedArgs: {
                        'current': '${session.setNumber}',
                        'total': '${session.exercise.sets}',
                      },
                    ) +
                    (session.isRest
                        ? ''
                        : 'workout.reps_suffix'.tr(
                            namedArgs: {'reps': '${session.currentReps}'},
                          )),
                style: AppTextStyles.body.copyWith(color: colors.textSecondary),
              ),
              const Spacer(),
              _Ring(session: session, accent: accent, colors: colors),
              const SizedBox(height: 14),
              _OverallProgress(session: session, colors: colors),
              const Spacer(),
              if (session.isReady)
                _ReadyControls(onStart: () => _controller.begin(widget.task))
              else if (session.isRest)
                _RestControls(
                  controller: _controller,
                  paused: session.paused,
                  upNext: session.upNextLabel,
                )
              else
                _WorkControls(controller: _controller),
              const SizedBox(height: 14),
              const AmbientSoundBar(),
              const SizedBox(height: 12),
              if (!session.isReady)
                AppButton(
                  label: 'goal.finish_session'.tr(),
                  variant: AppButtonVariant.secondary,
                  loading: _finishing,
                  onPressed: _finishing ? null : _controller.finishNow,
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.session,
    required this.accent,
    required this.colors,
  });

  final WorkoutSessionState session;
  final Color accent;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final isRest = session.isRest;
    final percent = isRest
        ? (session.restTotal == 0
              ? 0.0
              : 1 - (session.restRemaining / session.restTotal))
        : session.progress;

    return ProgressRing(
      percent: percent.clamp(0.0, 1.0),
      size: 250,
      strokeWidth: 6,
      color: accent,
      center: isRest
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatClock(session.restRemaining),
                  style: AppTextStyles.display.copyWith(
                    color: colors.textPrimary,
                    fontSize: 52,
                  ),
                ),
                Text(
                  session.paused ? 'workout.paused'.tr() : 'workout.rest'.tr(),
                  style: AppTextStyles.overline.copyWith(
                    color: accent,
                    letterSpacing: 2,
                  ),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${session.currentReps}',
                  style: AppTextStyles.display.copyWith(
                    color: colors.textPrimary,
                    fontSize: 60,
                  ),
                ),
                Text(
                  'workout.reps'.tr(),
                  style: AppTextStyles.overline.copyWith(
                    color: accent,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
    );
  }
}

class _OverallProgress extends StatelessWidget {
  const _OverallProgress({required this.session, required this.colors});

  final WorkoutSessionState session;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'workout.sets_done'.tr(
            namedArgs: {
              'done': '${session.setsCompleted}',
              'total': '${session.totalSets}',
            },
          ),
          style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: session.progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: colors.surfaceMuted,
            color: colors.primary,
          ),
        ),
      ],
    );
  }
}

class _ReadyControls extends StatelessWidget {
  const _ReadyControls({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'workout.start'.tr(),
      icon: Icons.play_arrow_rounded,
      onPressed: onStart,
    );
  }
}

class _WorkControls extends StatelessWidget {
  const _WorkControls({required this.controller});

  final WorkoutSessionController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SquareButton(
          icon: Icons.skip_next_rounded,
          label: 'workout.skip_set'.tr(),
          onTap: controller.skipSet,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: AppButton(
            label: 'workout.done_set'.tr(),
            icon: Icons.check_rounded,
            onPressed: controller.doneSet,
          ),
        ),
      ],
    );
  }
}

class _RestControls extends StatelessWidget {
  const _RestControls({
    required this.controller,
    required this.paused,
    required this.upNext,
  });

  final WorkoutSessionController controller;
  final bool paused;
  final String? upNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        if (upNext != null)
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppColors.studyFill,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    size: 18,
                    color: AppColors.studyText,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'workout.up_next'.tr(),
                        style: AppTextStyles.overline.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        upNext!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h3.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SquareButton(
              icon: Icons.remove_rounded,
              label: '−15s',
              onTap: () => controller.adjustRest(-15),
            ),
            const SizedBox(width: 14),
            _CenterControl(running: !paused, onTap: controller.togglePause),
            const SizedBox(width: 14),
            _SquareButton(
              icon: Icons.add_rounded,
              label: '+15s',
              onTap: () => controller.adjustRest(15),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: controller.skipRest,
          icon: const Icon(Icons.fast_forward_rounded, size: 18),
          label: Text('workout.skip_rest'.tr()),
        ),
      ],
    );
  }
}

class _CenterControl extends StatelessWidget {
  const _CenterControl({required this.running, required this.onTap});

  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: colors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          running ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: colors.onPrimary,
          size: 30,
        ),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border),
            ),
            child: Icon(icon, color: colors.textSecondary, size: 24),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 56,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fitness_center_rounded, size: 15, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.overline.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
