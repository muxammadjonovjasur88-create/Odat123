import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/features/ai_planner/domain/weekly_analytics.dart';
import 'package:flowa/features/gamification/domain/daily_stats.dart';

void main() {
  group('WeeklyAnalytics — pure calculation unit tests', () {
    test('returns zeros when no daily stats exist (empty list)', () {
      final analytics = WeeklyAnalytics.compute([]);

      expect(analytics.completionPercentage, equals(0));
      expect(analytics.totalCompleted, equals(0));
      expect(analytics.totalTasks, equals(0));
      expect(analytics.rates, equals([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]));
    });

    test('calculates 100% when all planned tasks are completed', () {
      final monday = DateTime(2026, 8, 10);
      final stats = List.generate(
        7,
        (i) => DailyStats(
          date: monday.add(Duration(days: i)),
          completed: 3,
          total: 3,
        ),
      );

      final analytics = WeeklyAnalytics.compute(stats);

      expect(analytics.completionPercentage, equals(100));
      expect(analytics.totalCompleted, equals(21));
      expect(analytics.totalTasks, equals(21));
      expect(analytics.rates, equals([1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]));
    });

    test('calculates partial completion percentage and per-day rates correctly', () {
      final monday = DateTime(2026, 8, 10);
      final stats = [
        DailyStats(date: monday, completed: 2, total: 4), // 50% = 0.5
        DailyStats(date: monday.add(const Duration(days: 1)), completed: 3, total: 3), // 100% = 1.0
        DailyStats(date: monday.add(const Duration(days: 2)), completed: 0, total: 2), // 0% = 0.0
        DailyStats(date: monday.add(const Duration(days: 3)), completed: 1, total: 1), // 100% = 1.0
        DailyStats(date: monday.add(const Duration(days: 4)), completed: 0, total: 0), // 0% = 0.0
        DailyStats(date: monday.add(const Duration(days: 5)), completed: 0, total: 0), // 0% = 0.0
        DailyStats(date: monday.add(const Duration(days: 6)), completed: 0, total: 0), // 0% = 0.0
      ];

      final analytics = WeeklyAnalytics.compute(stats);

      // Total completed = 2+3+0+1 = 6. Total tasks = 4+3+2+1 = 10.
      // Percentage = 6 / 10 = 60%.
      expect(analytics.completionPercentage, equals(60));
      expect(analytics.totalCompleted, equals(6));
      expect(analytics.totalTasks, equals(10));
      expect(
        analytics.rates,
        equals([0.5, 1.0, 0.0, 1.0, 0.0, 0.0, 0.0]),
      );
    });

    test('handles days with completed tasks but 0 total without dividing by zero', () {
      final monday = DateTime(2026, 8, 10);
      final stats = [
        DailyStats(date: monday, completed: 2, total: 0), // fallback 1.0
      ];

      final analytics = WeeklyAnalytics.compute(stats);

      expect(analytics.completionPercentage, equals(100));
      expect(analytics.totalCompleted, equals(2));
      expect(analytics.totalTasks, equals(0));
      expect(analytics.rates[0], equals(1.0));
    });
  });
}
