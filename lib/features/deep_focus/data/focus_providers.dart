import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_category.dart';
import '../../../core/models/task.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/locale_store.dart';
import '../../../core/services/task_repository.dart';
import '../../../core/services/user_repository.dart';
import '../../ambient/data/ambient_sound_controller.dart';
import '../../blocking/data/blocking_session.dart';
import '../../blocking/domain/blockable_app.dart';
import '../../blocking/domain/blocking_settings.dart';
import '../../gamification/data/gamification_repository.dart';
import '../../gamification/domain/gamification_math.dart';
import '../../goal_reached/domain/goal_reached_args.dart';
import '../../honest_focus/data/focus_session_repository.dart';
import '../../honest_focus/domain/honest_focus.dart';
import '../../honest_focus/domain/session_integrity.dart';
import '../../workout/domain/workout.dart';
import 'focus_service.dart';

/// Schedules the background focus session for a freshly-created [task]. An exact
/// alarm starts the native foreground-service countdown (and app blocking, if
/// configured) at the task's scheduled time — even if the app is then closed.
///
/// Takes resolved inputs (not a ref) so it can be called from both a
/// `WidgetRef` (Add Goal) and a provider `Ref` (AI planner).
Future<void> scheduleBackgroundFocus({
  required FocusService service,
  required String taskId,
  required Task task,
  required BlockingSettings? settings,
  DateTime? startAt,
  DateTime? endAt,
}) async {
  final start = startAt ?? task.start;
  final end = endAt ?? task.end;
  if (!end.isAfter(DateTime.now())) {
    debugPrint('[scheduleBackgroundFocus] skipped: end time is in the past');
    return;
  }
  final packagesToPass = (settings != null && settings.blockedPackages.isNotEmpty)
      ? settings.blockedPackages.toList()
      : kBlockableApps.map((a) => a.packageName).toList();

  debugPrint(
    '[scheduleBackgroundFocus] scheduling "${task.title}": '
    'packages=${packagesToPass.length}, '
    'strict=${settings?.strictMode ?? false}, '
    'start=$start, end=$end',
  );

  await service.scheduleSession(
    taskId: taskId,
    title: task.title,
    startAt: start,
    endAt: end,
    packages: packagesToPass,
    // Soft friction by default; strict mode is an opt-in hard wall.
    strict: settings?.strictMode ?? false,
    lang: LocaleStore.effectiveCode(),
  );
}

/// Begins a background session immediately (Forest-style "begin now"): the
/// session runs for the task's full duration starting at this moment.
Future<void> beginBackgroundFocusNow({
  required FocusService service,
  required String taskId,
  required Task task,
  required BlockingSettings? settings,
}) {
  final now = DateTime.now();
  debugPrint('[beginBackgroundFocusNow] starting immediately for "${task.title}"');
  return scheduleBackgroundFocus(
    service: service,
    taskId: taskId,
    task: task,
    settings: settings,
    startAt: now,
    endAt: now.add(Duration(minutes: task.durationMinutes)),
  );
}


/// The task the Focus tab should run: today's earliest not-yet-completed task.
/// Null when nothing is left to focus on.
final currentFocusTaskProvider = Provider<Task?>((ref) {
  final today = DateUtils.dateOnly(DateTime.now());
  final tasks = ref.watch(tasksForDayProvider(today)).asData?.value ?? const [];
  for (final t in tasks) {
    if (!t.isCompleted) return t;
  }
  return null;
});

/// Whether [task] should use the sport interval timer rather than Pomodoro.
/// Decided by the task's category, the user's primary focus type, or an
/// explicit custom interval method. [intervalSets] is intentionally NOT
/// checked here — every task defaults to intervalSets=4, so that field alone
/// cannot distinguish interval from deep-work sessions.
bool usesIntervalTimer(Task task, UserProfile? profile) =>
    task.focusMethod != FocusMethod.note &&
    (task.category == AppCategory.sport ||
        profile?.focusType == 'Sport' ||
        task.focusMethod == FocusMethod.custom);

/// Session runs already persisted this process, so a foreground finish and a
/// native "finished" event can't double-award / double-record. Counted runs
/// stay claimed for the process; uncounted runs release after a delay so the
/// user can retry the same task.
final Set<String> _handled = {};

