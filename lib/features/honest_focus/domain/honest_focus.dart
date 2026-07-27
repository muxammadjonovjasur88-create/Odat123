/// Whether a finished session earns full, partial, or no points.
enum FocusVerdict { full, partial, incomplete }

/// The live integrity signals captured by the native foreground service during
/// a focus session.
class FocusSignals {
  const FocusSignals({
    this.timerCompleted = false,
    this.distractingOpens = 0,
    this.awayCount = 0,
    this.awaySeconds = 0,
    this.totalSeconds = 0,
    this.checkInsPresented = 0,
    this.checkInsMissed = 0,
  });

  /// Whether the full task duration genuinely elapsed in real clock time (the
  /// native session reached its end), vs the user ending early.
  final bool timerCompleted;

  /// Times a blocked / distracting app was opened during the session.
  final int distractingOpens;

  /// Times the user left Flowa to another app while the screen was on.
  final int awayCount;

  /// Seconds spent in another app during the session.
  final int awaySeconds;

  /// The session's full length in seconds.
  final int totalSeconds;

  /// Check-ins presented to the user during this session.
  final int checkInsPresented;

  /// Check-ins missed by the user.
  final int checkInsMissed;

  /// Seconds genuinely spent focused (locked or in Flowa).
  int get focusedSeconds => (totalSeconds - awaySeconds).clamp(0, totalSeconds);

  FocusSignals copyWith({
    bool? timerCompleted,
    int? distractingOpens,
    int? awayCount,
    int? awaySeconds,
    int? totalSeconds,
    int? checkInsPresented,
    int? checkInsMissed,
  }) => FocusSignals(
    timerCompleted: timerCompleted ?? this.timerCompleted,
    distractingOpens: distractingOpens ?? this.distractingOpens,
    awayCount: awayCount ?? this.awayCount,
    awaySeconds: awaySeconds ?? this.awaySeconds,
    totalSeconds: totalSeconds ?? this.totalSeconds,
    checkInsPresented: checkInsPresented ?? this.checkInsPresented,
    checkInsMissed: checkInsMissed ?? this.checkInsMissed,
  );

  factory FocusSignals.fromMap(Map<dynamic, dynamic> m) => FocusSignals(
    timerCompleted: (m['completed'] as bool?) ?? false,
    distractingOpens: (m['distractingOpens'] as num?)?.toInt() ?? 0,
    awayCount: (m['awayCount'] as num?)?.toInt() ?? 0,
    awaySeconds: (m['awaySeconds'] as num?)?.toInt() ?? 0,
    totalSeconds: (m['totalSeconds'] as num?)?.toInt() ?? 0,
    checkInsPresented: (m['checkInsPresented'] as num?)?.toInt() ?? 0,
    checkInsMissed: (m['checkInsMissed'] as num?)?.toInt() ?? 0,
  );
}

/// Pure scoring for "Honest Focus" — decides whether a session counts, based on
/// the integrity signals. Firebase-free so it can be unit-tested.
///
/// * **Full**: the timer genuinely completed, no distracting-app opens, and the
///   user didn't spend much time away.
/// * **Partial**: completed, but blocking was broken a little (a couple of
///   distractions / some time away) — still counts, with reduced points.
/// * **Incomplete**: quit early, or spent most of the session in other apps —
///   no points.
abstract final class HonestFocus {
  HonestFocus._();

  /// Distracting-app opens at/after which a completed session no longer counts.
  static const int brokenOpens = 5;

  /// Fraction of the session spent away at/after which it no longer counts.
  static const double brokenAwayRatio = 0.5;

  /// Fraction of the session spent away above which it's only partial.
  static const double partialAwayRatio = 0.2;

  static double awayRatio(FocusSignals s) =>
      s.totalSeconds <= 0 ? 0 : s.awaySeconds / s.totalSeconds;

  static FocusVerdict evaluate(FocusSignals s) {
    if (!s.timerCompleted) return FocusVerdict.incomplete;
    final ratio = awayRatio(s);
    if (s.distractingOpens >= brokenOpens || ratio >= brokenAwayRatio) {
      return FocusVerdict.incomplete;
    }
    if (s.distractingOpens > 0 || ratio > partialAwayRatio) {
      return FocusVerdict.partial;
    }
    return FocusVerdict.full;
  }

  static bool counts(FocusVerdict v) => v != FocusVerdict.incomplete;

  /// Whether blocking was fully respected (drives the full points bonus).
  static bool blockingRespected(FocusSignals s) =>
      s.distractingOpens == 0 && awayRatio(s) <= partialAwayRatio;
}
