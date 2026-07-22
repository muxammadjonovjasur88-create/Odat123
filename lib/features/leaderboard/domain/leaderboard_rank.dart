import 'leaderboard_entry.dart';

/// Returns the 1-based rank for [uid] among active leaderboard entries.
/// Active means totalPoints > 0; zero-point users do not occupy a rank slot.
int? calculateUserRank({
  required List<LeaderboardEntry> entries,
  required String uid,
}) {
  final activeEntries = entries.where((entry) => entry.totalPoints > 0).toList()
    ..sort((a, b) {
      final totalPointsCompare = b.totalPoints.compareTo(a.totalPoints);
      if (totalPointsCompare != 0) return totalPointsCompare;
      final totalFocusCompare = b.totalFocusMinutes.compareTo(
        a.totalFocusMinutes,
      );
      if (totalFocusCompare != 0) return totalFocusCompare;
      return b.weeklyPoints.compareTo(a.weeklyPoints);
    });

  for (var index = 0; index < activeEntries.length; index++) {
    if (activeEntries[index].uid == uid) {
      return index + 1;
    }
  }

  return null;
}
