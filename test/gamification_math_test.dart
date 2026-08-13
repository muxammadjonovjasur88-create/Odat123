import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/features/gamification/domain/gamification_math.dart';

void main() {
  group('dailyPoints', () {
    test('base rate is completed/total * 100', () {
      expect(
        GamificationMath.dailyPoints(
          completed: 1,
          total: 2,
          accumulatedSessionBonus: 0,
          streak: 0,
        ),
        50,
      );
    });

    test('adds session bonuses and streak bonus', () {
      // 4/6 = 66.67 -> 67 base, +20 session bonus, +25 streak (5*5)
      expect(
        GamificationMath.dailyPoints(
          completed: 4,
          total: 6,
          accumulatedSessionBonus: 20,
          streak: 5,
        ),
        67 + 20 + 25,
      );
    });

    test('streak bonus is capped at 50', () {
      expect(GamificationMath.streakBonus(20), 50);
      expect(GamificationMath.streakBonus(10), 50);
      expect(GamificationMath.streakBonus(3), 15);
    });

    test('total of 0 yields no base points', () {
      expect(
        GamificationMath.dailyPoints(
          completed: 0,
          total: 0,
          accumulatedSessionBonus: 10,
          streak: 0,
        ),
        10,
      );
    });

    test('session bonus depends on blocking and scales with task points', () {
      expect(
        GamificationMath.sessionBonus(taskPoints: 20, blockingEngaged: true),
        12,
      );
      expect(
        GamificationMath.sessionBonus(taskPoints: 20, blockingEngaged: false),
        6,
      );
    });
    test('short tasks get smaller bonus than longer tasks', () {
      expect(
        GamificationMath.sessionBonus(taskPoints: 5, blockingEngaged: true),
        4,
      );
      expect(
        GamificationMath.sessionBonus(taskPoints: 10, blockingEngaged: true),
        6,
      );
    });

    test('10-minute task should earn at least as many total points as 5-minute task with same conditions', () {
      final fiveMinutePoints = 5;
      final tenMinutePoints = 10;

      final fiveMinuteTotal = fiveMinutePoints +
          GamificationMath.sessionBonus(taskPoints: fiveMinutePoints, blockingEngaged: true);
      final tenMinuteTotal = tenMinutePoints +
          GamificationMath.sessionBonus(taskPoints: tenMinutePoints, blockingEngaged: true);

      expect(tenMinuteTotal, greaterThan(fiveMinuteTotal));
    });

    test('gained total with blocking: 5m should be less than 10m', () {
      final fiveMinuteTotal = 5 +
          GamificationMath.sessionBonus(taskPoints: 5, blockingEngaged: true);
      final tenMinuteTotal = 10 +
          GamificationMath.sessionBonus(taskPoints: 10, blockingEngaged: true);

      expect(fiveMinuteTotal, 9);
      expect(tenMinuteTotal, 16);
      expect(tenMinuteTotal, greaterThan(fiveMinuteTotal));
    });

    test('gained total without blocking: 5m should be less than 10m', () {
      final fiveMinuteTotal = 5 +
          GamificationMath.sessionBonus(taskPoints: 5, blockingEngaged: false);
      final tenMinuteTotal = 10 +
          GamificationMath.sessionBonus(taskPoints: 10, blockingEngaged: false);

      expect(fiveMinuteTotal, 7);
      expect(tenMinuteTotal, 13);
      expect(tenMinuteTotal, greaterThan(fiveMinuteTotal));
    });

    test('full duration score matrix is monotonic and matches expected values', () {
      final durations = [1, 5, 10, 15, 25, 30, 45, 60, 90, 120, 180, 240, 300, 480];
      final expectedNoBlocking = {
        1: 1,
        5: 7,
        10: 13,
        15: 20,
        25: 33,
        30: 39,
        45: 59,
        60: 78,
        90: 117,
        120: 156,
        180: 234,
        240: 312,
        300: 390,
        480: 624,
      };
      final expectedBlocking = {
        1: 1,
        5: 9,
        10: 16,
        15: 25,
        25: 41,
        30: 48,
        45: 73,
        60: 96,
        90: 144,
        120: 192,
        180: 288,
        240: 384,
        300: 480,
        480: 768,
      };

      int previousNoBlocking = 0;
      int previousBlocking = 0;
      for (final duration in durations) {
        final noBlocking = duration +
            GamificationMath.sessionBonus(taskPoints: duration, blockingEngaged: false);
        final blocking = duration +
            GamificationMath.sessionBonus(taskPoints: duration, blockingEngaged: true);

        expect(noBlocking, expectedNoBlocking[duration]);
        expect(blocking, expectedBlocking[duration]);
        expect(noBlocking, greaterThanOrEqualTo(previousNoBlocking));
        expect(blocking, greaterThanOrEqualTo(previousBlocking));

        previousNoBlocking = noBlocking;
        previousBlocking = blocking;
      }
    });
  });

  group('completion percent', () {
    test('uses planned duration ratio when actual minutes exist', () {
      expect(
        GamificationMath.calculateTaskCompletionPercent(
          plannedMinutes: 120,
          actualMinutes: 60,
        ),
        0.5,
      );
    });

    test('caps completion percent to 1.0', () {
      expect(
        GamificationMath.calculateTaskCompletionPercent(
          plannedMinutes: 60,
          actualMinutes: 180,
        ),
        1.0,
      );
    });

    test('awards proportional points for partial completion', () {
      expect(
        GamificationMath.proportionalPoints(
          basePoints: 20,
          completionPercent: 0.5,
        ),
        10,
      );
    });

    test('returns zero points for tiny completion', () {
      expect(
        GamificationMath.proportionalPoints(
          basePoints: 20,
          completionPercent: 0.05,
        ),
        0,
      );
    });
  });

  group('nextStreak', () {
    final today = DateTime(2026, 6, 18);

    test('first ever completion starts at 1', () {
      expect(
        GamificationMath.nextStreak(
          current: 0,
          lastActiveDay: null,
          today: today,
        ),
        1,
      );
    });

    test('same-day completion does not change streak', () {
      expect(
        GamificationMath.nextStreak(
          current: 4,
          lastActiveDay: DateTime(2026, 6, 18, 9),
          today: today,
        ),
        4,
      );
    });

    test('consecutive day increments', () {
      expect(
        GamificationMath.nextStreak(
          current: 4,
          lastActiveDay: DateTime(2026, 6, 17),
          today: today,
        ),
        5,
      );
    });

    test('missed day resets to 1', () {
      expect(
        GamificationMath.nextStreak(
          current: 9,
          lastActiveDay: DateTime(2026, 6, 15),
          today: today,
        ),
        1,
      );
    });
  });
}
