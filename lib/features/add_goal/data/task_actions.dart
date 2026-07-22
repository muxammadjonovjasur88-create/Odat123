import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/task.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/task_repository.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../blocking/data/blocking_repository.dart';
import '../../deep_focus/data/focus_providers.dart';
import '../../deep_focus/data/focus_service.dart';
import '../../notifications/data/notification_service.dart';

/// (Re)schedules a task's reminder and background auto-start/blocking so they
/// match its current values. Pass [previous] when EDITING so the old reminder
/// (keyed by the old date/time) is cancelled before the new one is scheduled.
///
/// [task] must carry its real Firestore id. Mirrors what Add Goal does on
/// create, plus the cancel-old step and a clear of this task's background slot.
Future<void> syncTaskSchedule(
  WidgetRef ref,
  Task task, {
  Task? previous,
}) async {
  final notifications = ref.read(notificationServiceProvider);
  // The reminder id is derived from date+start time, so an edited time means a
  // new id — cancel the stale one first.
  if (previous != null) {
    await notifications.cancelTaskReminder(previous);
  }
  await notifications.scheduleTaskReminder(task);

  final service = ref.read(focusServiceProvider);
  // If this task currently owns the single background slot, clear it first so a
  // stale alarm/blocking from the old time can't fire.
  final active = await service.getActiveSession();
  if (active?.taskId == task.id) {
    await service.stopSession();
  }
  // Time-driven sessions get a background auto-start; a set-based workout is
  // user-driven (you must be there to do the reps), so it isn't scheduled.
  // scheduleBackgroundFocus itself no-ops when the end time is already past.
  if (!task.hasWorkout) {
    await scheduleBackgroundFocus(
      service: service,
      taskId: task.id,
      task: task,
      settings: ref.read(blockingSettingsProvider).asData?.value,
    );
  }
}

/// Permanently removes [task]: deletes the Firestore doc and cancels its
/// reminder plus any scheduled/active background session + blocking tied to it.
Future<void> deleteTaskCompletely(WidgetRef ref, Task task) async {
  final uid = ref.read(authStateProvider).asData?.value?.uid;
  if (uid == null) return;

  final service = ref.read(focusServiceProvider);
  final active = await service.getActiveSession();
  if (active?.taskId == task.id) {
    await service.stopSession();
  }
  await ref.read(notificationServiceProvider).cancelTaskReminder(task);
  await ref.read(taskRepositoryProvider).deleteTask(uid, task.id);
}

/// Gentle Zen confirmation before deleting a task. Returns true if confirmed.
Future<bool> confirmDeleteTask(
  BuildContext context, {
  required String title,
}) async {
  final colors = context.colors;
  const danger = Color(0xFFB3504B);
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Delete this task?',
        style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
      ),
      content: Text(
        '“$title” will be gently removed from your calendar. '
        'This can’t be undone.',
        style: AppTextStyles.body.copyWith(color: colors.textSecondary),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            'Keep it',
            style: AppTextStyles.label.copyWith(color: colors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            'Delete',
            style: AppTextStyles.label.copyWith(color: danger),
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}
