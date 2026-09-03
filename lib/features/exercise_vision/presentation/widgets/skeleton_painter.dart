import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// CustomPainter rendering 33 pose landmarks and skeleton bone connections over camera preview.
class SkeletonPainter extends CustomPainter {
  SkeletonPainter({
    required this.poses,
    required this.absoluteImageSize,
    required this.rotation,
    required this.isFrontCamera,
  });

  final List<Pose> poses;
  final Size absoluteImageSize;
  final InputImageRotation rotation;
  final bool isFrontCamera;

  @override
  void paint(Canvas canvas, Size size) {
    if (poses.isEmpty) return;

    final paintLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFF3A7FCC); // Neon Green

    final paintJoint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF4AADDC); // Neon Cyan

    final paintJointBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white;

    if (size.width <= 0 || size.height <= 0) return;

    final double rawW = absoluteImageSize.width;
    final double rawH = absoluteImageSize.height;
    if (rawW <= 0 || rawH <= 0) return;

    final bool isViewportPortrait = size.height >= size.width;
    final double imageWidth = isViewportPortrait ? math.min(rawW, rawH) : math.max(rawW, rawH);
    final double imageHeight = isViewportPortrait ? math.max(rawW, rawH) : math.min(rawW, rawH);

    final double scale = math.max(
      size.width / imageWidth,
      size.height / imageHeight,
    );

    if (scale.isNaN || scale.isInfinite || scale <= 0) return;

    final double scaledWidth = imageWidth * scale;
    final double scaledHeight = imageHeight * scale;

    final double offsetX = (scaledWidth - size.width) / 2;
    final double offsetY = (scaledHeight - size.height) / 2;

    double translateX(double x) {
      final srcX = isFrontCamera ? (imageWidth - x) : x;
      return srcX * scale - offsetX;
    }

    double translateY(double y) {
      return y * scale - offsetY;
    }

    for (final pose in poses) {
      void drawLine(PoseLandmarkType type1, PoseLandmarkType type2) {
        final lm1 = pose.landmarks[type1];
        final lm2 = pose.landmarks[type2];
        if (lm1 != null &&
            lm2 != null &&
            lm1.likelihood > 0.3 &&
            lm2.likelihood > 0.3) {
          final p1 = translateX(lm1.x);
          final p2 = translateX(lm2.x);
          final y1 = translateY(lm1.y);
          final y2 = translateY(lm2.y);

          if (p1.isNaN || p1.isInfinite || p2.isNaN || p2.isInfinite ||
              y1.isNaN || y1.isInfinite || y2.isNaN || y2.isInfinite) {
            return;
          }

          canvas.drawLine(Offset(p1, y1), Offset(p2, y2), paintLine);
        }
      }

      // Torso
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
      drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
      drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

      // Arms
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
      drawLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
      drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
      drawLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

      // Legs
      drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
      drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
      drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
      drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

      // Feet
      drawLine(PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel);
      drawLine(PoseLandmarkType.leftAnkle, PoseLandmarkType.leftFootIndex);
      drawLine(PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel);
      drawLine(PoseLandmarkType.rightAnkle, PoseLandmarkType.rightFootIndex);

      // Face landmarks to skip (keep ONLY nose dot on face)
      const faceLandmarksToSkip = {
        PoseLandmarkType.leftEyeInner,
        PoseLandmarkType.leftEye,
        PoseLandmarkType.leftEyeOuter,
        PoseLandmarkType.rightEyeInner,
        PoseLandmarkType.rightEye,
        PoseLandmarkType.rightEyeOuter,
        PoseLandmarkType.leftEar,
        PoseLandmarkType.rightEar,
        PoseLandmarkType.leftMouth,
        PoseLandmarkType.rightMouth,
      };

      // Draw Joints (Nose + Body joints only)
      pose.landmarks.forEach((type, lm) {
        if (faceLandmarksToSkip.contains(type)) return;

        if (lm.likelihood > 0.3) {
          final px = translateX(lm.x);
          final py = translateY(lm.y);

          if (px.isNaN || px.isInfinite || py.isNaN || py.isInfinite) {
            return;
          }

          canvas.drawCircle(Offset(px, py), 4.0, paintJoint);
          canvas.drawCircle(Offset(px, py), 4.0, paintJointBorder);
        }
      });
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) {
    return oldDelegate.poses != poses ||
        oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.isFrontCamera != isFrontCamera ||
        oldDelegate.rotation != rotation;
  }
}
