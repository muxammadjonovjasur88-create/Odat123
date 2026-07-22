import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/task.dart';
import '../../honest_focus/domain/honest_focus.dart';
import '../data/focus_service.dart';

/// Whether the current phase is focused work or a rest/break.
enum FocusKind { work, rest }

enum FocusRunStatus { waiting, running, paused, finished }

/// Holds an in-progress focus session. Lives in a persistent provider (above
/// the Focus screen), so navigating away and back never resets it. The
/// remaining time is always derived from the wall clock ([phaseEndsAt] − now),
/// so it stays correct across rebuilds, leaving the screen, or being backgrounded.
///
/// Phase lengths come from the task: [workSeconds] / [restSeconds] are the
/// user-entered work + auto break/rest, and [totalSets] the interval sets.
@immutable
class FocusSessionState {
  const FocusSessionState({
    required this.taskId,
    required this.isInterval,
    required this.status,
    required this.kind,
    required this.remainingSeconds,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.phaseEndsAt,
    required this.completedWork,
    required this.setNumber,
    required this.totalSets,
    required this.phaseIndex,
    required this.workSeconds,
    required this.restSeconds,
    this.distractingOpens = 0,
    this.awayCount = 0,
    this.awaySeconds = 0,
    this.finishedByTimer = false,
  });

  final String taskId;
  final bool isInterval;
  final FocusRunStatus status;
  final FocusKind kind;

  /// Display value, recomputed from the clock on every tick.
  final int remainingSeconds;

  final DateTime scheduledStart;
  final DateTime scheduledEnd;

  /// Absolute time the current phase ends (null while waiting/paused).
  final DateTime? phaseEndsAt;

  /// Pomodoro work phases completed (for display).
  final int completedWork;

  /// Interval set number / total (1-based). Unused for Pomodoro.
  final int setNumber;
  final int totalSets;

  /// Index into the interval plan. Unused for Pomodoro.
  final int phaseIndex;

  /// Configured work/rest lengths for this session (seconds).
  final int workSeconds;
  final int restSeconds;

  /// Live "honest focus" integrity signals, mirrored from the native service.
  final int distractingOpens;
  final int awayCount;
  final int awaySeconds;

  /// True only when the session ended because the clock genuinely ran out —
  /// NOT when the user skipped or ended early. This is what makes completion
  /// earned by real elapsed time rather than a button tap.
  final bool finishedByTimer;

  /// The session's full length (seconds), for integrity scoring.
  int get totalSessionSeconds =>
      scheduledEnd.difference(scheduledStart).inSeconds;

  /// The "Honest Focus" integrity signals for scoring this session.
  FocusSignals toSignals() => FocusSignals(
    timerCompleted: finishedByTimer,
    distractingOpens: distractingOpens,
    awayCount: awayCount,
    awaySeconds: awaySeconds,
    totalSeconds: totalSessionSeconds,
  );

  bool get isWaiting => status == FocusRunStatus.waiting;
  bool get isRunning => status == FocusRunStatus.running;
  bool get isPaused => status == FocusRunStatus.paused;
  bool get isFinished => status == FocusRunStatus.finished;

  /// Full length of the current phase, for the progress ring.
  int get currentPhaseSeconds =>
      kind == FocusKind.work ? workSeconds : restSeconds;

  FocusSessionState copyWith({
    FocusRunStatus? status,
    FocusKind? kind,
    int? remainingSeconds,
    DateTime? phaseEndsAt,
    bool clearPhaseEnd = false,
    int? completedWork,
    int? setNumber,
    int? phaseIndex,
    int? distractingOpens,
    int? awayCount,
    int? awaySeconds,
    bool? finishedByTimer,
  }) {
    return FocusSessionState(
      taskId: taskId,
      isInterval: isInterval,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      totalSets: totalSets,
      workSeconds: workSeconds,
      restSeconds: restSeconds,
      status: status ?? this.status,
      kind: kind ?? this.kind,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      phaseEndsAt: clearPhaseEnd ? null : (phaseEndsAt ?? this.phaseEndsAt),
      completedWork: completedWork ?? this.completedWork,
      setNumber: setNumber ?? this.setNumber,
      phaseIndex: phaseIndex ?? this.phaseIndex,
      distractingOpens: distractingOpens ?? this.distractingOpens,
      awayCount: awayCount ?? this.awayCount,
      awaySeconds: awaySeconds ?? this.awaySeconds,
      finishedByTimer: finishedByTimer ?? this.finishedByTimer,
    );
  }
}

