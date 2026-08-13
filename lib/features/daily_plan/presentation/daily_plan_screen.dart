import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/task.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/router/nav_helpers.dart';
import '../../../core/services/task_repository.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/widgets.dart';
import '../../add_goal/data/task_actions.dart';
import '../../deep_focus/data/focus_providers.dart';
import '../../starting_soon/presentation/starting_soon_watcher.dart';
import '../../streak/presentation/streak_reminder_scheduler.dart';
import '../../notifications/data/notification_service.dart';
import 'active_task_progress_card.dart';
import 'daily_quests_widget.dart';

/// Screen 06 / 07 — the daily plan home. Shows today's progress card and a
/// timeline of task cards, or an empty state inviting the user to plan.
class DailyPlanScreen extends ConsumerWidget {
  const DailyPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateUtils.dateOnly(DateTime.now());
    final tasksAsync = ref.watch(tasksForDayProvider(today));

    // Trigger permissions check once home is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).checkAndRequestPermissions(context);
    });

    return Scaffold(
      backgroundColor: const Color(0xFF051424),
      appBar: const FlowaAppBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.addGoal),
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        elevation: 2,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      bottomNavigationBar: AppBottomNav(
        current: AppNavTab.dashboard,
        onSelected: (tab) => goToTab(context, tab),
      ),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            tasksAsync.when(
              loading: () => const AppCardSkeletonList(),
              error: (e, _) => AppErrorView(
                message: 'home.load_error'.tr(),
                onRetry: () => ref.invalidate(tasksForDayProvider(today)),
              ),
              data: (tasks) => _Content(tasks: tasks),
            ),
            // Invisible: opens "Starting Soon" ~5 min before a task begins.
            const StartingSoonWatcher(),
            // Invisible: keeps the evening streak reminder in sync.
            const StreakReminderScheduler(),
          ],
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.tasks});

  final List<Task> tasks;

  /// Navigates to the correct focus screen for [task].
  ///
  /// • Pomodoro/note tasks → [AppRoutes.deepFocus] (FocusScreen handles the rest)
  /// • Interval/sport tasks → [AppRoutes.activeFocus]
  ///
  /// [FocusScreen] reads [currentFocusTaskProvider] and [focusSessionProvider]
  /// — timer state is already running in-process, so nothing resets.
  void _openFocusScreen(BuildContext context, WidgetRef ref, Task task) {
    try {
      final profile = ref.read(userProfileProvider).asData?.value;
      final isInterval = usesIntervalTimer(task, profile);
      context.go(isInterval ? AppRoutes.activeFocus : AppRoutes.deepFocus);
    } catch (e, st) {
      debugPrint('[ActiveCard] _openFocusScreen error: $e\n$st');
      // Fallback: always land on the deep focus route (safe)
      if (context.mounted) context.go(AppRoutes.deepFocus);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final fullDone = tasks.where((t) => t.isCompleted).length;
    final partial = tasks
        .where((t) => !t.isCompleted && t.completionPercent > 0)
        .length;
    final total = tasks.length;
    final percent = total == 0 ? 0.0 : (fullDone + partial * 0.5) / total;

    // Find the task currently in progress: within its time window and not yet
    // fully completed. Prefer the task whose window started most recently.
    final now = DateTime.now();
    final activeTask = tasks
        .where((t) =>
            !t.isCompleted &&
            !now.isBefore(t.start) &&
            now.isBefore(t.end))
        .fold<Task?>(
          null,
          (best, t) =>
              best == null || t.startMinute > best.startMinute ? t : best,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final listHeight = (constraints.maxHeight - 140).clamp(0.0, constraints.maxHeight);

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: DailyQuestsWidget(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: DailyProgressCard(percent: percent),
                ),
                const SizedBox(height: 16),

                // ── Active task real-time progress (shown only when a task
                //    is currently in progress; hides itself when null). ──
                ActiveTaskProgressCard(
                  task: activeTask,
                  // Only provide onTap while the task is genuinely in progress
                  // (not completed). The card ignores the tap when task == null.
                  onTap: activeTask != null && !activeTask.isCompleted
                      ? () => _openFocusScreen(context, ref, activeTask)
                      : null,
                ),

                if (tasks.isEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      12,
                      24,
                      24 + bottomInset + 80,
                    ),
                    child: const _EmptyState(),
                  )
                else
                  SizedBox(
                    height: listHeight,
                    child: _TimelineList(tasks: tasks),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DailyProgressCard extends StatelessWidget {
  const DailyProgressCard({
    super.key,
    required this.percent,
  });

  final double percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xB3122131),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.glassEdge,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonLime.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 0,
          ),
          const BoxShadow(
            color: Color(0x40000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'home.daily_progress'.tr().toUpperCase(),
            style: const TextStyle(
              fontFamily: 'monospace',
              color: AppColors.neonLime,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _GradientProgressBar(
            percent: percent,
            height: 10,
          ),
        ],
      ),
    );
  }
}

