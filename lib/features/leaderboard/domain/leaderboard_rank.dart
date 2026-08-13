import '../data/leaderboard_repository.dart';
import 'leaderboard_entry.dart';

/// Returns the 1-based rank for [uid] among leaderboard entries.
int? calculateUserRank({
  required List<LeaderboardEntry> entries,
  required String uid,
}) {
  final sorted = LeaderboardRepository.sortEntriesForDisplay(entries);

  for (var index = 0; index < sorted.length; index++) {
    if (sorted[index].uid == uid) {
      return index + 1;
    }
  }

  return null;
}
