import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'angle_calculator.dart';
import 'exercise_strategy.dart';

enum PullUpPhase { hanging, pulling, topHold }

/// Vision Strategy for Pull-ups / Turnik.
/// Tracks elbow flexion angle and shoulder elevation relative to wrist/elbow.
class PullUpStrategy implements ExerciseStrategy {
  PullUpStrategy({
    this.topAngleThreshold = 80.0, // Elbow fully flexed (chin over bar)
    this.hangingAngleThreshold = 150.0, // Dead hang
    this.minRepDurationMs = 800,
  });

  final double topAngleThreshold;
  final double hangingAngleThreshold;
  final int minRepDurationMs;

  @override
  String get exerciseType => 'PULL_UP';

  int _repCount = 0;
  @override
  int get repCount => _repCount;

  @override
  int get durationSeconds => 0;

  PullUpPhase _currentPhase = PullUpPhase.hanging;
  PullUpPhase get currentPhase => _currentPhase;

  int _lastRepTimestampMs = 0;
  int _phaseStartTimeMs = 0;

  @override
  void reset() {
    _repCount = 0;
    _currentPhase = PullUpPhase.hanging;
    _lastRepTimestampMs = 0;
    _phaseStartTimeMs = 0;
  }

  @override
  ExerciseEvaluationResult evaluateFrame(Pose pose, int timestampMs) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];

    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    // Anti-Cheat: Arms and shoulders must be visible
    final bool hasLeftArm = leftShoulder != null && leftElbow != null && leftWrist != null &&
        leftElbow.likelihood > 0.45;

    final bool hasRightArm = rightShoulder != null && rightElbow != null && rightWrist != null &&
        rightElbow.likelihood > 0.45;

    if (!hasLeftArm && !hasRightArm) {
      return ExerciseEvaluationResult(
        validRepAdded: false,
        currentCount: _repCount,
        feedback: '⚠️ Turnikda osiling va qo‘llaringiz kamerada to‘liq ko‘rinsin',
        formStatus: 'WARNING',
        currentPhase: _currentPhase.name,
        bodyVisible: false,
        avgAngle: 180.0,
      );
    }

    // ANTI-CHEAT RULE: Hands must be gripped overhead above shoulders
    final wrist = leftWrist ?? rightWrist;
    final shoulder = leftShoulder ?? rightShoulder;
    if (wrist != null && shoulder != null && wrist.likelihood > 0.4 && shoulder.likelihood > 0.4) {
      // Allow 60px tolerance so people farther from camera still pass
      if (wrist.y > shoulder.y + 60.0) {
        return ExerciseEvaluationResult(
          validRepAdded: false,
          currentCount: _repCount,
          feedback: '⚠️ Anti-Cheat: Turnikda to‘liq osiling! Stol yoki stul ustida turmang.',
          formStatus: 'WARNING',
          currentPhase: _currentPhase.name,
          bodyVisible: true,
          avgAngle: 180.0,
        );
      }
    }

    double angle;
    if (hasLeftArm && hasRightArm) {
      final leftAngle = AngleCalculator.calculateAngle(
        ax: leftShoulder!.x, ay: leftShoulder.y,
        bx: leftElbow!.x, by: leftElbow.y,
        cx: leftWrist!.x, cy: leftWrist.y,
      );
      final rightAngle = AngleCalculator.calculateAngle(
        ax: rightShoulder!.x, ay: rightShoulder.y,
        bx: rightElbow!.x, by: rightElbow.y,
        cx: rightWrist!.x, cy: rightWrist.y,
      );
      angle = (leftAngle + rightAngle) / 2.0;
    } else if (hasLeftArm) {
      angle = AngleCalculator.calculateAngle(
        ax: leftShoulder!.x, ay: leftShoulder.y,
        bx: leftElbow!.x, by: leftElbow.y,
        cx: leftWrist!.x, cy: leftWrist.y,
      );
    } else {
      // hasRightArm is true here — safe to use !
      angle = AngleCalculator.calculateAngle(
        ax: rightShoulder!.x, ay: rightShoulder.y,
        bx: rightElbow!.x, by: rightElbow.y,
        cx: rightWrist!.x, cy: rightWrist.y,
      );
    }

    bool validRepAdded = false;
    String feedback = '';
    String formStatus = 'GOOD';

    switch (_currentPhase) {
      case PullUpPhase.hanging:
        if (angle < (hangingAngleThreshold - 15)) {
          _currentPhase = PullUpPhase.pulling;
          _phaseStartTimeMs = timestampMs;
          feedback = 'Tortiling, iyakni turnik sathiga olib chiqing!';
        } else {
          feedback = 'Turnikda to‘liq osilib turing';
        }
        break;

      case PullUpPhase.pulling:
        if (angle <= topAngleThreshold) {
          _currentPhase = PullUpPhase.topHold;
          feedback = 'Ajoyib tortilish! Endi sekin tushing';
        } else if (angle >= hangingAngleThreshold) {
          _currentPhase = PullUpPhase.hanging;
          feedback = 'To‘liq tortiling!';
        } else {
          feedback = 'Yuqoriga tortilishda davom eting...';
        }
        break;

      case PullUpPhase.topHold:
        // Rep counted when angle opens back to at least 110° (coming down from top)
        if (angle >= (hangingAngleThreshold - 40)) {
          final repDuration = timestampMs - _phaseStartTimeMs;
          if (repDuration >= minRepDurationMs && (timestampMs - _lastRepTimestampMs) >= minRepDurationMs) {
            _repCount++;
            validRepAdded = true;
            _lastRepTimestampMs = timestampMs;
            feedback = '🔥 Ajoyib turnik! +1';
            formStatus = 'GOOD';
          } else {
            feedback = 'Juda tez tushdingiz, sekinroq qiling';
            formStatus = 'WARNING';
          }
          _currentPhase = PullUpPhase.hanging;
        } else {
          feedback = 'Sekin pastga tushing';
        }
        break;
    }

    return ExerciseEvaluationResult(
      validRepAdded: validRepAdded,
      currentCount: _repCount,
      feedback: feedback,
      formStatus: formStatus,
      currentPhase: _currentPhase.name,
      bodyVisible: true,
      avgAngle: angle,
    );
  }
}
