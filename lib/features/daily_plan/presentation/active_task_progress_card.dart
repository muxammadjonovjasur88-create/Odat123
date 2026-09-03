import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/models/task.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/utils/formatting.dart';

// ---------------------------------------------------------------------------
// Public entry-point
// ---------------------------------------------------------------------------

/// Shows a "Hozir bajarilyapti" card with a real-time circular progress ring
/// for the currently active (in-progress) task.
///
/// • Computes progress from [DateTime.now()] on every tick → survives
///   background/foreground cycles without drift.
/// • [Timer] and [AnimationController] inside [ProgressRing] are all disposed
///   properly — no memory leaks.
/// • Returns [SizedBox.shrink] when [task] is null (no layout gap).
class ActiveTaskProgressCard extends StatefulWidget {
  const ActiveTaskProgressCard({
    super.key,
    required this.task,
    this.onTap,
  });

  /// The currently active task, or null when nothing is in progress.
  final Task? task;

  /// Called when the card is tapped. Null means the card is not interactive.
  /// Typically only set when [task] is in progress (not completed).
  final VoidCallback? onTap;

  @override
  State<ActiveTaskProgressCard> createState() => _ActiveTaskProgressCardState();
}

class _ActiveTaskProgressCardState extends State<ActiveTaskProgressCard>
    with WidgetsBindingObserver {
  Timer? _ticker;

  /// Cached progress so we don't call setState on every tick if unchanged.
  double _progress = 0.0;

  /// Whether the task has hit 100 % (triggers completion glow).
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTicker();
  }

  @override
  void didUpdateWidget(ActiveTaskProgressCard old) {
    super.didUpdateWidget(old);
    if (old.task?.id != widget.task?.id) {
      // Task changed — reset state and restart ticker.
      _completed = false;
      _progress = 0.0;
      _startTicker();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On resume re-compute immediately (no stale display) then restart ticker.
    if (state == AppLifecycleState.resumed) {
      _tick();
      _startTicker();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopTicker();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTicker();
    super.dispose();
  }

  // ── Ticker helpers ──────────────────────────────────────────────────────────

  void _startTicker() {
    _stopTicker();
    if (widget.task == null) return;
    _tick(); // immediate first frame
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _tick() {
    final task = widget.task;
    if (task == null || !mounted) return;

    final newProgress = _computeProgress(task);
    final nowCompleted = newProgress >= 1.0;

    // Only rebuild when something actually changed (battery-friendly).
    if ((newProgress - _progress).abs() > 0.0005 ||
        nowCompleted != _completed) {
      if (mounted) {
        setState(() {
          _progress = newProgress;
          _completed = nowCompleted;
        });
      }
    }
  }

  // ── Progress computation ────────────────────────────────────────────────────

  /// Returns [0.0, 1.0] based on wall-clock time — unaffected by app restarts
  /// or background pauses.
  static double _computeProgress(Task task) {
    final now = DateTime.now();
    final taskStart = task.start; // DateTime at startMinute on task.date
    final taskEnd = task.end; // taskStart + durationMinutes

    if (now.isBefore(taskStart)) return 0.0;
    if (now.isAfter(taskEnd)) return 1.0;

    final elapsed = now.difference(taskStart).inSeconds;
    final total = task.durationMinutes * 60;
    if (total <= 0) return 0.0;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    if (task == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: _ActiveCard(
        task: task,
        progress: _progress,
        completed: _completed,
        onTap: widget.onTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ActiveCard — the visual card (stateless, driven by parent)
// ---------------------------------------------------------------------------

class _ActiveCard extends StatefulWidget {
  const _ActiveCard({
    required this.task,
    required this.progress,
    required this.completed,
    this.onTap,
  });

  final Task task;
  final double progress;
  final bool completed;
  final VoidCallback? onTap;

  @override
  State<_ActiveCard> createState() => _ActiveCardState();
}

class _ActiveCardState extends State<_ActiveCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 160),
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 0.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.975).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) _scaleCtrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _scaleCtrl.reverse().then((_) {
      if (mounted) widget.onTap?.call();
    });
  }

  void _onTapCancel() => _scaleCtrl.reverse();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final task = widget.task;
    final progress = widget.progress;
    final completed = widget.completed;
    final canTap = widget.onTap != null && !completed;

    // Accent transitions: cyan → amber → green as the session progresses.
    final Color accent;
    final Color glowColor;
    if (completed) {
      accent = const Color(0xFF3A7FCC); // green — done
      glowColor = const Color(0xFF3A7FCC);
    } else if (progress >= 0.75) {
      accent = const Color(0xFFFFB74D); // amber — near the end
      glowColor = const Color(0xFFFFB74D);
    } else {
      accent = AppColors.cyanAccent; // cyan — in progress
      glowColor = AppColors.cyanAccent;
    }

    final elapsedSeconds =
        (progress * task.durationMinutes * 60).round().clamp(0, task.durationMinutes * 60);
    final remainingSeconds =
        (task.durationMinutes * 60 - elapsedSeconds).clamp(0, task.durationMinutes * 60);

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: const Color(0xFF090B18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: completed ? 0.6 : 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: completed ? 0.18 : 0.10),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // ── Circular progress ring ────────────────────────────────────
                  _RingWithTime(
                    progress: progress,
                    accent: accent,
                    completed: completed,
                    remainingSeconds: remainingSeconds,
                  ),
                  const SizedBox(width: 12),
                  // ── Task info ─────────────────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Section label
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                completed
                                    ? 'home.active_task_done'.tr()
                                    : 'home.active_task_label'.tr(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.overline.copyWith(
                                  color: accent,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ),
                            if (canTap) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.play_circle_outline_rounded,
                                size: 13,
                                color: accent.withValues(alpha: 0.7),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Task title
                        Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.h3.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Time window
                        Text(
                          '${formatHm24(task.startMinute)} — '
                          '${formatHm24(task.startMinute + task.durationMinutes)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Progress pill
                        _ProgressPill(
                          progress: progress,
                          accent: accent,
                          completed: completed,
                        ),
                      ],
                    ),
                  ),
                  // ── Chevron hint (only when tappable) ─────────────────────────
                  if (canTap)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: accent.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
          );

          if (!canTap) return card;

          return ScaleTransition(
            scale: _scale,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                splashColor: accent.withValues(alpha: 0.12),
                highlightColor: accent.withValues(alpha: 0.06),
                onTapDown: _onTapDown,
                onTapUp: _onTapUp,
                onTapCancel: _onTapCancel,
                child: card,
              ),
            ),
          );
        }
      }

      // ---------------------------------------------------------------------------
      // _RingWithTime — the circular ring + remaining time in the centre
      // ---------------------------------------------------------------------------

      class _RingWithTime extends StatelessWidget {
        const _RingWithTime({
          required this.progress,
          required this.accent,
          required this.completed,
          required this.remainingSeconds,
        });

        final double progress;
        final Color accent;
        final bool completed;
        final int remainingSeconds;

        @override
        Widget build(BuildContext context) {
          final colors = context.colors;

          final centerWidget = completed
              ? Icon(Icons.check_rounded, color: accent, size: 28)
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatClock(remainingSeconds),
                          style: AppTextStyles.label.copyWith(
                            color: colors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'home.active_task_left'.tr(),
                          style: AppTextStyles.caption.copyWith(
                            color: colors.textSecondary,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      decoration: completed
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            )
          : const BoxDecoration(),
      child: ProgressRing(
        percent: progress,
        size: 80,
        strokeWidth: 5,
        color: accent,
        center: centerWidget,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ProgressPill — small inline progress bar at the bottom of the card
// ---------------------------------------------------------------------------

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({
    required this.progress,
    required this.accent,
    required this.completed,
  });

  final double progress;
  final Color accent;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pctInt = (progress * 100).round().clamp(0, 100);

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Stack(
                children: [
                  // Track
                  Container(
                    color: colors.border,
                    width: double.infinity,
                  ),
                  // Fill
                  LayoutBuilder(
                    builder: (context, constraints) => AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent.withValues(alpha: 0.8),
                            accent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$pctInt%',
          style: AppTextStyles.caption.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pure helper — exposed for testing without a widget tree
// ---------------------------------------------------------------------------

/// Computes elapsed-time progress [0.0, 1.0] for [task] relative to [now].
///
/// This is the same formula used by [_ActiveTaskProgressCardState] and is
/// extracted here so unit tests can verify it without spinning up widgets.
double computeTaskProgress(Task task, DateTime now) {
  final taskStart = task.start;
  final taskEnd = task.end;

  if (now.isBefore(taskStart)) return 0.0;
  if (now.isAfter(taskEnd)) return 1.0;

  final elapsed = now.difference(taskStart).inSeconds;
  final total = task.durationMinutes * 60;
  if (total <= 0) return 0.0;
  return (elapsed / total).clamp(0.0, 1.0);
}
