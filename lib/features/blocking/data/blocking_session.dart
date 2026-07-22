import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/task.dart';
import '../../../core/services/locale_store.dart';
import 'blocking_repository.dart';
import 'blocking_service.dart';

/// How long before a task starts that blocking begins.
const blockingLeadTime = Duration(minutes: 5);

/// Arms native app blocking for [task] for the window
/// `[task.start - 5min, task.end)`, if the user's settings call for it (the
/// task has "Block Distractions" on, or "always block" is set) and they've
/// chosen at least one app.
///
/// Safe to call early or repeatedly — the native side only enforces blocking
/// once the start of the window is reached, and stops automatically at the end.
/// Safe no-op off Android / when nothing should be blocked.
Future<void> startBlockingForTask(WidgetRef ref, Task task) async {
  final settings = ref.read(blockingSettingsProvider).asData?.value;
  if (settings == null || settings.blockedPackages.isEmpty) return;

  final shouldBlock = task.blockApps || settings.alwaysBlock;
  if (!shouldBlock) return;

  // Nothing to block if the window has already closed.
  if (!task.end.isAfter(DateTime.now())) return;

  await ref
      .read(blockingServiceProvider)
      .startSession(
        packages: settings.blockedPackages.toList(),
        startAt: task.start.subtract(blockingLeadTime),
        endTime: task.end,
        strict: settings.strictMode,
        lang: LocaleStore.effectiveCode(),
      );
}

Future<void> stopBlocking(WidgetRef ref) =>
    ref.read(blockingServiceProvider).stopSession();
