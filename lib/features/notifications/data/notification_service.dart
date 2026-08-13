import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
              title: const Text('Budilnik ruxsati'),
              content: const Text(
                'Vazifalar boshlanishidan oldin budilnik to\'g\'ri va o\'z vaqtida '
                'chalinishi uchun sozlamalardan "Alarmlar va eslatmalar" ruxsatini yoqing.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Yopish'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await android?.requestExactAlarmsPermission();
                  },
                  child: const Text('Sozlamalarga o\'tish'),
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
        body: 'Vazifaga tayyorlaning — Odat diqqatni jamlashga yordam beradi!',
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
        title: '${task.title} 5 daqiqadan so\'ng boshlanadi',
        body:
            'Diqqat rejimi yoqildi — Flowa vazifa tugaguniga qadar yoningizda!',
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
    final key =
        '${task.date.toIso8601String()}_${task.startMinute}_$minutesBefore';
    return key.hashCode & 0x7fffffff;
  }
}

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(ref),
);
