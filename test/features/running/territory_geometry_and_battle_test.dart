import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/features/running/domain/models/defense_structure.dart';
import 'package:flowa/features/running/domain/models/territory_polygon.dart';
import 'package:flowa/features/running/domain/services/territory_battle_service.dart';
import 'package:flowa/features/running/domain/services/territory_geometry_service.dart';

void main() {
  group('ODAT GPS Runner & Territory Geometry Tests', () {
    const startPoint = GpsPoint(latitude: 41.2995, longitude: 69.2401);

    test('TEST 1: Open route does NOT close loop if far from START point', () {
      const farPoint = GpsPoint(latitude: 41.3050, longitude: 69.2480);
      final isClosed = TerritoryGeometryService.isLoopClosedAtStart(
        startPoint: startPoint,
        currentPoint: farPoint,
        finishRadiusMeters: 25.0,
        minTotalDistanceMeters: 150.0,
        currentDistanceRanMeters: 600.0,
      );

      expect(isClosed, isFalse, reason: 'Far point must not trigger loop closure');
    });

    test('TEST 2: Returning to START within 25m radius closes the loop', () {
      // 10 meters away from start point
      const nearStartPoint = GpsPoint(latitude: 41.29955, longitude: 69.24015);
      final isClosed = TerritoryGeometryService.isLoopClosedAtStart(
        startPoint: startPoint,
        currentPoint: nearStartPoint,
        finishRadiusMeters: 25.0,
        minTotalDistanceMeters: 150.0,
        currentDistanceRanMeters: 800.0,
      );

      expect(isClosed, isTrue, reason: 'Near point with sufficient route must close loop');
    });

    test('TEST 3: Point-in-polygon verification for Defense Tower placement', () {
      // Square polygon around (41.300, 69.240)
      final polygon = [
        const GpsPoint(latitude: 41.2990, longitude: 69.2390),
        const GpsPoint(latitude: 41.3010, longitude: 69.2390),
        const GpsPoint(latitude: 41.3010, longitude: 69.2410),
        const GpsPoint(latitude: 41.2990, longitude: 69.2410),
      ];

      const insidePoint = GpsPoint(latitude: 41.3000, longitude: 69.2400);
      const outsidePoint = GpsPoint(latitude: 41.3050, longitude: 69.2450);

      expect(
        TerritoryGeometryService.isPointInPolygon(insidePoint, polygon),
        isTrue,
        reason: 'Center point must be inside polygon',
      );
      expect(
        TerritoryGeometryService.isPointInPolygon(outsidePoint, polygon),
        isFalse,
        reason: 'Far point must be outside polygon',
      );
    });

    test('TEST 4: Centroid calculation for owner logo placement', () {
      final polygon = [
        const GpsPoint(latitude: 41.2990, longitude: 69.2390),
        const GpsPoint(latitude: 41.3010, longitude: 69.2390),
        const GpsPoint(latitude: 41.3010, longitude: 69.2410),
        const GpsPoint(latitude: 41.2990, longitude: 69.2410),
      ];

      final centroid = TerritoryGeometryService.calculateCentroid(polygon);
      expect(centroid.latitude, closeTo(41.3000, 0.0005));
      expect(centroid.longitude, closeTo(69.2400, 0.0005));
      expect(TerritoryGeometryService.isPointInPolygon(centroid, polygon), isTrue);
    });

    test('TEST 5: Polygon intersection detection for enemy territory collision', () {
      final polyA = [
        const GpsPoint(latitude: 41.2990, longitude: 69.2390),
        const GpsPoint(latitude: 41.3010, longitude: 69.2390),
        const GpsPoint(latitude: 41.3010, longitude: 69.2410),
        const GpsPoint(latitude: 41.2990, longitude: 69.2410),
      ];

      // Overlapping polyB
      final polyB = [
        const GpsPoint(latitude: 41.3000, longitude: 69.2400),
        const GpsPoint(latitude: 41.3020, longitude: 69.2400),
        const GpsPoint(latitude: 41.3020, longitude: 69.2420),
        const GpsPoint(latitude: 41.3000, longitude: 69.2420),
      ];

      // Disjoint polyC
      final polyC = [
        const GpsPoint(latitude: 41.3100, longitude: 69.2500),
        const GpsPoint(latitude: 41.3120, longitude: 69.2500),
        const GpsPoint(latitude: 41.3120, longitude: 69.2520),
        const GpsPoint(latitude: 41.3100, longitude: 69.2520),
      ];

      expect(TerritoryGeometryService.doPolygonsIntersect(polyA, polyB), isTrue);
      expect(TerritoryGeometryService.doPolygonsIntersect(polyA, polyC), isFalse);
    });
  });

  group('ODAT Territory Defense & Battle System Tests', () {
    final territory = TerritoryPolygon(
      id: 'terr-1',
      ownerId: 'defender-1',
      ownerName: 'DefenderPro',
      ownerColor: '#FF0055',
      points: const [
        GpsPoint(latitude: 41.2990, longitude: 69.2390),
        GpsPoint(latitude: 41.3010, longitude: 69.2390),
        GpsPoint(latitude: 41.3010, longitude: 69.2410),
        GpsPoint(latitude: 41.2990, longitude: 69.2410),
      ],
      capturedAt: DateTime.now(),
      areaSqMeters: 1500.0,
    );

    final weakStructures = [
      DefenseStructure(
        id: 'def-1',
        territoryId: 'terr-1',
        ownerId: 'defender-1',
        level: 1,
        latitude: 41.3000,
        longitude: 69.2400,
        hp: 120,
        maxHp: 120,
        attackPower: 25,
        defensePower: 20,
        placedAt: DateTime.now(),
      ),
    ];

    final strongStructures = [
      DefenseStructure(
        id: 'def-1',
        territoryId: 'terr-1',
        ownerId: 'defender-1',
        level: 4,
        latitude: 41.3000,
        longitude: 69.2400,
        hp: 750,
        maxHp: 750,
        attackPower: 200,
        defensePower: 160,
        placedAt: DateTime.now(),
      ),
      DefenseStructure(
        id: 'def-2',
        territoryId: 'terr-1',
        ownerId: 'defender-1',
        level: 3,
        latitude: 41.3002,
        longitude: 69.2402,
        hp: 450,
        maxHp: 450,
        attackPower: 110,
        defensePower: 90,
        placedAt: DateTime.now(),
      ),
    ];

    test('TEST 6: Stronger Attacker defeats weaker Defense -> Attacker Wins', () {
      const attackerPower = 350; // Strong runner

      final battleResult = TerritoryBattleService.resolveBattle(
        attackerPower: attackerPower,
        territory: territory,
        structures: weakStructures,
        attackerName: 'SpeedRunner',
      );

      expect(battleResult.isAttackerWinner, isTrue);
      expect(battleResult.pointsAwarded, greaterThan(100));
      expect(battleResult.summaryMessage, contains('G‘ALABA'));
    });

    test('TEST 7: Strong Defense repels weaker Attacker -> Defender Holds', () {
      const weakAttackerPower = 80;

      final battleResult = TerritoryBattleService.resolveBattle(
        attackerPower: weakAttackerPower,
        territory: territory,
        structures: strongStructures,
        attackerName: 'BeginnerRunner',
      );

      expect(battleResult.isAttackerWinner, isFalse);
      expect(battleResult.summaryMessage, contains('QAYTARILDI'));
    });

    test('TEST 8: Defense Shop tier stats & upgrade pricing', () {
      expect(DefenseShopConfig.tiers.length, 5);
      expect(DefenseShopConfig.getTier(1).costPoints, 300);
      expect(DefenseShopConfig.getTier(2).costPoints, 750);
      expect(DefenseShopConfig.getTier(5).costPoints, 6000);
      expect(DefenseShopConfig.getTier(5).hp, 1200);
    });
  });
}
