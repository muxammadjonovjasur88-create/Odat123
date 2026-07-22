import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_repository.dart';
import '../../gamification/data/gamification_repository.dart';
import '../../gamification/domain/daily_stats.dart';

/// Monday (local midnight) of the week containing [d].
DateTime _mondayOf(DateTime d) {
  final day = DateUtils.dateOnly(d);
  return day.subtract(Duration(days: day.weekday - 1));
}

/// Last calendar week's daily stats (the Mon–Sun before this one).
final lastWeekStatsProvider = StreamProvider<List<DailyStats>>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return Stream.value(const []);
  final thisMonday = _mondayOf(DateTime.now());
  final lastMonday = thisMonday.subtract(const Duration(days: 7));
  return ref
      .watch(gamificationRepositoryProvider)
      .watchRange(uid, lastMonday, thisMonday);
});

/// The last 6 weeks of daily stats (this week + 5 prior), for the personal
/// growth chart.
final recentWeeksStatsProvider = StreamProvider<List<DailyStats>>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return Stream.value(const []);
  final thisMonday = _mondayOf(DateTime.now());
  final start = thisMonday.subtract(const Duration(days: 35)); // 5 weeks back
  final end = thisMonday.add(const Duration(days: 7)); // end of this week
  return ref.watch(gamificationRepositoryProvider).watchRange(uid, start, end);
});

/// Total focus minutes across [days].
int weekFocusMinutes(Iterable<DailyStats> days) =>
    days.fold(0, (acc, d) => acc + d.focusMinutes);

/// Focus minutes bucketed into the last [weeks] weeks (oldest → newest), so the
/// final bucket is the current week.
List<int> weeklyFocusBuckets(Iterable<DailyStats> days, {int weeks = 6}) {
  final thisMonday = _mondayOf(DateTime.now());
  final buckets = List<int>.filled(weeks, 0);
  for (final d in days) {
    final wkStart = _mondayOf(d.date);
    final weeksAgo = thisMonday.difference(wkStart).inDays ~/ 7;
    final idx = weeks - 1 - weeksAgo; // newest week is the last bucket
    if (idx >= 0 && idx < weeks) buckets[idx] += d.focusMinutes;
  }
  return buckets;
}

/// Growth in focus minutes this week vs last week, as a signed percentage, or
/// null when last week has nothing to compare against.
int? weeklyGrowthPercent(int thisWeek, int lastWeek) {
  if (lastWeek <= 0) return null;
  return (((thisWeek - lastWeek) / lastWeek) * 100).round();
}

/// Fraction (0..1) of this week's planned tasks completed — drives the
/// "X% of your plan done" goal-progress indicator.
double planProgressFraction(Iterable<DailyStats> week) {
  var completed = 0;
  var total = 0;
  for (final d in week) {
    completed += d.completed;
    total += d.total;
  }
  return total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
}

/// Live "% of this week's plan done".
final planProgressProvider = Provider<double>((ref) {
  final week = ref.watch(weekStatsProvider).asData?.value ?? const [];
  return planProgressFraction(week);
});
