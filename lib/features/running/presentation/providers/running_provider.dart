import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/user_repository.dart';
import '../../data/running_repository.dart';
import '../../domain/models/defense_structure.dart';
import '../../domain/models/run_session.dart';
import '../../domain/models/territory_battle.dart';
import '../../domain/models/territory_polygon.dart';
import '../../domain/services/anti_cheat_validator.dart';
import '../../domain/services/haversine_calculator.dart';
import '../../domain/services/running_telemetry_calculator.dart';
import '../../domain/services/territory_battle_service.dart';
import '../../domain/services/territory_conquest_service.dart';
import '../../domain/services/territory_geometry_service.dart';

enum WorkoutState { idle, selectingStart, running, paused, loopCompleted, completed }

@immutable
class RunningState {
  const RunningState({
    this.workoutState = WorkoutState.idle,
    this.currentPos,
    this.startPos,
    this.gpsPath = const [],
    this.territories = const [],
    this.defenseStructures = const [],
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
    this.totalAreaSqMeters = 0.0,
    this.isWalking = false,
    this.targetKm = 3.0,
    this.completedSession,
    this.activeMapFilter = 'all', // 'all', 'my_territories', 'nearby_runners', 'under_attack', 'my_defenses'
    this.startFinishRadiusMeters = 25.0,
    this.pendingBattleResult,
    this.pendingTargetTerritory,
    this.isLoopClosed = false,
  });

  final WorkoutState workoutState;
  final GpsPoint? currentPos;
  final GpsPoint? startPos;
  final List<GpsPoint> gpsPath;
  final List<TerritoryPolygon> territories;
  final List<DefenseStructure> defenseStructures;
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
  final double totalAreaSqMeters;
  final bool isWalking;
  final double targetKm;
  final RunSession? completedSession;
  final String activeMapFilter;
  final double startFinishRadiusMeters;
  final BattleResult? pendingBattleResult;
  final TerritoryPolygon? pendingTargetTerritory;
  final bool isLoopClosed;

  /// Distance in meters back to START point
  double? get distanceToStartMeters {
    if (startPos == null || currentPos == null) return null;
    final distKm = HaversineCalculator.calculateDistanceBetweenPoints(
      startPos!,
      currentPos!,
    );
    return distKm * 1000.0;
  }

  /// Whether current position is inside the START finish radius
  bool get isInsideStartRadius {
    final dist = distanceToStartMeters;
    if (dist == null) return false;
    return dist <= startFinishRadiusMeters;
  }

  String get formattedTotalArea =>
      TerritoryConquestService.formatArea(totalAreaSqMeters);

  RunningState copyWith({
    WorkoutState? workoutState,
    GpsPoint? currentPos,
    GpsPoint? startPos,
    List<GpsPoint>? gpsPath,
    List<TerritoryPolygon>? territories,
    List<DefenseStructure>? defenseStructures,
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
    double? totalAreaSqMeters,
    bool? isWalking,
    double? targetKm,
    RunSession? completedSession,
    String? activeMapFilter,
    double? startFinishRadiusMeters,
    BattleResult? pendingBattleResult,
    TerritoryPolygon? pendingTargetTerritory,
    bool? isLoopClosed,
    bool clearGpsError = false,
    bool clearAntiCheatWarning = false,
    bool clearNotification = false,
    bool clearBattle = false,
    bool clearStartPos = false,
  }) {
    return RunningState(
      workoutState: workoutState ?? this.workoutState,
      currentPos: currentPos ?? this.currentPos,
      startPos: clearStartPos ? null : (startPos ?? this.startPos),
      gpsPath: gpsPath ?? this.gpsPath,
      territories: territories ?? this.territories,
      defenseStructures: defenseStructures ?? this.defenseStructures,
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
      totalAreaSqMeters: totalAreaSqMeters ?? this.totalAreaSqMeters,
      isWalking: isWalking ?? this.isWalking,
      targetKm: targetKm ?? this.targetKm,
      completedSession: completedSession ?? this.completedSession,
      activeMapFilter: activeMapFilter ?? this.activeMapFilter,
      startFinishRadiusMeters:
          startFinishRadiusMeters ?? this.startFinishRadiusMeters,
      pendingBattleResult:
          clearBattle ? null : (pendingBattleResult ?? this.pendingBattleResult),
      pendingTargetTerritory: clearBattle
          ? null
          : (pendingTargetTerritory ?? this.pendingTargetTerritory),
      isLoopClosed: isLoopClosed ?? this.isLoopClosed,
    );
  }
}

