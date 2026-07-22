import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/task.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/router/nav_helpers.dart';
import '../../../core/services/task_repository.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/widgets.dart';
import '../../add_goal/data/task_actions.dart';
import '../../starting_soon/presentation/starting_soon_watcher.dart';
import '../../streak/presentation/streak_flame.dart';
import '../../streak/presentation/streak_reminder_scheduler.dart';

/// Screen 06 / 07 — the daily plan home. Shows today's progress ring and a
/// timeline of task cards, or an empty state inviting the user to plan.
class DailyPlanScreen extends ConsumerWidget {
  const DailyPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateUtils.dateOnly(DateTime.now());
    final tasksAsync = ref.watch(tasksForDayProvider(today));
    final profile = ref.watch(userProfileProvider).asData?.value;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.addGoal),
        backgroundColor: context.colors.primary,
        foregroundColor: context.colors.onPrimary,
        elevation: 2,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      bottomNavigationBar: AppBottomNav(
        current: AppNavTab.calendar,
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
              data: (tasks) => _Content(tasks: tasks, profile: profile),
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
  const _Content({required this.tasks, required this.profile});

  final List<Task> tasks;
  final UserProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final listHeight = (constraints.maxHeight - 120).clamp(0.0, constraints.maxHeight);

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(profile: profile),
                if (profile != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 2),
                    child: StreakCard(
                      streak: profile!.streak,
                      freezes: profile!.freezes,
                      onTap: () => context.push(AppRoutes.profile),
                    ),
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

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final UserProfile? profile;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'home.good_morning'.tr();
    if (h < 17) return 'home.good_afternoon'.tr();
    return 'home.good_evening'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = profile?.name ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(Icons.spa_rounded, size: 20, color: colors.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    name.isEmpty ? _greeting : '$_greeting, $name',
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'home.tooltip_blocking'.tr(),
            icon: Icon(Icons.shield_outlined, color: colors.textSecondary),
            onPressed: () => context.push(AppRoutes.blocking),
          ),
          IconButton(
            tooltip: 'home.tooltip_weekly'.tr(),
            icon: Icon(
              Icons.calendar_view_week_rounded,
              color: colors.textSecondary,
            ),
            onPressed: () => context.push(AppRoutes.weeklyView),
          ),
          GestureDetector(
            onTap: () => context.push(AppRoutes.profile),
            child: AvatarCircle(
              avatarKey: profile?.avatar ?? 'leaf',
              size: 40,
              photoBase64: profile?.photoBase64,
              photoUrl: profile?.photoUrl,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineList extends ConsumerWidget {
  const _TimelineList({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final fullDone = tasks.where((t) => t.isCompleted).length;
    final partial = tasks
        .where((t) => !t.isCompleted && t.completionPercent > 0)
        .length;
    final total = tasks.length;
    // For the progress ring: count fully done + partial (weighted 0.5)
    final percent = total == 0
        ? 0.0
        : (fullDone + partial * 0.5) / total;
    final categories = tasks.map((t) => t.category).toSet().toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
      children: [
        Center(
          child: ProgressRing(
            percent: percent,
            size: 150,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(percent * 100).round()}%',
                  style: AppTextStyles.h1.copyWith(
                    color: colors.textPrimary,
                    fontSize: 28,
                  ),
                ),
                Text(
                  'home.progress'.tr(),
                  style: AppTextStyles.overline.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'home.focus_ritual'.tr(),
            style: AppTextStyles.h2.copyWith(color: colors.textPrimary),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          partial > 0
              ? 'home.progress_message_mixed'.tr(
                  namedArgs: {
                    'done': '$fullDone',
                    'partial': '$partial',
                    'total': '$total',
                  },
                )
              : 'home.progress_message'.tr(
                  namedArgs: {'done': '$fullDone', 'total': '$total'},
                ),
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [for (final c in categories) AppChip.category(c)],
        ),
        const SizedBox(height: 24),
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
class _StatusBubble extends StatelessWidget {
  const _StatusBubble({required this.task, required this.pct});

  final Task task;

  /// Effective completion ratio: 1.0 if isCompleted, else completionPercent.
  final double pct;

  static const _size = 58.0;
  // Amber-gold for partial progress — signals "tried but not finished".
  static const _partialColor = Color(0xFFF5A623);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (pct >= 0.95) {
      // ── FULLY COMPLETED ──────────────────────────────────────────────────
      return Container(
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
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_outlined, size: 64, color: colors.textTertiary),
          const SizedBox(height: 16),
          Text(
            'home.empty_title'.tr(),
            textAlign: TextAlign.center,
            style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 10),
          Text(
            'home.empty_body'.tr(),
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 24),
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
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
