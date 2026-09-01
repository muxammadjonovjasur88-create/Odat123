import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/reminders_notification_service.dart';
import '../../data/reminders_repository.dart';
import '../../domain/models/reminder.dart';

/// Notifier that holds the full list of [Reminder] objects and synchronises
/// Hive + local notifications on every mutation.
///
/// State is `AsyncValue<List<Reminder>>` so the UI gets loading / error
/// handling for free.
class RemindersNotifier extends AsyncNotifier<List<Reminder>> {
  RemindersRepository get _repo => RemindersRepository.instance;
  RemindersNotificationService get _notif =>
      RemindersNotificationService.instance;

  @override
  Future<List<Reminder>> build() => _repo.all();

  // ── Mutations ─────────────────────────────────────────────────────────────

  /// Creates a new reminder / goal, persists it, and schedules its notification.
  Future<void> add({
    required String title,
    required DateTime dateTime,
    required RepeatType repeatType,
    String goalType = 'note',
    int durationMinutes = 25,
    String? startTimeStr,
    String? endTimeStr,
    String? exerciseType,
    int? targetReps,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final reminder = await _repo.add(
        title: title,
        dateTime: dateTime,
        repeatType: repeatType,
        goalType: goalType,
        durationMinutes: durationMinutes,
        startTimeStr: startTimeStr,
        endTimeStr: endTimeStr,
        exerciseType: exerciseType,
        targetReps: targetReps,
      );
      await _notif.schedule(reminder);
      return _repo.all();
    });
  }

  /// Updates an existing reminder and re-schedules its notification.
  ///
  /// Named [editReminder] to avoid conflict with [AsyncNotifier.update].
  Future<void> editReminder(Reminder updated) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.update(updated);
      await _notif.cancel(updated.notificationId);
      await _notif.schedule(updated);
      return _repo.all();
    });
  }

  /// Marks a reminder as completed and cancels its pending notification.
  Future<void> markCompleted(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.markCompleted(id);
      final all = await _repo.all();
      final reminder = all.firstWhere(
        (r) => r.id == id,
        orElse: () => throw StateError('Reminder $id not found after update'),
      );
      await _notif.cancel(reminder.notificationId);
      return all;
    });
  }

  /// Deletes a reminder and cancels its notification.
  Future<void> deleteReminder(String id) async {
    // Cancel notification before deletion (we still have the id in current state).
    final current = state.value;
    final reminder = current?.firstWhere(
      (r) => r.id == id,
      orElse: () => throw StateError('Reminder $id not found'),
    );
    if (reminder != null) {
      await _notif.cancel(reminder.notificationId);
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.delete(id);
      return _repo.all();
    });
  }

  /// Refreshes the list from Hive (e.g. after returning to the screen).
  Future<void> refresh() async {
    state = AsyncData(await _repo.all());
  }
}

// ── Provider ──────────────────────────────────────────────────────────────

final remindersProvider =
    AsyncNotifierProvider<RemindersNotifier, List<Reminder>>(
      RemindersNotifier.new,
    );

// ── Derived providers ─────────────────────────────────────────────────────

/// Reminders that are not yet completed and whose time is in the future.
final pendingRemindersProvider = Provider<List<Reminder>>((ref) {
  final all = ref.watch(remindersProvider).value ?? [];
  return all.where((r) => !r.isCompleted && !r.isPast).toList();
});

/// Reminders whose scheduled time has passed but have not been marked done.
final pastRemindersProvider = Provider<List<Reminder>>((ref) {
  final all = ref.watch(remindersProvider).value ?? [];
  return all.where((r) => !r.isCompleted && r.isPast).toList();
});

/// Reminders the user has marked as completed.
final completedRemindersProvider = Provider<List<Reminder>>((ref) {
  final all = ref.watch(remindersProvider).value ?? [];
  return all.where((r) => r.isCompleted).toList();
});
