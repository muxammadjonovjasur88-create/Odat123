import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:flowa/features/reminders/data/reminders_repository.dart';
import 'package:flowa/features/reminders/domain/models/reminder.dart';

/// Unit tests for [RemindersRepository] CRUD operations.
///
/// Uses an in-memory Hive box so no real disk I/O takes place.
void main() {
  setUpAll(() async {
    // Register Hive adapters (same as main.dart).
    Hive.registerAdapter(RepeatTypeAdapter());
    Hive.registerAdapter(ReminderAdapter());
    // Use a temp directory for Hive in tests.
    Hive.init('test_hive_${DateTime.now().millisecondsSinceEpoch}');
  });

  tearDown(() async {
    // Close and delete the box between tests to start clean.
    if (Hive.isBoxOpen('flowa_reminders')) {
      final box = Hive.box<Reminder>('flowa_reminders');
      await box.clear();
      await box.close();
    }
    // Reset the singleton instance so the next test gets a fresh box.
    RemindersRepository.resetInstance();
  });

  group('RemindersRepository - CRUD', () {
    test('add() creates a reminder and returns it', () async {
      final repo = RemindersRepository.instance;
      final reminder = await repo.add(
        title: 'Doktorga borish',
        dateTime: DateTime.now().add(const Duration(hours: 2)),
        repeatType: RepeatType.once,
      );

      expect(reminder.id, isNotEmpty);
      expect(reminder.title, 'Doktorga borish');
      expect(reminder.repeatType, RepeatType.once);
      expect(reminder.isCompleted, isFalse);
    });

    test('all() returns sorted list by dateTime', () async {
      final repo = RemindersRepository.instance;
      final now = DateTime.now();
      await repo.add(
        title: 'B reminder',
        dateTime: now.add(const Duration(hours: 3)),
      );
      await repo.add(
        title: 'A reminder',
        dateTime: now.add(const Duration(hours: 1)),
      );

      final all = await repo.all();
      expect(all.length, 2);
      expect(all[0].title, 'A reminder');
      expect(all[1].title, 'B reminder');
    });

    test('markCompleted() sets isCompleted to true', () async {
      final repo = RemindersRepository.instance;
      final r = await repo.add(
        title: 'Test',
        dateTime: DateTime.now().add(const Duration(hours: 1)),
      );

      await repo.markCompleted(r.id);
      final all = await repo.all();
      final updated = all.firstWhere((x) => x.id == r.id);
      expect(updated.isCompleted, isTrue);
    });

    test('delete() removes the reminder', () async {
      final repo = RemindersRepository.instance;
      final r = await repo.add(
        title: 'To delete',
        dateTime: DateTime.now().add(const Duration(hours: 1)),
      );

      await repo.delete(r.id);
      final all = await repo.all();
      expect(all.any((x) => x.id == r.id), isFalse);
    });

    test('update() changes title and dateTime', () async {
      final repo = RemindersRepository.instance;
      final r = await repo.add(
        title: 'Original',
        dateTime: DateTime.now().add(const Duration(hours: 1)),
      );

      final newDate = DateTime.now().add(const Duration(days: 2));
      final updated = r.copyWith(title: 'Updated', dateTime: newDate);
      await repo.update(updated);

      final all = await repo.all();
      final found = all.firstWhere((x) => x.id == r.id);
      expect(found.title, 'Updated');
      expect(found.dateTime.day, newDate.day);
    });

    test('pending() excludes completed and past reminders', () async {
      final repo = RemindersRepository.instance;
      // Future reminder — should appear in pending.
      await repo.add(
        title: 'Future',
        dateTime: DateTime.now().add(const Duration(hours: 5)),
      );
      // Completed reminder — should NOT appear in pending.
      final completed = await repo.add(
        title: 'Completed',
        dateTime: DateTime.now().add(const Duration(hours: 6)),
      );
      await repo.markCompleted(completed.id);

      final pending = await repo.pending();
      expect(pending.length, 1);
      expect(pending.first.title, 'Future');
    });

    test('deleteAll() clears the box', () async {
      final repo = RemindersRepository.instance;
      await repo.add(
        title: 'A',
        dateTime: DateTime.now().add(const Duration(hours: 1)),
      );
      await repo.add(
        title: 'B',
        dateTime: DateTime.now().add(const Duration(hours: 2)),
      );
      await repo.deleteAll();

      final all = await repo.all();
      expect(all, isEmpty);
    });
  });
}
