import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/core/constants/app_category.dart';
import 'package:flowa/core/models/task.dart';
import 'package:flowa/features/gamification/data/gamification_repository.dart';

void main() {
  group('GamificationRepository', () {
    test('records actual focused minutes instead of planned duration', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = GamificationRepository(firestore);
      final uid = 'user123';
      final now = DateTime.now();
      final today = DateUtils.dateOnly(now);
      final task = Task.draft(
        title: 'Partial task',
        category: AppCategory.study,
        date: today,
        startMinute: 0,
        durationMinutes: 30,
      );

      final result = await repo.recordCompletion(
        uid,
        task: task,
        completedToday: 1,
        totalToday: 1,
        deep: false,
        blockingEngaged: false,
        completionPercent: 0.5,
        awardedPoints: 15,
        fullCompletion: false,
        durationMinutesOverride: 30,
        focusedMinutesOverride: 15,
      );

      expect(result.gained, greaterThan(0));

      final userDoc = await firestore.collection('users').doc(uid).get();
      expect(userDoc.exists, isTrue);
      final userData = userDoc.data()!;
      expect(userData['totalFocusMinutes'], 15);
      expect(userData['weeklyFocusMinutes'], 15);

      final dayId = '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      final dailyDoc = await firestore
          .collection('users')
          .doc(uid)
          .collection('daily')
          .doc(dayId)
          .get();
      expect(dailyDoc.exists, isTrue);
      final dailyData = dailyDoc.data()!;
      expect(dailyData['focusMinutes'], 15);
      expect(dailyData['hours']?['${now.hour}'], 15);
      expect((dailyData['date'] as Timestamp).toDate(), today);
    });

    test('aggregates actual focused minutes across multiple tasks in one day', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = GamificationRepository(firestore);
      final uid = 'user123';
      final now = DateTime.now();
      final today = DateUtils.dateOnly(now);

      final taskA = Task.draft(
        title: 'Task A',
        category: AppCategory.study,
        date: today,
        startMinute: 0,
        durationMinutes: 10,
      );
      final taskB = Task.draft(
        title: 'Task B',
        category: AppCategory.study,
        date: today,
        startMinute: 10,
        durationMinutes: 20,
      );
      final taskC = Task.draft(
        title: 'Task C',
        category: AppCategory.study,
        date: today,
        startMinute: 30,
        durationMinutes: 30,
      );

      await repo.recordCompletion(
        uid,
        task: taskA,
        completedToday: 1,
        totalToday: 1,
        deep: false,
        blockingEngaged: false,
        completionPercent: 1.0,
        awardedPoints: 10,
        fullCompletion: true,
        durationMinutesOverride: 10,
        focusedMinutesOverride: 10,
      );

      await repo.recordCompletion(
        uid,
        task: taskB,
        completedToday: 2,
        totalToday: 2,
        deep: false,
        blockingEngaged: false,
        completionPercent: 1.0,
        awardedPoints: 20,
        fullCompletion: true,
        durationMinutesOverride: 20,
        focusedMinutesOverride: 20,
      );

      await repo.recordCompletion(
        uid,
        task: taskC,
        completedToday: 3,
        totalToday: 3,
        deep: false,
        blockingEngaged: false,
        completionPercent: 0.5,
        awardedPoints: 15,
        fullCompletion: false,
        durationMinutesOverride: 30,
        focusedMinutesOverride: 15,
      );

      final userDoc = await firestore.collection('users').doc(uid).get();
      expect(userDoc.exists, isTrue);
      final userData = userDoc.data()!;
      debugPrint('DEBUG final userData=$userData');
      expect(userData['totalFocusMinutes'], 45);
      expect(userData['weeklyFocusMinutes'], 45);

      final dayId = '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      final dailyDoc = await firestore
          .collection('users')
          .doc(uid)
          .collection('daily')
          .doc(dayId)
          .get();
      expect(dailyDoc.exists, isTrue);
      final dailyData = dailyDoc.data()!;
      debugPrint('DEBUG final dailyData=$dailyData');
      expect(dailyData['focusMinutes'], 45);
      expect(dailyData['hours']?['${now.hour}'], 45);
      expect((dailyData['date'] as Timestamp).toDate(), today);
    });
  });
}
