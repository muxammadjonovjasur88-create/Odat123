import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/reminder.dart';

const _kBoxName = 'flowa_reminders';

/// Local CRUD layer for [Reminder] objects stored in Hive.
///
/// All writes automatically persist to disk. The returned lists are new copies,
/// so callers don't hold live references to box internals.
class RemindersRepository {
  RemindersRepository._();

  static RemindersRepository? _instance;

  static RemindersRepository get instance {
    _instance ??= RemindersRepository._();
    return _instance!;
  }

  /// Resets the singleton — only used in tests to get a fresh instance.
  // ignore: invalid_use_of_visible_for_testing_member
  static void resetInstance() {
    _instance?._box = null;
    _instance = null;
  }

  Box<Reminder>? _box;

  Future<Box<Reminder>> _open() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<Reminder>(_kBoxName);
    return _box!;
  }

  // ---- Read ---------------------------------------------------------------

  Future<List<Reminder>> all() async {
    final box = await _open();
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
  }) async {
    final box = await _open();
    final reminder = Reminder(
      id: const Uuid().v4(),
      title: title,
      dateTime: dateTime,
      repeatType: repeatType,
      isCompleted: false,
      createdAt: DateTime.now(),
    );
    await box.put(reminder.id, reminder);
    return reminder;
  }

  Future<void> update(Reminder updated) async {
    final box = await _open();
    await box.put(updated.id, updated);
  }

  Future<void> markCompleted(String id) async {
    final box = await _open();
    final reminder = box.get(id);
    if (reminder == null) return;
    final updated = reminder.copyWith(isCompleted: true);
    await box.put(id, updated);
  }

  Future<void> delete(String id) async {
    final box = await _open();
    await box.delete(id);
  }

  Future<void> deleteAll() async {
    final box = await _open();
    await box.clear();
  }
}
