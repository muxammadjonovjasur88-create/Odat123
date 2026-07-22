import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
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
import '../../active_focus/presentation/active_focus_view.dart';
import '../../ambient/data/ambient_sound_controller.dart';
import '../../ambient/presentation/ambient_sound_bar.dart';
import '../../blocking/data/blocking_repository.dart';
import '../../honest_focus/domain/honest_focus.dart';
import '../../workout/presentation/workout_screen.dart';
import '../data/focus_providers.dart';
import '../data/focus_service.dart';
import 'focus_session_controller.dart';

/// Route entry for the Focus tab (12/13). Picks the current task and renders
/// either the Pomodoro (deep work) or the sport interval timer, per the task's
/// category and the user's focus type.
class FocusScreen extends ConsumerWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(currentFocusTaskProvider);
    final profile = ref.watch(userProfileProvider).asData?.value;

    if (task == null) return const _NothingToFocus();

    // Structured set-based workout takes priority for sport tasks that have one.
    if (task.hasWorkout) return WorkoutScreen(task: task);

    return usesIntervalTimer(task, profile)
        ? ActiveFocusView(task: task)
        : DeepFocusView(task: task);
  }
}

/// Pomodoro timer (12): 25-min work / 5-min break, cycling. The timer state
/// lives in [focusSessionProvider], so it keeps running and is never reset by
/// leaving and returning to this screen. The check button finishes the session.
class DeepFocusView extends ConsumerStatefulWidget {
  const DeepFocusView({super.key, required this.task});

  final Task task;

  @override
  ConsumerState<DeepFocusView> createState() => _DeepFocusViewState();
}

