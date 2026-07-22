import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/features/gamification/domain/weekly_reset.dart';

void main() {
  group('weeklyReset', () {
    test('keeps the current week totals flowing in the same week', () {
      expect(
        WeeklyReset.resolveWeeklyPoints(
          currentWeekId: '2026-06-15',
          weekId: '2026-06-15',
          weeklyPoints: 120,
          delta: 25,
        ),
        145,
      );
    });

    test('resets the weekly total when the week changes', () {
      expect(
        WeeklyReset.resolveWeeklyPoints(
          currentWeekId: '2026-06-08',
          weekId: '2026-06-15',
          weeklyPoints: 120,
          delta: 25,
        ),
        25,
      );
    });

    test('keeps the weekly focus minutes aligned with the current week', () {
      expect(
        WeeklyReset.resolveWeeklyFocusMinutes(
          currentWeekId: '2026-06-08',
          weekId: '2026-06-15',
          weeklyFocusMinutes: 90,
          durationMinutes: 35,
        ),
        35,
      );
    });
  });
}
