import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/models/reminder.dart';

/// Dedicated notification service for [Reminder] objects.
///
/// Uses a separate notification channel from task alarms so the two do not
/// interfere. Handles:
/// * One-time reminders (schedule once).
/// * Daily / weekly repeating reminders.
/// * Graceful degradation when exact-alarm permission is absent.
/// * Re-scheduling all pending reminders after a device reboot
///   (called from BootReceiver / [RemindersBootRescue]).
class RemindersNotificationService {
  static const _channelId = 'flowa_reminders_v1';
  static const _channelName = 'Reminders';
  static const _channelDesc = 'Personal reminder alarms (budilnik).';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  // ── Singleton ────────────────────────────────────────────────────────────

  RemindersNotificationService._();
  static final RemindersNotificationService instance =
      RemindersNotificationService._();

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialised) return;

    // Timezone setup – shared with other services but safe to call twice.
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fallback to UTC; better than crashing.
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // Create the notification channel for Android.
    final android =
        _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 800, 400, 800]),
        sound: const UriAndroidNotificationSound(
          'content://settings/system/alarm_alert',
        ),
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );

    _initialised = true;
  }

  // ── Schedule ─────────────────────────────────────────────────────────────

  int _idMain(int base) => (base.abs() & 0x1FFFFFFF) * 3;
  int _id60m(int base) => (base.abs() & 0x1FFFFFFF) * 3 + 1;
  int _id30m(int base) => (base.abs() & 0x1FFFFFFF) * 3 + 2;

  /// Schedules (or re-schedules) the notification for [reminder].
  ///
  /// No-op if the reminder is already completed or its time has passed and
  /// it is a one-time reminder.
  Future<void> schedule(Reminder reminder) async {
    await init();
    // Cancel any previous notification for this reminder first.
    await cancel(reminder.notificationId);

    if (reminder.isCompleted) return;

    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime.from(
      reminder.dateTime,
      tz.local,
    );

    DateTimeComponents? matchComponents;

    switch (reminder.repeatType) {
      case RepeatType.once:
        if (!scheduledDate.isAfter(now)) return; // already passed
        break;
      case RepeatType.daily:
        // Advance to the next future occurrence.
        while (!scheduledDate.isAfter(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }
        matchComponents = DateTimeComponents.time;
        break;
      case RepeatType.weekly:
        while (!scheduledDate.isAfter(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 7));
        }
        matchComponents = DateTimeComponents.dayOfWeekAndTime;
        break;
    }

    final details = _buildDetails();
    final payload = 'reminder:${reminder.id}';

    final android =
        _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final canExact = await android?.canScheduleExactNotifications() ?? false;
    final mode = canExact
        ? AndroidScheduleMode.alarmClock
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      // 1. Exact Alarm
      await _plugin.zonedSchedule(
        id: _idMain(reminder.notificationId),
        title: '🔔 ${reminder.title}',
        body: _repeatLabel(reminder.repeatType),
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: mode,
        matchDateTimeComponents: matchComponents,
        payload: payload,
      );

      // 2. Advance Reminder: 1 Hour Before (60 min)
      final when60 = scheduledDate.subtract(const Duration(hours: 1));
      if (when60.isAfter(now)) {
        await _plugin.zonedSchedule(
          id: _id60m(reminder.notificationId),
          title: '⏳ 1 soat qoldi: ${reminder.title}',
          body: 'ODAT eslatmasi: Rejalashtirilgan vazifaga tayyorlaning!',
          scheduledDate: when60,
          notificationDetails: details,
          androidScheduleMode: mode,
          payload: payload,
        );
      }

      // 3. Advance Reminder: 0.5 Hour Before (30 min)
      final when30 = scheduledDate.subtract(const Duration(minutes: 30));
      if (when30.isAfter(now)) {
        await _plugin.zonedSchedule(
          id: _id30m(reminder.notificationId),
          title: '⏰ 30 daqiqa qoldi: ${reminder.title}',
          body: 'ODAT eslatmasi: 30 daqiqadan so‘ng boshlanadi!',
          scheduledDate: when30,
          notificationDetails: details,
          androidScheduleMode: mode,
          payload: payload,
        );
      }
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          id: _idMain(reminder.notificationId),
          title: '🔔 ${reminder.title}',
          body: _repeatLabel(reminder.repeatType),
          scheduledDate: scheduledDate,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDesc,
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: matchComponents,
          payload: payload,
        );
      } catch (_) {}
    }
  }

  /// Cancels the scheduled notification for [notificationId].
  Future<void> cancel(int notificationId) async {
    await init();
    try {
      await _plugin.cancel(id: _idMain(notificationId));
      await _plugin.cancel(id: _id60m(notificationId));
      await _plugin.cancel(id: _id30m(notificationId));
    } catch (_) {}
  }

  /// Re-schedules all pending (not completed, not expired one-time) reminders.
  /// Called after device reboot.
  Future<void> rescheduleAll(List<Reminder> reminders) async {
    for (final r in reminders) {
      if (!r.isCompleted) {
        await schedule(r);
      }
    }
  }

  // ── Permission helpers ────────────────────────────────────────────────────

  /// Requests POST_NOTIFICATIONS permission on Android 13+.
  /// Returns true if already granted or just granted.
  Future<bool> requestNotificationPermission() async {
    await init();
    final android =
        _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true; // iOS handles permissions differently
    final granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Returns whether exact alarm scheduling is available.
  Future<bool> canScheduleExact() async {
    await init();
    final android =
        _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.canScheduleExactNotifications() ?? true;
  }

  /// Opens the system exact-alarm settings page.
  Future<void> openExactAlarmSettings() async {
    await init();
    final android =
        _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestExactAlarmsPermission();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  NotificationDetails _buildDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: UriAndroidNotificationSound(
          'content://settings/system/alarm_alert',
        ),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        vibrationPattern: null, // set on channel level
        enableVibration: true,
        fullScreenIntent: false,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  String _repeatLabel(RepeatType type) {
    switch (type) {
      case RepeatType.once:
        return 'Belgilangan eslatma';
      case RepeatType.daily:
        return 'Har kunlik eslatma';
      case RepeatType.weekly:
        return 'Har haftalik eslatma';
    }
  }
}

// ── Riverpod provider ─────────────────────────────────────────────────────

final remindersNotificationServiceProvider =
    Provider<RemindersNotificationService>(
      (_) => RemindersNotificationService.instance,
    );