class RunningNotifier extends Notifier<RunningState> {
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription? _territorySub;
  StreamSubscription? _defenseSub;
  Timer? _timer;
  GpsPoint? _previousPos;
  DateTime? _lastPosTime;
  Timer? _warningTimer;
  Timer? _notificationTimer;
  DateTime? _lastFirestoreUpdate;

  @override
  RunningState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _warningTimer?.cancel();
      _notificationTimer?.cancel();
      _positionSubscription?.cancel();
      _territorySub?.cancel();
      _defenseSub?.cancel();
    });

    _subscribeToPersistentData();
    Future.microtask(initGps);
    return const RunningState();
  }

  void _subscribeToPersistentData() {
    // 1. Stream Global Territories
    _territorySub?.cancel();
    _territorySub = ref
        .read(runningRepositoryProvider)
        .watchAllConqueredTerritories()
        .listen((loadedPolygons) {
      if (loadedPolygons.isEmpty) return;

      // Attach matching defense structures to each territory
      final currentDefenses = state.defenseStructures;
      final updatedList = loadedPolygons.map((poly) {
        final matchingDefenses = currentDefenses
            .where((d) => d.territoryId == poly.id)
            .toList();
        return poly.copyWith(defenseStructures: matchingDefenses);
      }).toList();

      state = state.copyWith(territories: updatedList);
    });

    // 2. Stream Global Defense Structures
    _defenseSub?.cancel();
    _defenseSub = ref
        .read(runningRepositoryProvider)
        .watchAllDefenseStructures()
        .listen((defenses) {
      state = state.copyWith(defenseStructures: defenses);

      // Re-link structures to territories
      if (state.territories.isNotEmpty) {
        final updatedList = state.territories.map((poly) {
          final matchingDefenses =
              defenses.where((d) => d.territoryId == poly.id).toList();
          return poly.copyWith(defenseStructures: matchingDefenses);
        }).toList();
        state = state.copyWith(territories: updatedList);
      }
    });
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

      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          final lastPoint = GpsPoint(
            latitude: lastPos.latitude,
            longitude: lastPos.longitude,
          );
          state = state.copyWith(
            currentPos: lastPoint,
            startPos: state.startPos ?? lastPoint,
          );
        }
      } catch (_) {}

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
          startPos: state.startPos ?? initPoint,
          clearGpsError: true,
        );
      } catch (_) {}

      _startGpsStream();
    } catch (e) {
      state = state.copyWith(gpsError: 'GPS ishga tushirishda xatolik: $e');
    }
  }

  void _startGpsStream() {
    _positionSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPositionUpdate,
      onError: (e) {
        state = state.copyWith(gpsError: 'GPS ulanish uzildi: $e');
      },
    );
  }

  /// Sets the explicit START POINT for the run
  void setStartPoint(GpsPoint point) {
    state = state.copyWith(
      startPos: point,
      workoutState: WorkoutState.idle,
      isLoopClosed: false,
    );
  }

  /// Toggles map filter tab
  void setMapFilter(String filter) {
    state = state.copyWith(activeMapFilter: filter);
  }

  /// Begins workout tracking from the chosen START POINT
  void startRun({bool isWalking = false, double targetKm = 3.0}) {
    final startCoordinate = state.startPos ?? state.currentPos;
    if (startCoordinate == null) {
      state = state.copyWith(gpsError: 'Iltimos, avval START nuqtasini belgilang!');
      return;
    }

    _timer?.cancel();
    _lastPosTime = DateTime.now();
    _previousPos = startCoordinate;

    state = state.copyWith(
      workoutState: WorkoutState.running,
      startPos: startCoordinate,
      isWalking: isWalking,
      targetKm: targetKm,
      elapsedSeconds: 0,
      distanceKm: 0.0,
      calories: 0,
      avgSpeedKmh: 0.0,
      currentSpeedKmh: 0.0,
      gpsPath: [startCoordinate],
      isLoopClosed: false,
      clearBattle: true,
      clearGpsError: true,
    );

    _startForegroundTimer();
    _initBackgroundService();
  }

  void _startForegroundTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.workoutState == WorkoutState.running) {
        final newElapsed = state.elapsedSeconds + 1;
        final now = DateTime.now();
        final lastTime = _lastPosTime ?? now;
        final secondsSinceLastFix = now.difference(lastTime).inSeconds;

        // If stationary for > 3s, drop instantaneous speed to 0.0
        final double currentSpeed = secondsSinceLastFix > 3 ? 0.0 : state.currentSpeedKmh;

        final updatedSpeed = RunningTelemetryCalculator.calculateAverageSpeed(
          distanceKm: state.distanceKm,
          durationSeconds: newElapsed,
        );
        final updatedPace = RunningTelemetryCalculator.formatPace(
          distanceKm: state.distanceKm,
          durationSeconds: newElapsed,
        );
        final updatedCalories = RunningTelemetryCalculator.calculateCalories(
          distanceKm: state.distanceKm,
          isWalking: state.isWalking,
        );

        state = state.copyWith(
          elapsedSeconds: newElapsed,
          avgSpeedKmh: updatedSpeed,
          currentSpeedKmh: currentSpeed,
          pace: updatedPace,
          calories: updatedCalories,
        );

        // Sync persistent foreground notification
        try {
          FlutterBackgroundService().invoke('update_notification', {
            'distanceKm': state.distanceKm,
            'elapsedSeconds': newElapsed,
            'calories': updatedCalories,
            'pace': updatedPace,
            'isPaused': false,
          });
        } catch (_) {}
      }
    });
  }

  Future<void> _initBackgroundService() async {
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      if (!isRunning) {
        await service.startService();
        // Wait briefly for service to fully start before sending first notification
        await Future.delayed(const Duration(milliseconds: 800));
      }
      // Send initial notification immediately after service is ready
      service.invoke('update_notification', {
        'distanceKm': state.distanceKm,
        'elapsedSeconds': state.elapsedSeconds,
        'calories': state.calories,
        'pace': state.pace,
        'isPaused': false,
      });
    } catch (_) {}
  }

  void pauseRun() {
    _timer?.cancel();
    state = state.copyWith(
      workoutState: WorkoutState.paused,
      currentSpeedKmh: 0.0,
    );
    try {
      FlutterBackgroundService().invoke('update_notification', {
        'distanceKm': state.distanceKm,
        'elapsedSeconds': state.elapsedSeconds,
        'calories': state.calories,
        'pace': state.pace,
        'isPaused': true,
      });
    } catch (_) {}
  }

  void resumeRun() {
    _lastPosTime = DateTime.now();
    state = state.copyWith(workoutState: WorkoutState.running);
    _startForegroundTimer();
  }

  void _onPositionUpdate(Position pos) {
    // 1. Filter out very low-accuracy / heavy indoor GPS jitter (> 20.0m accuracy)
    if (pos.accuracy > 20.0) {
      return;
    }

    final newPoint = GpsPoint(
      latitude: pos.latitude,
      longitude: pos.longitude,
      timestamp: DateTime.now(),
    );

    final newHeading = pos.heading >= 0 ? pos.heading : state.heading;

    // When not running, just smoothly update marker position without recording path
    if (state.workoutState != WorkoutState.running) {
      _previousPos = newPoint;
      state = state.copyWith(
        currentPos: newPoint,
        startPos: state.startPos ?? newPoint,
        heading: newHeading,
        currentSpeedKmh: 0.0,
        clearGpsError: true,
      );
      return;
    }

    final now = DateTime.now();
    final lastTime = _lastPosTime ?? now;
    final timeDiffSec = math.max(0.4, now.difference(lastTime).inMilliseconds / 1000.0);

    final lastPoint = _previousPos;
    double deltaKm = 0.0;
    double deltaMeters = 0.0;

    if (lastPoint != null) {
      deltaKm = HaversineCalculator.calculateDistanceBetweenPoints(lastPoint, newPoint);
      deltaMeters = deltaKm * 1000.0;

      // 2. Anti-teleport glitch filter (> 12 m/s / 43 km/h jump)
      final speedMps = deltaMeters / timeDiffSec;
      if (speedMps > 12.0 && deltaMeters > 30.0) {
        _lastPosTime = now;
        _previousPos = newPoint;
        state = state.copyWith(currentPos: newPoint, heading: newHeading);
        return;
      }
    }

    // 3. Stationary Deadband Filter: Ignore jitter movements (< 3.8 meters)
    // This strictly prevents zig-zag lines and fake distance when standing still!
    if (lastPoint != null && deltaMeters < 3.8) {
      state = state.copyWith(
        currentPos: newPoint,
        heading: newHeading,
        clearGpsError: true,
      );
      return;
    }

    // 4. Anti-cheat vehicle speed check (> 28 km/h)
    if (!AntiCheatValidator.isValidSpeed(deltaKm, timeDiffSec)) {
      HapticFeedback.heavyImpact();
      state = state.copyWith(
        currentPos: newPoint,
        heading: newHeading,
        antiCheatWarning:
            '⚠️ MASHINA YOKI SKUTER TEZLIGI ANIQLANDI! (>28 km/soat). Masofa hisoblanmadi.',
      );
      _warningTimer?.cancel();
      _warningTimer = Timer(const Duration(seconds: 4), () {
        state = state.copyWith(clearAntiCheatWarning: true);
      });
      return;
    }

    _lastPosTime = now;
    _previousPos = newPoint;

    // Calculate instantaneous speed in km/h
    double instantSpeedKmh = 0.0;
    if (pos.speed > 0.2) {
      instantSpeedKmh = pos.speed * 3.6;
    } else if (timeDiffSec > 0) {
      instantSpeedKmh = (deltaKm / (timeDiffSec / 3600.0));
    }
    instantSpeedKmh = instantSpeedKmh.clamp(0.0, 25.0);

    // Exponential moving average for smooth display
    final double smoothedSpeed = state.currentSpeedKmh > 0.1
        ? (0.75 * instantSpeedKmh + 0.25 * state.currentSpeedKmh)
        : instantSpeedKmh;

    final updatedDistance = state.distanceKm + deltaKm;
    final updatedPath =
        state.gpsPath.isEmpty ? [newPoint] : [...state.gpsPath, newPoint];

    final updatedCalories = RunningTelemetryCalculator.calculateCalories(
      distanceKm: updatedDistance,
      isWalking: state.isWalking,
    );

    final updatedSpeed = RunningTelemetryCalculator.calculateAverageSpeed(
      distanceKm: updatedDistance,
      durationSeconds: math.max(1, state.elapsedSeconds),
    );

    final updatedPace = RunningTelemetryCalculator.formatPace(
      distanceKm: updatedDistance,
      durationSeconds: math.max(1, state.elapsedSeconds),
    );

    state = state.copyWith(
      currentPos: newPoint,
      heading: newHeading,
      distanceKm: updatedDistance,
      gpsPath: updatedPath,
      calories: updatedCalories,
      avgSpeedKmh: updatedSpeed,
      currentSpeedKmh: double.parse(smoothedSpeed.toStringAsFixed(1)),
      pace: updatedPace,
      clearGpsError: true,
    );

    // Live runner broadcast
    final user = ref.read(userProfileProvider).asData?.value;
    final userName = user?.displayName ?? user?.name ?? 'Siz';
    final userId = user?.uid ?? 'user-1';

    if (user != null) {
      final now = DateTime.now();
      if (_lastFirestoreUpdate == null || now.difference(_lastFirestoreUpdate!).inSeconds >= 4) {
        _lastFirestoreUpdate = now;
        final sampleTrail = updatedPath.length > 80
            ? updatedPath.sublist(updatedPath.length - 80)
            : updatedPath;
        final trailMap = sampleTrail
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList();

        ref.read(runningRepositoryProvider).updateActiveRunnerLocation(
              uid: user.uid,
              userName: userName,
              clanTag: user.clanTag ?? 'SOLO',
              latitude: newPoint.latitude,
              longitude: newPoint.longitude,
              heading: newHeading,
              speedKmh: instantSpeedKmh,
              avatar: user.avatar,
              photoUrl: user.photoUrl,
              photoBase64: user.photoBase64,
              distanceKm: updatedDistance,
              trail: trailMap,
            );
      }
    }

    // ── CLOSED-LOOP REQUIREMENT VERIFICATION ────────────────────────────────
    // Territory is ONLY considered when player returns to original START point!
    final start = state.startPos;
    if (start != null && !state.isLoopClosed && updatedPath.length >= 10 && updatedDistance >= 0.15) {
      final isClosed = TerritoryGeometryService.isLoopClosedAtStart(
        startPoint: start,
        currentPoint: newPoint,
        finishRadiusMeters: state.startFinishRadiusMeters,
        minTotalDistanceMeters: 150.0,
        currentDistanceRanMeters: updatedDistance * 1000.0,
      );

      if (isClosed) {
        _handleClosedLoopCompletion(
          path: updatedPath,
          userId: userId,
          userName: userName,
          userAvatar: user?.avatar,
          clanId: user?.clanId,
          clanName: user?.clanName ?? user?.clanTag,
        );
      }
    }
  }

  /// Handles the completed loop: calculates area, checks for enemy territory intersection (Battle),
  /// or claims new territory.
  void _handleClosedLoopCompletion({
    required List<GpsPoint> path,
    required String userId,
    required String userName,
    String? userAvatar,
    String? clanId,
    String? clanName,
  }) {
    final simplifiedLoop = TerritoryGeometryService.simplifyRoute(path);
    final areaSqMeters =
        TerritoryGeometryService.calculatePolygonAreaSqMeters(simplifiedLoop);

    if (areaSqMeters < 100.0) return; // Ignore microscopic loops (< 100 m²)

    final centroid = TerritoryGeometryService.calculateCentroid(simplifiedLoop);

    // Check if this closed loop intersects any enemy territory
    TerritoryPolygon? targetEnemyTerritory;
    for (final existing in state.territories) {
      if (existing.ownerId != userId) {
        if (TerritoryGeometryService.doPolygonsIntersect(
            simplifiedLoop, existing.points)) {
          targetEnemyTerritory = existing;
          break;
        }
      }
    }

    HapticFeedback.heavyImpact();

    if (targetEnemyTerritory != null) {
      // ⚔️ INITIATE TERRITORY ATTACK BATTLE
      final attackerPower = TerritoryBattleService.calculateAttackerPower(
        distanceKm: state.distanceKm,
        avgSpeedKmh: state.avgSpeedKmh,
        areaSqMeters: areaSqMeters,
      );

      final battleResult = TerritoryBattleService.resolveBattle(
        attackerPower: attackerPower,
        territory: targetEnemyTerritory,
        structures: targetEnemyTerritory.defenseStructures,
        attackerName: userName,
      );

      // Record battle event
      final battleEvent = TerritoryBattleEvent(
        id: const Uuid().v4(),
        territoryId: targetEnemyTerritory.id,
        attackerUid: userId,
        attackerName: userName,
        attackerAvatar: userAvatar,
        defenderUid: targetEnemyTerritory.ownerId,
        defenderName: targetEnemyTerritory.ownerName,
        defenderAvatar: targetEnemyTerritory.ownerAvatar,
        attackerPower: attackerPower,
        defenderPower: battleResult.defenderTotalPower,
        isAttackerWinner: battleResult.isAttackerWinner,
        pointsTransferred: battleResult.pointsAwarded,
        timestamp: DateTime.now(),
        territoryAreaSqMeters: targetEnemyTerritory.areaSqMeters,
        structuresCount: targetEnemyTerritory.defenseStructures.length,
      );

      ref.read(runningRepositoryProvider).recordTerritoryBattle(battleEvent);

      if (battleResult.isAttackerWinner) {
        // Transfer ownership of attacked territory
        ref.read(runningRepositoryProvider).transferTerritoryOwnership(
              territoryId: targetEnemyTerritory.id,
              newOwnerUid: userId,
              newOwnerName: userName,
              newOwnerAvatar: userAvatar,
              clanId: clanId,
              clanTag: clanName,
            );
        ref.read(userRepositoryProvider).awardPoints(userId, battleResult.pointsAwarded);
      }

      // Also register the runner's newly enclosed area as their conquered territory
      final pointsMap = simplifiedLoop
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList();

      ref.read(runningRepositoryProvider).saveConqueredTerritory(
            uid: userId,
            userName: userName,
            clanTag: clanName ?? 'SOLO',
            clanId: clanId,
            clanName: clanName,
            ownerAvatar: userAvatar,
            points: pointsMap,
            areaSqMeters: areaSqMeters,
            centroidLat: centroid.latitude,
            centroidLng: centroid.longitude,
          );

      state = state.copyWith(
        isLoopClosed: true,
        workoutState: WorkoutState.loopCompleted,
        pendingBattleResult: battleResult,
        pendingTargetTerritory: targetEnemyTerritory,
        closedLoopNotification: battleResult.summaryMessage,
      );
    } else {
      // 🏰 CLAIM NEW UNCONTESTED TERRITORY
      final newPolygon = TerritoryPolygon(
        id: 'poly-${DateTime.now().millisecondsSinceEpoch}',
        ownerId: userId,
        ownerName: userName,
        ownerColor: '#5BC8FA',
        points: simplifiedLoop,
        capturedAt: DateTime.now(),
        areaSqMeters: areaSqMeters,
        clanId: clanId,
        clanName: clanName,
        ownerAvatar: userAvatar,
        centroid: centroid,
      );

      final ptsEarned = ((areaSqMeters / 15.0).round() + 50).clamp(50, 800);

      final pointsMap = simplifiedLoop
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList();

      ref.read(runningRepositoryProvider).saveConqueredTerritory(
            uid: userId,
            userName: userName,
            clanTag: clanName ?? 'SOLO',
            clanId: clanId,
            clanName: clanName,
            ownerAvatar: userAvatar,
            points: pointsMap,
            areaSqMeters: areaSqMeters,
            centroidLat: centroid.latitude,
            centroidLng: centroid.longitude,
          );

      ref.read(userRepositoryProvider).awardPoints(userId, ptsEarned);

      final formattedArea = TerritoryConquestService.formatArea(areaSqMeters);
      final newTerritories = [...state.territories, newPolygon];
      final newTotalArea = newTerritories.fold<double>(
        0.0,
        (sum, poly) => sum + poly.areaSqMeters,
      );

      state = state.copyWith(
        isLoopClosed: true,
        workoutState: WorkoutState.loopCompleted,
        territories: newTerritories,
        capturedLoopCount: state.capturedLoopCount + 1,
        totalAreaSqMeters: newTotalArea,
        closedLoopNotification:
            '🎯 LOOP YOPILDI! $formattedArea hudud zabt etildi! (+$ptsEarned PTS) 👑',
      );
    }

    _notificationTimer?.cancel();
    _notificationTimer = Timer(const Duration(seconds: 8), () {
      state = state.copyWith(clearNotification: true);
    });
  }

  /// Places a defense tower inside an owned territory.
  Future<String?> placeDefenseStructure({
    required TerritoryPolygon territory,
    required int level,
    required GpsPoint location,
  }) async {
    final user = ref.read(userProfileProvider).asData?.value;
    if (user == null) return 'Foydalanuvchi tizimga kirmagan.';

    // 1. Verify location is strictly INSIDE the owned territory
    final isInside = TerritoryGeometryService.isPointInPolygon(
      location,
      territory.points,
    );
    if (!isInside) {
      return 'Bu hudud sizga tegishli emas. Minora faqat o‘z hududingiz ichiga joylashtirilishi shart.';
    }

    // 2. Verify defense capacity limit
    final currentCount = state.defenseStructures
        .where((d) => d.territoryId == territory.id)
        .length;
    if (currentCount >= territory.defenseCapacity) {
      return 'Ushbu hududda minoralar sig‘imi to‘lgan (maksimum: ${territory.defenseCapacity} ta).';
    }

    // 3. Verify PTS balance & deduct
    final tier = DefenseShopConfig.getTier(level);
    if (user.totalPoints < tier.costPoints) {
      return 'Ballaringiz yetarli emas! Minora narxi: ${tier.costPoints} PTS (Sizda: ${user.totalPoints} PTS).';
    }

    await ref.read(userRepositoryProvider).deductPoints(user.uid, tier.costPoints);

    final structure = DefenseStructure(
      id: 'def-${const Uuid().v4()}',
      territoryId: territory.id,
      ownerId: user.uid,
      level: level,
      latitude: location.latitude,
      longitude: location.longitude,
      hp: tier.hp,
      maxHp: tier.maxHp,
      attackPower: tier.attackPower,
      defensePower: tier.defensePower,
      placedAt: DateTime.now(),
      name: tier.name,
      icon: tier.icon,
    );

    await ref.read(runningRepositoryProvider).saveDefenseStructure(structure);
    HapticFeedback.mediumImpact();
    return null; // Success
  }

  /// Upgrades an existing defense structure to the next level
  Future<String?> upgradeDefenseStructure(DefenseStructure structure) async {
    final user = ref.read(userProfileProvider).asData?.value;
    if (user == null) return 'Foydalanuvchi tizimga kirmagan.';

    final nextLevel = structure.level + 1;
    if (nextLevel > 5) return 'Ushbu minora allaqachon maksimal darajaga (Lv.5) yetgan.';

    final nextTier = DefenseShopConfig.getTier(nextLevel);
    if (user.totalPoints < nextTier.costPoints) {
      return 'Yangilash uchun ball yetarli emas! Narxi: ${nextTier.costPoints} PTS (Sizda: ${user.totalPoints} PTS).';
    }

    await ref.read(userRepositoryProvider).deductPoints(user.uid, nextTier.costPoints);

    await ref.read(runningRepositoryProvider).upgradeDefenseStructure(
          structureId: structure.id,
          newLevel: nextLevel,
          newHp: nextTier.hp,
          newMaxHp: nextTier.maxHp,
          newAttack: nextTier.attackPower,
          newDefense: nextTier.defensePower,
          name: nextTier.name,
          icon: nextTier.icon,
        );

    HapticFeedback.mediumImpact();
    return null;
  }

  /// Concludes workout session, calculates final PTS, and saves run history
  Future<RunSession> finishRun() async {
    _timer?.cancel();

    try {
      FlutterBackgroundService().invoke('stop_service');
    } catch (_) {}

    final user = ref.read(userProfileProvider).asData?.value;
    final userId = user?.uid ?? 'user-1';

    if (user != null) {
      ref.read(runningRepositoryProvider).removeActiveRunner(user.uid);
    }

    final pointsEarned = RunningTelemetryCalculator.calculatePointsEarned(
      distanceKm: state.distanceKm,
      targetKm: state.targetKm,
    ) + (state.capturedLoopCount * 50);

    final session = RunSession(
      id: const Uuid().v4(),
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
      territoriesGained: state.territories.where((t) => t.ownerId == userId).toList(),
      pointsEarned: pointsEarned,
    );

    await ref.read(runningRepositoryProvider).saveRunSession(session);

    state = state.copyWith(
      workoutState: WorkoutState.completed,
      completedSession: session,
    );

    return session;
  }

  void resetWorkout() {
    _timer?.cancel();

    try {
      FlutterBackgroundService().invoke('stop_service');
    } catch (_) {}

    state = state.copyWith(
      workoutState: WorkoutState.idle,
      distanceKm: 0.0,
      elapsedSeconds: 0,
      calories: 0,
      avgSpeedKmh: 0.0,
      currentSpeedKmh: 0.0,
      gpsPath: [],
      isLoopClosed: false,
      clearBattle: true,
    );
  }
}

final runningNotifierProvider =
    NotifierProvider<RunningNotifier, RunningState>(RunningNotifier.new);
