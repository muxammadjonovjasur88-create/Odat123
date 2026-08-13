import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Single pose landmark representation with 3D coordinates and visibility likelihood.
@immutable
class ExerciseLandmark {
  const ExerciseLandmark({
    required this.type,
    required this.x,
    required this.y,
    required this.z,
    required this.likelihood,
  });

  final PoseLandmarkType type;
  final double x;
  final double y;
  final double z;
  final double likelihood;

  factory ExerciseLandmark.fromMlKit(PoseLandmark lm) {
    return ExerciseLandmark(
      type: lm.type,
      x: lm.x,
      y: lm.y,
      z: lm.z,
      likelihood: lm.likelihood,
    );
  }
}
