import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

import '../models/territory_polygon.dart';
import 'anti_cheat_validator.dart';
import 'haversine_calculator.dart';
import 'running_telemetry_calculator.dart';
import 'territory_conquest_service.dart';

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
        importance: Importance.low,
      );
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
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
      service.setForegroundNotificationInfo(
        title: notificationTitle,
        content: 'Masofa: 0.00 km | Vaqt: 00:00',
      );
    }

    double distanceKm = 0.0;
    int elapsedSeconds = 0;
    int calories = 0;
    int capturedLoopCount = 0;
    String pace = "0'00\"";
    double avgSpeedKmh = 0.0;
    bool isWalking = false;
    double targetKm = 3.0;

    List<GpsPoint> gpsPath = [];
    List<TerritoryPolygon> territories = [];
    GpsPoint? lastPoint;
    DateTime? lastPosTime;

    Timer? timer;
    StreamSubscription<Position>? posSub;

    // Command Listeners from Main UI
    service.on('set_params').listen((event) {
      if (event != null) {
        isWalking = event['isWalking'] as bool? ?? false;
        targetKm = (event['targetKm'] as num?)?.toDouble() ?? 3.0;
        // ignore: avoid_print
        print('[BackgroundService] targetKm=$targetKm, isWalking=$isWalking');
      }
    });

    service.on('stop_service').listen((_) async {
      timer?.cancel();
      await posSub?.cancel();
      service.stopSelf();
    });

    // Start 1-second timer in background
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      elapsedSeconds++;
      avgSpeedKmh = RunningTelemetryCalculator.calculateAverageSpeed(
        distanceKm: distanceKm,
        durationSeconds: elapsedSeconds,
      );
      pace = RunningTelemetryCalculator.formatPace(
        distanceKm: distanceKm,
        durationSeconds: elapsedSeconds,
      );

      final timeFormatted = RunningTelemetryCalculator.formatDuration(elapsedSeconds);

      // Update Persistent Foreground Notification
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: '🏃 Yugurish davom etmoqda (${distanceKm.toStringAsFixed(2)} km)',
          content: 'Vaqt: $timeFormatted | Pace: $pace | Kaloriya: $calories kcal',
        );
      }

      // Send telemetry update to main UI isolate
      service.invoke('update_state', {
        'elapsedSeconds': elapsedSeconds,
        'distanceKm': distanceKm,
        'calories': calories,
        'avgSpeedKmh': avgSpeedKmh,
        'pace': pace,
        'capturedLoopCount': capturedLoopCount,
      });
    });

    // High Accuracy GPS stream (distanceFilter: 3m for battery optimization)
    posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).listen((Position pos) {
      final now = DateTime.now();
      final newPoint = GpsPoint(latitude: pos.latitude, longitude: pos.longitude);

      if (lastPoint != null) {
        final timeDiffSec =
            (lastPosTime != null) ? now.difference(lastPosTime!).inMilliseconds / 1000.0 : 1.0;
        final deltaKm = HaversineCalculator.calculateDistanceBetweenPoints(lastPoint!, newPoint);

        if (AntiCheatValidator.isSignificantMovement(deltaKm) &&
            AntiCheatValidator.isValidSpeed(deltaKm, timeDiffSec)) {
          distanceKm += deltaKm;
          gpsPath.add(newPoint);
          lastPosTime = now;

          calories = RunningTelemetryCalculator.calculateCalories(
            distanceKm: distanceKm,
            isWalking: isWalking,
          );

          // Check closed loop polygon conquest
          final polygon = TerritoryConquestService.detectClosedLoop(
            path: gpsPath,
            ownerId: 'user',
            ownerName: 'Siz',
          );

          if (polygon != null) {
            territories.add(polygon);
            capturedLoopCount++;
            service.invoke('closed_loop_detected', {
              'polygon': polygon.toMap(),
              'count': capturedLoopCount,
            });
          }
        }
      } else {
        gpsPath.add(newPoint);
        lastPosTime = now;
      }

      lastPoint = newPoint;

      service.invoke('location_update', {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'heading': pos.heading,
        'speed': pos.speed,
        'distanceKm': distanceKm,
        'gpsPath': gpsPath.map((p) => p.toMap()).toList(),
      });
    });
  }
}
