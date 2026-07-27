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
  if (!end.isAfter(DateTime.now())) return;
  final shouldBlock =
      settings != null &&
      settings.blockedPackages.isNotEmpty &&
      (task.blockApps || settings.alwaysBlock);
  await service.scheduleSession(
    taskId: taskId,
    title: task.title,
    startAt: start,
    endAt: end,
    packages: shouldBlock ? settings.blockedPackages.toList() : const [],
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
    task.category == AppCategory.sport ||
    profile?.focusType == 'Sport' ||
    task.focusMethod == FocusMethod.custom;

/// Session runs already persisted this process, so a foreground finish and a
/// native "finished" event can't double-award / double-record. Counted runs
/// stay claimed for the process; uncounted runs release after a delay so the
/// user can retry the same task.
final Set<String> _handled = {};

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
  WidgetRef ref,
  Task task, {
  required FocusSignals signals,
  WorkoutResult? workout,
}) async {
  final uid = ref.read(authStateProvider).asData?.value?.uid;
  final profile = ref.read(userProfileProvider).asData?.value;
  final isSport = usesIntervalTimer(task, profile);

  final today = DateUtils.dateOnly(DateTime.now());
  final tasks = ref.read(tasksForDayProvider(today)).asData?.value ?? const [];

  // Stop the native foreground session (timer + notification), blocking, and
  // the ambient focus sound.
  await ref.read(focusServiceProvider).stopSession();
  await stopBlocking(ref);
  await ref.read(ambientSoundProvider.notifier).stopPlayback();

  Task? next;
  for (final t in tasks) {
    if (t.id != task.id && !t.isCompleted) {
      next = t;
      break;
    }
  }

  var verdict = HonestFocus.evaluate(signals);
  var counted = HonestFocus.counts(verdict);

  final integrityPercent = SessionIntegrity.calculateScore(
    signals: signals,
    checkInsPresented: signals.checkInsPresented,
    checkInsMissed: signals.checkInsMissed,
  );

  if (integrityPercent < 0.2) {
    counted = false;
    verdict = FocusVerdict.incomplete;
  }

  final completionPercent = GamificationMath.calculateTaskCompletionPercent(
    plannedMinutes: task.durationMinutes,
    actualMinutes: signals.focusedSeconds ~/ 60,
  );

  var gained = 0;
  var streak = profile?.streak ?? 0;
  int? milestone;

  // Claim this session run for persistence (first handler wins).
  if (uid != null && _handled.add(task.id)) {
    if (!counted) {
      // Let the user retry an uncounted task after a short window.
      Future.delayed(
        const Duration(seconds: 10),
        () => _handled.remove(task.id),
      );
    }

    if (counted) {
      // Idempotently mark complete + write points (daily / weekly / total).
      final result = await completeAndAward(
        ref,
        task,
        deep: !isSport,
        // Full bonus only when blocking was fully respected.
        blockingEngaged: HonestFocus.blockingRespected(signals),
        integrityPercent: integrityPercent,
      );
      if (result != null) {
        gained = result.gained;
        streak = result.streak;
        milestone = result.milestone;
      }
    }

    // Store the session result + signals in Firestore (counted or not).
    await ref
        .read(focusSessionRepositoryProvider)
        .record(
          uid: uid,
          taskId: task.id,
          taskTitle: task.title,
          verdict: verdict,
          signals: signals,
          points: gained,
          workout: workout,
        );

    // Persist the completion ratio so the daily plan can show partial progress.
    // We always write it (even for uncounted sessions) to reflect the real
    // effort — only overwrite with a higher value so a retry can't lower it.
    final existing = await ref
        .read(taskRepositoryProvider)
        .getTask(uid, task.id);
    final prevPercent = existing?.completionPercent ?? 0.0;
    if (completionPercent > prevPercent) {
      await ref
          .read(taskRepositoryProvider)
          .saveCompletionPercent(uid, task.id, completionPercent);
    }
  }

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
  );
}

/// Scores a session that finished in the background (app closed or on another
/// screen), using its captured integrity [signals].
Future<void> processBackgroundCompletion(
  WidgetRef ref,
  String taskId,
  FocusSignals signals,
) async {
  final uid = ref.read(authStateProvider).asData?.value?.uid;
  if (uid == null) return;
  final task = await ref.read(taskRepositoryProvider).getTask(uid, taskId);
  if (task == null) return;
  await completeFocusSession(ref, task, signals: signals);
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
  WidgetRef ref,
  Task task, {
  bool deep = false,
  bool blockingEngaged = false,
  double integrityPercent = 1.0,
}) async {
  final uid = ref.read(authStateProvider).asData?.value?.uid;
  if (uid == null) return null;
  if (!_awardingTasks.add(task.id)) return null; // already in flight
  try {
    final repo = ref.read(taskRepositoryProvider);
    final fresh = await repo.getTask(uid, task.id);
    if (fresh != null && fresh.pointsAwarded) {
      debugPrint('[points] skip "${task.title}": already awarded');
      if (!fresh.isCompleted) await repo.setCompleted(uid, task.id, true);
      return null;
    }

    final completionPercent = GamificationMath.calculateTaskCompletionPercent(
      plannedMinutes: task.durationMinutes,
      actualMinutes: task.durationMinutes,
    );
    final basePoints = GamificationMath.proportionalPoints(
      basePoints: task.points,
      completionPercent: completionPercent,
    );
    final awardedPoints = (basePoints * integrityPercent).round();
    final fullCompletion = completionPercent >= 0.95;

    final today = DateUtils.dateOnly(DateTime.now());
    final tasks =
        ref.read(tasksForDayProvider(today)).asData?.value ?? const [];
    final completedIds =
        tasks.where((t) => t.isCompleted).map((t) => t.id).toSet()
          ..add(task.id);
    final total = tasks.isEmpty ? 1 : tasks.length;

    // Stamp completed + awarded first (idempotency), then write the points.
    await repo.markAwarded(uid, task.id);
    final result = await ref
        .read(gamificationRepositoryProvider)
        .recordCompletion(
          uid,
          task: task,
          completedToday: completedIds.length,
          totalToday: total,
          deep: deep,
          blockingEngaged: blockingEngaged,
          completionPercent: completionPercent,
          awardedPoints: awardedPoints,
          fullCompletion: fullCompletion,
        );
    debugPrint(
      '[points] awarded +${result.gained} for "${task.title}" '
      '(daily=${result.dailyPoints}, streak=${result.streak})',
    );
    return result;
  } catch (e, st) {
    debugPrint('[points] FAILED to award "${task.title}": $e\n$st');
    return null;
  } finally {
    _awardingTasks.remove(task.id);
  }
}
