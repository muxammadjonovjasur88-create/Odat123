import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/uzbekistan_regions.dart';
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
        final weeklyPointsCompare = b.weeklyPoints.compareTo(a.weeklyPoints);
        if (weeklyPointsCompare != 0) return weeklyPointsCompare;
        return a.uid.compareTo(b.uid);
      });
    return sorted;
  }

  /// Watches the global top-100 leaderboard, ordered by totalPoints.
  Stream<List<LeaderboardEntry>> watchGlobalLeaderboard() {
    debugPrint('[leaderboard] subscribing global');
    return _db
        .collection('users')
        .orderBy('totalPoints', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          debugPrint('[leaderboard] global docs=${snapshot.docs.length}');
          final entries = snapshot.docs.map(LeaderboardEntry.fromDoc).toList();
          final ranked = sortEntriesForDisplay(entries).take(50).toList();
          return ranked;
        });
  }

  /// Watches the regional leaderboard for [region], ordered by totalPoints.
  ///
  /// Requires a Firestore composite index on (region ASC, totalPoints DESC).
  /// See firestore.indexes.json.
  Stream<List<LeaderboardEntry>> watchRegionalLeaderboard({
    required UzRegion region,
  }) {
    debugPrint('[leaderboard] subscribing region=${region.firestoreKey}');
    return _db
        .collection('users')
        .where('region', isEqualTo: region.firestoreKey)
        .orderBy('totalPoints', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          debugPrint(
            '[leaderboard] region=${region.firestoreKey} docs=${snapshot.docs.length}',
          );
          final entries = snapshot.docs.map(LeaderboardEntry.fromDoc).toList();
          final ranked = sortEntriesForDisplay(entries).take(50).toList();
          return ranked;
        });
  }

  /// Legacy alias kept for backward compatibility.
  Stream<List<LeaderboardEntry>> watchWeeklyLeaderboard({
    required String weekId,
  }) => watchGlobalLeaderboard();
}

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>(
  (ref) => LeaderboardRepository(ref.watch(firestoreProvider)),
);
