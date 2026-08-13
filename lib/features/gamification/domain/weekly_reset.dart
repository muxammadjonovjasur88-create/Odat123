/// Helpers for weekly leaderboard and progress reset logic.
class WeeklyReset {
  static String weekIdFor(DateTime date) {
    final monday = DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - 1));
    return '${monday.year.toString().padLeft(4, '0')}-'
        '${monday.month.toString().padLeft(2, '0')}-'
        '${monday.day.toString().padLeft(2, '0')}';
  }

  static int resolveWeeklyPoints({
    required String currentWeekId,
    required String weekId,
    required int weeklyPoints,
    required int delta,
  }) {
    if (currentWeekId != weekId) {
      return delta;
    }
    return weeklyPoints + delta;
  }

  static int resolveWeeklyFocusMinutes({
    required String currentWeekId,
    required String weekId,
    required int weeklyFocusMinutes,
    required int durationMinutes,
  }) {
    if (currentWeekId != weekId) {
      return durationMinutes;
    }
    return weeklyFocusMinutes + durationMinutes;
  }
}

/// Helpers for monthly leaderboard and progress reset logic.
/// Month ID format: "yyyy-MM" (e.g. "2026-08").
class MonthlyReset {
  /// Returns the month ID for [date], e.g. "2026-08".
  static String monthIdFor(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}';

  /// Returns the new monthlyPoints value: resets to [delta] when the month
  /// changed, otherwise accumulates.
  static int resolveMonthlyPoints({
    required String currentMonthId,
    required String monthId,
    required int monthlyPoints,
    required int delta,
  }) {
    if (currentMonthId != monthId) return delta;
    return monthlyPoints + delta;
  }

  /// Returns the new monthlyFocusMinutes value.
  static int resolveMonthlyFocusMinutes({
    required String currentMonthId,
    required String monthId,
    required int monthlyFocusMinutes,
    required int durationMinutes,
  }) {
    if (currentMonthId != monthId) return durationMinutes;
    return monthlyFocusMinutes + durationMinutes;
  }
}
