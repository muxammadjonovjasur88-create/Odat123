import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/models/task.dart';
import '../../../core/router/app_router.dart';
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
import '../../blocking/data/blocking_repository.dart';
import '../../blocking/presentation/blocking_permission_gate.dart';
import '../../deep_focus/data/focus_providers.dart';
import '../../deep_focus/data/focus_service.dart';
import '../../deep_focus/presentation/focus_session_controller.dart';
import '../../goal_reached/domain/goal_reached_args.dart';
import '../../honest_focus/domain/honest_focus.dart';

/// Screen 13 — sport interval timer: WORK/REST phases across sets. The timer
/// state lives in [focusSessionProvider], so leaving and returning never resets
/// it. Finishing (or completing all sets) opens Goal Reached.
class ActiveFocusView extends ConsumerStatefulWidget {
  const ActiveFocusView({super.key, required this.task});

  final Task task;

  @override
  ConsumerState<ActiveFocusView> createState() => _ActiveFocusViewState();
}

class _ActiveFocusViewState extends ConsumerState<ActiveFocusView> {
  static const _work = Color(0xFFD49A6A); // warm sport accent
  static const _rest = AppColors.forest;

  // Plain bool — intentionally NOT using setState() here.
  // _finish() is always scheduled via addPostFrameCallback, so it never
  // runs inside a build() call. Using setState() caused a silent Flutter
  // exception ("setState called during build") that froze the session at 00:00.
  bool _finishing = false;
  bool _finishScheduled = false;

