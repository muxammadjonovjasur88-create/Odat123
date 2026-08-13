import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatting.dart';
import '../../../core/services/firebase_providers.dart';

class WeeklyInsightRepository {
  WeeklyInsightRepository(this._db);

  final FirebaseFirestore _db;

  String _fmtYmd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Returns the insightText for the current week (Monday-based) or null.
  Future<String?> getLatestWeeklyInsight(String uid) async {
    final monday = mondayOf(DateTime.now());
    final weekStartId = _fmtYmd(monday);
    final docId = '${uid}_$weekStartId';
    final snap = await _db.collection('weeklyInsights').doc(docId).get();
    if (!snap.exists) return null;
    final data = snap.data();
    return data == null ? null : (data['insightText'] as String?);
  }
}

final weeklyInsightRepositoryProvider = Provider<WeeklyInsightRepository>(
  (ref) => WeeklyInsightRepository(ref.watch(firestoreProvider)),
);

final weeklyInsightProvider =
    FutureProvider.family<String?, String>((ref, uid) async {
  if (uid.isEmpty) return null;
  return ref.watch(weeklyInsightRepositoryProvider).getLatestWeeklyInsight(uid);
});