class FocusSessionController extends Notifier<FocusSessionState?> {
  Timer? _ticker;
  StreamSubscription<FocusTick>? _nativeSub;

  @override
  FocusSessionState? build() {
    ref.onDispose(() {
      _ticker?.cancel();
      _nativeSub?.cancel();
    });
    return null;
  }

  /// Number of phases in the interval plan: W,R,…,W (rest between sets).
  int _intervalPhaseCount(int totalSets) => totalSets * 2 - 1;

  /// Ensures a session exists for [task]. Idempotent: if a session for the same
  /// task is already running, it is left untouched (this is what makes the timer
  /// survive navigating away and back).
  void ensureStarted(Task task, {required bool isInterval}) {
    if (state?.taskId == task.id) return;

    final workSeconds = isInterval
        ? task.intervalWorkSeconds
        : task.workSeconds;
    final restSeconds = isInterval
        ? task.intervalRestSeconds
        : task.breakSeconds;
    final totalSets = isInterval ? task.intervalSets : 0;

    final now = DateTime.now();
    final waiting = task.start.isAfter(now);

    // For deep work (a single background countdown) anchor the phase end to the
    // scheduled start, so opening the app mid-session shows the SAME remaining
    // time as the background foreground-service notification — rather than
    // restarting the countdown from "now".
    FocusRunStatus status;
    int remaining;
    DateTime? phaseEndsAt;
    if (waiting) {
      status = FocusRunStatus.waiting;
      remaining = task.start.difference(now).inSeconds;
      phaseEndsAt = null;
    } else if (!isInterval) {
      final end = task.start.add(Duration(seconds: workSeconds));
      remaining = end.difference(now).inSeconds;
      if (remaining <= 0) {
        status = FocusRunStatus.finished;
        remaining = 0;
        phaseEndsAt = null;
      } else {
        status = FocusRunStatus.running;
        phaseEndsAt = end;
      }
    } else {
      status = FocusRunStatus.running;
      remaining = workSeconds;
      phaseEndsAt = now.add(Duration(seconds: workSeconds));
    }

    state = FocusSessionState(
      taskId: task.id,
      isInterval: isInterval,
      status: status,
      kind: FocusKind.work,
      remainingSeconds: remaining,
      scheduledStart: task.start,
      scheduledEnd: task.end,
      phaseEndsAt: phaseEndsAt,
      completedWork: 0,
      setNumber: isInterval ? 1 : 0,
      totalSets: totalSets,
      phaseIndex: 0,
      workSeconds: workSeconds,
      restSeconds: restSeconds,
    );
    _ensureTicker();
    _listenNative();
  }

  /// Locks the in-app timer to the native background session: each tick from
  /// the foreground service updates the remaining time (deep work) and finishes
  /// the session when the service does. Interval sessions keep their own
  /// per-phase display but still finish when the service reports it.
  void _listenNative() {
    _nativeSub?.cancel();
    _nativeSub = ref.read(focusServiceProvider).events().listen((tick) {
      final s = state;
      if (s == null || tick.taskId != s.taskId) return;
      // Always mirror the live integrity signals.
      var next = s.copyWith(
        distractingOpens: tick.distractingOpens,
        awayCount: tick.awayCount,
        awaySeconds: tick.awaySeconds,
      );
      if (tick.isFinished) {
        if (!s.isFinished) {
          // The native service only reports finished at the real end time, so
          // this is a genuine, timer-driven completion.
          next = next.copyWith(
            status: FocusRunStatus.finished,
            remainingSeconds: 0,
            clearPhaseEnd: true,
            finishedByTimer: true,
          );
        }
      } else if (!s.isInterval && s.isRunning) {
        final now = DateTime.now();
        next = next.copyWith(
          remainingSeconds: tick.remainingSeconds,
          phaseEndsAt: now.add(Duration(seconds: tick.remainingSeconds)),
        );
      }
      state = next;
    });
  }

