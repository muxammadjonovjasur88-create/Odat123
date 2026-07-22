import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/features/leaderboard/data/leaderboard_repository.dart';
import 'package:flowa/features/leaderboard/domain/leaderboard_entry.dart';

void main() {
  group('LeaderboardRepository.sortEntriesForDisplay', () {
    test('ranks by weekly points descending for weekly leaderboard', () {
      final entries = [
        const LeaderboardEntry(
          uid: 'u1',
          name: 'A',
          avatar: 'leaf',
          weeklyPoints: 80,
          weeklyFocusMinutes: 120,
          totalPoints: 100,
          totalFocusMinutes: 200,
        ),
        const LeaderboardEntry(
          uid: 'u2',
          name: 'B',
          avatar: 'leaf',
          weeklyPoints: 100,
          weeklyFocusMinutes: 50,
          totalPoints: 200,
          totalFocusMinutes: 100,
        ),
        const LeaderboardEntry(
          uid: 'u3',
          name: 'C',
          avatar: 'leaf',
          weeklyPoints: 100,
          weeklyFocusMinutes: 90,
          totalPoints: 150,
          totalFocusMinutes: 180,
        ),
      ];

      final sorted = LeaderboardRepository.sortEntriesForDisplay(entries);

      expect(sorted.map((entry) => entry.uid).toList(), ['u3', 'u2', 'u1']);
    });
  });
}
