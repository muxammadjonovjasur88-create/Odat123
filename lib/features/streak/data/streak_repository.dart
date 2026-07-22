import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_repository.dart';
import '../../../core/services/firebase_providers.dart';
import '../domain/streak_math.dart';

/// Outcome of trying to buy a freeze.
enum BuyFreezeResult { ok, notEnoughPoints, full }

/// Firestore operations for the streak-freeze system: granting the weekly free
/// freeze, resolving missed days, buying freezes, and (debug) simulating time.
class StreakRepository {
  StreakRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  /// The Monday of [d]'s week, as `yyyy-mm-dd` — the weekly-freeze grant key.
  static String weekKey(DateTime d) {
    final date = DateUtils.dateOnly(d);
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return '${monday.year.toString().padLeft(4, '0')}-'
        '${monday.month.toString().padLeft(2, '0')}-'
        '${monday.day.toString().padLeft(2, '0')}';
  }

  /// Grants the weekly free freeze (once per week) and resolves any missed days
  /// (consuming freezes to bridge gaps, or breaking the streak). Idempotent —
  /// safe to call on every app open. Returns the freezes consumed by gaps.
  Future<int> refresh(String uid) {
    final today = DateUtils.dateOnly(DateTime.now());
    final ref = _userDoc(uid);
    return _db.runTransaction<int>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return 0;
      final data = snap.data() ?? const {};

      var freezes = (data['freezes'] as num?)?.toInt() ?? 0;
      final streak = (data['streak'] as num?)?.toInt() ?? 0;
      final lastActive = (data['lastActiveDate'] as Timestamp?)?.toDate();
      final freezeWeek = data['freezeWeek'] as String?;

      final update = <String, dynamic>{};

      // 1. Grant one free freeze on the first refresh of a new week.
      final thisWeek = weekKey(today);
      if (freezeWeek != thisWeek) {
        freezes = math.min(freezes + 1, StreakMath.maxFreezes);
        update['freezeWeek'] = thisWeek;
      }

      // 2. Bridge missed days with freezes, or break the streak.
      final r = StreakMath.resolve(
        streak: streak,
        lastActive: lastActive,
        freezes: freezes,
        today: today,
      );
      freezes = r.freezes;

      update['freezes'] = freezes;
      if (r.broke) {
        update['streak'] = 0;
      } else if (r.lastActive != null && r.lastActive != lastActive) {
        update['lastActiveDate'] = Timestamp.fromDate(r.lastActive!);
      }

      tx.set(ref, update, SetOptions(merge: true));
      return r.freezesUsed;
    });
  }

  /// Spends [StreakMath.freezeCost] lifetime points to bank one freeze.
  Future<BuyFreezeResult> buyFreeze(String uid) {
    final ref = _userDoc(uid);
    return _db.runTransaction<BuyFreezeResult>((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? const {};
      final freezes = (data['freezes'] as num?)?.toInt() ?? 0;
      final points = (data['totalPoints'] as num?)?.toInt() ?? 0;

      if (freezes >= StreakMath.maxFreezes) return BuyFreezeResult.full;
      if (points < StreakMath.freezeCost) return BuyFreezeResult.notEnoughPoints;

      tx.set(ref, {
        'freezes': freezes + 1,
        'totalPoints': points - StreakMath.freezeCost,
      }, SetOptions(merge: true));
      return BuyFreezeResult.ok;
    });
  }

  // ---- Debug helpers (used by the in-app developer panel) ------------------

  /// Sets the streak to [days], anchored to YESTERDAY (today still pending), so
  /// finishing one task today advances it to [days] + 1 — handy for testing the
  /// milestone at [days] + 1.
  Future<void> debugSetStreak(String uid, int days) {
    final yesterday = DateUtils.dateOnly(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    return _userDoc(uid).set({
      'streak': days,
      'longestStreak': days,
      'lastActiveDate': Timestamp.fromDate(yesterday),
    }, SetOptions(merge: true));
  }

  /// Pretends yesterday was missed: backdates the anchor by 2 days so the next
  /// [refresh] consumes a freeze (or breaks the streak if none).
  Future<void> debugSimulateMissedDay(String uid) {
    final twoDaysAgo = DateUtils.dateOnly(
      DateTime.now().subtract(const Duration(days: 2)),
    );
    return _userDoc(uid).set({
      'lastActiveDate': Timestamp.fromDate(twoDaysAgo),
      'freezeWeek': weekKey(DateTime.now()), // don't let the grant mask the test
    }, SetOptions(merge: true));
  }

  Future<void> debugAddFreezes(String uid, int n) => _userDoc(uid).set({
    'freezes': FieldValue.increment(n),
  }, SetOptions(merge: true));

  Future<void> debugClearBadges(String uid) => _userDoc(uid).set({
    'earnedBadges': <int>[],
  }, SetOptions(merge: true));
}

final streakRepositoryProvider = Provider<StreakRepository>(
  (ref) => StreakRepository(ref.watch(firestoreProvider)),
);

/// Runs [StreakRepository.refresh] once per signed-in session (weekly-freeze
/// grant + missed-day resolution). Exposed as a provider so it can be awaited
/// from app start.
final streakRefreshProvider = FutureProvider<void>((ref) async {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return;
  await ref.watch(streakRepositoryProvider).refresh(uid);
});
