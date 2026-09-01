import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'angle_calculator.dart';
import 'exercise_strategy.dart';

typedef PlankEvaluationResult = ExerciseEvaluationResult;

/// Plank exercise strategy ported directly from PlankStrategy.ts
/// Evaluates spine angle (Shoulder -> Hip -> Ankle). Valid range: 135° <= angle <= 220°.
/// Accumulates valid hold duration in seconds.
class PlankStrategy implements ExerciseStrategy {
  @override
  final String exerciseType = 'PLANK';

  double _validDurationSeconds = 0.0;
  int? _lastFrameTimestampMs;

  @override
  void reset() {
    _validDurationSeconds = 0.0;
    _lastFrameTimestampMs = null;
  }

  @override
  int get repCount => _validDurationSeconds.floor();

  @override
  int get durationSeconds => _validDurationSeconds.floor();

  @override
  ExerciseEvaluationResult evaluateFrame(Pose pose, int timestampMs) {
    _lastFrameTimestampMs ??= timestampMs;

    final deltaSec = (timestampMs - _lastFrameTimestampMs!) / 1000.0;
    _lastFrameTimestampMs = timestampMs;

    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    final shoulder = leftShoulder ?? rightShoulder;
    final hip = leftHip ?? rightHip;
    final leftLegPt = leftAnkle ?? leftKnee;
    final rightLegPt = rightAnkle ?? rightKnee;
    final legPt = leftLegPt ?? rightLegPt;

    if (shoulder == null || hip == null || legPt == null ||
        shoulder.likelihood < 0.5 || hip.likelihood < 0.5 || legPt.likelihood < 0.5) {
      return ExerciseEvaluationResult(
        validRepAdded: false,
        currentCount: _validDurationSeconds.floor(),
        feedback: 'Kamerada to‘liq gavdangiz (bosh, bel va oyoqlar) ko‘rinishi shart',
        formStatus: 'WARNING',
        currentPhase: 'PAUSED',
        bodyVisible: false,
      );
    }

    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];

    final armPt = leftWrist ?? rightWrist ?? leftElbow ?? rightElbow;
    if (armPt == null || armPt.likelihood < 0.3) {
      return ExerciseEvaluationResult(
        validRepAdded: false,
        currentCount: _validDurationSeconds.floor(),
        feedback: '⚠️ Qo‘llar va tirsaklar polga tiralgan bo‘lishi shart',
        formStatus: 'WARNING',
        currentPhase: 'PAUSED',
        bodyVisible: false,
      );
    }

    // Arms must be below or level with shoulders on the floor (not raised into the air)
    if (armPt.y < shoulder.y - 20.0) {
      return ExerciseEvaluationResult(
        validRepAdded: false,
        currentCount: _validDurationSeconds.floor(),
        feedback: '⚠️ Anti-Cheat: Qo‘llarni havoda ko‘tarmang! Polga tayaning.',
        formStatus: 'WARNING',
        currentPhase: 'PAUSED',
        bodyVisible: true,
      );
    }

    // ANTI-CHEAT RULE 1: Must be HORIZONTAL on floor, not standing upright
    final dy = (hip.y - shoulder.y).abs();
    final dx = (hip.x - shoulder.x).abs();
    final legDy = (legPt.y - hip.y).abs();
    final legDx = (legPt.x - hip.x).abs();

    // If torso and legs are aligned vertically (standing or sitting upright)
    final isTorsoVertical = dy > 40.0 && dy > dx * 1.0;
    final isLegsVertical = legDy > 40.0 && legDy > legDx * 1.0;

    if (isTorsoVertical || isLegsVertical) {
      return ExerciseEvaluationResult(
        validRepAdded: false,
        currentCount: _validDurationSeconds.floor(),
        feedback: '⚠️ Anti-Cheat: Plank uchun polga yoting! Tik turganda hisoblanmaydi.',
        formStatus: 'WARNING',
        currentPhase: 'PAUSED',
        bodyVisible: true,
      );
    }

    // Calculate spine line angle: Shoulder -> Hip -> Knee/Ankle

    double avgSpineAngle;
    if (leftShoulder != null && leftHip != null && rightShoulder != null && rightHip != null && leftLegPt != null && rightLegPt != null) {
      final leftAngle = AngleCalculator.calculateAngle(
        ax: leftShoulder.x, ay: leftShoulder.y,
        bx: leftHip.x, by: leftHip.y,
        cx: leftLegPt.x, cy: leftLegPt.y,
      );
      final rightAngle = AngleCalculator.calculateAngle(
        ax: rightShoulder.x, ay: rightShoulder.y,
        bx: rightHip.x, by: rightHip.y,
        cx: rightLegPt.x, cy: rightLegPt.y,
      );
      avgSpineAngle = (leftAngle + rightAngle) / 2.0;
    } else if (leftShoulder != null && leftHip != null && leftLegPt != null) {
      avgSpineAngle = AngleCalculator.calculateAngle(
        ax: leftShoulder.x, ay: leftShoulder.y,
        bx: leftHip.x, by: leftHip.y,
        cx: leftLegPt.x, cy: leftLegPt.y,
      );
    } else {
      final rPt = rightLegPt ?? rightHip!;
      avgSpineAngle = AngleCalculator.calculateAngle(
        ax: rightShoulder!.x, ay: rightShoulder.y,
        bx: rightHip!.x, by: rightHip.y,
        cx: rPt.x, cy: rPt.y,
      );
    }

    // ANTI-CHEAT RULE 2: Straight Spine Alignment (140° <= spine <= 210°)
    final isValidForm = avgSpineAngle >= 140.0 && avgSpineAngle <= 210.0;

    String feedback = '🔥 Ajoyib barqarorlik! Plank ushlab turing';
    String formStatus = 'GOOD';
    bool validRepAdded = false;

    if (isValidForm) {
      final prevWhole = _validDurationSeconds.floor();
      // Accumulate valid hold duration instantly
      _validDurationSeconds += math.min(deltaSec, 0.5);
      final newWhole = _validDurationSeconds.floor();

      if (newWhole > prevWhole) {
        validRepAdded = true;
      }
    } else {
      formStatus = 'WARNING';
      if (avgSpineAngle < 140.0) {
        feedback = '⚠️ Anti-Cheat: Beldan pastga tushib ketmang! Tanani tekis tuting.';
      } else {
        feedback = '⚠️ Anti-Cheat: Beldan yuqoriga ko‘tarilib ketmang!';
      }
    }

    return ExerciseEvaluationResult(
      validRepAdded: validRepAdded,
      currentCount: _validDurationSeconds.floor(),
      feedback: feedback,
      formStatus: formStatus,
      currentPhase: isValidForm ? 'HOLDING' : 'FORM_WARNING',
      bodyVisible: true,
      avgAngle: avgSpineAngle,
    );
  }
}
