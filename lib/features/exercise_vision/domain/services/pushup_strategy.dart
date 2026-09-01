import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'angle_calculator.dart';
import 'exercise_strategy.dart';

enum PushUpPhase { up, down }

typedef PushUpEvaluationResult = ExerciseEvaluationResult;

/// Push-up exercise strategy with flexible visibility checks for both front and side profiles.
class PushUpStrategy implements ExerciseStrategy {
  @override
  final String exerciseType = 'PUSH_UP';

  PushUpPhase _currentPhase = PushUpPhase.up;
  int _repCount = 0;
  int _lastRepTimestampMs = 0;
  bool _minDepthReached = false;
  int? _startTimeMs;
  int _totalDurationSeconds = 0;

  static const double upAngle = 145.0;
  static const double downAngle = 100.0;
  static const int debounceMs = 650; // Reduced for better UX
  double _downShoulderY = 0.0;

  @override
  void reset() {
    _currentPhase = PushUpPhase.up;
    _repCount = 0;
    _lastRepTimestampMs = 0;
    _minDepthReached = false;
    _downShoulderY = 0.0;
    _startTimeMs = null;
    _totalDurationSeconds = 0;
  }

  @override
  int get repCount => _repCount;

  @override
  int get durationSeconds => _totalDurationSeconds;

  PushUpPhase get currentPhase => _currentPhase;

  @override
  ExerciseEvaluationResult evaluateFrame(Pose pose, int timestampMs) {
    _startTimeMs ??= timestampMs;
    _totalDurationSeconds = ((timestampMs - _startTimeMs!) / 1000).floor();

    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    // 1. VISIBILITY CHECK: At least one arm with shoulder, elbow, wrist
    final hasLeftArm = leftShoulder != null &&
        leftElbow != null &&
        leftWrist != null &&
        leftShoulder.likelihood > 0.4 &&
        leftElbow.likelihood > 0.35 &&
        leftWrist.likelihood > 0.3;

    final hasRightArm = rightShoulder != null &&
        rightElbow != null &&
        rightWrist != null &&
        rightShoulder.likelihood > 0.4 &&
        rightElbow.likelihood > 0.35 &&
        rightWrist.likelihood > 0.3;

    final hip = (leftHip != null && leftHip.likelihood > 0.3)
        ? leftHip
        : ((rightHip != null && rightHip.likelihood > 0.3) ? rightHip : null);

    final shoulder = (leftShoulder != null && leftShoulder.likelihood > 0.4)
        ? leftShoulder
        : ((rightShoulder != null && rightShoulder.likelihood > 0.4) ? rightShoulder : null);

    if (!hasLeftArm && !hasRightArm) {
      return ExerciseEvaluationResult(
        validRepAdded: false,
        currentCount: _repCount,
        feedback: '📱 Telefonni polga qo‘ying, butun gavdangiz va qo‘llar ko‘rinsin',
        formStatus: 'WARNING',
        currentPhase: _currentPhase.name.toUpperCase(),
        bodyVisible: false,
      );
    }

    // 2. POSTURE CHECK: User must be in horizontal / plank position on floor
    if (hip != null && shoulder != null) {
      final dy = (hip.y - shoulder.y); // Positive if standing upright (shoulder high above hip)
      final dx = (hip.x - shoulder.x).abs();

      // If standing vertically facing or angled to camera, reject
      // Threshold raised to 50 to avoid false-positives from camera angle
      if (dy > 50.0 && dx < dy * 1.1) {
        return ExerciseEvaluationResult(
          validRepAdded: false,
          currentCount: _repCount,
          feedback: '⚠️ Push-up uchun polga gorizontal yoting! Tik turib bo\'lmaydi',
          formStatus: 'WARNING',
          currentPhase: _currentPhase.name.toUpperCase(),
          bodyVisible: true,
        );
      }
    }

    // 3. Calculate Arm Elbow Angle
    final leftAngle = hasLeftArm
        ? AngleCalculator.calculateAngle(
            ax: leftShoulder.x, ay: leftShoulder.y,
            bx: leftElbow.x, by: leftElbow.y,
            cx: leftWrist.x, cy: leftWrist.y,
          )
        : 180.0;
    final rightAngle = hasRightArm
        ? AngleCalculator.calculateAngle(
            ax: rightShoulder.x, ay: rightShoulder.y,
            bx: rightElbow.x, by: rightElbow.y,
            cx: rightWrist.x, cy: rightWrist.y,
          )
        : 180.0;

    final primaryElbowAngle = (hasLeftArm && hasRightArm)
        ? (leftAngle + rightAngle) / 2.0
        : (hasLeftArm ? leftAngle : rightAngle);

    final activeShoulder = hasLeftArm ? leftShoulder : rightShoulder!;
    final shoulderY = activeShoulder.y;

    bool validRepAdded = false;
    String feedback = 'Yaxshi, davom eting';
    String formStatus = 'GOOD';

    // 4. State machine with depth and debounce
    if (_currentPhase == PushUpPhase.up) {
      if (primaryElbowAngle <= downAngle) {
        _currentPhase = PushUpPhase.down;
        _minDepthReached = true;
        _downShoulderY = shoulderY;
        feedback = 'Ajoyib tushdingiz! Endi ko‘taring';
      }
    } else if (_currentPhase == PushUpPhase.down) {
      if (primaryElbowAngle >= upAngle) {
        final timeDiff = timestampMs - _lastRepTimestampMs;
        final verticalMovement = (shoulderY - _downShoulderY).abs();

        // Relaxed anti-cheat: 20px movement minimum (was 35px) for blurry cameras
        if (timeDiff >= debounceMs && (_minDepthReached && verticalMovement >= 20.0)) {
          _repCount++;
          validRepAdded = true;
          _lastRepTimestampMs = timestampMs;
          feedback = 'Zo\'r! $_repCount-takrorlash hisoblandi 🎯';
        }

        _currentPhase = PushUpPhase.up;
        _minDepthReached = false;
      }
    }

    return ExerciseEvaluationResult(
      validRepAdded: validRepAdded,
      currentCount: _repCount,
      feedback: feedback,
      formStatus: formStatus,
      currentPhase: _currentPhase.name.toUpperCase(),
      bodyVisible: true,
      avgAngle: primaryElbowAngle,
    );
  }
}
