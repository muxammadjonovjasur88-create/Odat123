import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'angle_calculator.dart';
import 'exercise_strategy.dart';

enum CrunchPhase { lying, crunching, holding }

/// Vision Strategy for Abdominal Crunches / Press (Sit-ups).
/// Tracks torso angle relative to hips/knees.
class CrunchStrategy implements ExerciseStrategy {
  CrunchStrategy({
    this.crunchAngleThreshold = 85.0,   // Wider: easier for beginners
    this.lyingAngleThreshold = 130.0,   // Wider window
    this.minRepDurationMs = 500,        // Faster rep acceptance
  });

  final double crunchAngleThreshold;
  final double lyingAngleThreshold;
  final int minRepDurationMs;

  @override
  String get exerciseType => 'CRUNCH';

  int _repCount = 0;
  @override
  int get repCount => _repCount;

  @override
  int get durationSeconds => 0;

  CrunchPhase _currentPhase = CrunchPhase.lying;
  CrunchPhase get currentPhase => _currentPhase;

  int _lastRepTimestampMs = 0;
  int _phaseStartTimeMs = 0;

  @override
  void reset() {
    _repCount = 0;
    _currentPhase = CrunchPhase.lying;
    _lastRepTimestampMs = 0;
    _phaseStartTimeMs = 0;
  }

  @override
  ExerciseEvaluationResult evaluateFrame(Pose pose, int timestampMs) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];

    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];

    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    // Anti-Cheat: Torso and hips must be visible
    final bool leftSideVisible = leftShoulder != null && leftHip != null && leftKnee != null &&
        leftShoulder.likelihood > 0.30 && leftHip.likelihood > 0.30 && leftKnee.likelihood > 0.30;

    final bool rightSideVisible = rightShoulder != null && rightHip != null && rightKnee != null &&
        rightShoulder.likelihood > 0.30 && rightHip.likelihood > 0.30 && rightKnee.likelihood > 0.30;

    if (!leftSideVisible && !rightSideVisible) {
      return ExerciseEvaluationResult(
        validRepAdded: false,
        currentCount: _repCount,
        feedback: '⚠️ Kamera qarshisiga yonbosh yoki to‘liq gavdangiz bilan joylashing',
        formStatus: 'WARNING',
        currentPhase: _currentPhase.name,
        bodyVisible: false,
        avgAngle: 180.0,
      );
    }

    // Feet anti-cheat: only reject if feet are VERY high above hips (not just slightly lifted)
    final ankle = leftAnkle ?? rightAnkle;
    final hip = leftHip ?? rightHip;
    if (ankle != null && hip != null && ankle.likelihood > 0.35 && hip.likelihood > 0.35) {
      if (ankle.y < hip.y - 40.0) { // Relaxed: must be clearly lifted, not just camera angle
        return ExerciseEvaluationResult(
          validRepAdded: false,
          currentCount: _repCount,
          feedback: '⚠️ Oyoqlarni polda ushlang! Havoga ko\'tarmang.',
          formStatus: 'WARNING',
          currentPhase: _currentPhase.name,
          bodyVisible: true,
          avgAngle: 180.0,
        );
      }
    }

    double angle;
    if (leftSideVisible && rightSideVisible) {
      final leftAngle = AngleCalculator.calculateAngle(
        ax: leftShoulder!.x, ay: leftShoulder.y,
        bx: leftHip!.x, by: leftHip.y,
        cx: leftKnee!.x, cy: leftKnee.y,
      );
      final rightAngle = AngleCalculator.calculateAngle(
        ax: rightShoulder!.x, ay: rightShoulder.y,
        bx: rightHip!.x, by: rightHip.y,
        cx: rightKnee!.x, cy: rightKnee.y,
      );
      angle = (leftAngle + rightAngle) / 2.0;
    } else if (leftSideVisible) {
      angle = AngleCalculator.calculateAngle(
        ax: leftShoulder!.x, ay: leftShoulder.y,
        bx: leftHip!.x, by: leftHip.y,
        cx: leftKnee!.x, cy: leftKnee.y,
      );
    } else {
      // rightSideVisible is true here — safe to use !
      angle = AngleCalculator.calculateAngle(
        ax: rightShoulder!.x, ay: rightShoulder.y,
        bx: rightHip!.x, by: rightHip.y,
        cx: rightKnee!.x, cy: rightKnee.y,
      );
    }

    bool validRepAdded = false;
    String feedback = '';
    String formStatus = 'GOOD';

    switch (_currentPhase) {
      case CrunchPhase.lying:
        if (angle < (lyingAngleThreshold - 15)) {
          _currentPhase = CrunchPhase.crunching;
          _phaseStartTimeMs = timestampMs;
          feedback = 'Gavdani ko‘taring, qorinni taranglashtiring!';
        } else {
          feedback = 'Tayyor! Press qilish uchun gavdani ko‘taring';
        }
        break;

      case CrunchPhase.crunching:
        if (angle <= crunchAngleThreshold) {
          _currentPhase = CrunchPhase.holding;
          feedback = 'Ajoyib! Endi sekin pastga tushing';
        } else if (angle >= lyingAngleThreshold) {
          _currentPhase = CrunchPhase.lying;
          feedback = 'To‘liqroq ko‘tariling!';
        } else {
          feedback = 'Ko‘tarilishda davom eting...';
        }
        break;

      case CrunchPhase.holding:
        if (angle >= (lyingAngleThreshold - 10)) {
          final repDuration = timestampMs - _phaseStartTimeMs;
          if (repDuration >= minRepDurationMs && (timestampMs - _lastRepTimestampMs) >= minRepDurationMs) {
            _repCount++;
            validRepAdded = true;
            _lastRepTimestampMs = timestampMs;
            feedback = '🔥 Ajoyib press! +1';
            formStatus = 'GOOD';
          } else {
            feedback = 'Juda tez bajardingiz, sekinroq qiling';
            formStatus = 'WARNING';
          }
          _currentPhase = CrunchPhase.lying;
        } else {
          feedback = 'Sekin dastlabki holatga qayting';
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
