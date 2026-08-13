import 'package:flutter/foundation.dart';
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
/// Returns the [BlockingStartResult] so the caller can inform the user if a
/// required permission is missing. Returns null if blocking is not applicable
/// (non-Android, task already ended, or no blocked apps configured).
///
/// Safe to call early or repeatedly — the native side only enforces blocking
/// once the start of the window is reached, and stops automatically at the end.
Future<BlockingStartResult?> startBlockingForTask(WidgetRef ref, Task task) async {
  final settings = ref.read(blockingSettingsProvider).asData?.value;
  if (settings == null || settings.blockedPackages.isEmpty) {
    debugPrint('[startBlockingForTask] skipped: no blocked packages configured');
    return null;
  }

  final shouldBlock = task.blockApps || settings.alwaysBlock;
  if (!shouldBlock) {
    debugPrint('[startBlockingForTask] skipped: task.blockApps=false and alwaysBlock=false');
    return null;
  }

  // Nothing to block if the window has already closed.
  if (!task.end.isAfter(DateTime.now())) {
    debugPrint('[startBlockingForTask] skipped: task end time is in the past');
    return null;
  }

  debugPrint(
    '[startBlockingForTask] arming blocking for "${task.title}" '
    '(packages: ${settings.blockedPackages.length}, strict: ${settings.strictMode})',
  );

  final result = await ref
      .read(blockingServiceProvider)
      .startSession(
        packages: settings.blockedPackages.toList(),
        startAt: task.start.subtract(blockingLeadTime),
        endTime: task.end,
        strict: settings.strictMode,
        lang: LocaleStore.effectiveCode(),
      );

  if (!result.armed) {
    debugPrint(
      '[startBlockingForTask] ✗ blocking NOT armed '
      '(reason: ${result.reason})',
    );
  } else {
    debugPrint('[startBlockingForTask] ✓ blocking armed successfully');
  }

  return result;
}

Future<void> stopBlocking(dynamic ref) {
  if (ref is ProviderContainer) {
    return ref.read(blockingServiceProvider).stopSession();
  }
  if (ref is WidgetRef) {
    return ref.container.read(blockingServiceProvider).stopSession();
  }
  if (ref is Ref) {
    return ref.container.read(blockingServiceProvider).stopSession();
  }
  throw ArgumentError('Invalid ref for stopBlocking: $ref');
}
