import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/task.dart';
import '../../honest_focus/domain/honest_focus.dart';
import '../data/focus_providers.dart';
import '../data/focus_service.dart';

/// Whether the current phase is focused work or a rest/break.
enum FocusKind { work, rest }

enum FocusRunStatus { waiting, running, paused, finished }

/// A single work or rest block inside a segmented Deep Focus session.
@immutable
class FocusSegment {
  const FocusSegment({required this.kind, required this.seconds});

  final FocusKind kind;
  final int seconds;

  bool get isWork => kind == FocusKind.work;
  bool get isRest => kind == FocusKind.rest;
}

/// Builds the ordered list of [FocusSegment]s for a Deep Focus session.
///
/// Rule:
///   • If [totalWorkSeconds] ≤ 45 min (2700 s): a single work block.
///   • Otherwise: alternate 45-min work blocks with 5-min breaks until
///     all [totalWorkSeconds] of *work* are scheduled. The last work
///     block may be shorter than 45 min. No trailing rest is added.
///
/// Example: 120 min work →
///   Work(2700) Rest(300) Work(2700) Rest(300) Work(1800)
///   = 7200 s work + 600 s rest total.
List<FocusSegment> buildDeepFocusSegments(int totalWorkSeconds) {
  const int workChunk = 45 * 60; // 45 min
  const int restChunk = 5 * 60; //  5 min

  if (totalWorkSeconds <= workChunk) {
    return [FocusSegment(kind: FocusKind.work, seconds: totalWorkSeconds)];
  }

  final segments = <FocusSegment>[];
  int remaining = totalWorkSeconds;
  while (remaining > 0) {
    final work = math.min(remaining, workChunk);
    segments.add(FocusSegment(kind: FocusKind.work, seconds: work));
    remaining -= work;
    if (remaining > 0) {
      segments.add(FocusSegment(kind: FocusKind.rest, seconds: restChunk));
    }
  }
  return segments;
}

