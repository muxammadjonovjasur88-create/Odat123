/// Pure level rules based on total focus minutes.
class LevelCalculator {
  static const int minutesPerLevelStep = 300;

  static int calculateLevel(int totalFocusMinutes) {
    if (totalFocusMinutes < 0) return 1;

    var level = 1;
    while (true) {
      final nextThreshold = _thresholdForLevel(level + 1);
      if (totalFocusMinutes < nextThreshold) return level;
      level += 1;
    }
  }

  static double levelProgress(int totalFocusMinutes) {
    if (totalFocusMinutes <= 0) return 0.0;

    final level = calculateLevel(totalFocusMinutes);
    final start = _thresholdForLevel(level);
    final end = _thresholdForLevel(level + 1);

    if (end <= start) return 1.0;
    return ((totalFocusMinutes - start) / (end - start)).clamp(0.0, 1.0);
  }

  static int minutesToNextLevel(int totalFocusMinutes) {
    final level = calculateLevel(totalFocusMinutes);
    final nextThreshold = _thresholdForLevel(level + 1);
    return (nextThreshold - totalFocusMinutes).clamp(0, 999999999);
  }

  static int minutesInCurrentLevel(int totalFocusMinutes) {
    final level = calculateLevel(totalFocusMinutes);
    final start = _thresholdForLevel(level);
    return (totalFocusMinutes - start).clamp(0, 999999999);
  }

  static int minutesForCurrentLevelGoal(int totalFocusMinutes) {
    final level = calculateLevel(totalFocusMinutes);
    final start = _thresholdForLevel(level);
    final end = _thresholdForLevel(level + 1);
    return (end - start).clamp(0, 999999999);
  }

  static int _thresholdForLevel(int level) {
    if (level <= 1) return 0;
    final stepCount = level - 1;
    return minutesPerLevelStep * stepCount * (stepCount + 1) ~/ 2;
  }
}