/// Resets the handled claim for [taskId], allowing subsequent focus sessions to earn points.
void clearHandledTask(String taskId) {
  _handled.remove(taskId);
}

/// Completes a focus session with "Honest Focus" scoring. Stops the background
/// service, evaluates the integrity [signals], and:
///
/// * **counts** the session (marks the task done + awards points) only if the
///   timer genuinely completed and focus held (full) or mostly held (partial);
/// * **doesn't count** it (no completion, no points) if quit early or spent in
///   other apps.
///
/// Either way it stores the session record in Firestore, and returns the data
/// the summary screen needs. Persistence is de-duplicated across the foreground
/// + background completion paths; the returned summary is always computed from
/// the live [signals] so it's correct even when another path persisted first.
ProviderContainer _getContainer(dynamic ref) {
  if (ref is ProviderContainer) return ref;
  if (ref is Ref) return ref.container;
  if (ref is WidgetRef) return ref.container;
  throw ArgumentError('Expected ProviderContainer, Ref, or WidgetRef, got $ref');
}

/// Completes a focus session with "Honest Focus" scoring. Stops the background
/// service, evaluates the integrity [signals], and:
///
/// * **counts** the session (marks the task done + awards points) only if the
///   timer genuinely completed and focus held (full) or mostly held (partial);
/// * **doesn't count** it (no completion, no points) if quit early or spent in
///   other apps.
///
/// Either way it stores the session record in Firestore, and returns the data
/// the summary screen needs. Persistence is de-duplicated across the foreground
/// + background completion paths; the returned summary is always computed from
/// the live [signals] so it's correct even when another path persisted first.
Future<GoalReachedArgs> completeFocusSession(
  dynamic ref,
  Task task, {
  required FocusSignals signals,
  WorkoutResult? workout,
}) async {
  final container = _getContainer(ref);
  final uid = container.read(authStateProvider).asData?.value?.uid;
  final profile = container.read(userProfileProvider).asData?.value;
  final isSport = usesIntervalTimer(task, profile);

  final today = DateUtils.dateOnly(DateTime.now());
  final tasks = container.read(tasksForDayProvider(today)).asData?.value ?? const [];

  // Stop the native foreground session (timer + notification), blocking, and
  // the ambient focus sound. Do this in try-catch so failure doesn't block points.
  try {
    debugPrint('[completeFocusSession] Stopping native session...');
    await container.read(focusServiceProvider).stopSession();
  } catch (e, st) {
    debugPrint('[completeFocusSession] ❌ stopSession failed: $e\n$st');
  }

  try {
    debugPrint('[completeFocusSession] Stopping blocking...');
    await stopBlocking(container).timeout(const Duration(seconds: 2));
  } catch (e, st) {
    debugPrint('[completeFocusSession] ❌ stopBlocking failed: $e\n$st');
  }

  try {
    debugPrint('[completeFocusSession] Stopping ambient sound...');
    await container.read(ambientSoundProvider.notifier).stopPlayback();
  } catch (e, st) {
    debugPrint('[completeFocusSession] ❌ stopPlayback failed: $e\n$st');
  }

  Task? next;
  for (final t in tasks) {
    if (t.id != task.id && !t.isCompleted) {
      next = t;
      break;
    }
  }

  var verdict = HonestFocus.evaluate(signals);
  var counted = HonestFocus.counts(verdict);
  debugPrint(
    '[completeFocusSession] HonestFocus.evaluate → verdict=$verdict, counted=$counted '
    'timerCompleted=${signals.timerCompleted} distractingOpens=${signals.distractingOpens} '
    'awayRatio=${signals.totalSeconds > 0 ? (signals.awaySeconds / signals.totalSeconds).toStringAsFixed(2) : "N/A"}',
  );

  final integrityPercent = SessionIntegrity.calculateScore(
    signals: signals,
    checkInsPresented: signals.checkInsPresented,
    checkInsMissed: signals.checkInsMissed,
  );

  if (integrityPercent < 0.2) {
    counted = false;
    verdict = FocusVerdict.incomplete;
  }

  // BUG FIX #1 + #2: plannedMinutes must be the PLANNED duration
  // (task.durationMinutes ± user's time adjustments), NOT the elapsed
  // real-time (signals.totalSeconds). Using elapsed time as the denominator
  // made completionPercent approach 1.0 regardless of how early the user quit.
  final adjustedPlannedMinutes = (task.durationMinutes + (signals.timeAdjustmentSeconds / 60).round()).clamp(1, 1440);

  // BUG FIX #2: always use adjustedPlannedMinutes as the "planned" denominator
  // so +/- time adjustments are properly reflected in completionPercent.
  final completionPercent = GamificationMath.calculateTaskCompletionPercent(
    plannedMinutes: adjustedPlannedMinutes,
    actualMinutes: signals.focusedSeconds ~/ 60,
  );
  debugPrint(
    '[completeFocusSession] verdict=$verdict counted=$counted '
    'integrityPercent=${integrityPercent.toStringAsFixed(2)} '
    'completionPercent=${completionPercent.toStringAsFixed(2)} '
    'focusedSeconds=${signals.focusedSeconds} '
    'taskDurationMinutes=${task.durationMinutes} '
    'adjustedPlannedMinutes=$adjustedPlannedMinutes '
    'timeAdjustmentSeconds=${signals.timeAdjustmentSeconds} '
    'actualMinutes=${signals.focusedSeconds ~/ 60}',
  );

  var gained = 0;
  var streak = profile?.streak ?? 0;
  int? milestone;

  var pointsError = false;
  String? errorMessage;

  final adjustedBasePoints = task.durationMinutes > 0 
      ? (task.points * (adjustedPlannedMinutes / task.durationMinutes)).round()
      : task.points;
  // BUG FIX #3: removed the dangerous fallback that granted task.points in
  // full even when completionPercent was tiny (e.g. 5%). Now points are always
  // strictly proportional — 0% completion → 0 points.
  var expectedGained = (GamificationMath.proportionalPoints(
    basePoints: adjustedBasePoints,
    completionPercent: completionPercent,
  ) * integrityPercent).round();

  // If already handled, we still want to show the correct gained points in the UI.
  if (counted) gained = expectedGained;

  // Claim this session run for persistence (first handler wins).
  debugPrint(
    '[completeFocusSession] _handled check: uid=$uid, '
    'task.id=${task.id}, alreadyHandled=${_handled.contains(task.id)}, '
    'counted=$counted, gained=$gained, expectedGained=$expectedGained',
  );
  if (uid != null && _handled.add(task.id)) {
    if (!counted) {
      // Let the user retry an uncounted task after a short window.
      Future.delayed(
        const Duration(seconds: 10),
        () => _handled.remove(task.id),
      );
    }

    if (counted) {
      try {
        debugPrint('[completeFocusSession] Step A: completeAndAward starting...');
        final result = await completeAndAward(
          container,
          task,
          deep: !isSport,
          blockingEngaged: HonestFocus.blockingRespected(signals),
          integrityPercent: integrityPercent,
          completionPercent: completionPercent,
          plannedMinutesOverride: adjustedPlannedMinutes,
          focusedMinutesOverride: signals.focusedSeconds ~/ 60,
        ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[completeFocusSession] ⚠️ completeAndAward timed out after 10s');
          throw Exception('completeAndAward timeout');
        },
      );
        if (result != null) {
          gained = result.gained;
          streak = result.streak;
          milestone = result.milestone;
          debugPrint('[completeFocusSession] Step A: completeAndAward done. gained=$gained, streak=$streak');
        } else {
          // If completeAndAward returned null (task already awarded), reuse
          // the already-computed completionPercent from the outer scope — it's
          // already corrected (adjustedPlannedMinutes as denominator).
          final adjustedBasePoints = task.durationMinutes > 0 
              ? (task.points * (adjustedPlannedMinutes / task.durationMinutes)).round()
              : task.points;
          final basePoints = GamificationMath.proportionalPoints(
            basePoints: adjustedBasePoints,
            completionPercent: completionPercent,
          );
          gained = (basePoints * integrityPercent).round();
          debugPrint('[completeFocusSession] Step A: task already awarded, fallback gained=$gained');
        }
      } catch (e, st) {
        debugPrint('[points] ❌ completeAndAward exception/timeout: $e\n$st');
        pointsError = true;
        errorMessage = 'Ochko saqlashda xato yuz berdi, internetni tekshiring';
        // On network error/timeout: reuse already-computed completionPercent
        // (adjustedPlannedMinutes as denominator) for proportional points.
        final adjustedBasePoints2 = task.durationMinutes > 0 
            ? (task.points * (adjustedPlannedMinutes / task.durationMinutes)).round()
            : task.points;
        gained = (GamificationMath.proportionalPoints(
          basePoints: adjustedBasePoints2,
          completionPercent: completionPercent,
        ) * integrityPercent).round();
      }
    }

    // Store the session result + signals in Firestore (counted or not).
    try {
      debugPrint('[completeFocusSession] Step B: recording session to repository...');
      await container
          .read(focusSessionRepositoryProvider)
          .record(
            uid: uid,
            taskId: task.id,
            taskTitle: task.title,
            verdict: verdict,
            signals: signals,
            points: gained,
            workout: workout,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () => debugPrint('[completeFocusSession] ⚠️ record timed out after 10s'),
          );
      debugPrint('[completeFocusSession] Step B: record done');
    } catch (e, st) {
      debugPrint('[completeFocusSession] ❌ record exception: $e\n$st');
      // Secondary record error does not fail the primary point award
    }

    // Persist the completion ratio so the daily plan can show partial progress.
    try {
      debugPrint('[completeFocusSession] Step C: saving completion percent...');
      final existing = await container
          .read(taskRepositoryProvider)
          .getTask(uid, task.id)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );
      final prevPercent = existing?.completionPercent ?? 0.0;
      if (completionPercent > prevPercent) {
        await container
            .read(taskRepositoryProvider)
            .saveCompletionPercent(uid, task.id, completionPercent)
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () => debugPrint('[completeFocusSession] ⚠️ saveCompletionPercent timed out'),
            );
      }
      debugPrint('[completeFocusSession] Step C: saveCompletionPercent done');
    } catch (e, st) {
      debugPrint('[completeFocusSession] ❌ saveCompletionPercent exception: $e\n$st');
    }
  }

  debugPrint(
    '[completeFocusSession] ========== FINAL RESULT ==========\n'
    '[completeFocusSession] points=$gained\n'
    '[completeFocusSession] awardedPoints=$gained\n'
    '[completeFocusSession] verdict=$verdict\n'
    '[completeFocusSession] counted=$counted\n'
    '[completeFocusSession] streak=$streak\n'
    '[completeFocusSession] completionPercent=${completionPercent.toStringAsFixed(2)}\n'
    '[completeFocusSession] integrityPercent=${integrityPercent.toStringAsFixed(2)}\n'
    '[completeFocusSession] focusSeconds=${signals.focusedSeconds}\n'
    '[completeFocusSession] isSport=$isSport\n'
    '[completeFocusSession] fullCompletion=${completionPercent >= 0.95}\n'
    '[completeFocusSession] pointsError=$pointsError\n'
    '[completeFocusSession] ================================',
  );

  return GoalReachedArgs(
    points: gained,
    taskTitle: task.title,
    streak: streak,
    isSport: isSport,
    nextTaskTitle: next?.title,
    milestone: counted ? milestone : null,
    verdict: verdict,
    focusSeconds: signals.focusedSeconds,
    distractions: signals.distractingOpens,
    workout: workout,
    completionPercent: completionPercent,
    awardedPoints: gained,
    fullCompletion: completionPercent >= 0.95,
    integrityPercent: integrityPercent,
    pointsError: pointsError,
    errorMessage: errorMessage,
  );
}

