import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive/hive.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/models/task.dart';
import '../../../core/router/app_router.dart';

/// Schedules Flowa's local notifications: a reminder 5 minutes before each task
/// and a gentle evening streak warning.
class NotificationService {
  final Ref _ref;
  NotificationService(this._ref);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _streakId = 900001;
  StreamSubscription<String>? _fcmTokenSub;

  /// Requests FCM permissions, fetches the current device token, saves it to
  /// Firestore under `users/{uid}`, and listens for token refreshes.
  Future<void> setupFcm(String uid) async {
    final messaging = FirebaseMessaging.instance;

    // 1. Request FCM permissions
    try {
      await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
    } catch (e) {
      // Permission request failed or is unsupported on this platform.
    }

    // 2. Fetch and save the current token
    try {
      final token = await messaging.getToken();
      if (token != null) {
        await _saveTokenToFirestore(uid, token);
      }
    } catch (e) {
      // Failed to retrieve FCM token (e.g. no internet or play services missing).
    }

    // 3. Listen for token refreshes
    await _fcmTokenSub?.cancel();
    _fcmTokenSub = messaging.onTokenRefresh.listen((newToken) async {
      await _saveTokenToFirestore(uid, newToken);
    });
  }

  /// Cancels the FCM token refresh subscription when it's no longer needed (e.g. logout).
  Future<void> cancelFcmSubscription() async {
    await _fcmTokenSub?.cancel();
    _fcmTokenSub = null;
  }