/// Holds an in-progress focus session. Lives in a persistent provider (above
/// the Focus screen), so navigating away and back never resets it. The
/// remaining time is always derived from the wall clock ([phaseEndsAt] − now),
/// so it stays correct across rebuilds, leaving the screen, or being backgrounded.
///
/// Phase lengths come from the task: [workSeconds] / [restSeconds] are the
/// user-entered work + auto break/rest, and [totalSets] the interval sets.
///
/// For Deep Focus (non-interval) sessions longer than 45 min the session is
/// automatically split into Pomodoro-style segments via [buildDeepFocusSegments].
/// [segments] holds the full plan and [segmentIndex] the current position.
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
    // Deep-focus auto-segmentation
    this.segments = const [],
    this.segmentIndex = 0,
    this.totalWorkSeconds = 0,
    this.completedWorkSeconds = 0,
    // Integrity signals
    this.distractingOpens = 0,
    this.awayCount = 0,
    this.awaySeconds = 0,
    this.finishedByTimer = false,
    this.checkInsPresented = 0,
    this.checkInsMissed = 0,
    this.isCheckInActive = false,
    this.checkInDeadline,
    // Segment-transition signal (cleared after one tick)
    this.segmentJustChanged = false,
    // Actual clock time when the countdown began (set in _begin()).
    this.actualSessionStart,
    // Cumulative seconds added (+) or removed (-) by the user during the session.
    // Used to adjust the effective planned duration for scoring.
    this.timeAdjustmentSeconds = 0,
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

  // ── Deep-focus auto-segmentation ────────────────────────────────────────
  /// Ordered list of work/rest blocks. Empty for interval sessions.
  final List<FocusSegment> segments;

  /// Index of the currently active segment.
  final int segmentIndex;

  /// Total scheduled *work* seconds for this deep-focus session.
  final int totalWorkSeconds;

  /// Accumulated *work* seconds already completed in past segments.
  final int completedWorkSeconds;

  /// True for exactly one tick after a segment transition (used by the UI
  /// to play a sound / vibrate).
  final bool segmentJustChanged;
  // ────────────────────────────────────────────────────────────────────────

  /// Live "honest focus" integrity signals, mirrored from the native service.
  final int distractingOpens;
  final int awayCount;
  final int awaySeconds;

  /// True only when the session ended because the clock genuinely ran out —
  /// NOT when the user skipped or ended early. This is what makes completion
  /// earned by real elapsed time rather than a button tap.
  final bool finishedByTimer;

  final int checkInsPresented;
  final int checkInsMissed;
  final bool isCheckInActive;
  final DateTime? checkInDeadline;

  /// The real wall-clock moment the countdown actually started
  /// (set inside [FocusSessionController._begin]). Null while waiting.
  final DateTime? actualSessionStart;

  /// Cumulative seconds the user has added (+) or removed (-) via the
  /// in-session time-adjust buttons. Persisted through [copyWith] and
  /// surfaced in [toSignals] so scoring can use the effective planned duration.
  final int timeAdjustmentSeconds;

  /// Seconds elapsed since the countdown genuinely began.
  /// Falls back to scheduledEnd–scheduledStart if the actual start wasn't
  /// captured yet (e.g. for background-completed sessions).
  int get totalSessionSeconds {
    final start = actualSessionStart;
    final int scheduledSeconds = scheduledEnd.difference(scheduledStart).inSeconds;
    final int effectiveScheduledSeconds = scheduledSeconds + timeAdjustmentSeconds;

    if (start != null) {
      return DateTime.now().difference(start).inSeconds.clamp(
        0,
        effectiveScheduledSeconds + 60,
      );
    }
    return effectiveScheduledSeconds;
  }

  /// The "Honest Focus" integrity signals for scoring this session.
  FocusSignals toSignals() {
    final total = totalSessionSeconds;
    final focused = (total - awaySeconds).clamp(0, total);
    final isCompleted = finishedByTimer || isFinished || remainingSeconds <= 0;
    debugPrint(
      '[toSignals] taskId=$taskId timerCompleted=$isCompleted '
      '(finishedByTimer=$finishedByTimer, isFinished=$isFinished, remainingSeconds=$remainingSeconds) '
      'total=${total}s away=${awaySeconds}s focused=${focused}s '
      'actualStart=$actualSessionStart '
      'timeAdjustment=${timeAdjustmentSeconds}s',
    );
    return FocusSignals(
      timerCompleted: isCompleted,
      distractingOpens: distractingOpens,
      awayCount: awayCount,
      awaySeconds: awaySeconds,
      totalSeconds: total,
      checkInsPresented: checkInsPresented,
      checkInsMissed: checkInsMissed,
      timeAdjustmentSeconds: timeAdjustmentSeconds,
    );
  }

  bool get isWaiting => status == FocusRunStatus.waiting;
  bool get isRunning => status == FocusRunStatus.running;
  bool get isPaused => status == FocusRunStatus.paused;
  bool get isFinished => status == FocusRunStatus.finished;

  /// Whether this deep-focus session uses auto-segmentation (>45 min work).
  bool get isSegmented => !isInterval && segments.length > 1;

  /// Full length of the current phase, for the per-phase progress ring.
  int get currentPhaseSeconds {
    if (isSegmented && segmentIndex < segments.length) {
      return segments[segmentIndex].seconds;
    }
    return kind == FocusKind.work ? workSeconds : restSeconds;
  }

  /// Overall progress across the whole session (0.0–1.0).
  /// For segmented sessions: work done / total work.
  /// For single-block or interval sessions: same as phase progress.
  double get overallProgress {
    if (isSegmented && totalWorkSeconds > 0) {
      final doneWork = kind == FocusKind.work
          ? completedWorkSeconds + (currentPhaseSeconds - remainingSeconds).clamp(0, currentPhaseSeconds)
          : completedWorkSeconds;
      return (doneWork / totalWorkSeconds).clamp(0.0, 1.0);
    }
    if (currentPhaseSeconds <= 0) return 0.0;
    return (1 - remainingSeconds / currentPhaseSeconds).clamp(0.0, 1.0);
  }

  FocusSessionState copyWith({
    FocusRunStatus? status,
    FocusKind? kind,
    int? remainingSeconds,
    DateTime? phaseEndsAt,
    bool clearPhaseEnd = false,
    int? completedWork,
    int? setNumber,
    int? phaseIndex,
    int? segmentIndex,
    int? completedWorkSeconds,
    bool? segmentJustChanged,
    int? distractingOpens,
    int? awayCount,
    int? awaySeconds,
    bool? finishedByTimer,
    int? checkInsPresented,
    int? checkInsMissed,
    bool? isCheckInActive,
    DateTime? checkInDeadline,
    DateTime? actualSessionStart,
    bool clearActualStart = false,
    int? workSeconds,
    int? restSeconds,
    int? timeAdjustmentSeconds,
  }) {
    return FocusSessionState(
      taskId: taskId,
      isInterval: isInterval,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      totalSets: totalSets,
      workSeconds: workSeconds ?? this.workSeconds,
      restSeconds: restSeconds ?? this.restSeconds,
      segments: segments,
      totalWorkSeconds: totalWorkSeconds,
      status: status ?? this.status,
      kind: kind ?? this.kind,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      phaseEndsAt: clearPhaseEnd ? null : (phaseEndsAt ?? this.phaseEndsAt),
      completedWork: completedWork ?? this.completedWork,
      setNumber: setNumber ?? this.setNumber,
      phaseIndex: phaseIndex ?? this.phaseIndex,
      segmentIndex: segmentIndex ?? this.segmentIndex,
      completedWorkSeconds: completedWorkSeconds ?? this.completedWorkSeconds,
      segmentJustChanged: segmentJustChanged ?? this.segmentJustChanged,
      distractingOpens: distractingOpens ?? this.distractingOpens,
      awayCount: awayCount ?? this.awayCount,
      awaySeconds: awaySeconds ?? this.awaySeconds,
      finishedByTimer: finishedByTimer ?? this.finishedByTimer,
      checkInsPresented: checkInsPresented ?? this.checkInsPresented,
      checkInsMissed: checkInsMissed ?? this.checkInsMissed,
      isCheckInActive: isCheckInActive ?? this.isCheckInActive,
      checkInDeadline: checkInDeadline ?? this.checkInDeadline,
      actualSessionStart:
          clearActualStart ? null : (actualSessionStart ?? this.actualSessionStart),
      timeAdjustmentSeconds: timeAdjustmentSeconds ?? this.timeAdjustmentSeconds,
    );
  }
}

