import 'package:flutter/material.dart' show DateUtils;

/// Pure points & streak rules for Flowa — kept free of Firebase so the logic
/// can be unit-tested. Matches the "How points work" rules (screen 17):
///
/// * **Base rate**: `dailyPoints = (completed / total) * 100`.
/// * **Deep work bonus**: +10 for finishing a focus session, +10 for not
///   breaking app blocking — accumulated into [sessionBonus].
/// * **Consistency**: +5 per streak day, capped at +50.
abstract final class GamificationMath {
  GamificationMath._();

  static const double finishedSessionBonusPercent = 0.3;
  static const double unbrokenBlockingBonusPercent = 0.3;
  static const int perStreakDay = 5;
  static const int maxStreakBonus = 50;
  static const double minCompletionPercentForPoints = 0.1;

  /// +5 per streak day, capped at +50.
  static int streakBonus(int streak) =>
      (streak * perStreakDay).clamp(0, maxStreakBonus);

  /// Bonus earned by completing a single session.
  ///
  /// This is proportional to the task's base point value, so short tasks do
  /// not get a larger fixed bonus than longer tasks.
  static int sessionBonus({
    required int taskPoints,
    required bool blockingEngaged,
  }) {
    final baseBonus = (taskPoints * finishedSessionBonusPercent).round();
    final blockBonus = blockingEngaged
        ? (taskPoints * unbrokenBlockingBonusPercent).round()
        : 0;
    return baseBonus + blockBonus;
  }

  /// Total points for a day: base rate + accumulated session bonuses + the
  /// consistency (streak) bonus.
  static int dailyPoints({
    required int completed,
    required int total,
    required int accumulatedSessionBonus,
    required int streak,
  }) {
    final base = total <= 0 ? 0 : ((completed / total) * 100).round();
    return base + accumulatedSessionBonus + streakBonus(streak);
  }

  /// Calculates task completion percentage from either planned duration or
  /// checklist-like subtasks, whichever is available.
  ///
  /// If a task has a planned duration and a real focus session length, we use
  /// the ratio of actual focus minutes to planned duration. If checklist data is
  /// available later, we can swap in the ratio of completed steps over total
  /// steps. For now the function is intentionally pure and testable.
  static double calculateTaskCompletionPercent({
    required int plannedMinutes,
    int? actualMinutes,
    int? completedSteps,
    int? totalSteps,
  }) {
    if (plannedMinutes > 0 && actualMinutes != null) {
      return (actualMinutes / plannedMinutes).clamp(0.0, 1.0);
    }
    if (completedSteps != null && totalSteps != null && totalSteps > 0) {
      return (completedSteps / totalSteps).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  static int proportionalPoints({
    required int basePoints,
    required double completionPercent,
  }) {
    if (completionPercent < minCompletionPercentForPoints) return 0;
    final weighted = basePoints * completionPercent;
    return weighted.round();
  }

  /// The streak after a task is completed on [today].
  ///
  /// +1 for each consecutive day with ≥1 completion; unchanged if today was
  /// already counted; reset to 1 after any missed day.
  static int nextStreak({
    required int current,
    required DateTime? lastActiveDay,
    required DateTime today,
  }) {
    if (lastActiveDay == null) return 1;
    final last = DateUtils.dateOnly(lastActiveDay);
    final t = DateUtils.dateOnly(today);
    if (last == t) return current < 1 ? 1 : current; // already counted today
    final yesterday = t.subtract(const Duration(days: 1));
    if (last == yesterday) return current + 1; // consecutive day
    return 1; // a day was missed → start over (today counts)
  }

  /// Preview helper: estimates the **base** points a task will award when
  /// fully completed with 100 % integrity — i.e. `durationMinutes * 1 pt/min`.
  ///
  /// This intentionally excludes runtime-only bonuses (sessionBonus,
  /// streakBonus) because those depend on dynamic state unknown at
  /// task-creation time. Pass [streak] to also show the streak bonus.
  ///
  /// Formula mirrors [Task.pointsPerMinute] and [proportionalPoints] at 100 %
  /// completion so the value shown is always consistent with actual awarding.
  static int previewPoints({
    required int durationMinutes,
    int streak = 0,
  }) {
    final base = durationMinutes.clamp(1, 600); // pointsPerMinute = 1
    return base + streakBonus(streak);
  }
}
