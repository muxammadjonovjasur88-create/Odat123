import 'dart:math' as math;

/// One exercise in a structured set-based workout (e.g. "Pull-ups, 100 total,
/// 20 per set"). The number of sets is derived from the reps.
class WorkoutExercise {
  const WorkoutExercise({
    required this.name,
    required this.totalReps,
    required this.repsPerSet,
    required this.restSeconds,
  });

  final String name;
  final int totalReps;

  /// Target reps per set; the last set holds any remainder.
  final int repsPerSet;

  /// Rest between sets of this exercise (suggested, user-editable).
  final int restSeconds;

  /// Number of sets = ceil(total / perSet), at least 1.
  int get sets =>
      repsPerSet <= 0 ? 1 : math.max(1, (totalReps / repsPerSet).ceil());

  /// Reps for [setNumber] (1-based) — the final set takes the remainder.
  int repsForSet(int setNumber) {
    if (setNumber < sets) return repsPerSet;
    final remainder = totalReps - (sets - 1) * repsPerSet;
    return remainder <= 0 ? repsPerSet : remainder;
  }

  /// Suggested rest from set intensity (heavier, low-rep sets rest longer).
  static int suggestedRest(int repsPerSet) {
    if (repsPerSet <= 0) return 60;
    if (repsPerSet <= 6) return 120; // heavy strength
    if (repsPerSet <= 10) return 90;
    if (repsPerSet <= 15) return 60;
    if (repsPerSet <= 20) return 45;
    return 30; // light / high-rep
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'totalReps': totalReps,
    'repsPerSet': repsPerSet,
    'restSeconds': restSeconds,
  };

  factory WorkoutExercise.fromMap(Map<dynamic, dynamic> m) {
    final nameVal = m['name'];
    final totalRepsVal = m['totalReps'];
    final repsPerSetVal = m['repsPerSet'];
    final restSecondsVal = m['restSeconds'];

    return WorkoutExercise(
      name: nameVal is String ? nameVal : (nameVal?.toString() ?? ''),
      totalReps: totalRepsVal is num ? totalRepsVal.toInt() : 0,
      repsPerSet: repsPerSetVal is num ? repsPerSetVal.toInt() : 1,
      restSeconds: restSecondsVal is num ? restSecondsVal.toInt() : 60,
    );
  }
}

/// A full structured workout: an ordered list of exercises + the rest taken
/// between different exercises.
class WorkoutPlan {
  const WorkoutPlan({
    required this.exercises,
    required this.restBetweenExercises,
  });

  final List<WorkoutExercise> exercises;
  final int restBetweenExercises;

  static const int suggestedRestBetweenExercises = 90;

  int get totalSets => exercises.fold(0, (s, e) => s + e.sets);
  int get totalReps => exercises.fold(0, (s, e) => s + e.totalReps);

  bool get isValid =>
      exercises.isNotEmpty &&
      exercises.every(
        (e) => e.name.trim().isNotEmpty && e.totalReps > 0 && e.repsPerSet > 0,
      );

  /// Rough total seconds (≈40s work per set) — drives the planned block length
  /// and the blocking window.
  int get estimatedSeconds {
    var s = 0;
    for (final e in exercises) {
      s += e.sets * 40;
      s += (e.sets - 1).clamp(0, e.sets) * e.restSeconds;
    }
    s +=
        (exercises.length - 1).clamp(0, exercises.length) *
        restBetweenExercises;
    return s;
  }

  Map<String, dynamic> toMap() => {
    'exercises': exercises.map((e) => e.toMap()).toList(),
    'restBetweenExercises': restBetweenExercises,
  };

  factory WorkoutPlan.fromMap(Map<dynamic, dynamic> m) {
    final exercisesVal = m['exercises'];
    final restBetweenExercisesVal = m['restBetweenExercises'];

    return WorkoutPlan(
      exercises: (exercisesVal is List ? exercisesVal : const [])
          .whereType<Map>()
          .map(WorkoutExercise.fromMap)
          .toList(),
      restBetweenExercises: restBetweenExercisesVal is num
          ? restBetweenExercisesVal.toInt()
          : suggestedRestBetweenExercises,
    );
  }
}

/// The completed result of a workout, stored with the task.
class WorkoutResult {
  const WorkoutResult({
    required this.exercises,
    required this.totalReps,
    required this.totalSeconds,
  });

  final List<WorkoutExerciseResult> exercises;
  final int totalReps;
  final int totalSeconds;

  Map<String, dynamic> toMap() => {
    'exercises': exercises.map((e) => e.toMap()).toList(),
    'totalReps': totalReps,
    'totalSeconds': totalSeconds,
  };

  factory WorkoutResult.fromMap(Map<dynamic, dynamic> m) {
    final exercisesVal = m['exercises'];
    final totalRepsVal = m['totalReps'];
    final totalSecondsVal = m['totalSeconds'];

    return WorkoutResult(
      exercises: (exercisesVal is List ? exercisesVal : const [])
          .whereType<Map>()
          .map(WorkoutExerciseResult.fromMap)
          .toList(),
      totalReps: totalRepsVal is num ? totalRepsVal.toInt() : 0,
      totalSeconds: totalSecondsVal is num ? totalSecondsVal.toInt() : 0,
    );
  }
}

class WorkoutExerciseResult {
  const WorkoutExerciseResult({
    required this.name,
    required this.repsCompleted,
    required this.totalReps,
  });

  final String name;
  final int repsCompleted;
  final int totalReps;

  Map<String, dynamic> toMap() => {
    'name': name,
    'repsCompleted': repsCompleted,
    'totalReps': totalReps,
  };

  factory WorkoutExerciseResult.fromMap(Map<dynamic, dynamic> m) {
    final nameVal = m['name'];
    final repsCompletedVal = m['repsCompleted'];
    final totalRepsVal = m['totalReps'];

    return WorkoutExerciseResult(
      name: nameVal is String ? nameVal : (nameVal?.toString() ?? ''),
      repsCompleted: repsCompletedVal is num ? repsCompletedVal.toInt() : 0,
      totalReps: totalRepsVal is num ? totalRepsVal.toInt() : 0,
    );
  }
}
