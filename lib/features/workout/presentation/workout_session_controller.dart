import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/task.dart';
import '../../../core/services/locale_store.dart';
import '../../blocking/data/blocking_repository.dart';
import '../../blocking/data/blocking_service.dart';
import '../domain/workout.dart';

enum WorkoutPhase { ready, work, rest, finished }

/// Immutable state of a structured set-based workout in progress. The work
/// phase is open-ended (ended by "Done set"); rest phases are wall-clock
/// countdowns ([restEndsAt] − now), so they stay correct across backgrounding.
@immutable
class WorkoutSessionState {
  const WorkoutSessionState({
    required this.taskId,
    required this.plan,
    required this.phase,
    required this.exerciseIndex,
    required this.setNumber,
    required this.repsDone,
    required this.setsCompleted,
    required this.startedAt,
    required this.restEndsAt,
    required this.restTotal,
    required this.restBetweenExercises,
    required this.paused,
    required this.pausedRestRemaining,
  });

  final String taskId;
  final WorkoutPlan plan;
  final WorkoutPhase phase;

  /// Current exercise (0-based) and set within it (1-based).
  final int exerciseIndex;
  final int setNumber;

  /// Reps completed per exercise (accumulated).
  final List<int> repsDone;

  /// Total sets finished across all exercises (for overall progress).
  final int setsCompleted;

  final DateTime startedAt;

  /// Absolute end of the current rest, or null when not resting/paused.
  final DateTime? restEndsAt;
  final int restTotal;
  final bool restBetweenExercises;

  final bool paused;
  final int pausedRestRemaining;

  bool get isReady => phase == WorkoutPhase.ready;
  bool get isWork => phase == WorkoutPhase.work;
  bool get isRest => phase == WorkoutPhase.rest;
  bool get isFinished => phase == WorkoutPhase.finished;

  WorkoutExercise get exercise => plan.exercises[exerciseIndex];
  int get currentReps => exercise.repsForSet(setNumber);
  int get totalSets => plan.totalSets;

  int get restRemaining {
    if (paused) return pausedRestRemaining;
    final end = restEndsAt;
    if (end == null) return 0;
    return end.difference(DateTime.now()).inSeconds.clamp(0, restTotal);
  }

  /// Overall progress 0..1 by sets completed.
  double get progress => totalSets == 0 ? 0 : setsCompleted / totalSets;

  /// What follows the current rest, for the "Up next" card.
  String? get upNextLabel {
    if (!isRest) return null;
    if (restBetweenExercises) {
      final next = exerciseIndex + 1;
      if (next < plan.exercises.length) {
        return '${plan.exercises[next].name} · Set 1';
      }
      return null;
    }
    return '${exercise.name} · Set ${setNumber + 1}';
  }

  WorkoutSessionState copyWith({
    WorkoutPhase? phase,
    int? exerciseIndex,
    int? setNumber,
    List<int>? repsDone,
    int? setsCompleted,
    DateTime? restEndsAt,
    bool clearRestEnd = false,
    int? restTotal,
    bool? restBetweenExercises,
    bool? paused,
    int? pausedRestRemaining,
  }) {
    return WorkoutSessionState(
      taskId: taskId,
      plan: plan,
      startedAt: startedAt,
      phase: phase ?? this.phase,
      exerciseIndex: exerciseIndex ?? this.exerciseIndex,
      setNumber: setNumber ?? this.setNumber,
      repsDone: repsDone ?? this.repsDone,
      setsCompleted: setsCompleted ?? this.setsCompleted,
      restEndsAt: clearRestEnd ? null : (restEndsAt ?? this.restEndsAt),
      restTotal: restTotal ?? this.restTotal,
      restBetweenExercises: restBetweenExercises ?? this.restBetweenExercises,
      paused: paused ?? this.paused,
      pausedRestRemaining: pausedRestRemaining ?? this.pausedRestRemaining,
    );
  }

  /// The completed result so far (for the summary + Firestore).
  WorkoutResult result() {
    final exercises = <WorkoutExerciseResult>[];
    for (var i = 0; i < plan.exercises.length; i++) {
      final e = plan.exercises[i];
      exercises.add(
        WorkoutExerciseResult(
          name: e.name,
          repsCompleted: i < repsDone.length ? repsDone[i] : 0,
          totalReps: e.totalReps,
        ),
      );
    }
    return WorkoutResult(
      exercises: exercises,
      totalReps: repsDone.fold(0, (s, r) => s + r),
      totalSeconds: DateTime.now().difference(startedAt).inSeconds,
    );
  }
}

/// Drives a structured set-based workout. Persistent (non-autoDispose) so
/// leaving and returning to the Focus screen never resets progress.
class WorkoutSessionController extends Notifier<WorkoutSessionState?> {
  Timer? _ticker;

  @override
  WorkoutSessionState? build() {
    ref.onDispose(() => _ticker?.cancel());
    return null;
  }

  /// Ensures a (ready) session exists for [task]. Idempotent for the same task.
  void ensureStarted(Task task) {
    if (state?.taskId == task.id) return;
    final plan = task.workout;
    if (plan == null || plan.exercises.isEmpty) return;
    state = WorkoutSessionState(
      taskId: task.id,
      plan: plan,
      phase: WorkoutPhase.ready,
      exerciseIndex: 0,
      setNumber: 1,
      repsDone: List<int>.filled(plan.exercises.length, 0),
      setsCompleted: 0,
      startedAt: DateTime.now(),
      restEndsAt: null,
      restTotal: 0,
      restBetweenExercises: false,
      paused: false,
      pausedRestRemaining: 0,
    );
  }

