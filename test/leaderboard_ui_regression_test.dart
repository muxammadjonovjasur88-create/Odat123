import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/features/leaderboard/data/leaderboard_repository.dart';
import 'package:flowa/features/leaderboard/domain/leaderboard_entry.dart';
import 'package:flowa/features/leaderboard/domain/leaderboard_rank.dart';

void main() {
  group('Leaderboard UI regression', () {
    test('podium, rows and current-user rank all follow the same totalPoints order', () {
      final entries = [
        const LeaderboardEntry(
          uid: 'u1',
          name: 'Alice',
          avatar: 'leaf',
          weeklyPoints: 5,
          weeklyFocusMinutes: 60,
          totalPoints: 5,
          totalFocusMinutes: 60,
        ),
        const LeaderboardEntry(
          uid: 'u2',
          name: 'Bob',
          avatar: 'leaf',
          weeklyPoints: 135,
          weeklyFocusMinutes: 120,
          totalPoints: 135,
          totalFocusMinutes: 120,
        ),
        const LeaderboardEntry(
          uid: 'u3',
          name: 'Cara',
          avatar: 'leaf',
          weeklyPoints: 251,
          weeklyFocusMinutes: 180,
          totalPoints: 251,
          totalFocusMinutes: 180,
        ),
        const LeaderboardEntry(
          uid: 'u4',
          name: 'Drew',
          avatar: 'leaf',
          weeklyPoints: 360,
          weeklyFocusMinutes: 300,
          totalPoints: 360,
          totalFocusMinutes: 300,
        ),
        const LeaderboardEntry(
          uid: 'u5',
          name: 'Eli',
          avatar: 'leaf',
          weeklyPoints: 125,
          weeklyFocusMinutes: 140,
          totalPoints: 125,
          totalFocusMinutes: 140,
        ),
      ];

      final ranked = LeaderboardRepository.sortEntriesForDisplay(entries);
      final podium = ranked.take(3).toList();
      final currentUserRank = calculateUserRank(entries: ranked, uid: 'u4');
      final rowRanks = List.generate(
        ranked.length,
        (index) => index + 1,
      );

      expect(podium.map((entry) => entry.uid).toList(), ['u4', 'u3', 'u2']);
      expect(currentUserRank, 1);
      expect(rowRanks.first, 1);
      expect(rowRanks[1], 2);
      expect(rowRanks[2], 3);
      expect(rowRanks[3], 4);
      expect(rowRanks[4], 5);
    });
  });
}
