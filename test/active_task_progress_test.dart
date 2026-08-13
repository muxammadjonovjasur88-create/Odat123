import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowa/core/constants/app_category.dart';
import 'package:flowa/core/models/task.dart';
import 'package:flowa/core/theme/app_theme.dart';
import 'package:flowa/features/daily_plan/presentation/active_task_progress_card.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a [Task] whose time window straddles [referenceTime] at [fraction].
///
/// E.g. [fraction] = 0.5 means [referenceTime] sits halfway through the task.
Task _makeTask({
  required DateTime referenceTime,
  required double fraction, // 0.0 = at start, 1.0 = at end
  int durationMinutes = 60,
}) {
  final start = referenceTime.subtract(
    Duration(seconds: (fraction * durationMinutes * 60).round()),
  );
  final startMinute = start.hour * 60 + start.minute;
  return Task(
    id: 'test-task',
    title: 'Test Task',
    category: AppCategory.study,
    date: DateUtils.dateOnly(start),
    startMinute: startMinute,
    durationMinutes: durationMinutes,
    points: durationMinutes,
  );
}

// ---------------------------------------------------------------------------
// Pure-function unit tests (no widget tree needed)
// ---------------------------------------------------------------------------

void main() {
  group('computeTaskProgress — pure function', () {
    final base = DateTime(2025, 6, 15, 10, 0); // 10:00 AM reference

    test('returns 0.0 when now is before task start', () {
      final task = _makeTask(referenceTime: base, fraction: 0.0, durationMinutes: 60);
      // now is 5 minutes BEFORE the window starts
      final before = task.start.subtract(const Duration(minutes: 5));
      expect(computeTaskProgress(task, before), equals(0.0));
    });

    test('returns 0.0 exactly at task start', () {
      final task = _makeTask(referenceTime: base, fraction: 0.0, durationMinutes: 60);
      // now == task.start
      expect(computeTaskProgress(task, task.start), closeTo(0.0, 0.001));
    });

    test('returns ~0.5 at the halfway point', () {
      final task = _makeTask(referenceTime: base, fraction: 0.5, durationMinutes: 60);
      // `base` is the reference time, which sits at fraction 0.5 into the window
      expect(computeTaskProgress(task, base), closeTo(0.5, 0.01));
    });

    test('returns ~0.75 at three-quarters through', () {
      final task = _makeTask(referenceTime: base, fraction: 0.75, durationMinutes: 60);
      expect(computeTaskProgress(task, base), closeTo(0.75, 0.01));
    });

    test('returns 1.0 exactly at task end', () {
      final task = _makeTask(referenceTime: base, fraction: 1.0, durationMinutes: 60);
      expect(computeTaskProgress(task, task.end), equals(1.0));
    });

    test('returns 1.0 when now is after task end', () {
      final task = _makeTask(referenceTime: base, fraction: 1.0, durationMinutes: 60);
      final after = task.end.add(const Duration(minutes: 10));
      expect(computeTaskProgress(task, after), equals(1.0));
    });

    test('result is always in [0.0, 1.0]', () {
      for (final fraction in [0.0, 0.25, 0.5, 0.75, 1.0, 1.5, -0.5]) {
        final task = _makeTask(referenceTime: base, fraction: fraction.clamp(0.0, 1.0));
        final when = fraction < 0
            ? task.start.subtract(const Duration(minutes: 10))
            : fraction > 1
                ? task.end.add(const Duration(minutes: 10))
                : base;
        final p = computeTaskProgress(task, when);
        expect(p, greaterThanOrEqualTo(0.0), reason: 'fraction=$fraction');
        expect(p, lessThanOrEqualTo(1.0), reason: 'fraction=$fraction');
      }
    });

    test('returns 0.0 for zero-duration task (guard against divide by zero)', () {
      final task = _makeTask(referenceTime: base, fraction: 0.5, durationMinutes: 0);
      // durationMinutes == 0 → should not throw and return 0.0
      expect(computeTaskProgress(task, base), equals(0.0));
    });

    test('survives a background restart: result depends only on wall-clock', () {
      // Simulate app reopened 30 minutes after task started.
      final task = _makeTask(referenceTime: base, fraction: 0.0, durationMinutes: 60);
      final afterRestart = task.start.add(const Duration(minutes: 30));
      expect(computeTaskProgress(task, afterRestart), closeTo(0.5, 0.01));
    });
  });

  // -------------------------------------------------------------------------
  // Widget smoke tests
  // -------------------------------------------------------------------------

  group('ActiveTaskProgressCard — widget smoke tests', () {
    /// Minimal MaterialApp wrapper with the Flowa theme (no localization).
    Widget buildWrapper(Widget child) {
      return MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: child,
        ),
      );
    }

    testWidgets('renders nothing (SizedBox.shrink) when task is null', (tester) async {
      await tester.pumpWidget(buildWrapper(const ActiveTaskProgressCard(task: null)));
      // No Padding or Row should be visible.
      expect(find.byType(Padding), findsNothing);
    });

    testWidgets('renders card when task is active (in progress)', (tester) async {
      final now = DateTime.now();
      // Task started 10 minutes ago and lasts 60 min → ~17% through.
      final startMinute = now.subtract(const Duration(minutes: 10)).hour * 60 +
          now.subtract(const Duration(minutes: 10)).minute;
      final task = Task(
        id: 'smoke-task',
        title: 'Morning Meditation',
        category: AppCategory.wellness,
        date: DateUtils.dateOnly(now),
        startMinute: startMinute,
        durationMinutes: 60,
        points: 60,
      );

      await tester.pumpWidget(buildWrapper(ActiveTaskProgressCard(task: task)));
      await tester.pump(); // allow initState / first tick

      // The card itself should appear.
      expect(find.byType(ActiveTaskProgressCard), findsOneWidget);
      // Task title should be visible.
      expect(find.text('Morning Meditation'), findsOneWidget);
    });

    testWidgets('shows completed state when task time has fully elapsed', (tester) async {
      // Task that ended 10 minutes ago → 100% done.
      final now = DateTime.now();
      final startMinute = now
          .subtract(const Duration(minutes: 70))
          .hour * 60 +
          now.subtract(const Duration(minutes: 70)).minute;
      final task = Task(
        id: 'done-task',
        title: 'Evening Run',
        category: AppCategory.sport,
        date: DateUtils.dateOnly(now),
        startMinute: startMinute,
        durationMinutes: 60,
        points: 60,
      );

      await tester.pumpWidget(buildWrapper(ActiveTaskProgressCard(task: task)));
      await tester.pump();

      // Widget renders (progress = 1.0) — completed check icon should appear.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('replaces content when task changes (didUpdateWidget)', (tester) async {
      final now = DateTime.now();
      final startMinute = now.subtract(const Duration(minutes: 5)).hour * 60 +
          now.subtract(const Duration(minutes: 5)).minute;

      final taskA = Task(
        id: 'task-a',
        title: 'Task A',
        category: AppCategory.study,
        date: DateUtils.dateOnly(now),
        startMinute: startMinute,
        durationMinutes: 60,
        points: 60,
      );
      final taskB = Task(
        id: 'task-b',
        title: 'Task B',
        category: AppCategory.work,
        date: DateUtils.dateOnly(now),
        startMinute: startMinute,
        durationMinutes: 45,
        points: 45,
      );

      await tester.pumpWidget(buildWrapper(ActiveTaskProgressCard(task: taskA)));
      await tester.pump();
      expect(find.text('Task A'), findsOneWidget);

      // Swap to task B.
      await tester.pumpWidget(buildWrapper(ActiveTaskProgressCard(task: taskB)));
      await tester.pump();
      expect(find.text('Task B'), findsOneWidget);
      expect(find.text('Task A'), findsNothing);
    });

    // ── onTap / navigation callback tests ────────────────────────────────────

    testWidgets('onTap callback fires when in-progress card is tapped', (tester) async {
      final now = DateTime.now();
      final startMinute = now.subtract(const Duration(minutes: 10)).hour * 60 +
          now.subtract(const Duration(minutes: 10)).minute;
      final task = Task(
        id: 'tap-task',
        title: 'Tap Me',
        category: AppCategory.study,
        date: DateUtils.dateOnly(now),
        startMinute: startMinute,
        durationMinutes: 60,
        points: 60,
      );

      var tapCount = 0;
      await tester.pumpWidget(
        buildWrapper(ActiveTaskProgressCard(task: task, onTap: () => tapCount++)),
      );
      await tester.pump();

      // Tap the card — InkWell + ScaleTransition; pump through the animation.
      await tester.tap(find.byType(ActiveTaskProgressCard));
      await tester.pumpAndSettle();

      expect(tapCount, equals(1), reason: 'onTap should fire exactly once');
    });

    testWidgets('onTap callback does NOT fire when card has no onTap', (tester) async {
      final now = DateTime.now();
      final startMinute = now.subtract(const Duration(minutes: 10)).hour * 60 +
          now.subtract(const Duration(minutes: 10)).minute;
      final task = Task(
        id: 'no-tap-task',
        title: 'Not Tappable',
        category: AppCategory.study,
        date: DateUtils.dateOnly(now),
        startMinute: startMinute,
        durationMinutes: 60,
        points: 60,
      );

      var tapCount = 0;
      // onTap is null → card should not be interactive
      await tester.pumpWidget(
        buildWrapper(ActiveTaskProgressCard(task: task)),
      );
      await tester.pump();

      await tester.tap(find.byType(ActiveTaskProgressCard), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(tapCount, equals(0), reason: 'onTap should not fire when null');
    });

    testWidgets('completed task card does not show play icon or chevron', (tester) async {
      final now = DateTime.now();
      // Task ended 10 minutes ago → completed
      final startMinute = now.subtract(const Duration(minutes: 70)).hour * 60 +
          now.subtract(const Duration(minutes: 70)).minute;
      final task = Task(
        id: 'completed-tap',
        title: 'Done Task',
        category: AppCategory.work,
        date: DateUtils.dateOnly(now),
        startMinute: startMinute,
        durationMinutes: 60,
        points: 60,
      );

      var tapped = false;
      await tester.pumpWidget(
        buildWrapper(ActiveTaskProgressCard(task: task, onTap: () => tapped = true)),
      );
      await tester.pump();

      // When completed, _ActiveCard sets canTap = false (onTap && !completed).
      // So play_circle_outline_rounded and chevron_right_rounded should not appear.
      expect(find.byIcon(Icons.play_circle_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

      // Tapping should be no-op (no InkWell wraps a completed card).
      await tester.tap(find.byType(ActiveTaskProgressCard), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tapped, isFalse, reason: 'Completed card tap must be ignored');
    });

    testWidgets('does not overflow on narrow screens (320px) with long title and chevron', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      final startMinute = now.subtract(const Duration(minutes: 10)).hour * 60 +
          now.subtract(const Duration(minutes: 10)).minute;
      final task = Task(
        id: 'narrow-task',
        title: 'Juda uzun nomli vazifa misoli va qismlari super uzun nom',
        category: AppCategory.study,
        date: DateUtils.dateOnly(now),
        startMinute: startMinute,
        durationMinutes: 60,
        points: 60,
      );

      await tester.pumpWidget(
        buildWrapper(ActiveTaskProgressCard(task: task, onTap: () {})),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });
  });
}
