import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/models/task.dart';

/// Schedules Flowa's local notifications: a reminder 5 minutes before each task
/// and a gentle evening streak warning.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _streakId = 900001;

  Future<void> init() async {
    if (_ready) return;

    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fall back to UTC if the device timezone can't be resolved.
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: settings);

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    // Android 13+ runtime notification permission, and exact-alarm permission so
    // the "5 minutes before" reminder fires precisely (even in Doze).
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    _ready = true;
  }

  /// Schedules with an exact alarm when allowed, falling back to an inexact one
  /// (which a user can't disable) if exact alarms aren't permitted.
  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required NotificationDetails details,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final canExact = await android?.canScheduleExactNotifications() ?? false;
    final mode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: details,
      androidScheduleMode: mode,
      matchDateTimeComponents: matchDateTimeComponents,
    );
  }

  static const _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'flowa_reminders',
      'Focus reminders',
      channelDescription: 'Reminders shortly before a focus task begins.',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static const _streakDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'flowa_streak',
      'Streak reminders',
      channelDescription: 'Evening nudge to keep your streak alive.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
  );

  /// Schedules reminders 10 minutes and 5 minutes before [task] starts. No-op if
  /// those moments have already passed. Safe to call repeatedly — re-scheduling
  /// the same id just replaces the pending notification.
  Future<void> scheduleTaskReminder(Task task) async {
    await init();
    
    // 10 minutes before reminder
    final when10 = task.start.subtract(const Duration(minutes: 10));
    if (when10.isAfter(DateTime.now())) {
      await _schedule(
        id: _taskNotificationId(task, 10),
        title: '${task.title} 10 daqiqadan so\'ng boshlanadi',
        body: 'Vazifaga tayyorlaning — Flowa diqqatni jamlashga yordam beradi!',
        when: tz.TZDateTime.from(when10, tz.local),
        details: _reminderDetails,
      );
    }

    // 5 minutes before reminder
    final when5 = task.start.subtract(const Duration(minutes: 5));
    if (when5.isAfter(DateTime.now())) {
      await _schedule(
        id: _taskNotificationId(task, 5),
        title: '${task.title} 5 daqiqadan so\'ng boshlanadi',
        body:
            'Diqqat rejimi yoqildi — Flowa vazifa tugaguniga qadar yoningizda!',
        when: tz.TZDateTime.from(when5, tz.local),
        details: _reminderDetails,
      );
    }
  }

  /// Schedules tonight's streak nudge at 20:00 with a personalised message.
  /// No-op if 20:00 has already passed today; replaces any pending one. Call
  /// when the user has an active streak but hasn't completed a task today.
  Future<void> scheduleStreakReminder({required int streak}) async {
    await init();
    await _plugin.cancel(id: _streakId);
    if (streak <= 0) return;

    final now = tz.TZDateTime.now(tz.local);
    final when = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20);
    if (!when.isAfter(now)) return; // evening already passed

    await _schedule(
      id: _streakId,
      title: 'Keep your $streak-day streak alive 🔥',
      body:
          "Don't lose your $streak-day streak! Just one small task keeps it "
          'alive 🔥',
      when: when,
      details: _streakDetails,
    );
  }

  /// Cancels tonight's streak nudge — call when the user completes a task today.
  Future<void> cancelStreakReminder() async {
    await init();
    await _plugin.cancel(id: _streakId);
  }

  Future<void> cancelTaskReminder(Task task) async {
    await init();
    await _plugin.cancel(id: _taskNotificationId(task, 10));
    await _plugin.cancel(id: _taskNotificationId(task, 5));
  }

  /// Stable per-task id derived from its day, start time, and reminder offset minutes.
  int _taskNotificationId(Task task, int minutesBefore) {
    final key = '${task.date.toIso8601String()}_${task.startMinute}_$minutesBefore';
    return key.hashCode & 0x7fffffff;
  }
}

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);
