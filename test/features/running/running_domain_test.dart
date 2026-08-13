import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/features/running/domain/models/territory_polygon.dart';
import 'package:flowa/features/running/domain/services/anti_cheat_validator.dart';
import 'package:flowa/features/running/domain/services/haversine_calculator.dart';
import 'package:flowa/features/running/domain/services/running_telemetry_calculator.dart';
import 'package:flowa/features/running/domain/services/territory_conquest_service.dart';

void main() {
  group('HaversineCalculator Tests', () {
    test('Calculates distance between Tashkent Amir Timur square & Chorsu Market correctly (~3.5km)', () {
      const lat1 = 41.3111; // Amir Timur Square
      const lon1 = 69.2797;
      const lat2 = 41.3275; // Chorsu Market
      const lon2 = 69.2401;

      final dist = HaversineCalculator.calculateDistance(lat1, lon1, lat2, lon2);
      expect(dist, greaterThan(3.0));
      expect(dist, lessThan(4.5));
    });

    test('Zero distance for identical points', () {
      final dist = HaversineCalculator.calculateDistance(41.2995, 69.2401, 41.2995, 69.2401);
      expect(dist, equals(0.0));
    });
  });

  group('AntiCheatValidator Tests', () {
    test('Validates normal running speed (10 km/h)', () {
      const deltaKm = 0.5; // 500 meters
      const timeDiffSec = 180.0; // 3 minutes -> 10 km/h

      final isValid = AntiCheatValidator.isValidSpeed(deltaKm, timeDiffSec);
      expect(isValid, isTrue);
    });

    test('Rejects high speed vehicle / fake GPS (60 km/h)', () {
      const deltaKm = 1.0; // 1 km
      const timeDiffSec = 60.0; // 1 minute -> 60 km/h

      final isValid = AntiCheatValidator.isValidSpeed(deltaKm, timeDiffSec);
      expect(isValid, isFalse);
    });

    test('Accepts stationary GPS jitter (< 4 meters)', () {
      const deltaKm = 0.002; // 2 meters jitter
      const timeDiffSec = 1.0;

      final isValid = AntiCheatValidator.isValidSpeed(deltaKm, timeDiffSec);
      expect(isValid, isTrue);
      expect(AntiCheatValidator.isSignificantMovement(deltaKm), isFalse);
    });
  });

  group('TerritoryConquestService Tests', () {
    test('Does not trigger loop if path has fewer than 5 points', () {
      final List<GpsPoint> path = [
        const GpsPoint(latitude: 41.2995, longitude: 69.2401),
        const GpsPoint(latitude: 41.3000, longitude: 69.2405),
        const GpsPoint(latitude: 41.3005, longitude: 69.2410),
        const GpsPoint(latitude: 41.2995, longitude: 69.2401),
      ];

      final polygon = TerritoryConquestService.detectClosedLoop(
        path: path,
        ownerId: 'user1',
        ownerName: 'Ali',
      );

      expect(polygon, isNull);
    });

    test('Detects closed loop when returning to start point within 30 meters', () {
      final List<GpsPoint> path = [
        const GpsPoint(latitude: 41.2995, longitude: 69.2401), // Start
        const GpsPoint(latitude: 41.3005, longitude: 69.2405),
        const GpsPoint(latitude: 41.3010, longitude: 69.2415),
        const GpsPoint(latitude: 41.3000, longitude: 69.2420),
        const GpsPoint(latitude: 41.2996, longitude: 69.2402), // Return within ~15m
      ];

      final polygon = TerritoryConquestService.detectClosedLoop(
        path: path,
        ownerId: 'user1',
        ownerName: 'Ali',
        ownerColor: '#00F3FF',
      );

      expect(polygon, isNotNull);
      expect(polygon!.ownerId, equals('user1'));
      expect(polygon.points.length, equals(5));
    });

    test('Does not detect loop if end point is far from start point (> 30 meters)', () {
      final List<GpsPoint> path = [
        const GpsPoint(latitude: 41.2995, longitude: 69.2401),
        const GpsPoint(latitude: 41.3005, longitude: 69.2405),
        const GpsPoint(latitude: 41.3010, longitude: 69.2415),
        const GpsPoint(latitude: 41.3020, longitude: 69.2425),
        const GpsPoint(latitude: 41.3030, longitude: 69.2435),
      ];

      final polygon = TerritoryConquestService.detectClosedLoop(
        path: path,
        ownerId: 'user1',
        ownerName: 'Ali',
      );

      expect(polygon, isNull);
    });
  });

  group('RunningTelemetryCalculator Tests', () {
    test('Calculates running calories correctly (65 kcal/km)', () {
      final kcal = RunningTelemetryCalculator.calculateCalories(distanceKm: 3.0, isWalking: false);
      expect(kcal, equals(195));
    });

    test('Calculates walking calories correctly (45 kcal/km)', () {
      final kcal = RunningTelemetryCalculator.calculateCalories(distanceKm: 3.0, isWalking: true);
      expect(kcal, equals(135));
    });

    test('Formats pace correctly', () {
      // 1 km in 330 seconds (5 min 30 sec) -> 5'30"
      final pace = RunningTelemetryCalculator.formatPace(distanceKm: 1.0, durationSeconds: 330);
      expect(pace, equals("5'30\""));
    });

    test('Formats duration correctly', () {
      expect(RunningTelemetryCalculator.formatDuration(330), equals('05:30'));
      expect(RunningTelemetryCalculator.formatDuration(3665), equals('01:01:05'));
    });

    test('Calculates points earned with daily quest completion bonus', () {
      final pointsIncomplete = RunningTelemetryCalculator.calculatePointsEarned(distanceKm: 2.0, targetKm: 3.0);
      expect(pointsIncomplete, equals(60)); // 2 * 30

      final pointsCompleted = RunningTelemetryCalculator.calculatePointsEarned(distanceKm: 3.2, targetKm: 3.0);
      expect(pointsCompleted, equals(96 + 100)); // 3.2*30 + 100 bonus = 196
    });
  });
}