class _GradientProgressBar extends StatelessWidget {
  const _GradientProgressBar({
    required this.percent,
    required this.height,
  });

  final double percent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0.0, 1.0);
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1C2D),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final activeWidth = constraints.maxWidth * clamped;
          return Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: activeWidth,
              height: height,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TimelineList extends ConsumerWidget {
  const _TimelineList({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = tasks.map((t) => t.category).toSet().toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
      children: [
        if (categories.isNotEmpty) ...[
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [for (final c in categories) AppChip.category(c)],
          ),
          const SizedBox(height: 16),
        ],
        for (var i = 0; i < tasks.length; i++)
          FadeSlideIn(
            delay: FadeSlideIn.stagger(i),
            child: _TimelineTile(task: tasks[i], isLast: i == tasks.length - 1),
          ),
      ],
    );
  }
}

class _TimelineTile extends ConsumerWidget {
  const _TimelineTile({required this.task, required this.isLast});

  final Task task;
  final bool isLast;

  /// 0.0 means not started, 0–95% is partial, ≥95% is full.
  double get _pct => task.isCompleted ? 1.0 : task.completionPercent;

  bool get _isFull => _pct >= 0.95;

  void _showDetailSnackbar(BuildContext context) {
    if (!task.isCompleted && _pct == 0) return; // nothing to report
    final pctInt = (_pct * 100).round();
    final earnedPoints = (task.points * _pct).round();
    final msg = _isFull
        ? 'home.task_detail_full'.tr(
            namedArgs: {'points': '${task.points}'},
          )
        : 'home.task_detail_partial'.tr(
            namedArgs: {
              'percent': '$pctInt',
              'earned': '$earnedPoints',
              'total': '${task.points}',
            },
          );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return Dismissible(
      key: ValueKey('task-${task.id}'),
      direction: DismissDirection.endToStart,
      background: _deleteBackground(),
      confirmDismiss: (_) async {
        final ok = await confirmDeleteTask(context, title: task.title);
        if (ok) await deleteTaskCompletely(ref, task);
        return false;
      },
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time gutter + connector.
            SizedBox(
              width: 52,
              child: Column(
                children: [
                  Text(
                    formatHm24(task.startMinute),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: task.category.foreground,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: colors.border,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AppCard(
                  padding: const EdgeInsets.all(16),
                  onTap: () {
                    _showDetailSnackbar(context);
                    context.push(AppRoutes.editGoal, extra: task);
                  },
                  child: Opacity(
                    opacity: _isFull ? 0.6 : 1,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.h3.copyWith(
                                  color: colors.textPrimary,
                                  // Strikethrough only for fully completed tasks.
                                  decoration: _isFull
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${formatHm24(task.startMinute)} — '
                                '${formatHm24(task.startMinute + task.durationMinutes)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              if (_isFull && !task.pointsAwarded) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'home.no_focus_note'.tr(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption.copyWith(
                                    color: colors.textTertiary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _StatusBubble(task: task, pct: _pct),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Soft red reveal shown behind the tile when swiping left to delete.
  Widget _deleteBackground() {
    const danger = Color(0xFFB3504B);
    return Padding(
      padding: const EdgeInsets.only(left: 60, bottom: 16),
      child: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, color: danger),
            SizedBox(width: 8),
            Text(
              'Delete',
              style: TextStyle(color: danger, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three-state status bubble shown on the right of every task tile.
///
/// * **Full** (pct ≥ 0.95 or isCompleted): solid green circle + check icon.
/// * **Partial** (0 < pct < 0.95): amber circular progress ring with
///   the percentage label inside.
/// * **None** (pct == 0): category-tinted circle with the pending point value.
class _StatusBubble extends StatefulWidget {
  const _StatusBubble({required this.task, required this.pct});

  final Task task;

  /// Effective completion ratio: 1.0 if isCompleted, else completionPercent.
  final double pct;

  @override
  State<_StatusBubble> createState() => _StatusBubbleState();
}

class _StatusBubbleState extends State<_StatusBubble> {
  static const _size = 58.0;
  // Amber-gold for partial progress — signals "tried but not finished".
  static const _partialColor = Color(0xFFF5A623);

  bool _prevCompleted = false;

  @override
  void didUpdateWidget(_StatusBubble old) {
    super.didUpdateWidget(old);
    // When pct drops below 0.95 (e.g. task reset), reset flag so the
    // animation can fire again if the task is re-completed.
    if (widget.pct < 0.95 && _prevCompleted) {
      _prevCompleted = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pct = widget.pct;
    final task = widget.task;

    if (pct >= 0.95) {
      // ── FULLY COMPLETED ──────────────────────────────────────────────────
      final justCompleted = !_prevCompleted;
      // Update flag for future rebuilds (safe here; build is always followed
      // by frame commit before the next build).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _prevCompleted = true);
      });

      final bubble = Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: task.category.fill,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            Icons.check_rounded,
            color: task.pointsAwarded ? colors.primary : colors.textTertiary,
            size: 26,
          ),
        ),
      );

      return TaskCheckAnimation(
        triggered: justCompleted,
        color: colors.primary,
        child: bubble,
      );
    }

    if (pct > 0) {
      // ── PARTIALLY COMPLETED ──────────────────────────────────────────────
      final pctInt = (pct * 100).round();
      return SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background track.
            SizedBox(
              width: _size,
              height: _size,
              child: CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 3,
                valueColor:
                    AlwaysStoppedAnimation(colors.border),
              ),
            ),
            // Amber progress arc.
            SizedBox(
              width: _size,
              height: _size,
              child: CircularProgressIndicator(
                value: pct,
                strokeWidth: 3,
                valueColor:
                    const AlwaysStoppedAnimation(_partialColor),
                backgroundColor: Colors.transparent,
              ),
            ),
            // Percentage label inside the ring.
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$pctInt%',
                  style: AppTextStyles.label.copyWith(
                    color: _partialColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'common.pts'.tr(),
                  style: AppTextStyles.caption.copyWith(
                    color: colors.textTertiary,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // ── NOT STARTED ────────────────────────────────────────────────────────
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: task.category.fill,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '+${task.points}',
              style: AppTextStyles.label.copyWith(
                color: task.category.foreground,
                fontSize: 14,
              ),
            ),
            Text(
              'common.pts'.tr(),
              style: AppTextStyles.caption.copyWith(
                color: task.category.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton(
          label: 'home.add_manually'.tr(),
          icon: Icons.edit_calendar_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: () => context.push(AppRoutes.addGoal),
        ),
        const SizedBox(height: 12),
        AppButton(
          label: 'home.ask_ai'.tr(),
          icon: Icons.auto_awesome_rounded,
          onPressed: () => context.push(AppRoutes.aiPlanner),
        ),
      ],
    );
  }
}
