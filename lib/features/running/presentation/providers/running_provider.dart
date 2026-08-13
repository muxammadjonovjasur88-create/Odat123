import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/user_repository.dart';
import '../../data/running_repository.dart';
import '../../domain/models/run_session.dart';
import '../../domain/models/territory_polygon.dart';
import '../../domain/services/anti_cheat_validator.dart';
import '../../domain/services/haversine_calculator.dart';
import '../../domain/services/running_telemetry_calculator.dart';
import '../../domain/services/territory_conquest_service.dart';

enum WorkoutState { idle, running, paused, completed }

@immutable
class RunningState {
  const RunningState({
    this.workoutState = WorkoutState.idle,
    this.currentPos,
    this.gpsPath = const [],
    this.territories = const [],
    this.elapsedSeconds = 0,
    this.distanceKm = 0.0,
    this.calories = 0,
    this.avgSpeedKmh = 0.0,
    this.currentSpeedKmh = 0.0,
    this.heading = 0.0,
    this.pace = "0'00\"",
    this.gpsError,
    this.antiCheatWarning,
    this.closedLoopNotification,
    this.capturedLoopCount = 0,
    this.isWalking = false,
    this.targetKm = 3.0,
    this.completedSession,
  });

  final WorkoutState workoutState;
  final GpsPoint? currentPos;
  final List<GpsPoint> gpsPath;
  final List<TerritoryPolygon> territories;
  final int elapsedSeconds;
  final double distanceKm;
  final int calories;
  final double avgSpeedKmh;
  final double currentSpeedKmh;
  final double heading;
  final String pace;
  final String? gpsError;
  final String? antiCheatWarning;
  final String? closedLoopNotification;
  final int capturedLoopCount;
  final bool isWalking;
  final double targetKm;
  final RunSession? completedSession;

  RunningState copyWith({
    WorkoutState? workoutState,
    GpsPoint? currentPos,
    List<GpsPoint>? gpsPath,
    List<TerritoryPolygon>? territories,
    int? elapsedSeconds,
    double? distanceKm,
    int? calories,
    double? avgSpeedKmh,
    double? currentSpeedKmh,
    double? heading,
    String? pace,
    String? gpsError,
    String? antiCheatWarning,
    String? closedLoopNotification,
    int? capturedLoopCount,
    bool? isWalking,
    double? targetKm,
    RunSession? completedSession,
    bool clearGpsError = false,
    bool clearAntiCheatWarning = false,
    bool clearNotification = false,
  }) {
    return RunningState(
      workoutState: workoutState ?? this.workoutState,
      currentPos: currentPos ?? this.currentPos,
      gpsPath: gpsPath ?? this.gpsPath,
      territories: territories ?? this.territories,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      distanceKm: distanceKm ?? this.distanceKm,
      calories: calories ?? this.calories,
      avgSpeedKmh: avgSpeedKmh ?? this.avgSpeedKmh,
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      heading: heading ?? this.heading,
      pace: pace ?? this.pace,
      gpsError: clearGpsError ? null : (gpsError ?? this.gpsError),
      antiCheatWarning: clearAntiCheatWarning
          ? null
          : (antiCheatWarning ?? this.antiCheatWarning),
      closedLoopNotification: clearNotification
          ? null
          : (closedLoopNotification ?? this.closedLoopNotification),
      capturedLoopCount: capturedLoopCount ?? this.capturedLoopCount,
      isWalking: isWalking ?? this.isWalking,
      targetKm: targetKm ?? this.targetKm,
      completedSession: completedSession ?? this.completedSession,
    );
  }
}

class RunningNotifier extends Notifier<RunningState> {
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription? _serviceStateSub;
  StreamSubscription? _serviceLocationSub;
  StreamSubscription? _serviceLoopSub;
  Timer? _timer;
  DateTime? _lastPosTime;
  Timer? _warningTimer;
  Timer? _notificationTimer;