class _DeepFocusViewState extends ConsumerState<DeepFocusView> {
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    // Provider mutations are illegal during initState/build, so defer the
    // on-entry session start to after the first frame. Idempotent: if a session
    // for this task is already running, it's left untouched.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The countdown + app blocking live in the native background session
      // (scheduled when the task was created); this just mirrors it on screen.
      ref
          .read(focusSessionProvider.notifier)
          .ensureStarted(widget.task, isInterval: false);
      // Resume the remembered ambient sound for this session.
      ref.read(ambientSoundProvider.notifier).resumeIfSelected();
    });
  }

  FocusSessionController get _controller =>
      ref.read(focusSessionProvider.notifier);

  /// "Begin now": start the background session immediately (countdown +
  /// blocking + ongoing notification), and reflect it in the UI.
  void _beginNow() {
    _controller.beginNow();
    beginBackgroundFocusNow(
      service: ref.read(focusServiceProvider),
      taskId: widget.task.id,
      task: widget.task,
      settings: ref.read(blockingSettingsProvider).asData?.value,
    );
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    final args = await completeFocusSession(
      ref,
      widget.task,
      signals:
          ref.read(focusSessionProvider)?.toSignals() ?? const FocusSignals(),
    );
    _controller.clear();
    if (mounted) context.go(AppRoutes.goalReached, extra: args);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // When the session ends (in-app or reported by the background service),
    // finish: award points and show Goal Reached.
    ref.listen<FocusSessionState?>(focusSessionProvider, (prev, next) {
      if (next != null &&
          next.taskId == widget.task.id &&
          next.isFinished &&
          !_finishing) {
        _finish();
      }
    });

    final session = ref.watch(focusSessionProvider);

    if (session == null || session.taskId != widget.task.id) {
      return const FlowaLoadingScreen();
    }

    final started = !session.isWaiting;
    final isWork = session.kind == FocusKind.work;
    final remaining = session.remainingSeconds;
    final fullPhase = session.currentPhaseSeconds;
    final percent = started ? 1 - (remaining / fullPhase) : 0.0;
    final startLabel = formatHm24(widget.task.startMinute);
    // For a long single deep-work block, gently suggest a break after a while.
    final elapsedSeconds = (started && isWork)
        ? (session.workSeconds - remaining).clamp(0, session.workSeconds)
        : 0;

    return Scaffold(
      bottomNavigationBar: AppBottomNav(
        current: AppNavTab.focus,
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
                  // No manual "mark done" — completion is earned automatically
                  // when the full time elapses with focus maintained.
                  if (kDebugMode)
                    _RoundButton(
                      icon: Icons.bug_report_rounded,
                      onTap: () => ref
                          .read(focusServiceProvider)
                          .debugSimulateDistraction(),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'focus.current_task'.tr(),
                style: AppTextStyles.overline.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.task.title,
                textAlign: TextAlign.center,
                style: AppTextStyles.h2.copyWith(color: colors.textPrimary),
              ),
              const Spacer(),
              ProgressRing(
                percent: percent,
                size: 260,
                strokeWidth: 6,
                color: AppColors.forest,
                center: started
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatClock(remaining),
                            style: AppTextStyles.display.copyWith(
                              color: colors.textPrimary,
                              fontSize: 56,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isWork ? 'focus.focusing'.tr() : 'focus.break'.tr(),
                            style: AppTextStyles.body.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'focus.starts_in'.tr(),
                            style: AppTextStyles.body.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatClock(remaining),
                            style: AppTextStyles.display.copyWith(
                              color: colors.textPrimary,
                              fontSize: 48,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 28),
              if (!started)
                Text(
                  'focus.begins_at'.tr(namedArgs: {'time': startLabel}),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                )
              else if (isWork)
                _BlockedIndicator(
                  colors: colors,
                  redirects: session.distractingOpens,
                )
              else
                Text(
                  'focus.rest_breathe'.tr(),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              if (elapsedSeconds >= 50 * 60) ...[
                const SizedBox(height: 12),
                _BreakReminder(elapsedSeconds: elapsedSeconds),
              ],
              if (started && session.completedWork > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'focus.pomodoros_done'.tr(
                    namedArgs: {'count': '${session.completedWork}'},
                  ),
                  style: AppTextStyles.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ],
              const Spacer(),
              const AmbientSoundBar(),
              const SizedBox(height: 14),
              if (!started)
                AppButton(
                  label: 'focus.begin_now'.tr(),
                  icon: Icons.play_arrow_rounded,
                  expand: false,
                  onPressed: _beginNow,
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _ControlButton(
                      icon: Icons.stop_rounded,
                      label: 'focus.end'.tr(),
                      onTap: _controller.skip,
                    ),
                    const SizedBox(width: 28),
                    _BigPlayButton(
                      running: session.isRunning,
                      onTap: _controller.togglePause,
                    ),
                    const SizedBox(width: 28),
                    _ControlButton(
                      icon: Icons.refresh_rounded,
                      label: 'focus.reset'.tr(),
                      onTap: _controller.reset,
                    ),
                  ],
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// A caring, non-forcing break reminder for long focus blocks. Appears after
/// ~50 min and escalates gently past 2 hours. It never interrupts the session —
/// just a supportive nudge to rest.
class _BreakReminder extends StatelessWidget {
  const _BreakReminder({required this.elapsedSeconds});

  final int elapsedSeconds;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final minutes = elapsedSeconds ~/ 60;
    final message = elapsedSeconds >= 120 * 60
        ? 'focus.break_2h'.tr()
        : 'focus.break_minutes'.tr(namedArgs: {'minutes': '$minutes'});
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.tintSage,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.self_improvement_rounded, size: 16, color: colors.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockedIndicator extends StatelessWidget {
  const _BlockedIndicator({required this.colors, this.redirects = 0});

  final AppColorScheme colors;
  final int redirects;

  @override
  Widget build(BuildContext context) {
    if (redirects > 0) {
      // Gentle, non-punishing nudge back to focus.
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.spa_outlined, size: 16, color: colors.textSecondary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              redirects == 1
                  ? 'focus.redirected_one'.tr()
                  : 'focus.redirected_many'.tr(
                      namedArgs: {'count': '$redirects'},
                    ),
              style: AppTextStyles.label.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_rounded, size: 16, color: colors.textSecondary),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'focus.distractions_blocked'.tr(),
            style: AppTextStyles.label.copyWith(color: colors.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.lock_rounded, size: 16, color: colors.textSecondary),
      ],
    );
  }
}

class _BigPlayButton extends StatelessWidget {
  const _BigPlayButton({required this.running, required this.onTap});

  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: colors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          running ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: colors.onPrimary,
          size: 34,
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: colors.border),
            ),
            child: Icon(icon, color: colors.textSecondary, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: colors.border),
        ),
        child: Icon(icon, size: 22, color: colors.textSecondary),
      ),
    );
  }
}

class _NothingToFocus extends StatelessWidget {
  const _NothingToFocus();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      bottomNavigationBar: Builder(
        builder: (context) => AppBottomNav(
          current: AppNavTab.focus,
          onSelected: (tab) => goToTab(context, tab),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.self_improvement_rounded,
                  size: 56,
                  color: colors.textTertiary,
                ),
                const SizedBox(height: 20),
                Text(
                  'focus.nothing_title'.tr(),
                  style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'focus.nothing_body'.tr(),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'focus.plan_task'.tr(),
                  expand: false,
                  onPressed: () => context.go(AppRoutes.dailyPlan),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
