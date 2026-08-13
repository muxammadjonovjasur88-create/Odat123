import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class ExerciseEvaluationResult {
  const ExerciseEvaluationResult({
    required this.validRepAdded,
    required this.currentCount,
    required this.feedback,
    required this.formStatus, // 'GOOD', 'WARNING', 'INVALID'
    required this.currentPhase,
    required this.bodyVisible,
    this.avgAngle = 180.0,
  });

  final bool validRepAdded;
  final int currentCount;
  final String feedback;
  final String formStatus;
  final String currentPhase;
  final bool bodyVisible;
  final double avgAngle;
}

/// Abstract interface for all exercise evaluation strategies (Squat, PushUp, Plank).
abstract class ExerciseStrategy {
  String get exerciseType;
  int get repCount;
  int get durationSeconds;
  void reset();
  ExerciseEvaluationResult evaluateFrame(Pose pose, int timestampMs);
}