  @override
  RunningState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _warningTimer?.cancel();
      _notificationTimer?.cancel();
      _positionSubscription?.cancel();
      _serviceStateSub?.cancel();
      _serviceLocationSub?.cancel();
      _serviceLoopSub?.cancel();
    });

    Future.microtask(initGps);
    return const RunningState();
  }

  /// Requests permissions and initializes high-accuracy GPS stream.
  Future<void> initGps() async {
    try {
      state = state.copyWith(clearGpsError: true);

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          gpsError:
              'GPS joylashuv yoqilmagan. Telefon sozlamalaridan GPS-ni yoqing.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(
            gpsError: 'GPS joylashuv uchun ruxsat berilishi shart.',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          gpsError:
              'GPS ruxsati butunlay rad etilgan. Sozlamalardan ruxsat bering.',
        );
        return;
      }

      // Step 1: Instant location fallback from Last Known Position
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          final lastPoint = GpsPoint(
            latitude: lastPos.latitude,
            longitude: lastPos.longitude,
          );
          state = state.copyWith(
            currentPos: lastPoint,
            gpsPath: state.gpsPath.isEmpty ? [lastPoint] : state.gpsPath,
          );
        }
      } catch (_) {}

      // Step 2: Try fetching current fresh position with fast fallback
      try {
        final initPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );

        final initPoint = GpsPoint(
          latitude: initPosition.latitude,
          longitude: initPosition.longitude,
        );

        state = state.copyWith(
          currentPos: initPoint,
          gpsPath: state.gpsPath.isEmpty ? [initPoint] : state.gpsPath,
        );
      } catch (_) {}

      // Step 3: Always start continuous high-accuracy location stream
      final locationSettings = defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 2,
              forceLocationManager: false,
              intervalDuration: const Duration(seconds: 2),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 2,
            );

      _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _onPositionUpdate,
        onError: (err) {
          state = state.copyWith(
            gpsError: 'GPS signali yo\'qoldi. Qayta ulanmoqda...',
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        gpsError: 'GPS joylashuvini olishda xatolik yuz berdi.',
      );
    }
  }

  void _onPositionUpdate(Position pos) {
    final newPoint = GpsPoint(
      latitude: pos.latitude,
      longitude: pos.longitude,
    );

    // Calculate instantaneous speed (m/s to km/h) from GPS sensor
    double instantSpeedKmh = state.currentSpeedKmh;
    if (pos.speed > 0) {
      instantSpeedKmh = double.parse((pos.speed * 3.6).toStringAsFixed(1));
    }

    final newHeading = pos.heading >= 0 ? pos.heading : state.heading;

    // Always update current display marker, heading, and live speed
    state = state.copyWith(
      currentPos: newPoint,
      heading: newHeading,
      currentSpeedKmh: instantSpeedKmh,
      clearGpsError: true,
    );

    // Only process distance & loop conquest when workout is running!
    if (state.workoutState != WorkoutState.running) return;

    final now = DateTime.now();
    final lastTime = _lastPosTime ?? now;
    final timeDiffSec = now.difference(lastTime).inMilliseconds / 1000.0;

    final lastPoint = state.currentPos;
    if (lastPoint == null) {
      _lastPosTime = now;
      return;
    }

    final deltaKm = HaversineCalculator.calculateDistanceBetweenPoints(
      lastPoint,
      newPoint,
    );

    // Ignore stationary jitter (< 4 meters)
    if (!AntiCheatValidator.isSignificantMovement(deltaKm)) {
      return;
    }

    // Fallback instant speed calculation if pos.speed is 0
    if (pos.speed <= 0 && timeDiffSec > 0) {
      instantSpeedKmh = double.parse(((deltaKm / timeDiffSec) * 3600.0).toStringAsFixed(1));
    }

    // ANTI-CHEAT CHECK (speed limit 25 km/h)
    if (!AntiCheatValidator.isValidSpeed(deltaKm, timeDiffSec)) {
      state = state.copyWith(
        antiCheatWarning:
            '⚠️ TEZLIK CHEKLOVI BUZILDI! (Avtomobil yoki soxta GPS)',
      );
      _warningTimer?.cancel();
      _warningTimer = Timer(const Duration(seconds: 4), () {
        state = state.copyWith(clearAntiCheatWarning: true);
      });
      return;
    }

    _lastPosTime = now;
    final updatedDistance = state.distanceKm + deltaKm;
    final updatedPath = [...state.gpsPath, newPoint];

    final updatedCalories = RunningTelemetryCalculator.calculateCalories(
      distanceKm: updatedDistance,
      isWalking: state.isWalking,
    );

    final updatedSpeed = RunningTelemetryCalculator.calculateAverageSpeed(
      distanceKm: updatedDistance,
      durationSeconds: state.elapsedSeconds,
    );

    final updatedPace = RunningTelemetryCalculator.formatPace(
      distanceKm: updatedDistance,
      durationSeconds: state.elapsedSeconds,
    );

    state = state.copyWith(
      distanceKm: updatedDistance,
      gpsPath: updatedPath,
      calories: updatedCalories,
      avgSpeedKmh: updatedSpeed,
      currentSpeedKmh: instantSpeedKmh,
      pace: updatedPace,
    );

    // CLOSED-LOOP CONQUEST CHECK
    final user = ref.read(userProfileProvider).asData?.value;
    final userName = user?.displayName ?? user?.name ?? 'Siz';
    final userId = user?.uid ?? 'user-1';

    final polygon = TerritoryConquestService.detectClosedLoop(
      path: updatedPath,
      ownerId: userId,
      ownerName: userName,
    );

    if (polygon != null) {
      state = state.copyWith(
        territories: [...state.territories, polygon],
        capturedLoopCount: state.capturedLoopCount + 1,
        closedLoopNotification:
            '🎉 DAVRA YOPILDI! HUDUD TO‘LIQ BO‘YALDI VA EGALLANDI!',
      );

      _notificationTimer?.cancel();
      _notificationTimer = Timer(const Duration(seconds: 4), () {
        state = state.copyWith(clearNotification: true);
      });
    }
  }

  Future<void> startWorkout({bool isWalking = false, double targetKm = 3.0}) async {
    _lastPosTime = DateTime.now();
    state = state.copyWith(
      workoutState: WorkoutState.running,
      isWalking: isWalking,
      targetKm: targetKm,
    );

    // Start Android Foreground Service for background location tracking (safely guarded)
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
      if (await Permission.location.isDenied) {
        await Permission.location.request();
      }
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      if (!isRunning) {
        await service.startService();
      }
      service.invoke('set_params', {
        'isWalking': isWalking,
        'targetKm': targetKm,
      });

      _subscribeToBackgroundService(service);
    } catch (e) {
      debugPrint('Background service launch warning (main UI tracking active): $e');
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.workoutState != WorkoutState.running) return;

      final nextSec = state.elapsedSeconds + 1;
      final updatedSpeed = RunningTelemetryCalculator.calculateAverageSpeed(
        distanceKm: state.distanceKm,
        durationSeconds: nextSec,
      );
      final updatedPace = RunningTelemetryCalculator.formatPace(
        distanceKm: state.distanceKm,
        durationSeconds: nextSec,
      );

      state = state.copyWith(
        elapsedSeconds: nextSec,
        avgSpeedKmh: updatedSpeed,
        pace: updatedPace,
      );
    });
  }

  void _subscribeToBackgroundService(FlutterBackgroundService service) {
    _serviceStateSub?.cancel();
    _serviceStateSub = service.on('update_state').listen((event) {
      if (event != null && state.workoutState == WorkoutState.running) {
        final bgSec = event['elapsedSeconds'] as int? ?? state.elapsedSeconds;
        final bgDist = (event['distanceKm'] as num?)?.toDouble() ?? state.distanceKm;
        final bgCal = event['calories'] as int? ?? state.calories;
        final bgSpeed = (event['avgSpeedKmh'] as num?)?.toDouble() ?? state.avgSpeedKmh;
        final bgPace = event['pace'] as String? ?? state.pace;

        state = state.copyWith(
          elapsedSeconds: bgSec > state.elapsedSeconds ? bgSec : state.elapsedSeconds,
          distanceKm: bgDist > state.distanceKm ? bgDist : state.distanceKm,
          calories: bgCal > state.calories ? bgCal : state.calories,
          avgSpeedKmh: bgSpeed,
          pace: bgPace,
        );
      }
    });

    _serviceLocationSub?.cancel();
    _serviceLocationSub = service.on('location_update').listen((event) {
      if (event != null && state.workoutState == WorkoutState.running) {
        final lat = (event['latitude'] as num?)?.toDouble();
        final lng = (event['longitude'] as num?)?.toDouble();
        final heading = (event['heading'] as num?)?.toDouble() ?? state.heading;
        final speedMs = (event['speed'] as num?)?.toDouble() ?? 0.0;
        final speedKmh = speedMs > 0 ? double.parse((speedMs * 3.6).toStringAsFixed(1)) : state.currentSpeedKmh;

        if (lat != null && lng != null) {
          final pt = GpsPoint(latitude: lat, longitude: lng);
          state = state.copyWith(
            currentPos: pt,
            heading: heading,
            currentSpeedKmh: speedKmh,
          );
        }
      }
    });

    _serviceLoopSub?.cancel();
    _serviceLoopSub = service.on('closed_loop_detected').listen((event) {
      if (event != null && state.workoutState == WorkoutState.running) {
        final polyMap = event['polygon'] as Map<String, dynamic>?;
        if (polyMap != null) {
          final poly = TerritoryPolygon.fromMap(polyMap);
          if (!state.territories.contains(poly)) {
            state = state.copyWith(
              territories: [...state.territories, poly],
              capturedLoopCount: state.capturedLoopCount + 1,
              closedLoopNotification: '🎉 DAVRA YOPILDI! HUDUD TO‘LIQ BO‘YALDI VA EGALLANDI!',
            );
          }
        }
      }
    });
  }

  void pauseWorkout() {
    _timer?.cancel();
    state = state.copyWith(workoutState: WorkoutState.paused);
  }

  void resumeWorkout() {
    startWorkout(isWalking: state.isWalking, targetKm: state.targetKm);
  }

  Future<RunSession?> finishWorkout() async {
    _timer?.cancel();
    _warningTimer?.cancel();
    _notificationTimer?.cancel();
    _serviceStateSub?.cancel();
    _serviceLocationSub?.cancel();
    _serviceLoopSub?.cancel();

    // Stop Android Foreground Service
    try {
      final service = FlutterBackgroundService();
      service.invoke('stop_service');
    } catch (e) {
      debugPrint('Error stopping background service: $e');
    }

    final user = ref.read(userProfileProvider).asData?.value;
    final userId = user?.uid ?? 'anonymous';
    final sessionId = const Uuid().v4();

    final pointsEarned = RunningTelemetryCalculator.calculatePointsEarned(
      distanceKm: state.distanceKm,
      targetKm: state.targetKm,
    );

    final session = RunSession(
      id: sessionId,
      userId: userId,
      exerciseType: state.isWalking ? 'WALKING' : 'RUNNING',
      startedAt: DateTime.now().subtract(Duration(seconds: state.elapsedSeconds)),
      endedAt: DateTime.now(),
      distanceKm: state.distanceKm,
      durationSeconds: state.elapsedSeconds,
      caloriesBurned: state.calories,
      avgSpeedKmh: state.avgSpeedKmh,
      avgPaceMinKm: state.pace,
      gpsPath: state.gpsPath,
      territoriesGained: state.territories,
      pointsEarned: pointsEarned,
    );

    state = state.copyWith(
      workoutState: WorkoutState.completed,
      completedSession: session,
    );

    // Save to Firestore & Award Points
    if (userId != 'anonymous') {
      try {
        await ref.read(runningRepositoryProvider).saveRunSession(session);
      } catch (e) {
        debugPrint('Error saving run session to Firestore: $e');
      }
    }

    return session;
  }

  void reset() {
    _timer?.cancel();
    _warningTimer?.cancel();
    _notificationTimer?.cancel();
    _serviceStateSub?.cancel();
    _serviceLocationSub?.cancel();
    _serviceLoopSub?.cancel();

    try {
      final service = FlutterBackgroundService();
      service.invoke('stop_service');
    } catch (_) {}

    state = const RunningState();
    initGps();
  }
}

final runningNotifierProvider =
    NotifierProvider<RunningNotifier, RunningState>(RunningNotifier.new);
