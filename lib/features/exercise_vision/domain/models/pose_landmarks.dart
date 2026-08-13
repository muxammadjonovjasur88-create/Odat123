import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Index mapping for all 33 MediaPipe / ML Kit Pose Landmarks
enum PoseLandmarkIndex {
  nose,
  leftEyeInner,
  leftEye,
  leftEyeOuter,
  rightEyeInner,
  rightEye,
  rightEyeOuter,
  leftEar,
  rightEar,
  mouthLeft,
  mouthRight,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftPinky,
  rightPinky,
  leftIndex,
  rightIndex,
  leftThumb,
  rightThumb,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
  leftHeel,
  rightHeel,
  leftFootIndex,
  rightFootIndex;
}

/// Single 3D Landmark Point with visibility/likelihood.
@immutable
class LandmarkPoint {
  const LandmarkPoint({
    required this.x,
    required this.y,
    required this.z,
    required this.visibility,
    this.type,
  });

  final double x; // Normalized 0.0 to 1.0 or pixel coordinate
  final double y;
  final double z;
  final double visibility; // Likelihood / confidence (0.0 to 1.0)
  final PoseLandmarkType? type;

  factory LandmarkPoint.fromMlKit(PoseLandmark lm) {
    return LandmarkPoint(
      x: lm.x,
      y: lm.y,
      z: lm.z,
      visibility: lm.likelihood,
      type: lm.type,
    );
  }
}

/// 33 Pose Landmark Data Model
@immutable
class PoseLandmarks {
  const PoseLandmarks({
    required this.points,
  });

  final List<LandmarkPoint> points;

  LandmarkPoint? get nose => _get(PoseLandmarkType.nose);
  LandmarkPoint? get leftShoulder => _get(PoseLandmarkType.leftShoulder);
  LandmarkPoint? get rightShoulder => _get(PoseLandmarkType.rightShoulder);
  LandmarkPoint? get leftElbow => _get(PoseLandmarkType.leftElbow);
  LandmarkPoint? get rightElbow => _get(PoseLandmarkType.rightElbow);
  LandmarkPoint? get leftWrist => _get(PoseLandmarkType.leftWrist);
  LandmarkPoint? get rightWrist => _get(PoseLandmarkType.rightWrist);
  LandmarkPoint? get leftHip => _get(PoseLandmarkType.leftHip);
  LandmarkPoint? get rightHip => _get(PoseLandmarkType.rightHip);
  LandmarkPoint? get leftKnee => _get(PoseLandmarkType.leftKnee);
  LandmarkPoint? get rightKnee => _get(PoseLandmarkType.rightKnee);
  LandmarkPoint? get leftAnkle => _get(PoseLandmarkType.leftAnkle);
  LandmarkPoint? get rightAnkle => _get(PoseLandmarkType.rightAnkle);

  LandmarkPoint? _get(PoseLandmarkType type) {
    for (final p in points) {
      if (p.type == type) return p;
    }
    return null;
  }

  factory PoseLandmarks.fromPose(Pose pose) {
    final list = <LandmarkPoint>[];
    pose.landmarks.forEach((_, lm) {
      list.add(LandmarkPoint.fromMlKit(lm));
    });
    return PoseLandmarks(points: list);
  }
}