  void _ensureTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final s = state;
    if (s == null) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    final now = DateTime.now();
    switch (s.status) {
      case FocusRunStatus.waiting:
        if (!s.scheduledStart.isAfter(now)) {
          _begin();
        } else {
          state = s.copyWith(
            remainingSeconds: s.scheduledStart.difference(now).inSeconds,
          );
        }
      case FocusRunStatus.running:
        final remaining = s.phaseEndsAt!.difference(now).inSeconds;
        if (remaining <= 0) {
          _advance(countWork: true);
        } else {
          state = s.copyWith(remainingSeconds: remaining);
        }
      case FocusRunStatus.paused:
      case FocusRunStatus.finished:
        break;
    }
  }

  void _begin() {
    final s = state;
    if (s == null) return;
    state = s.copyWith(
      status: FocusRunStatus.running,
      kind: FocusKind.work,
      phaseIndex: 0,
      setNumber: s.isInterval ? 1 : 0,
      remainingSeconds: s.workSeconds,
      phaseEndsAt: DateTime.now().add(Duration(seconds: s.workSeconds)),
    );
  }

  /// Advances to the next phase. [countWork] counts a finished work phase
  /// (auto-completion); a manual skip passes false.
  void _advance({required bool countWork}) {
    final s = state;
    if (s == null) return;
    final now = DateTime.now();

    if (s.isInterval) {
      final next = s.phaseIndex + 1;
      if (next >= _intervalPhaseCount(s.totalSets)) {
        state = s.copyWith(
          status: FocusRunStatus.finished,
          remainingSeconds: 0,
          clearPhaseEnd: true,
          // Only an honest completion when the clock ran out (countWork), not a
          // manual skip/end.
          finishedByTimer: countWork,
        );
        return;
      }
      final isWork = next.isEven;
      final seconds = isWork ? s.workSeconds : s.restSeconds;
      state = s.copyWith(
        phaseIndex: next,
        kind: isWork ? FocusKind.work : FocusKind.rest,
        setNumber: (next ~/ 2) + 1,
        status: FocusRunStatus.running,
        remainingSeconds: seconds,
        phaseEndsAt: now.add(Duration(seconds: seconds)),
      );
    } else {
      // Deep-work is a single background countdown (Forest-style): when the
      // work block ends, the session is finished — it does not loop into a
      // break — so it matches the native foreground-service session that runs
      // to the task's end time.
      state = s.copyWith(
        status: FocusRunStatus.finished,
        completedWork: countWork ? s.completedWork + 1 : s.completedWork,
        remainingSeconds: 0,
        clearPhaseEnd: true,
        // Honest completion only when the clock ran out, not a manual skip/end.
        finishedByTimer: countWork,
      );
    }
  }

  /// Begin the countdown immediately, skipping the wait for the scheduled time.
  void beginNow() {
    if (state?.isWaiting ?? false) _begin();
  }

  void togglePause() {
    final s = state;
    if (s == null) return;
    if (s.isRunning) {
      state = s.copyWith(status: FocusRunStatus.paused, clearPhaseEnd: true);
    } else if (s.isPaused) {
      state = s.copyWith(
        status: FocusRunStatus.running,
        phaseEndsAt: DateTime.now().add(Duration(seconds: s.remainingSeconds)),
      );
    }
  }

  /// Restart the current phase (Pomodoro).
  void reset() {
    final s = state;
    if (s == null || s.isWaiting) return;
    final seconds = s.currentPhaseSeconds;
    state = s.copyWith(
      status: FocusRunStatus.running,
      remainingSeconds: seconds,
      phaseEndsAt: DateTime.now().add(Duration(seconds: seconds)),
    );
  }

  /// Skip to the next phase (Pomodoro).
  void skip() {
    if (state?.isWaiting ?? true) return;
    _advance(countWork: false);
  }

  /// Interval: jump to the next phase (or finish).
  void next() {
    if (state?.isWaiting ?? true) return;
    _advance(countWork: false);
  }

  /// Interval: go back to the previous phase.
  void previous() {
    final s = state;
    if (s == null || s.isWaiting || !s.isInterval) return;
    final prev = (s.phaseIndex - 1).clamp(0, _intervalPhaseCount(s.totalSets));
    final isWork = prev.isEven;
    final seconds = isWork ? s.workSeconds : s.restSeconds;
    state = s.copyWith(
      phaseIndex: prev,
      kind: isWork ? FocusKind.work : FocusKind.rest,
      setNumber: (prev ~/ 2) + 1,
      status: FocusRunStatus.running,
      remainingSeconds: seconds,
      phaseEndsAt: DateTime.now().add(Duration(seconds: seconds)),
    );
  }

  /// Ends the session (the caller persists completion + navigates).
  void clear() {
    _ticker?.cancel();
    _ticker = null;
    _nativeSub?.cancel();
    _nativeSub = null;
    state = null;
  }
}

final focusSessionProvider =
    NotifierProvider<FocusSessionController, FocusSessionState?>(
      FocusSessionController.new,
    );
