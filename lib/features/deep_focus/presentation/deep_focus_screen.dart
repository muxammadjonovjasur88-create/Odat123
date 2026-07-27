import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../goal_reached/domain/goal_reached_args.dart';
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
  bool _finishCallbackScheduled = false;

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

  /// Called whenever [focusSessionProvider] emits a new state. Handles the
  /// one-tick [segmentJustChanged] signal to give the user tactile + visual
  /// feedback when a work/rest segment transitions.
  void _onSessionChanged(FocusSessionState? prev, FocusSessionState? next) {
    if (next == null || !mounted) return;

    // Segment-transition feedback (fires for exactly one tick).
    if (next.segmentJustChanged) {
      final isNowRest = next.kind == FocusKind.rest;
      final message = isNowRest
          ? 'focus.break_time'.tr()
          : 'focus.back_to_work'.tr();
      // Haptic vibration
      HapticFeedback.mediumImpact();
      // Visual snackbar
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isNowRest ? Icons.coffee_rounded : Icons.bolt_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          backgroundColor: isNowRest
              ? const Color(0xFF5C8A6F)
              : const Color(0xFF4C74B9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    }

    // Session finished → navigate to goal screen.
    if (next.taskId == widget.task.id && next.isFinished && !_finishing) {
      _finish();
    }
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
    GoalReachedArgs? args;
    try {
      args = await completeFocusSession(
        ref,
        widget.task,
        signals:
            ref.read(focusSessionProvider)?.toSignals() ?? const FocusSignals(),
      );
    } catch (e, st) {
      debugPrint('[DeepFocus] completeFocusSession failed: $e\n$st');
      // Even on error, navigate to goal screen with 0 points so the user
      // is never left with a frozen 00:00 screen.
      args = GoalReachedArgs(
        points: 0,
        taskTitle: widget.task.title,
        streak: 0,
        isSport: false,
        verdict: FocusVerdict.incomplete,
      );
    } finally {
      _controller.clear();
      if (mounted) context.go(AppRoutes.goalReached, extra: args);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Single unified listener: handles both segment-transition feedback and
    // session-finished navigation. Replaces the old inline ref.listen block.
    ref.listen<FocusSessionState?>(focusSessionProvider, _onSessionChanged);

    final session = ref.watch(focusSessionProvider);

    if (session == null || session.taskId != widget.task.id) {
      return const FlowaLoadingScreen();
    }

    if (session.isFinished && !_finishing && !_finishCallbackScheduled) {
      _finishCallbackScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _finishCallbackScheduled = false;
        if (mounted && !_finishing) _finish();
      });
    }

    final started = !session.isWaiting;
    final isWork = session.kind == FocusKind.work;
    final remaining = session.remainingSeconds;
    final startLabel = formatHm24(widget.task.startMinute);

    // Overall progress:
    //  • Segmented sessions → tracks completed work across ALL segments.
    //  • Single-block / interval → tracks the current phase only.
    final double percent = started
        ? (session.isSegmented
            ? session.overallProgress
            : (() {
                final fullPhase = session.currentPhaseSeconds;
                return fullPhase > 0
                    ? (1 - remaining / fullPhase).clamp(0.0, 1.0)
                    : 0.0;
              })())
        : 0.0;

    // For a long single deep-work block (no auto-segments), gently suggest a
    // break after ~50 min. Segmented sessions already have built-in breaks.
    final elapsedSeconds = (!session.isSegmented && started && isWork)
        ? (session.workSeconds - remaining).clamp(0, session.workSeconds)
        : 0;

    return Scaffold(
      bottomNavigationBar: AppBottomNav(
        current: AppNavTab.focus,
        onSelected: (tab) => goToTab(context, tab),
      ),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: FitOrScroll(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const BrandLogo(),
                      const Spacer(),
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
                  // Segment dots: shown only for segmented deep-focus sessions
                  // (>45 min work). Each dot represents one work or rest block;
                  // the active segment is highlighted.
                  if (started && session.isSegmented) ...[
                    const SizedBox(height: 12),
                    _SegmentDots(
                      segments: session.segments,
                      currentIndex: session.segmentIndex,
                    ),
                  ] else if (started && session.completedWork > 0) ...[
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 12),
                            _ControlButton(
                              icon: Icons.stop_rounded,
                              onTap: _controller.skip,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'focus.end'.tr(),
                              style: AppTextStyles.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 28),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _BigPlayButton(
                              running: session.isRunning,
                              onTap: _controller.togglePause,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'focus.end'.tr(),
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 28),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 12),
                            _ControlButton(
                              icon: Icons.refresh_rounded,
                              onTap: _controller.reset,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'focus.reset'.tr(),
                              style: AppTextStyles.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          if (session.isCheckInActive)
            _CheckInOverlay(
              onConfirm: _controller.answerCheckIn,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Segment dots indicator
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a row of small dots, one per segment in the auto-generated Pomodoro
/// plan. Work segments are green; rest segments are amber. The active segment
/// is filled (opaque); completed segments are slightly dimmed; upcoming
/// segments are faint.
class _SegmentDots extends StatelessWidget {
  const _SegmentDots({
    required this.segments,
    required this.currentIndex,
  });

  final List<FocusSegment> segments;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    const double dotSize = 8;
    const double spacing = 5;
    const Color workColor = Color(0xFF5C8A6F); // forest green
    const Color restColor = Color(0xFFD4875A); // warm amber

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: WrapAlignment.center,
      children: List.generate(segments.length, (i) {
        final seg = segments[i];
        final isActive = i == currentIndex;
        final isPast = i < currentIndex;
        final baseColor = seg.isWork ? workColor : restColor;
        final opacity = isActive
            ? 1.0
            : isPast
                ? 0.45
                : 0.22;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isActive ? dotSize + 4 : dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(dotSize),
            border: isActive
                ? Border.all(color: baseColor, width: 1.5)
                : null,
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Break reminder (for non-segmented single-block sessions only)
// ─────────────────────────────────────────────────────────────────────────────

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

class _CheckInOverlay extends StatelessWidget {
  const _CheckInOverlay({required this.onConfirm});

  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 24,
      right: 24,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
             color: colors.surface,
             borderRadius: BorderRadius.circular(16),
             border: Border.all(color: colors.border),
             boxShadow: [
               BoxShadow(
                 color: Colors.black.withValues(alpha: 0.1),
                 blurRadius: 10,
                 offset: const Offset(0, 4),
               ),
             ],
          ),
          child: Row(
            children: [
              Icon(Icons.psychology_alt_rounded, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'focus.check_in_prompt'.tr(),
                  style: AppTextStyles.body.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: onConfirm,
                child: Text('focus.check_in_confirm'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
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
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              colors.primary.withValues(alpha: 0.9),
              colors.primaryPressed,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.35),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          running ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: colors.onPrimary,
          size: 36,
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(color: colors.border.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: colors.textSecondary, size: 24),
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

class _NothingToFocus extends ConsumerStatefulWidget {
  const _NothingToFocus();

  @override
  ConsumerState<_NothingToFocus> createState() => _NothingToFocusState();
}

class _NothingToFocusState extends ConsumerState<_NothingToFocus>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  Widget _buildBreathingAnimation(AppColorScheme colors) {
    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) {
        final value = _breathingController.value;
        return SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring pulsing
              Transform.scale(
                scale: 1.0 + (value * 0.6),
                child: Opacity(
                  opacity: (1.0 - value).clamp(0.0, 1.0) * 0.2,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.primary,
                        width: 1.5,
                      ),
                      color: colors.primary.withValues(alpha: 0.03),
                    ),
                  ),
                ),
              ),
              // Inner ring pulsing
              Transform.scale(
                scale: 1.0 + (((value + 0.5) % 1.0) * 0.35),
                child: Opacity(
                  opacity: (1.0 - ((value + 0.5) % 1.0)).clamp(0.0, 1.0) * 0.35,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.primary,
                        width: 2.0,
                      ),
                      color: colors.primary.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              ),
              // Center circle
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colors.primary.withValues(alpha: 0.25),
                      colors.primary.withValues(alpha: 0.05),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.15),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.self_improvement_rounded,
                    size: 42,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final profile = ref.watch(userProfileProvider).asData?.value;
    final userName = profile?.name ?? '';

    // Calculate time-based greeting
    final hour = DateTime.now().hour;
    String greetingKey;
    if (hour < 12) {
      greetingKey = 'focus.good_morning';
    } else if (hour < 18) {
      greetingKey = 'focus.good_afternoon';
    } else {
      greetingKey = 'focus.good_evening';
    }

    final greetingText = userName.isNotEmpty
        ? greetingKey.tr(args: [userName])
        : 'focus.nothing_title'.tr();

    // Streak / Motivation section
    final streak = profile?.streak ?? 0;
    final longestStreak = profile?.longestStreak ?? 0;

    return Scaffold(
      bottomNavigationBar: Builder(
        builder: (context) => AppBottomNav(
          current: AppNavTab.focus,
          onSelected: (tab) => goToTab(context, tab),
        ),
      ),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.5),
              radius: 1.2,
              colors: [
                colors.primary.withValues(alpha: 0.06),
                colors.background,
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildBreathingAnimation(colors),
                  const SizedBox(height: 24),
                  Text(
                    greetingText,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h3.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'focus.nothing_body'.tr(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Streak / Motivation Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.border.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (streak > 0) ...[
                          Text(
                            'focus.streak_status'.tr(args: [streak.toString()]),
                            style: AppTextStyles.body.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'focus.streak_status_sub'.tr(),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ] else if (longestStreak > 0) ...[
                          Text(
                            'focus.longest_streak'.tr(args: [longestStreak.toString()]),
                            style: AppTextStyles.body.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'focus.motivation_new'.tr(),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ] else ...[
                          Text(
                            'focus.motivation_new'.tr(),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  AppButton(
                    label: 'focus.plan_task'.tr(),
                    expand: false,
                    icon: Icons.calendar_today_rounded,
                    onPressed: () => context.go(AppRoutes.dailyPlan),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
