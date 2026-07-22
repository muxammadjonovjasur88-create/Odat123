import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/task_repository.dart';
import '../../../core/services/user_repository.dart';
import '../../notifications/data/notification_service.dart';

/// Invisible widget that keeps the evening (20:00) streak reminder in sync:
/// schedules it when the user has an active streak but hasn't completed any
/// task today, and cancels it the moment they complete one. Evaluated whenever
/// the profile or today's tasks change while the app is open.
class StreakReminderScheduler extends ConsumerStatefulWidget {
  const StreakReminderScheduler({super.key});

  @override
  ConsumerState<StreakReminderScheduler> createState() =>
      _StreakReminderSchedulerState();
}

class _StreakReminderSchedulerState
    extends ConsumerState<StreakReminderScheduler> {
  String? _applied;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).asData?.value;
    final today = DateUtils.dateOnly(DateTime.now());
    final tasks =
        ref.watch(tasksForDayProvider(today)).asData?.value ?? const [];

    final streak = profile?.streak ?? 0;
    final completedToday = tasks.any((t) => t.isCompleted);
    final key = '$streak|$completedToday';

    if (key != _applied) {
      _applied = key;
      final notifications = ref.read(notificationServiceProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (streak > 0 && !completedToday) {
          notifications.scheduleStreakReminder(streak: streak);
        } else {
          notifications.cancelStreakReminder();
        }
      });
    }
    return const SizedBox.shrink();
  }
}
