import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'angle_calculator.dart';
import 'exercise_strategy.dart';

enum SquatPhase { standing, descending, bottom, ascending }

typedef SquatEvaluationResult = ExerciseEvaluationResult;

/// Squat exercise strategy implementing exact State Machine logic ported from TS:
/// STANDING (>=150°) -> DESCENDING (<140°) -> BOTTOM (<=115°) -> ASCENDING (>125°) -> STANDING (+1 rep, min 250ms debounce)
class SquatStrategy implements ExerciseStrategy {
  @override
  final String exerciseType = 'SQUAT';

  SquatPhase _currentPhase = SquatPhase.standing;
  int _repCount = 0;
  int _lastRepTimestampMs = 0;
  bool _minDepthReached = false;
  int? _startTimeMs;
  int _totalDurationSeconds = 0;

  static const double standingAngle = 140.0;   // Relaxed for beginners
  static const double squatDepthAngle = 130.0; // Easier depth target
  static const int debounceMs = 700;           // Faster rep acceptance

  @override
  void reset() {
    _currentPhase = SquatPhase.standing;
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

  SquatPhase get currentPhase => _currentPhase;

  @override
  ExerciseEvaluationResult evaluateFrame(Pose pose, int timestampMs) {
    _startTimeMs ??= timestampMs;
    _totalDurationSeconds = ((timestampMs - _startTimeMs!) / 1000).floor();

    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    // Note: leftWrist/rightWrist not used (wrist anti-cheat removed for better UX)

    // ANTI-CHEAT: Ensure user is STANDING UPRIGHT (vertically), not lying on the floor doing pushups or plank
    final shoulder = leftShoulder ?? rightShoulder;
    final hip = leftHip ?? rightHip;
    if (shoulder != null && hip != null && shoulder.likelihood > 0.3 && hip.likelihood > 0.3) {
      final dy = hip.y - shoulder.y; // Positive when standing upright (shoulder above hip)
      final dx = (hip.x - shoulder.x).abs();
      // If user is lying flat on floor (dy < 25 or dx is significantly greater than dy):
      final isLyingDown = dy < 25.0 || (dx > 50.0 && dx > dy * 1.3);
      if (isLyingDown) {
        return ExerciseEvaluationResult(
          validRepAdded: false,
          currentCount: _repCount,
          feedback: '⚠️ Anti-Cheat: Squat uchun tik turing! Polga yotmang.',
          formStatus: 'WARNING',
          currentPhase: _currentPhase.name.toUpperCase(),
          bodyVisible: true,
        );
      }
    }

    // Wrist anti-cheat removed — caused too many false-positives for beginners
    // (phone placement, side angles, wide-arm squats all triggered it unfairly).

    final hasLeftLeg = leftHip != null &&
        leftKnee != null &&
        leftAnkle != null &&
        leftKnee.likelihood > 0.2;
    final hasRightLeg = rightHip != null &&
        rightKnee != null &&
        rightAnkle != null &&
        rightKnee.likelihood > 0.2;

    // At least ONE leg must be visible (blurry cameras often miss one side)
    if (!hasLeftLeg && !hasRightLeg) {
      return ExerciseEvaluationResult(
        validRepAdded: false,
        currentCount: _repCount,
        feedback: '⚠️ Oyoq ko\'rinmayapti! Kamerani pastroqqa qarating.',
        formStatus: 'WARNING',
        currentPhase: _currentPhase.name.toUpperCase(),
        bodyVisible: false,
      );
    }

    final leftAngle = hasLeftLeg ? AngleCalculator.calculateAngle(
      ax: leftHip.x, ay: leftHip.y,
      bx: leftKnee.x, by: leftKnee.y,
      cx: leftAnkle.x, cy: leftAnkle.y,
    ) : 180.0;
    
    final rightAngle = hasRightLeg ? AngleCalculator.calculateAngle(
      ax: rightHip.x, ay: rightHip.y,
      bx: rightKnee.x, by: rightKnee.y,
      cx: rightAnkle.x, cy: rightAnkle.y,
    ) : 180.0;
    
    final avgKneeAngle = (leftAngle + rightAngle) / 2.0;

    // Symmetry check: widened to 30° to account for natural asymmetry & camera angle
    final angleDiff = (leftAngle - rightAngle).abs();
    if (hasLeftLeg && hasRightLeg && angleDiff > 30.0 && (leftAngle < 135.0 || rightAngle < 135.0)) {
      return ExerciseEvaluationResult(
        validRepAdded: false,
        currentCount: _repCount,
        feedback: '⚠️ Ikkala oyoqda teng cho\'king! Bir oyoqni ko\'tarib aldamang.',
        formStatus: 'WARNING',
        currentPhase: _currentPhase.name.toUpperCase(),
        bodyVisible: true,
      );
    }

    // Use available leg(s) for angle — if only one visible, use that side
    final availLeftAngle = hasLeftLeg ? leftAngle : rightAngle;
    final availRightAngle = hasRightLeg ? rightAngle : leftAngle;
    final avgAngle = (availLeftAngle + availRightAngle) / 2.0;

    final bothKneesBent = avgAngle <= 135.0;
    final bothKneesDeep = avgAngle <= 130.0; // Relaxed depth
    final bothKneesStanding = avgAngle >= 140.0; // Relaxed standing

    bool validRepAdded = false;
    String feedback = 'Yaxshi davom eting';
    String formStatus = 'GOOD';

    // State Machine (Requires BOTH knees to reach depth and return together)
    switch (_currentPhase) {
      case SquatPhase.standing:
        if (bothKneesBent) {
          _currentPhase = SquatPhase.descending;
          _minDepthReached = false;
        }
        break;

      case SquatPhase.descending:
        if (bothKneesDeep) {
          _currentPhase = SquatPhase.bottom;
          _minDepthReached = true;
        } else if (bothKneesStanding) {
          _currentPhase = SquatPhase.standing;
          feedback = 'Pastroq cho‘kishingiz kerak';
          formStatus = 'WARNING';
        }
        break;

      case SquatPhase.bottom:
        if (avgAngle > 130.0) {
          _currentPhase = SquatPhase.ascending;
        }
        break;

      case SquatPhase.ascending:
        if (bothKneesStanding) {
          if (_minDepthReached &&
              (timestampMs - _lastRepTimestampMs) > debounceMs) {
            _repCount++;
            _lastRepTimestampMs = timestampMs;
            validRepAdded = true;
            feedback = 'Ajoyib squat! +1';
          }
          _currentPhase = SquatPhase.standing;
          _minDepthReached = false;
        }
        break;
    }

    if (_currentPhase == SquatPhase.descending && !bothKneesDeep) {
      feedback = 'Pastroq cho‘kishingiz kerak';
    } else if (_currentPhase == SquatPhase.bottom) {
      feedback = 'Ajoyib chuqurlik! Endi tiklaning';
    }

    return ExerciseEvaluationResult(
      validRepAdded: validRepAdded,
      currentCount: _repCount,
      feedback: feedback,
      formStatus: formStatus,
      currentPhase: _currentPhase.name.toUpperCase(),
      bodyVisible: true,
      avgAngle: avgKneeAngle,
    );
  }
}
