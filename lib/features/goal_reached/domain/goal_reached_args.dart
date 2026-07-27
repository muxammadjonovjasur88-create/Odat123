import '../../honest_focus/domain/honest_focus.dart';
import '../../workout/domain/workout.dart';

/// Data passed to the Goal Reached screen (14) after a focus session completes.
class GoalReachedArgs {
  const GoalReachedArgs({
    required this.points,
    required this.taskTitle,
    required this.streak,
    required this.isSport,
    this.nextTaskTitle,
    this.milestone,
    this.verdict = FocusVerdict.full,
    this.focusSeconds = 0,
    this.distractions = 0,
    this.workout,
    this.completionPercent = 1.0,
    this.awardedPoints = 0,
    this.fullCompletion = true,
    this.integrityPercent = 1.0,
  });

  /// Set-based workout result, when the completed task was a structured workout.
  final WorkoutResult? workout;

  final int points;
  final String taskTitle;
  final int streak;

  /// The streak milestone (3/7/30/100) newly reached, if this completion
  /// crossed one — triggers the celebratory overlay.
  final int? milestone;

  /// The "Honest Focus" outcome and the signals behind it, for the summary.
  final FocusVerdict verdict;
  final int focusSeconds;
  final int distractions;

  bool get counted => HonestFocus.counts(verdict);

  /// Whether the completed session was a sport interval (vs deep work) — only
  /// changes the celebratory copy.
  final bool isSport;

  /// The next task to suggest under "Up Next", if any.
  final String? nextTaskTitle;

  /// Completion percentage for the just-finished task (0..1).
  final double completionPercent;

  /// Points that were actually awarded for this task after proportional logic.
  final int awardedPoints;

  /// Whether the task was effectively completed at 95%+.
  final bool fullCompletion;

  /// Integrity score of the session (1.0 = fully honest, <1.0 = partial).
  final double integrityPercent;
}
