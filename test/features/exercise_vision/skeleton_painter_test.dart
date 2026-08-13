import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flowa/features/exercise_vision/presentation/widgets/skeleton_painter.dart';

void main() {
  group('SkeletonPainter Tests', () {
    testWidgets('renders skeleton without errors on canvas under BoxFit.cover scaling',
        (WidgetTester tester) async {
      final poseLandmarks = <PoseLandmarkType, PoseLandmark>{
        PoseLandmarkType.leftShoulder: PoseLandmark(
          type: PoseLandmarkType.leftShoulder,
          x: 200,
          y: 300,
          z: 0,
          likelihood: 0.9,
        ),
        PoseLandmarkType.rightShoulder: PoseLandmark(
          type: PoseLandmarkType.rightShoulder,
          x: 520,
          y: 300,
          z: 0,
          likelihood: 0.9,
        ),
        PoseLandmarkType.leftHip: PoseLandmark(
          type: PoseLandmarkType.leftHip,
          x: 250,
          y: 700,
          z: 0,
          likelihood: 0.9,
        ),
        PoseLandmarkType.rightHip: PoseLandmark(
          type: PoseLandmarkType.rightHip,
          x: 470,
          y: 700,
          z: 0,
          likelihood: 0.9,
        ),
      };

      final testPose = Pose(landmarks: poseLandmarks);

      final painter = SkeletonPainter(
        poses: [testPose],
        absoluteImageSize: const Size(720, 1280),
        rotation: InputImageRotation.rotation90deg,
        isFrontCamera: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: const Size(1080, 2400),
              painter: painter,
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is SkeletonPainter,
        ),
        findsOneWidget,
      );
    });
  });
}
