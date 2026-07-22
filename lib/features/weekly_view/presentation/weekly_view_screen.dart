import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/task.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/router/nav_helpers.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/task_repository.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/widgets.dart';
import '../../add_goal/data/task_actions.dart';

/// The day the weekly view is focused on (drives the visible week + task list).
class _SelectedDay extends Notifier<DateTime> {
  @override
  DateTime build() => DateUtils.dateOnly(DateTime.now());

  void select(DateTime day) => state = DateUtils.dateOnly(day);
  void shift(int days) =>
      state = DateUtils.dateOnly(state.add(Duration(days: days)));
}

final _selectedDayProvider = NotifierProvider<_SelectedDay, DateTime>(
  _SelectedDay.new,
);

/// Screen 08 — weekly overview: month/week selector, a day strip, the selected
/// day's tasks, and a "Consistency Peak" card for the whole week.
class WeeklyViewScreen extends ConsumerWidget {
  const WeeklyViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final selectedDay = ref.watch(_selectedDayProvider);
    final weekStart = mondayOf(selectedDay);
    final profile = ref.watch(userProfileProvider).asData?.value;

    final dayTasks =
        ref.watch(tasksForDayProvider(selectedDay)).asData?.value ?? const [];
    final weekTasks =
        ref.watch(tasksForWeekProvider(weekStart)).asData?.value ?? const [];

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.addGoal),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.spa_rounded, size: 20, color: colors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'weekly.overview'.tr(),
                      style: AppTextStyles.h3.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                AvatarCircle(
                  avatarKey: profile?.avatar ?? 'leaf',
                  size: 40,
                  photoBase64: profile?.photoBase64,
                  photoUrl: profile?.photoUrl,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _MonthSelector(
              month: selectedDay,
              onPrev: () => _shiftWeek(ref, -7),
              onNext: () => _shiftWeek(ref, 7),
            ),
            const SizedBox(height: 16),
            _DayStrip(
              weekStart: weekStart,
              selected: selectedDay,
              onSelect: (d) =>
                  ref.read(_selectedDayProvider.notifier).select(d),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    formatLongDay(selectedDay),
                    style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
                  ),
                ),
                Text(
                  'weekly.tasks_today'.tr(
                    namedArgs: {'count': '${dayTasks.length}'},
                  ),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (dayTasks.isEmpty)
              _NoTasks(colors: colors)
            else
              for (final t in dayTasks) _WeeklyTaskCard(task: t),
            const SizedBox(height: 8),
            _ConsistencyCard(tasks: weekTasks),
          ],
        ),
      ),
    );
  }

  void _shiftWeek(WidgetRef ref, int days) =>
      ref.read(_selectedDayProvider.notifier).shift(days);
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          formatMonthYear(month),
          style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
        ),
        Row(
          children: [
            _RoundIcon(icon: Icons.chevron_left_rounded, onTap: onPrev),
            const SizedBox(width: 8),
            _RoundIcon(icon: Icons.chevron_right_rounded, onTap: onNext),
          ],
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
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

class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.weekStart,
    required this.selected,
    required this.onSelect,
  });

  final DateTime weekStart;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 78,
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Builder(
              builder: (context) {
                final day = DateUtils.dateOnly(
                  weekStart.add(Duration(days: i)),
                );
                final isSelected = DateUtils.isSameDay(day, selected);
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onSelect(day),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: isSelected ? colors.primary : colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? colors.primary : colors.border,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            shortWeekday(day),
                            style: AppTextStyles.caption.copyWith(
                              color: isSelected
                                  ? colors.onPrimary
                                  : colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${day.day}',
                            style: AppTextStyles.h3.copyWith(
                              color: isSelected
                                  ? colors.onPrimary
                                  : colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _WeeklyTaskCard extends ConsumerWidget {
  const _WeeklyTaskCard({required this.task});

  final Task task;

  Future<void> _toggle(WidgetRef ref) async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;
    await ref
        .read(taskRepositoryProvider)
        .setCompleted(uid, task.id, !task.isCompleted);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final done = task.isCompleted;

    return Dismissible(
      key: ValueKey('wtask-${task.id}'),
      direction: DismissDirection.endToStart,
      background: _deleteBackground(),
      confirmDismiss: (_) async {
        final ok = await confirmDeleteTask(context, title: task.title);
        if (ok) await deleteTaskCompletely(ref, task);
        // The Firestore stream removes the card; the row just settles back.
        return false;
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: AppCard(
          padding: const EdgeInsets.all(16),
          onTap: () => context.push(AppRoutes.editGoal, extra: task),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: task.category.fill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  task.category.icon,
                  size: 20,
                  color: task.category.foreground,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: AppTextStyles.h3.copyWith(
                              color: colors.textPrimary,
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (done)
                          AppChip(label: 'weekly.completed'.tr())
                        else
                          AppChip.category(task.category),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatHm12(task.startMinute)} • '
                      '${formatDuration(task.durationMinutes)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    if (task.hasReminder) ...[
                      const SizedBox(height: 10),
                      _ReminderRow(task: task),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _toggle(ref),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? colors.primary : Colors.transparent,
                    border: Border.all(
                      color: done ? colors.primary : colors.border,
                      width: 1.6,
                    ),
                  ),
                  child: done
                      ? Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: colors.onPrimary,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Soft red reveal shown behind the card when swiping left to delete.
  Widget _deleteBackground() {
    const danger = Color(0xFFB3504B);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_outline_rounded, color: danger),
            const SizedBox(width: 8),
            Text(
              'weekly.delete'.tr(),
              style: const TextStyle(color: danger, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final remindAt = task.startMinute - (task.reminderMinutesBefore ?? 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 16,
            color: colors.textSecondary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'weekly.reminder_set'.tr(
                namedArgs: {'time': formatHm12(remindAt)},
              ),
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsistencyCard extends StatelessWidget {
  const _ConsistencyCard({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final total = tasks.length;
    final done = tasks.where((t) => t.isCompleted).length;
    final percent = total == 0 ? 0.0 : done / total;

    return AppCard(
      color: colors.tintSage,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'weekly.consistency_peak'.tr(),
                  style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'weekly.consistency_body'.tr(
                    namedArgs: {'percent': '${(percent * 100).round()}'},
                  ),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ProgressRing(
            percent: percent,
            size: 72,
            strokeWidth: 6,
            color: colors.primary,
            trackColor: colors.border,
            center: Text(
              '${(percent * 100).round()}%',
              style: AppTextStyles.label.copyWith(
                color: colors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoTasks extends StatelessWidget {
  const _NoTasks({required this.colors});

  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Text(
          'weekly.nothing_planned'.tr(),
          style: AppTextStyles.body.copyWith(color: colors.textTertiary),
        ),
      ),
    );
  }
}