/// Scores a session that finished in the background (app closed or on another
/// screen), using its captured integrity [signals].
Future<void> processBackgroundCompletion(
  dynamic ref,
  String taskId,
  FocusSignals signals,
) async {
  final container = _getContainer(ref);
  final uid = container.read(authStateProvider).asData?.value?.uid;
  if (uid == null) return;
  final task = await container.read(taskRepositoryProvider).getTask(uid, taskId);
  if (task == null) return;
  await completeFocusSession(container, task, signals: signals);
}

/// Tasks whose points are being written right now (in-flight dedup within the
/// process). Permanent cross-session dedup is the persisted `pointsAwarded` flag.
final Set<String> _awardingTasks = {};

/// Idempotently marks [task] completed and writes its points to Firestore: the
/// daily `points` doc and the user's `weeklyPoints` / `totalPoints` (which the
/// Home, Profile and Leaderboard streams read live, so they refresh at once).
///
/// Safe to call from the daily-plan checkbox, the end-of-time auto-complete, and
/// the focus-session flow — it never awards a task twice. Returns the
/// [CompletionResult], or null if the task was already awarded / no user.
Future<CompletionResult?> completeAndAward(
  dynamic ref,
  Task task, {
  bool deep = false,
  bool blockingEngaged = false,
  double integrityPercent = 1.0,
  double? completionPercent,
  int? plannedMinutesOverride,
  int? focusedMinutesOverride,
  int timeAdjustmentSeconds = 0,
}) async {
  final container = _getContainer(ref);
  final uid = container.read(authStateProvider).asData?.value?.uid;
  if (uid == null) return null;
  if (!_awardingTasks.add(task.id)) return null; // already in flight
  try {
    final repo = container.read(taskRepositoryProvider);
    final fresh = await repo.getTask(uid, task.id);
    if (fresh != null && fresh.pointsAwarded) {
      debugPrint('[points] skip "${task.title}": already awarded');
      if (!fresh.isCompleted) await repo.setCompleted(uid, task.id, true);
      return null;
    }

    final plannedMinutes = plannedMinutesOverride ?? (task.durationMinutes + (timeAdjustmentSeconds / 60).round()).clamp(1, 1440);

    final cp = completionPercent ?? GamificationMath.calculateTaskCompletionPercent(
      plannedMinutes: plannedMinutes,
      actualMinutes: plannedMinutes,
    );
    // Base points are proportional to the session's planned minutes (after any
    // user adjustments), not the original task.points stored at creation time.
    final adjustedBasePoints = task.durationMinutes > 0 
        ? (task.points * (plannedMinutes / task.durationMinutes)).round()
        : task.points;

    final basePoints = GamificationMath.proportionalPoints(
      basePoints: adjustedBasePoints,
      completionPercent: cp,
    );
    final awardedPoints = (basePoints * integrityPercent).round();
    final fullCompletion = cp >= 0.95;
    debugPrint(
      '[completeAndAward] "${task.title}" '
      'plannedMin=${task.durationMinutes} '
      'adjustedMin=$plannedMinutes '
      'basePoints=${task.points} '
      'adjustedBasePoints=$adjustedBasePoints '
      'completionPercent=${cp.toStringAsFixed(2)} '
      'integrityPercent=${integrityPercent.toStringAsFixed(2)} '
      'awardedPoints=$awardedPoints',
    );

    final today = DateUtils.dateOnly(DateTime.now());
    final tasks =
        container.read(tasksForDayProvider(today)).asData?.value ?? const [];
    final completedIds =
        tasks.where((t) => t.isCompleted).map((t) => t.id).toSet()
          ..add(task.id);
    final total = tasks.isEmpty ? 1 : tasks.length;

    // Stamp completed + awarded first (idempotency), then write the points.
    await repo.markAwarded(uid, task.id);
    final result = await container
        .read(gamificationRepositoryProvider)
        .recordCompletion(
          uid,
          task: task,
          completedToday: completedIds.length,
          totalToday: total,
          deep: deep,
          blockingEngaged: blockingEngaged,
          completionPercent: cp,
          awardedPoints: awardedPoints,
          fullCompletion: fullCompletion,
          durationMinutesOverride: plannedMinutes,
          focusedMinutesOverride: focusedMinutesOverride,
        );
    debugPrint(
      '[points] awarded +${result.gained} for "${task.title}" '
      '(daily=${result.dailyPoints}, streak=${result.streak})',
    );
    return result;
  } catch (e, st) {
    debugPrint('[points] FAILED to award "${task.title}": $e\n$st');
    rethrow;
  } finally {
    _awardingTasks.remove(task.id);
  }
}
