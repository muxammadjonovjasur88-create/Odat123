import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'running_telemetry_calculator.dart';

/// Background Foreground Service Manager for continuous GPS running session tracking.
abstract final class RunningBackgroundService {
  static const String channelId = 'running_service_channel';
  static const String notificationTitle = '🏃 Yugurish davom etmoqda';

  /// Initializes the flutter_background_service configuration.
  static Future<void> initialize() async {
    // Explicitly create NotificationChannel on Android OS to prevent CannotPostForegroundServiceNotificationException
    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const androidChannel = AndroidNotificationChannel(
        channelId,
        'Yugurish Xizmati',
        description: 'Yugurish masofasi va vaqtini orqa fonda kuzatish',
        importance: Importance.high, // HIGH so notification is always visible
      );
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Error creating notification channel for running service: $e');
    }

    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: channelId,
        initialNotificationTitle: notificationTitle,
        initialNotificationContent: 'Masofa: 0.00 km | Vaqt: 00:00',
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    try {
      final isRunning = await service.isRunning();
      if (isRunning) {
        service.invoke('stop_service');
      }
    } catch (_) {}
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      // Set notification immediately so it appears right when service starts
      service.setForegroundNotificationInfo(
        title: notificationTitle,
        content: 'Masofa: 0.00 km | Vaqt: 00:00 | Hazir bo\'layapti...',
      );
    }

    // Command Listeners from Main UI
    service.on('update_notification').listen((event) {
      if (event != null && service is AndroidServiceInstance) {
        final distanceKm = (event['distanceKm'] as num?)?.toDouble() ?? 0.0;
        final elapsedSeconds = event['elapsedSeconds'] as int? ?? 0;
        final calories = event['calories'] as int? ?? 0;
        final pace = event['pace'] as String? ?? "0'00\"";
        final isPaused = event['isPaused'] as bool? ?? false;

        final timeFormatted = RunningTelemetryCalculator.formatDuration(elapsedSeconds);
        final title = isPaused
            ? '⏸️ Yugurish to\'xtatilgan (${distanceKm.toStringAsFixed(2)} km)'
            : '🏃 Yugurish davom etmoqda (${distanceKm.toStringAsFixed(2)} km)';

        service.setForegroundNotificationInfo(
          title: title,
          content: 'Vaqt: $timeFormatted | Pace: $pace | Kaloriya: $calories kcal',
        );
      }
    });

    service.on('stop_service').listen((_) async {
      service.stopSelf();
    });
  }
}

