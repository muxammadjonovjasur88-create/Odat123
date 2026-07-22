import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../domain/leaderboard_entry.dart';

class LeaderboardRepository {
  LeaderboardRepository(this._db);

  final FirebaseFirestore _db;

  static List<LeaderboardEntry> sortEntriesForDisplay(
    List<LeaderboardEntry> entries,
  ) {
    final sorted = entries.toList()
      ..sort((a, b) {
        final totalPointsCompare = b.totalPoints.compareTo(a.totalPoints);
        if (totalPointsCompare != 0) return totalPointsCompare;
        final totalFocusCompare = b.totalFocusMinutes.compareTo(
          a.totalFocusMinutes,
        );
        if (totalFocusCompare != 0) return totalFocusCompare;
        return b.weeklyPoints.compareTo(a.weeklyPoints);
      });
    return sorted;
  }

  Stream<List<LeaderboardEntry>> watchWeeklyLeaderboard({
    required String weekId,
  }) {
    debugPrint('[leaderboard] subscribing weekId=$weekId');
    return _db
        .collection('users')
        .orderBy('totalPoints', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          debugPrint(
            '[leaderboard] weekId=$weekId docs=${snapshot.docs.length}',
          );
          final entries = snapshot.docs.map(LeaderboardEntry.fromDoc).toList();

          final ranked = sortEntriesForDisplay(entries).take(50).toList();
          debugPrint('[leaderboard] weekId=$weekId entries=${ranked.length}');
          for (final entry in ranked.take(5)) {
            debugPrint(
              '[leaderboard] sample entry uid=${entry.uid} name=${entry.name} totalPts=${entry.totalPoints}',
            );
          }
          return ranked;
        });
  }
}

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>(
  (ref) => LeaderboardRepository(ref.watch(firestoreProvider)),
);
