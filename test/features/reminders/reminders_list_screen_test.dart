import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/core/theme/app_theme.dart';
import 'package:flowa/features/reminders/domain/models/reminder.dart';
import 'package:flowa/features/reminders/presentation/providers/reminders_provider.dart';
import 'package:flowa/features/reminders/presentation/screens/reminders_list_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// An [AsyncNotifier] override that serves a fixed list without hitting Hive.
class _FakeRemindersNotifier extends RemindersNotifier {
  _FakeRemindersNotifier(this._reminders);

  final List<Reminder> _reminders;

  @override
  Future<List<Reminder>> build() async => _reminders;
}

/// A notifier that always throws so we can test the error state.
class _ErrorNotifier extends RemindersNotifier {
  @override
  Future<List<Reminder>> build() async => throw Exception('Test error');
}

Reminder _makeReminder({
  String id = 'r1',
  String title = 'Doktorga borish',
  bool isCompleted = false,
  bool isPast = false,
}) {
  final dt = isPast
      ? DateTime.now().subtract(const Duration(hours: 1))
      : DateTime.now().add(const Duration(hours: 2));
  return Reminder(
    id: id,
    title: title,
    dateTime: dt,
    repeatType: RepeatType.once,
    isCompleted: isCompleted,
    createdAt: DateTime.now(),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RemindersListScreen — widget tests', () {
    testWidgets('shows empty state when no reminders exist', (tester) async {
      final notifier = _FakeRemindersNotifier([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            remindersProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            home: const RemindersListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The "Pending" tab should show the empty-state title.
      expect(find.text('Hali eslatma yo\'q'), findsOneWidget);
    });

    testWidgets('shows reminder card when list is non-empty', (tester) async {
      final reminder = _makeReminder(title: 'Doktorga borish');
      final notifier = _FakeRemindersNotifier([reminder]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            remindersProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            home: const RemindersListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Card title should be visible in the Pending tab.
      expect(find.text('Doktorga borish'), findsOneWidget);
    });

    testWidgets('completed reminders appear in Completed tab', (tester) async {
      final pending = _makeReminder(id: 'r1', title: 'Pending task');
      final done = _makeReminder(
        id: 'r2',
        title: 'Done task',
        isCompleted: true,
      );
      final notifier = _FakeRemindersNotifier([pending, done]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            remindersProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            home: const RemindersListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the 'Bajarildi' tab.
      await tester.tap(find.text('Bajarildi'));
      await tester.pumpAndSettle();

      expect(find.text('Done task'), findsOneWidget);
      // Pending card should not be visible in this tab.
      expect(find.text('Pending task'), findsNothing);
    });

    testWidgets("past reminders appear in O'tib ketdi tab", (tester) async {
      final past = _makeReminder(id: 'r1', title: 'Past task', isPast: true);
      final future = _makeReminder(id: 'r2', title: 'Future task');
      final notifier = _FakeRemindersNotifier([past, future]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            remindersProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            home: const RemindersListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the "O'tib ketdi" tab.
      await tester.tap(find.text("O'tib ketdi"));
      await tester.pumpAndSettle();

      expect(find.text('Past task'), findsOneWidget);
      expect(find.text('Future task'), findsNothing);
    });

    testWidgets('swipe-to-dismiss shows confirmation dialog', (tester) async {
      final reminder = _makeReminder(title: 'Swipe me');
      final notifier = _FakeRemindersNotifier([reminder]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            remindersProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            home: const RemindersListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Swipe the card from right to left to trigger dismiss.
      await tester.drag(
        find.text('Swipe me'),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();

      // Confirmation dialog should appear.
      expect(find.text("Eslatmani o'chirish"), findsOneWidget);

      // Tap 'Bekor qilish' — card should remain.
      await tester.tap(find.text('Bekor qilish'));
      await tester.pumpAndSettle();

      expect(find.text('Swipe me'), findsOneWidget);
    });

    testWidgets('error state shows retry button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            remindersProvider.overrideWith(() => _ErrorNotifier()),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            home: const RemindersListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("Ma'lumotlarni yuklashda xato"), findsOneWidget);
      expect(find.text('Qayta urinish'), findsOneWidget);
    });
  });
}