  @override
  void initState() {
    super.initState();
    // Keep the screen on during the sport interval session safely.
    try {
      WakelockPlus.enable().then((_) {
        debugPrint('[ActiveFocus] ✅ Wakelock ENABLED — ekran yonib turadi');
      }).catchError((e) {
        debugPrint('[ActiveFocus] ❌ Wakelock enable FAILED: $e');
      });
    } catch (e) {
      debugPrint('[ActiveFocus] ❌ Wakelock enable sync exception: $e');
    }
    // Defer the provider mutation out of initState (forbidden there).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Countdown + blocking run in the native background session (scheduled
      // at task creation); this view just mirrors it.
      ref
          .read(focusSessionProvider.notifier)
          .ensureStarted(widget.task, isInterval: true);
      ref.read(ambientSoundProvider.notifier).resumeIfSelected();
    });
  }

  @override
  void dispose() {
    // Release the wakelock when leaving the sport focus screen.
    try {
      WakelockPlus.disable().then((_) {
        debugPrint('[ActiveFocus] 🔓 Wakelock DISABLED — ekran normal rejimga qaytdi');
      }).catchError((e) {
        debugPrint('[ActiveFocus] ❌ Wakelock disable FAILED: $e');
      });
    } catch (e) {
      debugPrint('[ActiveFocus] ❌ Wakelock disable sync exception: $e');
    }
    super.dispose();
  }

  FocusSessionController get _controller =>
      ref.read(focusSessionProvider.notifier);

  /// "Begin now": start the background interval session immediately.
  Future<void> _beginNow() async {
    try {
      _controller.beginNow();
    } catch (e) {
      debugPrint('[ActiveFocus] ❌ beginNow controller exception: $e');
    }

    final settings = ref.read(blockingSettingsProvider).asData?.value;
    final hasBlockedApps =
        settings != null &&
        settings.blockedPackages.isNotEmpty &&
        (widget.task.blockApps || settings.alwaysBlock);

    if (hasBlockedApps && context.mounted) {
      try {
        await ensureBlockingPermissions(context, ref);
      } catch (e) {
        debugPrint('[ActiveFocus] ❌ ensureBlockingPermissions exception: $e');
      }
    }

    if (!mounted) return;
    try {
      await beginBackgroundFocusNow(
        service: ref.read(focusServiceProvider),
        taskId: widget.task.id,
        task: widget.task,
        settings: settings,
      );
    } catch (e) {
      debugPrint('[ActiveFocus] ❌ beginBackgroundFocusNow exception: $e');
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    // Set flag synchronously to prevent double-invocation.
    _finishing = true;
    debugPrint('[ActiveFocus] 🚀 _finish() ENTERED');

    // ── Non-blocking Wakelock release ──────────────────────────────────────
    try {
      await WakelockPlus.disable();
      debugPrint('[ActiveFocus] Finish: wakelock disabled successfully');
    } catch (e) {
      debugPrint('[ActiveFocus] ❌ Finish: wakelock disable failed (non-critical): $e');
    }

    // ── Capture signals NOW, before clear() nulls the state ────────────────
    final signals =
        ref.read(focusSessionProvider)?.toSignals() ?? const FocusSignals();
    debugPrint(
      '[ActiveFocus] _finish() — timerCompleted=${signals.timerCompleted} '
      'total=${signals.totalSeconds}s away=${signals.awaySeconds}s '
      'focused=${signals.focusedSeconds}s '
      '(focusedMin=${signals.focusedSeconds ~/ 60}, '
      'plannedMin=${widget.task.durationMinutes})',
    );

    final container = ref.container;

    GoalReachedArgs? args;
    try {
      debugPrint('[ActiveFocus] Finish step 1: calling completeFocusSession...');
      args = await completeFocusSession(
        container,
        widget.task,
        signals: signals,
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          debugPrint('[ActiveFocus] ⚠️ completeFocusSession timed out after 12s');
          return GoalReachedArgs(
            points: widget.task.points > 0 ? widget.task.points : 20,
            taskTitle: widget.task.title,
            streak: 0,
            isSport: true,
            verdict: FocusVerdict.full,
            focusSeconds: signals.focusedSeconds,
            awardedPoints: widget.task.points,
          );
        },
      );
      debugPrint('[ActiveFocus] Finish step 1: done. points=${args.points}');
    } catch (e, st) {
      debugPrint('[ActiveFocus] ❌ completeFocusSession FAILED: $e\n$st');
      args = GoalReachedArgs(
        points: widget.task.points > 0 ? widget.task.points : 20,
        taskTitle: widget.task.title,
        streak: 0,
        isSport: true,
        verdict: FocusVerdict.full,
      );
    }

    debugPrint('[ActiveFocus] Finish step 2: navigating to GoalReached. mounted=$mounted');
    bool navigated = false;
    if (mounted) {
      try {
        context.go(AppRoutes.goalReached, extra: args);
        navigated = true;
        debugPrint('[ActiveFocus] Finish step 2: navigation command executed successfully');
      } catch (e, st) {
        debugPrint('[ActiveFocus] ❌ context.go failed: $e\n$st');
      }
    }

    if (!navigated) {
      debugPrint('[ActiveFocus] ⚠️ Local context navigation not performed or failed — trying rootNavigatorKey context...');
      final rootContext = rootNavigatorKey.currentContext;
      if (rootContext != null && rootContext.mounted) {
        try {
          GoRouter.of(rootContext).go(AppRoutes.goalReached, extra: args);
          debugPrint('[ActiveFocus] Finish step 2 (fallback): navigation command executed successfully via rootNavigatorKey!');
        } catch (e, st) {
          debugPrint('[ActiveFocus] ❌ rootNavigatorKey context.go failed: $e\n$st');
        }
      } else {
        debugPrint('[ActiveFocus] ❌ rootNavigatorKey context is null or unmounted');
      }
    }

    try {
      debugPrint('[ActiveFocus] Finish step 3: clearing session controller...');
      container.read(focusSessionProvider.notifier).clear();
      debugPrint('[ActiveFocus] Finish step 3: controller cleared');
    } catch (e) {
      debugPrint('[ActiveFocus] ❌ container.read clear() failed: $e');
    }
  }

  /// The phase that follows [index] in the work/rest plan, or null at the end.
  ({bool isWork, int set})? _phaseAt(int index, int totalSets) {
    final total = totalSets * 2 - 1; // W,R,...,W
    if (index < 0 || index >= total) return null;
    return (isWork: index.isEven, set: (index ~/ 2) + 1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final profile = ref.watch(userProfileProvider).asData?.value;
    final session = ref.watch(focusSessionProvider);

    if (session == null || session.taskId != widget.task.id) {
      return const FlowaLoadingScreen();
    }

    // All sets done → finish automatically.
    // IMPORTANT: ref.listen fires during build(). Never call _finish() or
    // setState() synchronously here — schedule via postFrameCallback instead.
    ref.listen(focusSessionProvider, (_, next) {
      if (next != null && next.isFinished && !_finishing && !_finishScheduled) {
        _finishScheduled = true;
        debugPrint('[ActiveFocus] ref.listen: session finished, scheduling _finish()');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _finishScheduled = false;
          if (mounted && !_finishing) {
            debugPrint('[ActiveFocus] postFrameCallback: calling _finish()');
            _finish();
          }
        });
      }
    });

    if (session.isFinished && !_finishing && !_finishScheduled) {
      _finishScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _finishScheduled = false;
        if (mounted && !_finishing) {
          debugPrint('[ActiveFocus] build() safety-net: calling _finish()');
          _finish();
        }
      });
    }

    final started = !session.isWaiting;
    final isWork = session.kind == FocusKind.work;
    final remaining = session.remainingSeconds;
    final fullPhase = session.currentPhaseSeconds;
    final percent = started ? 1 - (remaining / fullPhase) : 0.0;
    final accent = isWork ? _work : _rest;
    final startLabel = formatHm24(widget.task.startMinute);
    final next = _phaseAt(session.phaseIndex + 1, session.totalSets);

    return Scaffold(
      bottomNavigationBar: AppBottomNav(
        current: AppNavTab.dashboard,
        onSelected: (tab) => goToTab(context, tab),
      ),
      body: SafeArea(
        bottom: false,
        child: FitOrScroll(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
          child: Column(
            children: [
              _Pill(
                label: isWork
                    ? 'focus.interval_training'.tr()
                    : 'focus.rest'.tr(),
                color: accent,
              ),
              const SizedBox(height: 16),
              Text(
                isWork ? widget.task.title : 'focus.rest_name'.tr(),
                textAlign: TextAlign.center,
                style: AppTextStyles.h1.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'focus.set_of'.tr(
                  namedArgs: {
                    'current': '${session.setNumber}',
                    'total': '${session.totalSets}',
                  },
                ),
                style: AppTextStyles.body.copyWith(color: colors.textSecondary),
              ),
              const Spacer(),
              ProgressRing(
                percent: percent,
                size: 250,
                strokeWidth: 6,
                color: accent,
                center: started
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatClock(remaining),
                            style: AppTextStyles.display.copyWith(
                              color: colors.textPrimary,
                              fontSize: 52,
                            ),
                          ),
                          Text(
                            isWork ? 'focus.work'.tr() : 'focus.rest'.tr(),
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
                              fontSize: 46,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 28),
              if (!started) ...[
                Text(
                  'focus.workout_begins_at'.tr(namedArgs: {'time': startLabel}),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const Spacer(),
                const AmbientSoundBar(),
                const SizedBox(height: 14),
                AppButton(
                  label: 'focus.begin_now'.tr(),
                  icon: Icons.play_arrow_rounded,
                  expand: false,
                  onPressed: _beginNow,
                ),
                const SizedBox(height: 12),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SideControl(
                      icon: Icons.skip_previous_rounded,
                      onTap: _controller.previous,
                    ),
                    const SizedBox(width: 28),
                    _CenterControl(
                      accent: accent,
                      running: session.isRunning,
                      onTap: _controller.togglePause,
                    ),
                    const SizedBox(width: 28),
                    _SideControl(
                      icon: Icons.skip_next_rounded,
                      onTap: _controller.next,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _StreakRow(streak: profile?.streak ?? 0),
                const Spacer(),
                if (next != null)
                  _UpNextCard(
                    label: next.isWork
                        ? 'focus.upnext_set'.tr(
                            namedArgs: {
                              'set': '${next.set}',
                              'title': widget.task.title,
                            },
                          )
                        : 'focus.rest_name'.tr(),
                    isRest: !next.isWork,
                  ),
                const SizedBox(height: 12),
                const AmbientSoundBar(),
                const SizedBox(height: 12),
                AppButton(
                  label: 'focus.end_session'.tr(),
                  variant: AppButtonVariant.secondary,
                  loading: _finishing,
                  onPressed: _finishing ? null : _finish,
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
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

class _CenterControl extends StatelessWidget {
  const _CenterControl({
    required this.accent,
    required this.running,
    required this.onTap,
  });

  final Color accent;
  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          running ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }
}

class _SideControl extends StatelessWidget {
  const _SideControl({required this.icon, required this.onTap});

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
          color: colors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: colors.border),
        ),
        child: Icon(icon, color: colors.textSecondary, size: 24),
      ),
    );
  }
}

class _StreakRow extends StatelessWidget {
  const _StreakRow({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.local_fire_department_rounded,
          color: Color(0xFFE08A4B),
          size: 18,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'common.days_streak'.tr(namedArgs: {'count': '$streak'}),
            style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _UpNextCard extends StatelessWidget {
  const _UpNextCard({required this.label, required this.isRest});

  final String label;
  final bool isRest;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.studyFill,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isRest ? Icons.air_rounded : Icons.fitness_center_rounded,
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
                  isRest ? 'focus.upcoming_rest'.tr() : 'focus.up_next'.tr(),
                  style: AppTextStyles.overline.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
