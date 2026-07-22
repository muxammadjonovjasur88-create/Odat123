import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/task.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/firebase_providers.dart';
import '../../streak/domain/streak_math.dart';
import '../domain/daily_stats.dart';
import '../domain/gamification_math.dart';
import '../domain/weekly_reset.dart';

/// Result of recording a completed focus session. [milestone] is the streak
/// milestone (3/7/30/100) newly reached by this completion, or null.
typedef CompletionResult = ({
  int gained,
  int streak,
  int dailyPoints,
  int? milestone,
  double completionPercent,
  int awardedPoints,
  bool fullCompletion,
});

/// Persists points, streak and daily stats when a focus session is completed,
/// using [GamificationMath] for all the arithmetic.
class GamificationRepository {
  GamificationRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _dailyCol(String uid) =>
      _userDoc(uid).collection('daily');

  static String _dayId(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Records a finished session: recomputes today's points, advances the
  /// streak, and rolls up lifetime totals — all in one transaction.
  Future<CompletionResult> recordCompletion(
    String uid, {
    required Task task,
    required int completedToday,
    required int totalToday,
    required bool deep,
    required bool blockingEngaged,
    required double completionPercent,
    required int awardedPoints,
    required bool fullCompletion,
  }) {
    final today = DateUtils.dateOnly(DateTime.now());
    final userRef = _userDoc(uid);
    final dailyRef = _dailyCol(uid).doc(_dayId(today));

    return _db.runTransaction<CompletionResult>((tx) async {
      final userSnap = await tx.get(userRef);
      final dailySnap = await tx.get(dailyRef);
      final user = userSnap.data() ?? const {};
      final daily = dailySnap.data() ?? const {};

      final oldDailyPoints = (daily['points'] as num?)?.toInt() ?? 0;
      final oldBonus = (daily['bonus'] as num?)?.toInt() ?? 0;
      final oldFocusMin = (daily['focusMinutes'] as num?)?.toInt() ?? 0;
      final oldDeep = (daily['deepSessions'] as num?)?.toInt() ?? 0;

      final currentStreak = (user['streak'] as num?)?.toInt() ?? 0;
      final lastActive = (user['lastActiveDate'] as Timestamp?)?.toDate();
      final freezes = (user['freezes'] as num?)?.toInt() ?? 0;
      final currentWeekId = (user['currentWeekId'] as String?) ?? '';
      final weeklyPoints = (user['weeklyPoints'] as num?)?.toInt() ?? 0;
      final weeklyFocusMinutes =
          (user['weeklyFocusMinutes'] as num?)?.toInt() ?? 0;
      final earnedBadges =
          (user['earnedBadges'] as List?)
              ?.map((e) => (e as num).toInt())
              .toSet() ??
          <int>{};

      // Freeze-aware streak: bridge any missed day with a freeze before
      // counting today.
      final resolution = StreakMath.onCompletion(
        streak: currentStreak,
        lastActive: lastActive,
        freezes: freezes,
        today: today,
      );
      final newStreak = resolution.streak;
      final longest = math.max(
        (user['longestStreak'] as num?)?.toInt() ?? 0,
        newStreak,
      );

      // Milestone: award a badge the first time a threshold is reached.
      final milestone = StreakMath.milestoneFor(newStreak, earnedBadges);

      final newBonus =
          oldBonus +
          GamificationMath.sessionBonus(blockingEngaged: blockingEngaged);
      final newDailyPoints = GamificationMath.dailyPoints(
        completed: completedToday,
        total: totalToday,
        accumulatedSessionBonus: newBonus,
        streak: newStreak,
      );
      final delta = newDailyPoints - oldDailyPoints;

      // Tally focus minutes by completion hour (deep-merged), for the premium
      // "most productive time of day" stat.
      final completionHour = DateTime.now().hour;
      final weekId = WeeklyReset.weekIdFor(today);
      final nextWeeklyPoints = WeeklyReset.resolveWeeklyPoints(
        currentWeekId: currentWeekId,
        weekId: weekId,
        weeklyPoints: weeklyPoints,
        delta: delta,
      );
      final nextWeeklyFocusMinutes = WeeklyReset.resolveWeeklyFocusMinutes(
        currentWeekId: currentWeekId,
        weekId: weekId,
        weeklyFocusMinutes: weeklyFocusMinutes,
        durationMinutes: task.durationMinutes,
      );

      tx.set(dailyRef, {
        'date': Timestamp.fromDate(today),
        'points': newDailyPoints,
        'bonus': newBonus,
        'focusMinutes': oldFocusMin + task.durationMinutes,
        'deepSessions': oldDeep + (deep ? 1 : 0),
        'completed': completedToday,
        'total': totalToday,
        'hours': {
          '$completionHour': FieldValue.increment(task.durationMinutes),
        },
      }, SetOptions(merge: true));

      tx.set(userRef, {
        'streak': newStreak,
        'longestStreak': longest,
        'lastActiveDate': Timestamp.fromDate(today),
        'freezes': resolution.freezes,
        'currentWeekId': weekId,
        'weeklyPoints': nextWeeklyPoints,
        'weeklyFocusMinutes': nextWeeklyFocusMinutes,
        'totalPoints': FieldValue.increment(delta),
        'totalFocusMinutes': FieldValue.increment(task.durationMinutes),
        'totalDeepSessions': FieldValue.increment(deep ? 1 : 0),
        if (milestone != null)
          'earnedBadges': FieldValue.arrayUnion([milestone]),
      }, SetOptions(merge: true));

      debugPrint(
        '[points] tx write → users/$uid: daily(${_dayId(today)}).points='
        '$newDailyPoints, weeklyPoints=$nextWeeklyPoints, '
        'weeklyFocusMinutes=$nextWeeklyFocusMinutes, totalPoints+=$delta',
      );

      return (
        gained: delta,
        streak: newStreak,
        dailyPoints: newDailyPoints,
        milestone: milestone,
        completionPercent: completionPercent,
        awardedPoints: awardedPoints,
        fullCompletion: fullCompletion,
      );
    });
  }

  Stream<DailyStats> watchDay(String uid, DateTime day) {
    final id = _dayId(DateUtils.dateOnly(day));
    return _dailyCol(uid)
        .doc(id)
        .snapshots()
        .map((s) => s.exists ? DailyStats.fromDoc(s) : DailyStats(date: day));
  }

  /// The 7 days of stats from [weekStart] (a Monday).
  Stream<List<DailyStats>> watchWeek(String uid, DateTime weekStart) {
    final start = DateUtils.dateOnly(weekStart);
    final end = start.add(const Duration(days: 7));
    return watchRange(uid, start, end);
  }

  /// Daily stats in the half-open range [start, end) — used by the premium
  /// monthly statistics screen.
  Stream<List<DailyStats>> watchRange(
    String uid,
    DateTime start,
    DateTime end,
  ) {
    final s = DateUtils.dateOnly(start);
    final e = DateUtils.dateOnly(end);
    return _dailyCol(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(s))
        .where('date', isLessThan: Timestamp.fromDate(e))
        .snapshots()
        .map((q) => q.docs.map(DailyStats.fromDoc).toList());
  }
}

final gamificationRepositoryProvider = Provider<GamificationRepository>(
  (ref) => GamificationRepository(ref.watch(firestoreProvider)),
);

final _uidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).asData?.value?.uid,
);

final todayStatsProvider = StreamProvider<DailyStats>((ref) {
  final uid = ref.watch(_uidProvider);
  final today = DateUtils.dateOnly(DateTime.now());
  if (uid == null) return Stream.value(DailyStats(date: today));
  return ref.watch(gamificationRepositoryProvider).watchDay(uid, today);
});

/// This week's daily stats (Mon–Sun), for the activity chart.
final weekStatsProvider = StreamProvider<List<DailyStats>>((ref) {
  final uid = ref.watch(_uidProvider);
  final now = DateTime.now();
  final monday = DateUtils.dateOnly(
    now.subtract(Duration(days: now.weekday - 1)),
  );
  if (uid == null) return Stream.value(const []);
  return ref.watch(gamificationRepositoryProvider).watchWeek(uid, monday);
});