  /// Begins the workout: starts blocking + the work phase + the rest ticker.
  void begin(Task task) {
    final s = state;
    if (s == null || !s.isReady) return;
    _startBlocking(task);
    state = s.copyWith(phase: WorkoutPhase.work, restTotal: 0);
    _ensureTicker();
  }

  void _ensureTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final s = state;
    if (s == null || !s.isRest || s.paused) return;
    
    // Force a rebuild every second so the countdown timer updates visually
    // even though restRemaining is calculated from restEndsAt
    if (s.restRemaining <= 0) {
      _advanceAfterRest();
    } else {
      // Touch state to force UI rebuild (this updates all listeners)
      state = s.copyWith();
    }
  }

  /// "Done set": count the reps, then rest (or advance / finish).
  void doneSet() => _completeSet(counted: true);

  /// "Skip set": advance past this set without counting reps.
  void skipSet() => _completeSet(counted: false);

  void _completeSet({required bool counted}) {
    final s = state;
    if (s == null || !s.isWork) return;

    final reps = [...s.repsDone];
    if (counted) reps[s.exerciseIndex] += s.currentReps;
    final setsDone = s.setsCompleted + 1;

    final isLastSet = s.setNumber >= s.exercise.sets;
    if (!isLastSet) {
      _startRest(
        s.copyWith(repsDone: reps, setsCompleted: setsDone),
        seconds: s.exercise.restSeconds,
        betweenExercises: false,
      );
      return;
    }

    final isLastExercise = s.exerciseIndex >= s.plan.exercises.length - 1;
    if (isLastExercise) {
      state = s.copyWith(
        repsDone: reps,
        setsCompleted: setsDone,
        phase: WorkoutPhase.finished,
        clearRestEnd: true,
      );
      return;
    }
    _startRest(
      s.copyWith(repsDone: reps, setsCompleted: setsDone),
      seconds: s.plan.restBetweenExercises,
      betweenExercises: true,
    );
  }

  void _startRest(
    WorkoutSessionState from, {
    required int seconds,
    required bool betweenExercises,
  }) {
    if (seconds <= 0) {
      state = from;
      _advanceAfterRest();
      return;
    }
    state = from.copyWith(
      phase: WorkoutPhase.rest,
      restEndsAt: DateTime.now().add(Duration(seconds: seconds)),
      restTotal: seconds,
      restBetweenExercises: betweenExercises,
      paused: false,
    );
  }

  void _advanceAfterRest() {
    final s = state;
    if (s == null) return;
    if (s.restBetweenExercises) {
      state = s.copyWith(
        phase: WorkoutPhase.work,
        exerciseIndex: s.exerciseIndex + 1,
        setNumber: 1,
        clearRestEnd: true,
        paused: false,
      );
    } else {
      state = s.copyWith(
        phase: WorkoutPhase.work,
        setNumber: s.setNumber + 1,
        clearRestEnd: true,
        paused: false,
      );
    }
  }

  /// Skip the remaining rest and advance now.
  void skipRest() {
    if (state?.isRest ?? false) _advanceAfterRest();
  }

  /// Add/subtract rest time on the fly (during rest).
  void adjustRest(int deltaSeconds) {
    final s = state;
    if (s == null || !s.isRest) return;
    final newTotal = (s.restTotal + deltaSeconds).clamp(5, 3600);
    if (s.paused) {
      state = s.copyWith(
        restTotal: newTotal,
        pausedRestRemaining: (s.pausedRestRemaining + deltaSeconds).clamp(
          0,
          newTotal,
        ),
      );
    } else {
      final newRemaining = (s.restRemaining + deltaSeconds).clamp(0, newTotal);
      state = s.copyWith(
        restTotal: newTotal,
        restEndsAt: DateTime.now().add(Duration(seconds: newRemaining)),
      );
    }
  }

  /// Pause/resume the rest countdown.
  void togglePause() {
    final s = state;
    if (s == null || !s.isRest) return;
    if (s.paused) {
      state = s.copyWith(
        paused: false,
        restEndsAt: DateTime.now().add(
          Duration(seconds: s.pausedRestRemaining),
        ),
      );
    } else {
      state = s.copyWith(paused: true, pausedRestRemaining: s.restRemaining);
    }
  }

  /// End the session early — counts whatever's been done so far.
  void finishNow() {
    final s = state;
    if (s == null) return;
    state = s.copyWith(phase: WorkoutPhase.finished, clearRestEnd: true);
  }

  void clear() {
    _ticker?.cancel();
    _ticker = null;
    state = null;
  }

  void _startBlocking(Task task) {
    final settings = ref.read(blockingSettingsProvider).asData?.value;
    if (settings == null || settings.blockedPackages.isEmpty) return;
    if (!(task.blockApps || settings.alwaysBlock)) return;
    final now = DateTime.now();
    final plan = task.workout;
    final estimate = plan == null ? 1800 : plan.estimatedSeconds + 600;
    ref
        .read(blockingServiceProvider)
        .startSession(
          packages: settings.blockedPackages.toList(),
          startAt: now,
          endTime: now.add(Duration(seconds: estimate.clamp(300, 10800))),
          strict: settings.strictMode,
          lang: LocaleStore.effectiveCode(),
        );
  }
}

final workoutSessionProvider =
    NotifierProvider<WorkoutSessionController, WorkoutSessionState?>(
      WorkoutSessionController.new,
    );
