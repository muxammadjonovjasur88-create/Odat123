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

    test('session bonus depends on blocking', () {
      expect(GamificationMath.sessionBonus(blockingEngaged: true), 20);
      expect(GamificationMath.sessionBonus(blockingEngaged: false), 10);
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
