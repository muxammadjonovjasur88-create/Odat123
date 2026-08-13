import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'angle_calculator.dart';
import 'exercise_strategy.dart';

enum PushUpPhase { up, down }

typedef PushUpEvaluationResult = ExerciseEvaluationResult;

/// Push-up exercise strategy ported directly from PushUpStrategy.ts
/// UP (>=145°) -> DOWN (<=110°) -> UP (>=145°, +1 rep, min 250ms debounce)
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
  static const double downAngle = 110.0;
  static const int debounceMs = 250;

  @override
  void reset() {
    _currentPhase = PushUpPhase.up;
    _repCount = 0;
    _lastRepTimestampMs = 0;
    _minDepthReached = false;
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

    // ANTI-CHEAT: Ensure user is HORIZONTAL on the floor, not standing upright flexing arms
    final shoulder = leftShoulder ?? rightShoulder;
    final hip = leftHip ?? rightHip;
    if (shoulder != null && hip != null) {
      final dy = hip.y - shoulder.y;
      final dx = (hip.x - shoulder.x).abs();
      final isStandingUpright = dy > 100.0 && dy > dx * 0.8;
      if (isStandingUpright) {
        return ExerciseEvaluationResult(
          validRepAdded: false,
          currentCount: _repCount,
          feedback: '⚠️ Anti-Cheat: Push-Up uchun polga yoting! Tik turib bajarilmaydi.',
          formStatus: 'WARNING',
          currentPhase: _currentPhase.name.toUpperCase(),
          bodyVisible: true,
        );
      }
    }

    final hasLeftArm = leftShoulder != null &&
        leftElbow != null &&
        leftWrist != null &&
        leftElbow.likelihood > 0.2;
    final hasRightArm = rightShoulder != null &&
        rightElbow != null &&
        rightWrist != null &&
        rightElbow.likelihood > 0.2;

    // ANTI-CHEAT RULE 1: Require BOTH arms to be visible in frame
    if (!hasLeftArm || !hasRightArm) {
      return ExerciseEvaluationResult(
        validRepAdded: false,
        currentCount: _repCount,
        feedback: '⚠️ Anti-Cheat: Ikkala qo‘l ham kamerada ko‘rinishi kerak',
        formStatus: 'WARNING',
        currentPhase: _currentPhase.name.toUpperCase(),
        bodyVisible: false,
      );
    }

    final leftAngle = AngleCalculator.calculateAngle(
      ax: leftShoulder.x, ay: leftShoulder.y,
      bx: leftElbow.x, by: leftElbow.y,
      cx: leftWrist.x, cy: leftWrist.y,
    );
    final rightAngle = AngleCalculator.calculateAngle(
      ax: rightShoulder.x, ay: rightShoulder.y,
      bx: rightElbow.x, by: rightElbow.y,
      cx: rightWrist.x, cy: rightWrist.y,
    );
    final avgElbowAngle = (leftAngle + rightAngle) / 2.0;

    // ANTI-CHEAT RULE 2: Single-arm wiggling prevention (Both elbows MUST bend symmetrically)
    final armAngleDiff = (leftAngle - rightAngle).abs();
    if (armAngleDiff > 35.0 && (leftAngle < 120.0 || rightAngle < 120.0)) {
      return ExerciseEvaluationResult(
        validRepAdded: false,
        currentCount: _repCount,
        feedback: '⚠️ Anti-Cheat: Ikkala qo‘lda teng otjimaniya bajaring!',
        formStatus: 'WARNING',
        currentPhase: _currentPhase.name.toUpperCase(),
        bodyVisible: true,
      );
    }

    bool validRepAdded = false;
    String feedback = 'Yaxshi davom eting';
    String formStatus = 'GOOD';

    // State machine logic
    if (_currentPhase == PushUpPhase.up) {
      if (avgElbowAngle <= downAngle) {
        _currentPhase = PushUpPhase.down;
        _minDepthReached = true;
        feedback = 'Ajoyib tushdingiz!';
      }
    } else if (_currentPhase == PushUpPhase.down) {
      if (avgElbowAngle >= upAngle) {
        if (_minDepthReached &&
            (timestampMs - _lastRepTimestampMs) > debounceMs) {
          _repCount++;
          _lastRepTimestampMs = timestampMs;
          validRepAdded = true;
          feedback = 'Zo‘r otjimaniya! +1';
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
      avgAngle: avgElbowAngle,
    );
  }
}
