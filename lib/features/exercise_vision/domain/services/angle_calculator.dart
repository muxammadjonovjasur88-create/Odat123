import 'dart:math' as math;

/// Utility service to calculate 2D angles in degrees and Euclidean distance between points.
abstract final class AngleCalculator {
  /// Calculates 2D angle in degrees (0 to 180) between three keypoints (A -> B -> C, vertex at B).
  static double calculateAngle({
    required double ax,
    required double ay,
    required double bx,
    required double by,
    required double cx,
    required double cy,
  }) {
    final radians =
        math.atan2(cy - by, cx - bx) - math.atan2(ay - by, ax - bx);
    var angle = (radians * 180.0 / math.pi).abs();
    if (angle > 180.0) {
      angle = 360.0 - angle;
    }
    return angle;
  }

  /// Calculates Euclidean distance between two points (x1, y1) and (x2, y2).
  static double calculateDistance({
    required double x1,
    required double y1,
    required double x2,
    required double y2,
  }) {
    final dx = x1 - x2;
    final dy = y1 - y2;
    return math.sqrt(dx * dx + dy * dy);
  }
}
