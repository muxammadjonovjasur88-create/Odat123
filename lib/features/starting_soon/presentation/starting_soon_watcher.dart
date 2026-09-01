import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/task.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/task_repository.dart';
import '../../notifications/data/notification_service.dart';

/// Task ids already surfaced this app session, so we prompt only once per task.
final _armed = <String>{};

/// Task ids we've already scheduled a 5-min reminder for this session.
final _scheduled = <String>{};

/// Task ids we've already auto-marked ended this session (dedup).
final _autoCompleted = <String>{};

/// Invisible widget that, while the app is open, keeps reminders in sync with
/// today's tasks:
///
/// * schedules the 5-minutes-before reminder for every upcoming task (this is
///   delivered by AlarmManager even if the app is later closed);
/// * opens the "Starting Soon" screen as the task gets close.
///
/// App blocking + the focus countdown are owned by the native background focus
/// session (scheduled when the task is created), so they are NOT armed here.
class StartingSoonWatcher extends ConsumerStatefulWidget {
  const StartingSoonWatcher({super.key});

  @override
  ConsumerState<StartingSoonWatcher> createState() =>
      _StartingSoonWatcherState();
}

class _StartingSoonWatcherState extends ConsumerState<StartingSoonWatcher> {
  /// How close to its start a task triggers the "Starting Soon" popup.
  static const _leadMinutes = 5;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _check() {
    if (!mounted) return;
    final today = DateUtils.dateOnly(DateTime.now());
    final tasks =
        ref.read(tasksForDayProvider(today)).asData?.value ?? const [];
    final now = DateTime.now();
    final notifications = ref.read(notificationServiceProvider);

    for (final Task task in tasks) {
      final ended = !task.end.isAfter(now); // end time has passed

      // 0. When the end time passes, mark the task ended/Done — but DO NOT
      //    award points. Points are earned only from a genuine focus session
      //    (Honest Focus) or a manual checkbox; if neither happened, this just
      //    closes the task out with zero points (a gentle "no session" note is
      //    shown on the tile, derived from isCompleted && !pointsAwarded).
      if (!task.isCompleted && ended) {
        final uid = ref.read(authStateProvider).asData?.value?.uid;
        if (uid != null && _autoCompleted.add(task.id)) {
          ref.read(taskRepositoryProvider).setCompleted(uid, task.id, true);
        }
      }
      if (task.isCompleted || ended) continue;
      final minutesUntil = task.start.difference(now).inMinutes;

      // 1. Schedule the 5-min-before reminder for any still-upcoming task.
      if (task.start.isAfter(now) && !_scheduled.contains(task.id)) {
        _scheduled.add(task.id);
        notifications.scheduleTaskReminder(task);
      }

      // 2. Only surface the Starting Soon strict screen if this task is explicitly marked for Hard Focus / Blocking
      final isStrictFocus = task.blockApps ||
          task.title.toLowerCase().contains('qat\'iy') ||
          task.title.toLowerCase().contains('fokus');

      if (isStrictFocus && minutesUntil <= _leadMinutes && !_armed.contains(task.id)) {
        _armed.add(task.id);
        context.push(AppRoutes.startingSoon, extra: task);
        break; // one prompt at a time
      }
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
