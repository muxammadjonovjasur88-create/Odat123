import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_repository.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../core/services/user_repository.dart';
import '../../gamification/data/gamification_repository.dart';
import '../../gamification/domain/daily_stats.dart';
import '../domain/premium.dart';

/// The master Premium switch as a provider, so widgets/providers react to it and
/// it can later be swapped for a remote-config value without touching callers.
final premiumEnabledProvider = Provider<bool>((ref) => kPremiumEnabled);

/// The signed-in user's raw Premium status (false until the paywall flips it).
final isPremiumProvider = Provider<bool>(
  (ref) => ref.watch(userProfileProvider).asData?.value?.isPremium ?? false,
);

// ---------------------------------------------------------------------------
// AI-plan daily usage (the free limit).
// ---------------------------------------------------------------------------

/// Counts AI plans generated per day at `users/{uid}/usage/{yyyy-MM-dd}`.
class AiUsageRepository {
  AiUsageRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid, String dayId) =>
      _db.collection('users').doc(uid).collection('usage').doc(dayId);

  static String dayId(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Live count of AI plans generated today.
  Stream<int> watchToday(String uid) => _doc(
    uid,
    dayId(DateTime.now()),
  ).snapshots().map((s) => (s.data()?['aiPlans'] as num?)?.toInt() ?? 0);

  /// Records one more AI plan generated today.
  Future<void> incrementToday(String uid) {
    final today = DateUtils.dateOnly(DateTime.now());
    return _doc(uid, dayId(today)).set({
      'date': Timestamp.fromDate(today),
      'aiPlans': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }
}

final aiUsageRepositoryProvider = Provider<AiUsageRepository>(
  (ref) => AiUsageRepository(ref.watch(firestoreProvider)),
);

/// How many AI plans the user has generated today (live).
final aiPlansTodayProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return Stream.value(0);
  return ref.watch(aiUsageRepositoryProvider).watchToday(uid);
});

/// Free AI plans remaining today (clamped 0..limit). Only meaningful for free
/// users while the system is enabled.
final aiPlansRemainingProvider = Provider<int>((ref) {
  final used = ref.watch(aiPlansTodayProvider).asData?.value ?? 0;
  return (kFreeAiPlansPerDay - used).clamp(0, kFreeAiPlansPerDay);
});

/// Whether the user may generate another AI plan right now. Always true when the
/// premium system is off or the user is premium; otherwise gated by the daily
/// free limit.
final canGenerateAiProvider = Provider<bool>((ref) {
  if (!ref.watch(premiumEnabledProvider)) return true;
  if (ref.watch(isPremiumProvider)) return true;
  final used = ref.watch(aiPlansTodayProvider).asData?.value ?? 0;
  return used < kFreeAiPlansPerDay;
});

// ---------------------------------------------------------------------------
// Monthly statistics (premium screen).
// ---------------------------------------------------------------------------

DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

/// This calendar month's daily stats (1st → today).
final thisMonthStatsProvider = StreamProvider<List<DailyStats>>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return Stream.value(const []);
  final now = DateTime.now();
  final start = _firstOfMonth(now);
  final end = DateTime(now.year, now.month + 1, 1); // exclusive
  return ref.watch(gamificationRepositoryProvider).watchRange(uid, start, end);
});

/// Last calendar month's daily stats — for the growth-vs-last-month figure.
final lastMonthStatsProvider = StreamProvider<List<DailyStats>>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return Stream.value(const []);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month - 1, 1);
  final end = _firstOfMonth(now); // exclusive
  return ref.watch(gamificationRepositoryProvider).watchRange(uid, start, end);
});

/// Total focus minutes across [days].
int totalFocusMinutes(Iterable<DailyStats> days) =>
    days.fold(0, (acc, d) => acc + d.focusMinutes);

/// A human label for the user's most productive time of day across [days], or
/// null when there isn't enough data yet.
String? mostProductiveLabel(Iterable<DailyStats> days) {
  final byHour = <int, int>{};
  for (final d in days) {
    d.hours.forEach((h, m) => byHour[h] = (byHour[h] ?? 0) + m);
  }
  if (byHour.isEmpty) return null;
  final peak = byHour.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  // Returns a translation KEY (resolved with `.tr()` at the call site).
  if (peak >= 5 && peak < 12) return 'premium.productive_mornings';
  if (peak >= 12 && peak < 17) return 'premium.productive_afternoons';
  if (peak >= 17 && peak < 22) return 'premium.productive_evenings';
  return 'premium.productive_nights';
}

/// Growth in focus minutes this month vs last month, as a signed percentage.
/// Null when last month has no data to compare against.
int? growthPercent(int thisMonth, int lastMonth) {
  if (lastMonth <= 0) return null;
  return (((thisMonth - lastMonth) / lastMonth) * 100).round();
}