  /// Clears all local notifications, FCM subscriptions, and the current device
  /// token on logout. When a uid is provided, it also removes the `fcmToken`
  /// field from the user's Firestore document so the old account can no longer
  /// receive notifications on this device.
  Future<void> clearAllUserData({String? uid}) async {
    if (!_ready) await init();

    try {
      await _plugin.cancelAll();
    } catch (_) {}

    await cancelFcmSubscription();

    if (uid != null && uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'fcmToken': FieldValue.delete(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  Future<void> _saveTokenToFirestore(String uid, String token) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    } catch (e) {
      // Silently catch firestore save issues in case of permission errors or offline state
    }
  }

  /// Shows high-priority notification when opponent enters the waiting room
  Future<void> showBattleStartNotification({
    required String opponentName,
    required String battleId,
  }) async {
    if (!_ready) await init();
    const androidDetails = AndroidNotificationDetails(
      'battle_channel',
      '1v1 Battle Notifications',
      channelDescription: 'Notifications when opponent enters waiting room',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      id: 888888,
      title: '⚔️ Jang boshlanadi!',
      body: 'extra.battle_waiting'.tr(namedArgs: {'opponent': opponentName}),
      notificationDetails: details,
      payload: 'battle:$battleId',
    );
  }

  /// Shows notification when a friend sends a message
  Future<void> showChatNotification({
    required String senderName,
    required String message,
    required String chatId,
  }) async {
    if (!_ready) await init();
    const androidDetails = AndroidNotificationDetails(
      'chat_channel',
      'Do‘stlar Chati Xabarlari',
      channelDescription: 'Yangi chat xabarlari bildirishnomasi',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      id: chatId.hashCode & 0x7fffffff,
      title: '💬 $senderName',
      body: message,
      notificationDetails: details,
      payload: 'chat:$chatId',
    );
  }

  /// Shows notification for friend requests
  Future<void> showFriendRequestNotification({
    required String senderName,
  }) async {
    if (!_ready) await init();
    const androidDetails = AndroidNotificationDetails(
      'friends_channel',
      'Do‘stlik Takliflari',
      channelDescription: 'Yangi do‘stlik taklifi bildirishnomasi',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      id: 777777,
      title: '👥 Yangi Do‘stlik Taklifi!',
      body: '$senderName sizga do‘stlik taklifi yubordi.',
      notificationDetails: details,
      payload: 'friends',
    );
  }

  Future<void> init() async {
    if (_ready) return;
    if (kIsWeb) {
      _ready = true;
      return;
    }

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
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationResponse(response);
      },
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final settingsBox = await Hive.openBox('flowa_settings');
    final rawSoundPath =
        settingsBox.get(
              'task_alarm_sound',
              defaultValue: 'system_alarm',
            )
            as String;

    // Migrate from the old low-quality default to the system alarm.
    final soundPath = rawSoundPath == 'assets/sounds/alarm.wav' 
        ? 'system_alarm' 
        : rawSoundPath;

    final bool isSystemAlarm = soundPath == 'system_alarm';
    final bool isAsset = soundPath.startsWith('assets/sounds/');
    
    String rawSoundName = 'custom';
    String channelId;
    AndroidNotificationSound? androidSound;

    if (isSystemAlarm) {
      channelId = 'task_alarm_channel_system_v2';
      rawSoundName = 'system_alarm';
      androidSound = const UriAndroidNotificationSound('content://settings/system/alarm_alert');
    } else if (isAsset) {
      rawSoundName = soundPath.split('/').last.replaceAll('.wav', '');
      channelId = 'task_alarm_channel_$rawSoundName';
      androidSound = RawResourceAndroidNotificationSound(rawSoundName);
    } else {
      // Custom file chosen by user
      final fileUri = soundPath.startsWith('file://')
          ? soundPath
          : 'file://$soundPath';
      channelId = 'task_alarm_channel_custom';
      androidSound = UriAndroidNotificationSound(fileUri);
    }

    // Delete a few legacy channels to avoid clutter
    await android?.deleteNotificationChannel(channelId: 'task_alarm_channel');
    await android?.deleteNotificationChannel(
      channelId: 'task_alarm_channel_alarm',
    );
    await android?.deleteNotificationChannel(
      channelId: 'task_alarm_channel_alarm_soft',
    );
    await android?.deleteNotificationChannel(
      channelId: 'task_alarm_channel_alarm_loud',
    );
    // Delete the intermediate channel we might have just created in dev
    await android?.deleteNotificationChannel(
      channelId: 'task_alarm_channel_sys_alarm',
    );

    // Register our task alarm channel with the chosen sound and vibration pattern
    final alarmChannel = AndroidNotificationChannel(
      channelId,
      'Task Alarms',
      description: 'Sound alarm reminders for scheduled tasks.',
      importance: Importance.max,
      playSound: true,
      sound: androidSound,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
    );
    await android?.createNotificationChannel(alarmChannel);

    // Check if the app was launched by a notification action (or full screen intent)
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final response = launchDetails!.notificationResponse;
      if (response != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleNotificationResponse(response);
        });
      }
    }

    _ready = true;
  }

  /// Checks if the notifications permission has been requested, and displays
  /// a one-time dialog prompting the user to grant EXACT ALARM settings on Android.
  Future<void> checkAndRequestPermissions(BuildContext context) async {
    final settingsBox = await Hive.openBox('flowa_settings');
    final hasAskedNotification =
        settingsBox.get('asked_notification_permission', defaultValue: false)
            as bool;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (!hasAskedNotification) {
      // First-time automatic request for notifications permission (Android 13+)
      await android?.requestNotificationsPermission();
      await settingsBox.put('asked_notification_permission', true);
    }

    // Now check exact alarm permission
    final canExact = await android?.canScheduleExactNotifications() ?? true;
    if (!canExact) {
      final hasAskedExactAlarm =
          settingsBox.get('asked_exact_alarm_dialog', defaultValue: false)
              as bool;
      if (!hasAskedExactAlarm) {
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text('notifications.alarm_permission_title'.tr()),
              content: Text('notifications.alarm_permission_body'.tr()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('common.close'.tr()),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await android?.requestExactAlarmsPermission();
                  },
                  child: Text('notifications.go_to_settings'.tr()),
                ),
              ],
            ),
          );
        }
        await settingsBox.put('asked_exact_alarm_dialog', true);
      }
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.startsWith('task_alarm:')) {
      final parts = payload.split(':');
      if (parts.length >= 4) {
        final taskId = parts[1];
        final taskTitle = parts[2];
        final minutesBefore = int.tryParse(parts[3]) ?? 10;
        final notificationId = response.id ?? 0;

        Future.microtask(() {
          try {
            _ref
                .read(routerProvider)
                .push(
                  '/task-alarm?taskId=$taskId&title=${Uri.encodeComponent(taskTitle)}&minutesBefore=$minutesBefore&notificationId=$notificationId',
                );
          } catch (e) {
            // Router might not be ready yet
          }
        });
      }
    } else if (payload == 'mission_alarm') {
      Future.microtask(() {
        try {
          _ref.read(routerProvider).push('/mission-alarm');
        } catch (_) {}
      });
    }
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
    String? payload,
  }) async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final canExact = await android?.canScheduleExactNotifications() ?? false;
    final mode = canExact
        ? AndroidScheduleMode.alarmClock
        : AndroidScheduleMode.inexactAllowWhileIdle;

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: details,
      androidScheduleMode: mode,
      matchDateTimeComponents: matchDateTimeComponents,
      payload: payload,
    );
  }

  Future<NotificationDetails> _getAlarmDetails() async {
    final settingsBox = await Hive.openBox('flowa_settings');
    final rawSoundPath =
        settingsBox.get(
              'task_alarm_sound',
              defaultValue: 'system_alarm',
            )
            as String;

    // Migrate from the old low-quality default to the system alarm.
    final soundPath = rawSoundPath == 'assets/sounds/alarm.wav' 
        ? 'system_alarm' 
        : rawSoundPath;

    final bool isSystemAlarm = soundPath == 'system_alarm';
    final bool isAsset = soundPath.startsWith('assets/sounds/');
    
    String rawSoundName = 'custom';
    String channelId;
    AndroidNotificationSound? androidSound;

    if (isSystemAlarm) {
      channelId = 'task_alarm_channel_system_v2';
      rawSoundName = 'system_alarm';
      androidSound = const UriAndroidNotificationSound('content://settings/system/alarm_alert');
    } else if (isAsset) {
      rawSoundName = soundPath.split('/').last.replaceAll('.wav', '');
      channelId = 'task_alarm_channel_$rawSoundName';
      androidSound = RawResourceAndroidNotificationSound(rawSoundName);
    } else {
      final fileUri = soundPath.startsWith('file://')
          ? soundPath
          : 'file://$soundPath';
      channelId = 'task_alarm_channel_custom';
      androidSound = UriAndroidNotificationSound(fileUri);
    }

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        'Task Alarms',
        channelDescription: 'Sound alarm reminders for scheduled tasks.',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: androidSound,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
        fullScreenIntent: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        // iOS requires bundled sounds; for custom file selections we fall
        // back to the default system sound by leaving this null.
        sound: isAsset ? '$rawSoundName.wav' : null,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  static const _streakDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'flowa_streak',
      'Streak reminders',
      channelDescription: 'Evening nudge to keep your streak alive.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
  );

  /// Schedules reminders 60 minutes, 30 minutes, 10 minutes, and 5 minutes before [task] starts.
  Future<void> scheduleTaskReminder(Task task) async {
    await init();

    // 1 Hour (60 minutes) before reminder
    final when60 = task.start.subtract(const Duration(hours: 1));
    if (when60.isAfter(DateTime.now())) {
      await _schedule(
        id: _taskNotificationId(task, 60),
        title: '⏳ 1 soat qoldi: ${task.title}',
        body: 'ODAT: Vazifaga 1 soat qoldi — boshlashga tayyorlaning!',
        when: tz.TZDateTime.from(when60, tz.local),
        details: await _getAlarmDetails(),
        payload: 'task_alarm:${task.id}:${task.title}:60',
      );
    }

    // 0.5 Hour (30 minutes) before reminder
    final when30 = task.start.subtract(const Duration(minutes: 30));
    if (when30.isAfter(DateTime.now())) {
      await _schedule(
        id: _taskNotificationId(task, 30),
        title: '⏰ 30 daqiqa qoldi: ${task.title}',
        body: 'ODAT: 30 daqiqadan so‘ng rejalashtirilgan vazifa boshlanadi!',
        when: tz.TZDateTime.from(when30, tz.local),
        details: await _getAlarmDetails(),
        payload: 'task_alarm:${task.id}:${task.title}:30',
      );
    }

    // 10 minutes before reminder
    final when10 = task.start.subtract(const Duration(minutes: 10));
    if (when10.isAfter(DateTime.now())) {
      await _schedule(
        id: _taskNotificationId(task, 10),
        title: '🔔 10 daqiqa qoldi: ${task.title}',
        body: 'ODAT: Vazifaga 10 daqiqa qoldi!',
        when: tz.TZDateTime.from(when10, tz.local),
        details: await _getAlarmDetails(),
        payload: 'task_alarm:${task.id}:${task.title}:10',
      );
    }

    // 5 minutes before reminder
    final when5 = task.start.subtract(const Duration(minutes: 5));
    if (when5.isAfter(DateTime.now())) {
      await _schedule(
        id: _taskNotificationId(task, 5),
        title: '⚡ 5 daqiqa qoldi: ${task.title}',
        body: 'ODAT diqqat rejimi: Vazifa boshlanish arafasida!',
        when: tz.TZDateTime.from(when5, tz.local),
        details: await _getAlarmDetails(),
        payload: 'task_alarm:${task.id}:${task.title}:5',
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

  /// Schedules daily motivating nudges at 09:00, 14:00 and 20:30 to keep users engaged.
  Future<void> scheduleDailyMotivationReminders() async {
    await init();
    final now = tz.TZDateTime.now(tz.local);

    // 09:00 Ertalabki Motivatsiya
    var morning = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9, 0);
    if (morning.isBefore(now)) morning = morning.add(const Duration(days: 1));
    await _schedule(
      id: 900010,
      title: '🔥 O‘z ustingda ishlash vaqti keldi!',
      body: 'Bugungi kun chempioni sen! Vazifalaringiz va odatlaringiz sizni kutmoqda 🚀',
      when: morning,
      details: _streakDetails,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // 14:00 Kunduzgi Energiya
    var midday = tz.TZDateTime(tz.local, now.year, now.month, now.day, 14, 0);
    if (midday.isBefore(now)) midday = midday.add(const Duration(days: 1));
    await _schedule(
      id: 900011,
      title: '⚡ Dangasalikni yeng!',
      body: '15 daqiqalik mashg‘ulot yoki intizom seni yangi cho‘qqiga olib chiqadi 🌿',
      when: midday,
      details: _streakDetails,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // 20:30 Kechki Streak Eslatmasi
    var evening = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 30);
    if (evening.isBefore(now)) evening = evening.add(const Duration(days: 1));
    await _schedule(
      id: 900012,
      title: '❄️ Streakingizni saqlab qoling!',
      body: 'Bugungi rejangizni yakunlang yoki Muzlatgichingizni tekshirib oling 🔥',
      when: evening,
      details: _streakDetails,
      matchDateTimeComponents: DateTimeComponents.time,
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

  // ── Mission Alarm (Ertalabki Budilnik) ─────────────────────────────────────

  static const int _missionAlarmBaseId = 800001;

  /// Schedules (or re-schedules) the mission alarm for every selected weekday.
  /// [hour] and [minute] are the desired wake-up time (local).
  /// [selectedDays] is a 7-element list where index 0 = Monday … 6 = Sunday.
  /// Pass an empty / all-false list (or [enabled] = false) to cancel only.
  Future<void> scheduleMissionAlarm({
    required int hour,
    required int minute,
    required List<bool> selectedDays,
    required bool enabled,
  }) async {
    await init();

    // Always cancel all 7 previous slots first.
    for (int i = 0; i < 7; i++) {
      await _plugin.cancel(id: _missionAlarmBaseId + i);
    }

    if (!enabled) return;

    final now = tz.TZDateTime.now(tz.local);
    final details = await _getAlarmDetails();

    for (int i = 0; i < 7; i++) {
      if (!selectedDays[i]) continue;

      // ISO weekday: Monday = 1 … Sunday = 7. List index 0 = Monday.
      final isoWeekday = i + 1;

      // Find the next occurrence of this weekday at the requested time.
      tz.TZDateTime scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      // Advance to the correct day-of-week.
      while (scheduled.weekday != isoWeekday || !scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      try {
        await _plugin.zonedSchedule(
          id: _missionAlarmBaseId + i,
          title: '⏰ Ertalabki Missiya Budilnigi!',
          body: "Uyg'onish vaqti! 20 Squat + 20 Push-up qilmaguncha ovozi o'chmaydi! 🏆",
          scheduledDate: scheduled,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'mission_alarm',
        );
      } catch (_) {
        // Fall back to inexact if exact alarm permission is missing.
        try {
          await _plugin.zonedSchedule(
            id: _missionAlarmBaseId + i,
            title: '⏰ Ertalabki Missiya Budilnigi!',
            body: "Uyg'onish vaqti! 20 Squat + 20 Push-up qilmaguncha ovozi o'chmaydi! 🏆",
            scheduledDate: scheduled,
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            payload: 'mission_alarm',
          );
        } catch (_) {}
      }
    }
  }

  /// Cancels all mission-alarm slots.
  Future<void> cancelMissionAlarm() async {
    await init();
    for (int i = 0; i < 7; i++) {
      await _plugin.cancel(id: _missionAlarmBaseId + i);
    }
  }

  /// Stable per-task id derived from its day, start time, and reminder offset minutes.
  int _taskNotificationId(Task task, int minutesBefore) {
    final key =
        '${task.date.toIso8601String()}_${task.startMinute}_$minutesBefore';
    return key.hashCode & 0x7fffffff;
  }
}

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(ref),
);
