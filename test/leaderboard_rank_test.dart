import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/features/leaderboard/domain/leaderboard_entry.dart';
import 'package:flowa/features/leaderboard/domain/leaderboard_rank.dart';

void main() {
  group('calculateUserRank', () {
    final entries = [
      const LeaderboardEntry(
        uid: 'u1',
        name: 'A',
        avatar: 'leaf',
        weeklyPoints: 0,
        weeklyFocusMinutes: 0,
        totalPoints: 0,
        totalFocusMinutes: 0,
      ),
      const LeaderboardEntry(
        uid: 'u2',
        name: 'B',
        avatar: 'leaf',
        weeklyPoints: 120,
        weeklyFocusMinutes: 60,
        totalPoints: 500,
        totalFocusMinutes: 1000,
      ),
      const LeaderboardEntry(
        uid: 'u3',
        name: 'C',
        avatar: 'leaf',
        weeklyPoints: 80,
        weeklyFocusMinutes: 40,
        totalPoints: 400,
        totalFocusMinutes: 800,
      ),
      const LeaderboardEntry(
        uid: 'u4',
        name: 'D',
        avatar: 'leaf',
        weeklyPoints: 80,
        weeklyFocusMinutes: 30,
        totalPoints: 350,
        totalFocusMinutes: 700,
      ),
    ];

    test('ignores zero-point users and ranks active users only', () {
      expect(calculateUserRank(entries: entries, uid: 'u2'), 1);
      expect(calculateUserRank(entries: entries, uid: 'u3'), 2);
      expect(calculateUserRank(entries: entries, uid: 'u4'), 3);
      expect(calculateUserRank(entries: entries, uid: 'u1'), isNull);
    });
  });
}
