import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/reminder.dart';

const _kBoxName = 'flowa_reminders';

/// Hybrid CRUD layer for [Reminder] objects stored in Hive and synced with Firestore.
///
/// Ensures reminders survive app reinstalls and device changes by backing them up to Firebase.
class RemindersRepository {
  RemindersRepository._();

  static RemindersRepository? _instance;

  static RemindersRepository get instance {
    _instance ??= RemindersRepository._();
    return _instance!;
  }

  static void resetInstance() {
    _instance?._box = null;
    _instance = null;
  }

  Box<Reminder>? _box;
  bool _hasSyncedRemote = false;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _userRemindersCol {
    final uid = _currentUid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('reminders');
  }

  Future<Box<Reminder>> _open() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<Reminder>(_kBoxName);
    return _box!;
  }

  // ---- Read & Sync --------------------------------------------------------

  Future<void> syncFromCloud() async {
    final col = _userRemindersCol;
    if (col == null) return;

    try {
      final snap = await col.get();
      final box = await _open();
      for (final doc in snap.docs) {
        final data = doc.data();
        final reminder = Reminder.fromMap(data);
        if (reminder.id.isNotEmpty) {
          await box.put(reminder.id, reminder);
        }
      }
      _hasSyncedRemote = true;
    } catch (e) {
      debugPrint('Reminders cloud sync error: $e');
    }
  }

  Future<List<Reminder>> all() async {
    final box = await _open();
    if (!_hasSyncedRemote && _currentUid != null) {
      // Async sync from cloud without blocking initial render
      syncFromCloud();
    }
    return box.values.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  Future<List<Reminder>> pending() async {
    final all = await this.all();
    return all.where((r) => !r.isCompleted && !r.isPast).toList();
  }

  Future<List<Reminder>> past() async {
    final all = await this.all();
    return all.where((r) => !r.isCompleted && r.isPast).toList();
  }

  Future<List<Reminder>> completed() async {
    final all = await this.all();
    return all.where((r) => r.isCompleted).toList();
  }

  // ---- Write --------------------------------------------------------------

  Future<Reminder> add({
    required String title,
    required DateTime dateTime,
    RepeatType repeatType = RepeatType.once,
    String goalType = 'note',
    int durationMinutes = 25,
    String? startTimeStr,
    String? endTimeStr,
    String? exerciseType,
    int? targetReps,
  }) async {
    final box = await _open();
    final reminder = Reminder(
      id: const Uuid().v4(),
      title: title,
      dateTime: dateTime,
      repeatType: repeatType,
      isCompleted: false,
      createdAt: DateTime.now(),
      goalType: goalType,
      durationMinutes: durationMinutes,
      startTimeStr: startTimeStr,
      endTimeStr: endTimeStr,
      exerciseType: exerciseType,
      targetReps: targetReps,
    );
    await box.put(reminder.id, reminder);

    // Sync to Cloud Firestore
    _syncToCloud(reminder);

    return reminder;
  }

  Future<void> update(Reminder updated) async {
    final box = await _open();
    await box.put(updated.id, updated);
    _syncToCloud(updated);
  }

  Future<void> markCompleted(String id) async {
    final box = await _open();
    final reminder = box.get(id);
    if (reminder == null) return;
    final updated = reminder.copyWith(isCompleted: true);
    await box.put(id, updated);
    _syncToCloud(updated);
  }

  Future<void> delete(String id) async {
    final box = await _open();
    await box.delete(id);

    final col = _userRemindersCol;
    if (col != null) {
      try {
        await col.doc(id).delete();
      } catch (e) {
        debugPrint('Failed to delete reminder from cloud: $e');
      }
    }
  }

  Future<void> deleteAll() async {
    final box = await _open();
    await box.clear();
  }

  void _syncToCloud(Reminder reminder) {
    final col = _userRemindersCol;
    if (col != null) {
      col.doc(reminder.id).set(reminder.toMap(), SetOptions(merge: true)).catchError((e) {
        debugPrint('Failed to sync reminder to cloud: $e');
      });
    }
  }
}
