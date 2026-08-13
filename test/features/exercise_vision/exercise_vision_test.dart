import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flowa/features/exercise_vision/domain/services/angle_calculator.dart';
import 'package:flowa/features/exercise_vision/domain/services/squat_strategy.dart';
import 'package:flowa/features/exercise_vision/domain/services/pushup_strategy.dart';
import 'package:flowa/features/exercise_vision/domain/services/plank_strategy.dart';

void main() {
  group('AngleCalculator Tests', () {
    test('Calculates 90 degree right angle correctly', () {
      final angle = AngleCalculator.calculateAngle(
        ax: 0, ay: 1,
        bx: 0, by: 0,
        cx: 1, cy: 0,
      );
      expect(angle, closeTo(90.0, 0.01));
    });

    test('Calculates 180 degree straight line correctly', () {
      final angle = AngleCalculator.calculateAngle(
        ax: 0, ay: 1,
        bx: 0, by: 0,
        cx: 0, cy: -1,
      );
      expect(angle, closeTo(180.0, 0.01));
    });

    test('Calculates 45 degree angle correctly', () {
      final angle = AngleCalculator.calculateAngle(
        ax: 1, ay: 0,
        bx: 0, by: 0,
        cx: 1, cy: 1,
      );
      expect(angle, closeTo(45.0, 0.01));
    });

    test('Calculates Euclidean distance correctly', () {
      final dist = AngleCalculator.calculateDistance(
        x1: 0, y1: 0,
        x2: 3, y2: 4,
      );
      expect(dist, closeTo(5.0, 0.001));
    });
  });

  group('SquatStrategy State Machine Tests', () {
    late SquatStrategy strategy;

    setUp(() {
      strategy = SquatStrategy();
    });

    test('Initial state is standing with 0 reps', () {
      expect(strategy.repCount, equals(0));
      expect(strategy.currentPhase, equals(SquatPhase.standing));
    });

    test('Missing landmarks returns warning state', () {
      final emptyPose = Pose(landmarks: {});
      final result = strategy.evaluateFrame(emptyPose, 1000);

      expect(result.bodyVisible, isFalse);
      expect(result.formStatus, equals('WARNING'));
      expect(result.feedback, contains('Oyoqlar va sonlar'));
    });

    test('Shallow squat without reaching bottom depth does not increment rep count', () {
      // Standing (180 deg)
      final poseStanding = Pose(landmarks: {
        PoseLandmarkType.leftHip: PoseLandmark(type: PoseLandmarkType.leftHip, x: 0, y: 100, z: 0, likelihood: 0.9),
        PoseLandmarkType.leftKnee: PoseLandmark(type: PoseLandmarkType.leftKnee, x: 0, y: 0, z: 0, likelihood: 0.9),
        PoseLandmarkType.leftAnkle: PoseLandmark(type: PoseLandmarkType.leftAnkle, x: 0, y: -100, z: 0, likelihood: 0.9),
      });

      // Shallow (135 deg: > 115 deg threshold)
      final poseShallow = Pose(landmarks: {
        PoseLandmarkType.leftHip: PoseLandmark(type: PoseLandmarkType.leftHip, x: 100, y: -100, z: 0, likelihood: 0.9),
        PoseLandmarkType.leftKnee: PoseLandmark(type: PoseLandmarkType.leftKnee, x: 0, y: 0, z: 0, likelihood: 0.9),
        PoseLandmarkType.leftAnkle: PoseLandmark(type: PoseLandmarkType.leftAnkle, x: 0, y: 100, z: 0, likelihood: 0.9),
      });

      strategy.evaluateFrame(poseStanding, 1000);
      strategy.evaluateFrame(poseShallow, 1200);
      expect(strategy.currentPhase, equals(SquatPhase.descending));

      // Standing back up without reaching BOTTOM (<=115 deg)
      final res = strategy.evaluateFrame(poseStanding, 1500);
      expect(strategy.currentPhase, equals(SquatPhase.standing));
      expect(strategy.repCount, equals(0));
      expect(res.validRepAdded, isFalse);
    });

    test('Full valid squat sequence increments rep count', () {
      final poseStanding = Pose(landmarks: {
        PoseLandmarkType.leftHip: PoseLandmark(type: PoseLandmarkType.leftHip, x: 0, y: 100, z: 0, likelihood: 0.9),
        PoseLandmarkType.leftKnee: PoseLandmark(type: PoseLandmarkType.leftKnee, x: 0, y: 0, z: 0, likelihood: 0.9),
        PoseLandmarkType.leftAnkle: PoseLandmark(type: PoseLandmarkType.leftAnkle, x: 0, y: -100, z: 0, likelihood: 0.9),
      });

      final poseShallow = Pose(landmarks: {
        PoseLandmarkType.leftHip: PoseLandmark(type: PoseLandmarkType.leftHip, x: 100, y: -100, z: 0, likelihood: 0.9),
        PoseLandmarkType.leftKnee: PoseLandmark(type: PoseLandmarkType.leftKnee, x: 0, y: 0, z: 0, likelihood: 0.9),
        PoseLandmarkType.leftAnkle: PoseLandmark(type: PoseLandmarkType.leftAnkle, x: 0, y: 100, z: 0, likelihood: 0.9),
      });

      final poseBottom = Pose(landmarks: {
        PoseLandmarkType.leftHip: PoseLandmark(type: PoseLandmarkType.leftHip, x: 100, y: 0, z: 0, likelihood: 0.9),
        PoseLandmarkType.leftKnee: PoseLandmark(type: PoseLandmarkType.leftKnee, x: 0, y: 0, z: 0, likelihood: 0.9),
        PoseLandmarkType.leftAnkle: PoseLandmark(type: PoseLandmarkType.leftAnkle, x: 0, y: 100, z: 0, likelihood: 0.9),
      });

      strategy.evaluateFrame(poseStanding, 1000);
      strategy.evaluateFrame(poseShallow, 1200);
      strategy.evaluateFrame(poseBottom, 1500);
      strategy.evaluateFrame(poseShallow, 1800);

      final resFinal = strategy.evaluateFrame(poseStanding, 2200);
      expect(resFinal.validRepAdded, isTrue);
      expect(strategy.repCount, equals(1));
      expect(resFinal.feedback, contains('Ajoyib squat! +1'));
    });
  });

  group('PushUpStrategy Tests', () {
    late PushUpStrategy strategy;

    setUp(() {
      strategy = PushUpStrategy();
    });

    test('Initial state is UP with 0 reps', () {
      expect(strategy.repCount, equals(0));
      expect(strategy.currentPhase, equals(PushUpPhase.up));
    });

    test('Missing landmarks returns warning state', () {
      final emptyPose = Pose(landmarks: {});
      final result = strategy.evaluateFrame(emptyPose, 1000);

      expect(result.bodyVisible, isFalse);
      expect(result.formStatus, equals('WARNING'));
      expect(result.feedback, contains('Qo‘llar ko‘rinishi kerak'));
    });

    test('Full push-up sequence (UP -> DOWN -> UP) increments rep count', () {
      // 1. Arms extended UP (180 deg)
      final poseUp = Pose(landmarks: {
        PoseLandmarkType.leftShoulder: PoseLandmark(type: PoseLandmarkType.leftShoulder, x: 0, y: 100, z: 0, likelihood: 0.9),
        PoseLandmarkType.leftElbow: PoseLandmark(type: PoseLandmarkType.leftElbow, x: 0, y: 0, z: 0, likelihood: 0.9),
        PoseLandmarkType.leftWrist: PoseLandmark(type: PoseLandmarkType.leftWrist, x: 0, y: -100, z: 0, likelihood: 0.9),
      });

      // 2. Arms bent DOWN (90 deg <= 110 deg)
      final poseDown = Pose(landmarks: {
        PoseLandmarkType.leftShoulder: PoseLandmark(type: PoseLandmarkType.leftShoulder, x: 100, y: 0, z: 0, likelihood: 0.9),
        PoseLandmarkType.leftElbow: PoseLandmark(type: PoseLandmarkType.leftElbow, x: 0, y: 0, z: 0, likelihood: 0.9),
        PoseLandmarkType.leftWrist: PoseLandmark(type: PoseLandmarkType.leftWrist, x: 0, y: 100, z: 0, likelihood: 0.9),
      });

      strategy.evaluateFrame(poseUp, 1000);
      expect(strategy.currentPhase, equals(PushUpPhase.up));

      // Reaching DOWN
      final resDown = strategy.evaluateFrame(poseDown, 1300);
      expect(strategy.currentPhase, equals(PushUpPhase.down));
      expect(resDown.feedback, contains('Ajoyib tushdingiz!'));

      // Returning to UP (after >250ms debounce)
      final resUp = strategy.evaluateFrame(poseUp, 1800);
      expect(strategy.currentPhase, equals(PushUpPhase.up));
      expect(resUp.validRepAdded, isTrue);
      expect(strategy.repCount, equals(1));
      expect(resUp.feedback, contains('Zo‘r otjimaniya! +1'));
    });
  });

  group('PlankStrategy Tests', () {
    late PlankStrategy strategy;

    setUp(() {
      strategy = PlankStrategy();
    });

    test('Initial duration is 0 seconds', () {
      expect(strategy.durationSeconds, equals(0));
      expect(strategy.repCount, equals(0));
    });

    test('Missing landmarks returns warning', () {
      final emptyPose = Pose(landmarks: {});
      final result = strategy.evaluateFrame(emptyPose, 1000);

      expect(result.bodyVisible, isFalse);
      expect(result.formStatus, equals('WARNING'));
      expect(result.feedback, contains('Kamerada tanangiz ko‘rinishi kerak'));
    });

    test('Valid straight plank posture accumulates duration', () {
      // Straight line posture (180 deg)
      final posePlankGood = Pose(landmarks: {
        PoseLandmarkType.leftShoulder: PoseLandmark(type: PoseLandmarkType.leftShoulder, x: 0, y: 100, z: 0, likelihood: 0.9),
        PoseLandmarkType.leftHip: PoseLandmark(type: PoseLandmarkType.leftHip, x: 0, y: 0, z: 0, likelihood: 0.9),
        PoseLandmarkType.leftAnkle: PoseLandmark(type: PoseLandmarkType.leftAnkle, x: 0, y: -100, z: 0, likelihood: 0.9),
      });

      strategy.evaluateFrame(posePlankGood, 1000);
      strategy.evaluateFrame(posePlankGood, 1500);
      strategy.evaluateFrame(posePlankGood, 2100);

      expect(strategy.durationSeconds, equals(1));
    });

    test('Sagging hips (angle < 135 deg) gives form warning and pauses duration', () {
      // Sagging posture (90 deg < 135 deg)
      final posePlankSagging = Pose(landmarks: {
        PoseLandmarkType.leftShoulder: PoseLandmark(type: PoseLandmarkType.leftShoulder, x: 100, y: 0, z: 0, likelihood: 0.9),
        PoseLandmarkType.leftHip: PoseLandmark(type: PoseLandmarkType.leftHip, x: 0, y: 0, z: 0, likelihood: 0.9),
        PoseLandmarkType.leftAnkle: PoseLandmark(type: PoseLandmarkType.leftAnkle, x: 0, y: 100, z: 0, likelihood: 0.9),
      });

      final result = strategy.evaluateFrame(posePlankSagging, 1000);
      expect(result.formStatus, equals('WARNING'));
      expect(result.feedback, contains('Beldan pastga tushib ketmang'));
    });
  });
}
