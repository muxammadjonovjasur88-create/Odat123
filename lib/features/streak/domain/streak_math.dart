import 'package:flutter/material.dart' show DateUtils;

/// The result of resolving / advancing a streak: the new streak count, the new
/// anchor date (last day the streak is considered "kept alive"), the remaining
/// freezes, how many freezes were spent, and whether the streak broke.
class StreakResolution {
  const StreakResolution({
    required this.streak,
    required this.lastActive,
    required this.freezes,
    required this.freezesUsed,
    required this.broke,
  });

  final int streak;
  final DateTime? lastActive;
  final int freezes;
  final int freezesUsed;
  final bool broke;
}

/// Pure, Firebase-free streak rules — freeze handling + milestones — kept
/// testable in isolation.
///
/// A day counts toward the streak if ≥1 task was completed. Missing a day
/// consumes one freeze (if available) to bridge the gap; otherwise the streak
/// resets. The "anchor" ([UserProfile.lastActiveDate]) advances as freezes
/// bridge gaps, so resolution is idempotent within a day.
abstract final class StreakMath {
  StreakMath._();

  /// Consecutive-day milestones that award a badge + celebration.
  static const List<int> milestones = [3, 7, 30, 100];

  /// Most freezes a user can bank at once.
  static const int maxFreezes = 7;

  /// Point cost to buy one freeze.
  static const int freezeCost = 150;

  /// Whole days from [a] to [b] (date-only).
  static int dayGap(DateTime a, DateTime b) =>
      DateUtils.dateOnly(b).difference(DateUtils.dateOnly(a)).inDays;

  /// Passively resolves the streak as of [today] WITHOUT a completion: bridges
  /// any fully-missed days with freezes, or breaks the streak if there aren't
  /// enough. The streak count itself never increases here (no task was done).
  static StreakResolution resolve({
    required int streak,
    required DateTime? lastActive,
    required int freezes,
    required DateTime today,
  }) {
    if (lastActive == null || streak <= 0) {
      return StreakResolution(
        streak: streak <= 0 ? 0 : streak,
        lastActive: lastActive,
        freezes: freezes,
        freezesUsed: 0,
        broke: false,
      );
    }
    final last = DateUtils.dateOnly(lastActive);
    final t = DateUtils.dateOnly(today);
    final gap = t.difference(last).inDays;

    // Active today (0) or yesterday (1): the streak is still alive — today is
    // simply not completed yet.
    if (gap <= 1) {
      return StreakResolution(
        streak: streak,
        lastActive: last,
        freezes: freezes,
        freezesUsed: 0,
        broke: false,
      );
    }

    final missed = gap - 1; // fully-missed days strictly between last and today
    if (freezes >= missed) {
      return StreakResolution(
        streak: streak,
        lastActive: t.subtract(const Duration(days: 1)), // bridged to yesterday
        freezes: freezes - missed,
        freezesUsed: missed,
        broke: false,
      );
    }
    return StreakResolution(
      streak: 0,
      lastActive: last,
      freezes: freezes,
      freezesUsed: 0,
      broke: true,
    );
  }

  /// The streak after completing a task on [today], freeze-aware: bridges gaps
  /// first, then counts today.
  static StreakResolution onCompletion({
    required int streak,
    required DateTime? lastActive,
    required int freezes,
    required DateTime today,
  }) {
    final r = resolve(
      streak: streak,
      lastActive: lastActive,
      freezes: freezes,
      today: today,
    );
    final t = DateUtils.dateOnly(today);
    final last = r.lastActive == null ? null : DateUtils.dateOnly(r.lastActive!);

    int newStreak;
    if (last == null) {
      newStreak = 1;
    } else if (last == t) {
      newStreak = r.streak < 1 ? 1 : r.streak; // already counted today
    } else if (last == t.subtract(const Duration(days: 1))) {
      newStreak = r.streak + 1; // consecutive (or freeze-bridged) day
    } else {
      newStreak = 1; // streak had broken → today starts a new one
    }
    return StreakResolution(
      streak: newStreak,
      lastActive: t,
      freezes: r.freezes,
      freezesUsed: r.freezesUsed,
      broke: r.broke,
    );
  }

  /// The highest milestone newly reached at [streak] that isn't already in
  /// [earned], or null. Handles jumps (e.g. debug) by taking the highest.
  static int? milestoneFor(int streak, Set<int> earned) {
    int? hit;
    for (final m in milestones) {
      if (streak >= m && !earned.contains(m)) hit = m;
    }
    return hit;
  }
}
