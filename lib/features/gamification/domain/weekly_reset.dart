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
