import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import 'auth_repository.dart';
import 'firebase_providers.dart';

/// Reads/writes tasks under `users/{uid}/tasks`.
///
/// Queries filter only on `date` (no secondary `orderBy`) so no composite
/// Firestore index is required; ordering within a day is done client-side.
class TaskRepository {
  TaskRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('tasks');

  List<Task> _sorted(QuerySnapshot<Map<String, dynamic>> snap) {
    final tasks = snap.docs.map(Task.fromDoc).toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.startMinute.compareTo(b.startMinute);
      });
    return tasks;
  }

  /// Live tasks for a single calendar [day].
  Stream<List<Task>> watchTasksForDay(String uid, DateTime day) {
    final start = DateUtils.dateOnly(day);
    return _col(uid)
        .where('date', isEqualTo: Timestamp.fromDate(start))
        .snapshots()
        .map(_sorted);
  }

  /// Live tasks for the 7-day week beginning [weekStart] (a Monday).
  Stream<List<Task>> watchTasksForWeek(String uid, DateTime weekStart) {
    final start = DateUtils.dateOnly(weekStart);
    final end = start.add(const Duration(days: 7));
    return _col(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map(_sorted);
  }

  /// Adds a task and returns its new document id.
  Future<String> addTask(String uid, Task task) async {
    final ref = await _col(uid).add(task.toMap());
    return ref.id;
  }

  Future<Task?> getTask(String uid, String taskId) async {
    final snap = await _col(uid).doc(taskId).get();
    return snap.exists ? Task.fromDoc(snap) : null;
  }

  Future<void> setCompleted(String uid, String taskId, bool completed) =>
      _col(uid).doc(taskId).update({'isCompleted': completed});

  /// Marks the task completed AND its points as awarded, in one write — the
  /// idempotency stamp used by [completeAndAward].
  Future<void> markAwarded(String uid, String taskId) => _col(
    uid,
  ).doc(taskId).update({'isCompleted': true, 'pointsAwarded': true});

  /// Overwrites an existing task's editable fields (title, schedule, category,
  /// focus config, blocking, reminder) while preserving `createdAt`. Completion
  /// state is carried on [task] by the caller.
  Future<void> updateTask(String uid, String taskId, Task task) =>
      _col(uid).doc(taskId).update(task.toUpdateMap());

  /// Persists the focus-session completion ratio [percent] (0.0–1.0) without
  /// touching completion / awarded flags — safe to call from both the foreground
  /// and background completion paths.
  Future<void> saveCompletionPercent(
    String uid,
    String taskId,
    double percent,
  ) => _col(uid).doc(taskId).update({
        'completionPercent': percent.clamp(0.0, 1.0),
      });

  Future<void> deleteTask(String uid, String taskId) =>
      _col(uid).doc(taskId).delete();
}

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(ref.watch(firestoreProvider)),
);

/// Current signed-in uid, or null.
final _uidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).asData?.value?.uid,
);

/// Live tasks for a given day (keyed by the normalized day).
final tasksForDayProvider = StreamProvider.family<List<Task>, DateTime>((
  ref,
  day,
) {
  final uid = ref.watch(_uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(taskRepositoryProvider).watchTasksForDay(uid, day);
});

/// Live tasks for the week starting at [weekStart] (a Monday).
final tasksForWeekProvider = StreamProvider.family<List<Task>, DateTime>((
  ref,
  weekStart,
) {
  final uid = ref.watch(_uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(taskRepositoryProvider).watchTasksForWeek(uid, weekStart);
});
