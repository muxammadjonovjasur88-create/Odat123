import '../models/territory_polygon.dart';
import 'haversine_calculator.dart';

/// Service responsible for detecting closed-loop territory conquests.
abstract final class TerritoryConquestService {
  /// Maximum distance (in km) between loop start & end points to consider it closed (~30 meters).
  static const double maxLoopDistanceKm = 0.03;

  /// Minimum number of GPS points required to form a closed polygon.
  static const int minPointsForLoop = 5;

  /// Checks if the latest point in [path] closes a loop with any previous point.
  ///
  /// If closed loop is found, returns a newly formed [TerritoryPolygon].
  /// Otherwise returns `null`.
  static TerritoryPolygon? detectClosedLoop({
    required List<GpsPoint> path,
    required String ownerId,
    required String ownerName,
    String ownerColor = '#00F3FF',
  }) {
    if (path.length < minPointsForLoop) return null;

    final latestPoint = path.last;

    // Check against earlier points up to (path.length - 4) to ensure valid loop area
    for (int i = 0; i < path.length - 4; i++) {
      final loopStartDist = HaversineCalculator.calculateDistanceBetweenPoints(
        latestPoint,
        path[i],
      );

      if (loopStartDist <= maxLoopDistanceKm) {
        final loopPoints = path.sublist(i);
        return TerritoryPolygon(
          id: 'poly-${DateTime.now().millisecondsSinceEpoch}',
          ownerId: ownerId,
          ownerName: ownerName,
          ownerColor: ownerColor,
          points: List.unmodifiable(loopPoints),
          capturedAt: DateTime.now(),
        );
      }
    }

    return null;
  }
}
