import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_category.dart';
import '../../../../core/models/task.dart';
import '../../../../core/services/auth_repository.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../../../core/services/task_repository.dart';
import '../../../reminders/domain/models/reminder.dart';
import '../../../reminders/presentation/providers/reminders_provider.dart';
import '../../domain/family_goal_models.dart';

final familyGoalsProvider = NotifierProvider<FamilyGoalsNotifier, List<FamilyGoal>>(() {
  return FamilyGoalsNotifier();
});

class FamilyGoalsNotifier extends Notifier<List<FamilyGoal>> {
  @override
  List<FamilyGoal> build() {
    _listenToGoals();
    return [];
  }

  /// Stream goals from Firestore so they persist across restarts.
  void _listenToGoals() {
    final uid = ref.watch(authStateProvider).asData?.value?.uid;
    if (uid == null) return;
    final db = ref.read(firestoreProvider);

    db
        .collection('users')
        .doc(uid)
        .collection('family_goals')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      final goals = snap.docs.map((doc) {
        final d = doc.data();
        return FamilyGoal(
          id: doc.id,
          parentId: d['parentId'] as String? ?? uid,
          parentName: d['parentName'] as String? ?? 'Ota-ona',
          childId: d['childId'] as String? ?? '',
          title: d['title'] as String? ?? '',
          category: FamilyGoalCategory.values.firstWhere(
            (c) => c.name == (d['category'] as String?),
            orElse: () => FamilyGoalCategory.study,
          ),
          scheduledTime: d['scheduledTime'] as String? ?? '20:00',
          targetValue: (d['targetValue'] as num?)?.toInt() ?? 0,
          unit: d['unit'] as String? ?? '',
          rewardCoins: (d['rewardCoins'] as num?)?.toInt() ?? 0,
          status: FamilyGoalStatus.values.firstWhere(
            (s) => s.name == (d['status'] as String?),
            orElse: () => FamilyGoalStatus.pending,
          ),
          currentProgress: (d['currentProgress'] as num?)?.toInt() ?? 0,
          isAutoVerified: (d['isAutoVerified'] as bool?) ?? false,
          createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
          respondedAt: (d['respondedAt'] as Timestamp?)?.toDate(),
          completedAt: (d['completedAt'] as Timestamp?)?.toDate(),
        );
      }).toList();
      state = goals;
    });
  }

  /// Parent creates a new goal for child — saves to Firestore and adds to child's tasks & inbox
  Future<void> createGoal({
    required String title,
    required FamilyGoalCategory category,
    required String scheduledTime,
    required int targetValue,
    required String unit,
    required int rewardCoins,
  }) async {
    final uid = ref.read(authStateProvider).asData?.value?.uid ?? 'parent_local';
    final db = ref.read(firestoreProvider);

    String? childUid;
    String parentName = 'Ota-ona';

    try {
      final parentDoc = await db.collection('users').doc(uid).get().timeout(const Duration(seconds: 4));
      if (parentDoc.exists) {
        final data = parentDoc.data() ?? {};
        childUid = data['childUid'] as String?;
        if (childUid == null || childUid.isEmpty) {
          final list = data['connectedChildren'] as List?;
          childUid = list?.isNotEmpty == true ? list!.first as String? : null;
        }
        parentName = (data['displayName'] as String?) ?? (data['name'] as String?) ?? 'Ota-ona';
      }
    } catch (_) {}

    final goalId = 'fg_${DateTime.now().millisecondsSinceEpoch}';

    final goalData = {
      'parentId': uid,
      'parentName': parentName,
      'childId': childUid ?? '',
      'title': title,
      'category': category.name,
      'scheduledTime': scheduledTime,
      'targetValue': targetValue,
      'unit': unit,
      'rewardCoins': rewardCoins,
      'status': FamilyGoalStatus.pending.name,
      'currentProgress': 0,
      'isAutoVerified': false,
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Save to parent's Firestore goals collection
    await db.collection('users').doc(uid).collection('family_goals').doc(goalId).set(goalData);

    if (childUid != null && childUid.isNotEmpty) {
      try {
        final timeParts = scheduledTime.split(':');
        final hour = int.tryParse(timeParts[0]) ?? 18;
        final min = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
        final startMinute = hour * 60 + min;

        AppCategory appCat = AppCategory.study;
        if (category == FamilyGoalCategory.running || category == FamilyGoalCategory.workout) {
          appCat = AppCategory.sport;
        } else if (category == FamilyGoalCategory.habit) {
          appCat = AppCategory.personal;
        }

        // 1. Add to child's task list
        final task = Task(
          id: goalId,
          title: title,
          category: appCat,
          date: DateUtils.dateOnly(DateTime.now()),
          startMinute: startMinute,
          durationMinutes: targetValue > 0 ? targetValue : 30,
          points: rewardCoins * 15,
          note: 'Ota-onangizdan yangi maqsad (+$rewardCoins Fenix Coin)',
        );
        await ref.read(taskRepositoryProvider).addTask(childUid, task);

        // 2. Save goal copy to child's collection so child can see it
        await db
            .collection('users')
            .doc(childUid)
            .collection('family_goals')
            .doc(goalId)
            .set(goalData);

        // 3. Add notification to child inbox
        final msgId = 'inbox_goal_$goalId';
        await db.collection('users').doc(childUid).collection('inbox').doc(msgId).set({
          'id': msgId,
          'title': 'Ota-onangizdan yangi vazifa! 🎯',
          'body': '«$title» — Bugun soat $scheduledTime gacha bajarilsa, +$rewardCoins Fenix Coin olasiz!',
          'type': 'parentReward',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('⚠️ Error syncing parent goal to child: $e');
      }
    }
  }

  /// Child accepts goal -> Creates Task and Reminder, updates Firestore status
  Future<void> acceptGoal(String goalId) async {
    final index = state.indexWhere((g) => g.id == goalId);
    if (index == -1) return;

    final goal = state[index];
    final uid = ref.read(authStateProvider).asData?.value?.uid ?? 'child_local';
    final db = ref.read(firestoreProvider);

    // Update Firestore status (both parent and child copies)
    final statusUpdate = {
      'status': FamilyGoalStatus.accepted.name,
      'respondedAt': FieldValue.serverTimestamp(),
    };
    try {
      await db.collection('users').doc(uid).collection('family_goals').doc(goalId).update(statusUpdate);
      if (goal.parentId.isNotEmpty && goal.parentId != uid) {
        await db.collection('users').doc(goal.parentId).collection('family_goals').doc(goalId).update(statusUpdate);
      }
    } catch (e) {
      debugPrint('⚠️ Error updating goal status in Firestore: $e');
    }

    // Update local state optimistically
    final updatedList = List<FamilyGoal>.from(state);
    updatedList[index] = goal.copyWith(status: FamilyGoalStatus.accepted, respondedAt: DateTime.now());
    state = updatedList;

    // 1. Add to Child's Task Repository (Daily Plan)
    final taskRepo = ref.read(taskRepositoryProvider);
    final timeParts = goal.scheduledTime.split(':');
    final hour = int.tryParse(timeParts[0]) ?? 20;
    final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
    final startMinute = hour * 60 + minute;

    AppCategory appCat = AppCategory.study;
    if (goal.category == FamilyGoalCategory.running || goal.category == FamilyGoalCategory.workout) {
      appCat = AppCategory.sport;
    } else if (goal.category == FamilyGoalCategory.habit) {
      appCat = AppCategory.personal;
    }

    final newTask = Task(
      id: 'task_fam_${goal.id}',
      title: goal.title,
      category: appCat,
      date: DateUtils.dateOnly(DateTime.now()),
      startMinute: startMinute,
      durationMinutes: goal.targetValue > 0 ? goal.targetValue : 25,
      points: goal.rewardCoins * 10,
      note: 'Oila maqsadi: ${goal.targetValue} ${goal.unit} (+${goal.rewardCoins} FC)',
    );
    try {
      await taskRepo.addTask(uid, newTask);
    } catch (_) {}

    // 2. Create scheduled Reminder
    try {
      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
      final reminderNotifier = ref.read(remindersProvider.notifier);
      await reminderNotifier.add(
        title: goal.title,
        dateTime: scheduledDate,
        repeatType: RepeatType.daily,
        durationMinutes: goal.targetValue > 0 ? goal.targetValue : 25,
      );
    } catch (_) {}
  }

  /// Child declines goal — updates Firestore status
  Future<void> declineGoal(String goalId) async {
    final index = state.indexWhere((g) => g.id == goalId);
    if (index == -1) return;

    final goal = state[index];
    final uid = ref.read(authStateProvider).asData?.value?.uid ?? 'child_local';
    final db = ref.read(firestoreProvider);

    final statusUpdate = {
      'status': FamilyGoalStatus.declined.name,
      'respondedAt': FieldValue.serverTimestamp(),
    };
    try {
      await db.collection('users').doc(uid).collection('family_goals').doc(goalId).update(statusUpdate);
      if (goal.parentId.isNotEmpty && goal.parentId != uid) {
        await db.collection('users').doc(goal.parentId).collection('family_goals').doc(goalId).update(statusUpdate);
      }
    } catch (e) {
      debugPrint('⚠️ Error declining goal in Firestore: $e');
    }

    final updatedList = List<FamilyGoal>.from(state);
    updatedList[index] = goal.copyWith(status: FamilyGoalStatus.declined, respondedAt: DateTime.now());
    state = updatedList;
  }
}

