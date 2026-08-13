import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:flowa/core/theme/app_theme.dart';
import 'package:flowa/features/reminders/domain/models/reminder.dart';
import 'package:flowa/features/reminders/presentation/providers/reminders_provider.dart';
import 'package:flowa/features/reminders/presentation/screens/reminders_list_screen.dart';
import 'package:flowa/features/reminders/presentation/screens/add_reminder_screen.dart';

class FakeRemindersNotifier extends RemindersNotifier {
  final List<Reminder> _initial;
  FakeRemindersNotifier(this._initial);
  
  @override
  Future<List<Reminder>> build() async => _initial;

  @override
  Future<void> add({
    required String title,
    required DateTime dateTime,
    required RepeatType repeatType,
  }) async {
    final list = [
      ...state.value ?? _initial,
      Reminder(
        id: 'test_id',
        title: title,
        dateTime: dateTime,
        repeatType: repeatType,
        isCompleted: false,
        createdAt: DateTime.now(),
      ),
    ];
    state = AsyncData(list);
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('uz');
  });

  testWidgets('Reminders grouping logic groups by date correctly', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12, 0);
    final tomorrow = today.add(const Duration(days: 1));
    final nextWeek = today.add(const Duration(days: 5));

    final mockReminders = [
      Reminder(
        id: '1',
        title: 'Bugungi vazifa',
        dateTime: today,
        repeatType: RepeatType.once,
        isCompleted: false,
        createdAt: today,
      ),
      Reminder(
        id: '2',
        title: 'Ertangi vazifa',
        dateTime: tomorrow,
        repeatType: RepeatType.once,
        isCompleted: false,
        createdAt: today,
      ),
      Reminder(
        id: '3',
        title: 'Keyingi haftadagi vazifa',
        dateTime: nextWeek,
        repeatType: RepeatType.once,
        isCompleted: false,
        createdAt: today,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remindersProvider.overrideWith(() => FakeRemindersNotifier(mockReminders)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const RemindersListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify section headers exist
    expect(find.text('Bugun'), findsWidgets);
    expect(find.text('Ertaga'), findsWidgets);
    expect(find.text('Bu hafta'), findsWidgets);

    // Verify tasks are present
    expect(find.text('Bugungi vazifa'), findsOneWidget);
    expect(find.text('Ertangi vazifa'), findsOneWidget);
    expect(find.text('Keyingi haftadagi vazifa'), findsOneWidget);
  });

  testWidgets('Add Reminder form validation test', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remindersProvider.overrideWith(() => FakeRemindersNotifier([])),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () => RemindersSheet.show(context),
                    child: const Text('Open'),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Verify we are on Add form
    expect(find.text('Yangi eslatma'), findsOneWidget);

    // Try to save empty form
    await tester.tap(find.text('Eslatma qo\'shish'));
    await tester.pumpAndSettle();

    // Verify validation error
    expect(find.text('Sarlavha kiriting'), findsOneWidget);

    // Enter title
    await tester.enterText(find.byType(TextFormField), 'Doktorga borish');
    await tester.pumpAndSettle();

    // Hit save again
    await tester.tap(find.text('Eslatma qo\'shish'));
    await tester.pumpAndSettle();

    expect(find.text('Sarlavha kiriting'), findsNothing);
  });
}