class FocusSessionController extends Notifier<FocusSessionState?> with WidgetsBindingObserver {
  Timer? _ticker;
  StreamSubscription<FocusTick>? _nativeSub;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  DateTime? _pausedAt;
  int _lastCheckInElapsed = 0;

  @override
  FocusSessionState? build() {
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    ref.onDispose(() {
      binding.removeObserver(this);
      _ticker?.cancel();
      _ticker = null;       // ← null QILISH shart: _ensureTicker ??= ishlasin
      _nativeSub?.cancel();
      _nativeSub = null;    // ← null QILISH shart: _listenNative qayta o'rnatsin
    });
    return null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final previousState = _lifecycleState;
    _lifecycleState = state;

    final s = this.state;
    if (s == null || !s.isRunning) return;

    if ((state == AppLifecycleState.paused || state == AppLifecycleState.inactive) &&
        (previousState == AppLifecycleState.resumed)) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _pausedAt != null) {
      final awayDuration = DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
      final awaySecs = awayDuration.inSeconds;
      if (awaySecs > 0) {
        // Exits under 20s are not counted towards awayCount
        final newAwaySeconds = s.awaySeconds + awaySecs;
        final newAwayCount = awaySecs >= 20 ? s.awayCount + 1 : s.awayCount;
        this.state = s.copyWith(
          awaySeconds: newAwaySeconds,
          awayCount: newAwayCount,
        );
      }
    }
  }

  /// Number of phases in the interval plan: W,R,…,W (rest between sets).
  int _intervalPhaseCount(int totalSets) => totalSets * 2 - 1;

  /// Ensures a session exists for [task]. Idempotent: if a session for the same
  /// task is already running, it is left untouched (this is what makes the timer
  /// survive navigating away and back).
  ///
  /// MUHIM: Navigatsiya paytida `onDispose` tikerni bekor qiladi va null ga
  /// o'rnatadi. Shu sababli, bir xil task uchun qaytganda ham ticker va native
  /// subscription QAYTA ishga tushirilishi kerak.
  void ensureStarted(Task task, {required bool isInterval}) {
    if (state?.taskId == task.id) {
      // Xuddi shu task — state saqlanadi, lekin ticker qayta ishga tushirilishi kerak
      // (navigatsiya paytida onDispose uni bekor qilgan bo'lishi mumkin).
      debugPrint(
        '[FocusController] ensureStarted: same task (${task.id}), '
        'ticker isActive=${_ticker?.isActive ?? false} — restarting ticker+native',
      );
      _ensureTicker();
      _listenNative();
      return;
    }
    clearHandledTask(task.id);

    final workSeconds = isInterval
        ? task.intervalWorkSeconds
        : task.workSeconds;
    final restSeconds = isInterval
        ? task.intervalRestSeconds
        : task.breakSeconds;
    final totalSets = isInterval ? task.intervalSets : 0;

    // Build segment plan for deep-focus (non-interval) sessions.
    final segments = isInterval
        ? const <FocusSegment>[]
        : buildDeepFocusSegments(workSeconds);
    final totalWorkSec = isInterval
        ? 0
        : segments.where((s) => s.isWork).fold(0, (sum, s) => sum + s.seconds);

    final initialRemaining = segments.isNotEmpty
        ? segments[0].seconds
        : workSeconds;
    final firstKind = segments.isNotEmpty
        ? segments[0].kind
        : FocusKind.work;

    state = FocusSessionState(
      taskId: task.id,
      isInterval: isInterval,
      status: FocusRunStatus.waiting,
      kind: firstKind,
      remainingSeconds: initialRemaining,
      scheduledStart: task.start,
      scheduledEnd: task.end,
      phaseEndsAt: null,
      completedWork: 0,
      setNumber: isInterval ? 1 : 0,
      totalSets: totalSets,
      phaseIndex: 0,
      workSeconds: workSeconds,
      restSeconds: restSeconds,
      segments: segments,
      segmentIndex: 0,
      totalWorkSeconds: totalWorkSec,
      completedWorkSeconds: 0,
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
      // If already finished in Flutter, don't overwrite status back to running!
      if (s.isFinished) return;

      // Always mirror the live integrity signals (combining native + flutter observers).
      var next = s.copyWith(
        distractingOpens: math.max(s.distractingOpens, tick.distractingOpens),
        awayCount: math.max(s.awayCount, tick.awayCount),
        awaySeconds: math.max(s.awaySeconds, tick.awaySeconds),
      );
      if (tick.isFinished || tick.remainingSeconds <= 0) {
        debugPrint(
          '[FocusController] _listenNative: native tick finished or remaining=0 '
          'for taskId=${tick.taskId}. Setting finishedByTimer=true.',
        );
        next = next.copyWith(
          status: FocusRunStatus.finished,
          remainingSeconds: 0,
          clearPhaseEnd: true,
          finishedByTimer: true,
        );
      } else if (!s.isInterval &&
          (s.isRunning || (s.isWaiting && tick.status == 'running')) &&
          !s.isSegmented) {
        // For single-block deep work, mirror native remaining seconds directly.
        final now = DateTime.now();
        // Also capture actualSessionStart if we just transitioned from waiting.
        next = next.copyWith(
          status: FocusRunStatus.running,
          remainingSeconds: tick.remainingSeconds,
          phaseEndsAt: now.add(Duration(seconds: tick.remainingSeconds)),
          actualSessionStart: s.actualSessionStart ?? now,
        );
      }
      state = next;
    });
  }

  void _ensureTicker() {
    // Agar eski ticker mavjud bo'lsa (cancel qilingan yoki emas) — uni bekor qilib,
    // null qilamiz, shundan keyin yangi ticker yaratamiz.
    if (_ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    debugPrint('[FocusController] _ensureTicker: yangi Timer.periodic yaratildi');
  }

  void _tick() {
    try {
      final s = state;
      if (s == null) {
        _ticker?.cancel();
        _ticker = null;
        return;
      }
      final now = DateTime.now();

      // Clear the one-tick segment-change signal
      FocusSessionState cur = s.segmentJustChanged
          ? s.copyWith(segmentJustChanged: false)
          : s;

      switch (cur.status) {
        case FocusRunStatus.waiting:
          if (!cur.scheduledStart.isAfter(now)) {
            _begin();
          } else {
            state = cur.copyWith(
              remainingSeconds: cur.scheduledStart.difference(now).inSeconds,
            );
          }
        case FocusRunStatus.running:
          final phaseEnd = cur.phaseEndsAt;
          final remaining = phaseEnd != null
              ? phaseEnd.difference(now).inSeconds
              : cur.remainingSeconds;

          FocusSessionState nextState = cur;

          // 1. Check-in expiration
          if (cur.isCheckInActive && cur.checkInDeadline != null) {
            if (now.isAfter(cur.checkInDeadline!)) {
              nextState = nextState.copyWith(
                isCheckInActive: false,
                checkInsMissed: cur.checkInsMissed + 1,
              );
            }
          }

          // 2. Trigger check-in every 5 mins (300s) if in foreground and not near end (>10s remaining)
          if (!nextState.isCheckInActive && _lifecycleState == AppLifecycleState.resumed && remaining > 10) {
            final int elapsed = nextState.totalSessionSeconds - remaining;
            if (elapsed - _lastCheckInElapsed >= 300) {
              _lastCheckInElapsed = elapsed - (elapsed % 300);
              nextState = nextState.copyWith(
                isCheckInActive: true,
                checkInsPresented: nextState.checkInsPresented + 1,
                checkInDeadline: now.add(const Duration(seconds: 45)),
              );
            }
          }

          if (remaining <= 0) {
            // Phase ended — advance and clear check-in
            debugPrint(
              '[FocusController] _tick: phase ended '
              '(taskId=${cur.taskId}, kind=${cur.kind}, remaining=$remaining). '
              'Calling _advance().',
            );
            _advance(countWork: true, baseState: nextState.copyWith(isCheckInActive: false));
          } else {
            state = nextState.copyWith(remainingSeconds: remaining);
          }
        case FocusRunStatus.paused:
        case FocusRunStatus.finished:
          break;
      }
    } catch (e, st) {
      debugPrint('[FocusController] ❌ _tick exception: $e\n$st');
    }
  }

  void _begin() {
    final s = state;
    if (s == null) return;
    final now = DateTime.now();
    clearHandledTask(s.taskId);
    // Capture the real start time for accurate totalSessionSeconds scoring.
    debugPrint('[FocusController] _begin() — session started at $now for taskId=${s.taskId}');

    if (s.isSegmented) {
      // Start from the first segment
      final firstSeg = s.segments[0];
      state = s.copyWith(
        status: FocusRunStatus.running,
        kind: firstSeg.kind,
        segmentIndex: 0,
        phaseIndex: 0,
        setNumber: 0,
        remainingSeconds: firstSeg.seconds,
        phaseEndsAt: now.add(Duration(seconds: firstSeg.seconds)),
        actualSessionStart: now,
        completedWork: 0,
        completedWorkSeconds: 0,
        distractingOpens: 0,
        awayCount: 0,
        awaySeconds: 0,
        finishedByTimer: false,
        checkInsPresented: 0,
        checkInsMissed: 0,
        isCheckInActive: false,
        timeAdjustmentSeconds: 0,
      );
    } else {
      state = s.copyWith(
        status: FocusRunStatus.running,
        kind: FocusKind.work,
        phaseIndex: 0,
        setNumber: s.isInterval ? 1 : 0,
        remainingSeconds: s.workSeconds,
        phaseEndsAt: now.add(Duration(seconds: s.workSeconds)),
        actualSessionStart: now,
        completedWork: 0,
        completedWorkSeconds: 0,
        distractingOpens: 0,
        awayCount: 0,
        awaySeconds: 0,
        finishedByTimer: false,
        checkInsPresented: 0,
        checkInsMissed: 0,
        isCheckInActive: false,
        timeAdjustmentSeconds: 0,
      );
    }
  }

  /// Advances to the next phase. [countWork] counts a finished work phase
  /// (auto-completion); a manual skip passes false.
  void _advance({required bool countWork, FocusSessionState? baseState}) {
    final s = baseState ?? state;
    if (s == null) return;
    final now = DateTime.now();
    debugPrint(
      '[FocusController] _advance() countWork=$countWork '
      'kind=${s.kind} isInterval=${s.isInterval} '
      'isSegmented=${s.isSegmented} phaseIndex=${s.phaseIndex}',
    );

    if (s.isInterval) {
      // ── Interval (sport) session: unchanged ──────────────────────────────
      final next = s.phaseIndex + 1;
      if (next >= _intervalPhaseCount(s.totalSets)) {
        state = s.copyWith(
          status: FocusRunStatus.finished,
          remainingSeconds: 0,
          clearPhaseEnd: true,
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
    } else if (s.isSegmented) {
      // ── Segmented deep-focus session ─────────────────────────────────────
      final finishedSeg = s.segments[s.segmentIndex];
      final newCompletedWork = finishedSeg.isWork && countWork
          ? s.completedWorkSeconds + finishedSeg.seconds
          : s.completedWorkSeconds;
      final newCompletedCount = finishedSeg.isWork && countWork
          ? s.completedWork + 1
          : s.completedWork;

      final nextIdx = s.segmentIndex + 1;
      if (nextIdx >= s.segments.length) {
        // All segments done → session finished
        state = s.copyWith(
          status: FocusRunStatus.finished,
          completedWork: newCompletedCount,
          completedWorkSeconds: newCompletedWork,
          remainingSeconds: 0,
          clearPhaseEnd: true,
          finishedByTimer: countWork,
        );
        return;
      }

      final nextSeg = s.segments[nextIdx];
      state = s.copyWith(
        segmentIndex: nextIdx,
        kind: nextSeg.kind,
        remainingSeconds: nextSeg.seconds,
        phaseEndsAt: now.add(Duration(seconds: nextSeg.seconds)),
        status: FocusRunStatus.running,
        completedWork: newCompletedCount,
        completedWorkSeconds: newCompletedWork,
        // Signal the UI to play a transition sound/vibration for one tick.
        segmentJustChanged: true,
      );
    } else {
      // ── Single-block deep-work: session finished ──────────────────────────
      state = s.copyWith(
        status: FocusRunStatus.finished,
        completedWork: countWork ? s.completedWork + 1 : s.completedWork,
        remainingSeconds: 0,
        clearPhaseEnd: true,
        finishedByTimer: countWork,
      );
    }
  }

  /// Begin the countdown immediately, skipping the wait for the scheduled time.
  void beginNow() {
    final s = state;
    if (s != null && (s.isWaiting || s.isFinished)) {
      _begin();
    }
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

  /// Skip to the next phase (Pomodoro / segmented deep-focus).
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

  /// Answers an active check-in prompt.
  void answerCheckIn() {
    final s = state;
    if (s == null || !s.isCheckInActive) return;
    state = s.copyWith(isCheckInActive: false);
  }

  /// Adds [deltaSeconds] to the current phase (positive = more time,
  /// negative = less time). The progress ring, remaining clock, and scoring
  /// are all kept in sync. Minimum remaining time is 60 seconds.
  ///
  /// Works for any session type: deep-focus (single or segmented) and interval.
  void adjustTime(int deltaSeconds) {
    final s = state;
    if (s == null || !s.isRunning || s.phaseEndsAt == null) return;

    // Clamp so we can't go below 60 s remaining.
    final newRemaining = (s.remainingSeconds + deltaSeconds).clamp(60, 24 * 3600);
    final actualDelta = newRemaining - s.remainingSeconds;
    if (actualDelta == 0) return;

    final newPhaseEndsAt = s.phaseEndsAt!.add(Duration(seconds: actualDelta));

    // Keep the "full phase" length in sync so the progress arc stays correct.
    final newWorkSeconds = s.kind == FocusKind.work
        ? (s.workSeconds + actualDelta).clamp(60, 24 * 3600)
        : s.workSeconds;
    final newRestSeconds = s.kind == FocusKind.rest
        ? (s.restSeconds + actualDelta).clamp(60, 24 * 3600)
        : s.restSeconds;

    debugPrint(
      '[FocusController] adjustTime: delta=${actualDelta}s '
      'remaining: ${s.remainingSeconds}→$newRemaining '
      'phaseEndsAt: ${s.phaseEndsAt}→$newPhaseEndsAt',
    );

    state = s.copyWith(
      remainingSeconds: newRemaining,
      phaseEndsAt: newPhaseEndsAt,
      workSeconds: newWorkSeconds,
      restSeconds: newRestSeconds,
      timeAdjustmentSeconds: s.timeAdjustmentSeconds + actualDelta,
    );
  }
}

final focusSessionProvider =
    NotifierProvider<FocusSessionController, FocusSessionState?>(
      FocusSessionController.new,
    );
