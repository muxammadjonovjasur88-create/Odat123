import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/features/leaderboard/data/leaderboard_repository.dart';
import 'package:flowa/features/leaderboard/domain/leaderboard_entry.dart';

void main() {
  group('LeaderboardRepository.sortEntriesForDisplay', () {
    test('ranks by total points descending, then focus minutes, then weekly points', () {
      final entries = [
        const LeaderboardEntry(
          uid: 'u1',
          name: 'A',
          avatar: 'leaf',
          weeklyPoints: 80,
          weeklyFocusMinutes: 120,
          monthlyPoints: 80,
          monthlyFocusMinutes: 120,
          totalPoints: 100,
          totalFocusMinutes: 200,
        ),
        const LeaderboardEntry(
          uid: 'u2',
          name: 'B',
          avatar: 'leaf',
          weeklyPoints: 100,
          weeklyFocusMinutes: 50,
          monthlyPoints: 100,
          monthlyFocusMinutes: 50,
          totalPoints: 200,
          totalFocusMinutes: 100,
        ),
        const LeaderboardEntry(
          uid: 'u3',
          name: 'C',
          avatar: 'leaf',
          weeklyPoints: 100,
          weeklyFocusMinutes: 90,
          monthlyPoints: 100,
          monthlyFocusMinutes: 90,
          totalPoints: 150,
          totalFocusMinutes: 180,
        ),
      ];

      final sorted = LeaderboardRepository.sortEntriesForDisplay(entries);

      expect(sorted.map((entry) => entry.uid).toList(), ['u2', 'u3', 'u1']);
    });

    test('handles zero point users and tie-breaking by UID', () {
      final entries = [
        const LeaderboardEntry(
          uid: 'user_z',
          name: 'Zoe',
          avatar: 'leaf',
          weeklyPoints: 0,
          weeklyFocusMinutes: 0,
          monthlyPoints: 0,
          monthlyFocusMinutes: 0,
          totalPoints: 0,
          totalFocusMinutes: 0,
        ),
        const LeaderboardEntry(
          uid: 'user_a',
          name: 'Adam',
          avatar: 'leaf',
          weeklyPoints: 0,
          weeklyFocusMinutes: 0,
          monthlyPoints: 0,
          monthlyFocusMinutes: 0,
          totalPoints: 0,
          totalFocusMinutes: 0,
        ),
        const LeaderboardEntry(
          uid: 'user_p',
          name: 'Paul',
          avatar: 'leaf',
          weeklyPoints: 50,
          weeklyFocusMinutes: 30,
          monthlyPoints: 50,
          monthlyFocusMinutes: 30,
          totalPoints: 50,
          totalFocusMinutes: 30,
        ),
      ];

      final sorted = LeaderboardRepository.sortEntriesForDisplay(entries);

      expect(sorted.map((e) => e.uid).toList(), ['user_p', 'user_a', 'user_z']);
    });
  });

  group('LeaderboardEntry.fromDoc', () {
    test('resets weeklyPoints to 0 when doc currentWeekId is stale', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final docRef = fakeFirestore.collection('users').doc('uid_123');
      await docRef.set({
        'name': 'Test User',
        'avatar': 'leaf',
        'weeklyPoints': 150,
        'weeklyFocusMinutes': 120,
        'totalPoints': 500,
        'totalFocusMinutes': 400,
        'currentWeekId': '2000-01-01',
      });
      final doc = await docRef.get();

      final entry = LeaderboardEntry.fromDoc(doc);

      expect(entry.uid, 'uid_123');
      expect(entry.totalPoints, 500);
      expect(entry.weeklyPoints, 0);
      expect(entry.weeklyFocusMinutes, 0);
      expect(entry.monthlyPoints, 0);
      expect(entry.monthlyFocusMinutes, 0);
    });
  });
}
