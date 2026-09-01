import 'dart:math' as math;
import '../models/territory_polygon.dart';
import 'haversine_calculator.dart';

/// Service responsible for detecting closed-loop territory conquests and calculating area.
abstract final class TerritoryConquestService {
  /// Maximum distance (in km) between loop start & end points to consider it closed (~30 meters).
  static const double maxLoopDistanceKm = 0.035; // 35 meters

  /// Minimum number of GPS points required to form a closed polygon.
  static const int minPointsForLoop = 5;

  /// Minimum polygon area in m² to avoid false positive micro-loops.
  static const double minLoopAreaSqMeters = 20.0;

  /// Earth radius in meters
  static const double _earthRadiusMeters = 6378137.0;

  /// Calculates the geodesic area of a polygon defined by [points] in square meters (m²).
  /// Uses the spherical excess / Gauss Shoelace formula on WGS84 sphere.
  static double calculatePolygonAreaSqMeters(List<GpsPoint> points) {
    if (points.length < 3) return 0.0;

    double total = 0.0;
    final int n = points.length;

    for (int i = 0; i < n; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % n];

      final lat1Rad = p1.latitude * (math.pi / 180.0);
      final lat2Rad = p2.latitude * (math.pi / 180.0);
      final lon1Rad = p1.longitude * (math.pi / 180.0);
      final lon2Rad = p2.longitude * (math.pi / 180.0);

      total += (lon2Rad - lon1Rad) * (2.0 + math.sin(lat1Rad) + math.sin(lat2Rad));
    }

    final area = (total.abs() * _earthRadiusMeters * _earthRadiusMeters) / 2.0;
    return area;
  }

  /// Formats area in square meters to user-friendly string (e.g., '1,250 m²' or '1.45 km²').
  static String formatArea(double areaSqMeters) {
    if (areaSqMeters >= 1000000) {
      final sqKm = areaSqMeters / 1000000.0;
      return '${sqKm.toStringAsFixed(2)} km²';
    } else {
      return '${areaSqMeters.round()} m²';
    }
  }

  /// Checks if the latest point in [path] closes a loop with any previous point.
  ///
  /// If closed loop is found, returns a newly formed [TerritoryPolygon] with its calculated area.
  /// Otherwise returns `null`.
  static TerritoryPolygon? detectClosedLoop({
    required List<GpsPoint> path,
    required String ownerId,
    required String ownerName,
    String ownerColor = '#5BC8FA',
    String? clanId,
    String? clanName,
    String? ownerAvatar,
  }) {
    final length = path.length;
    if (length < minPointsForLoop) return null;

    final latestPoint = path.last;
    const maxDegreeDiff = 0.0005; // ~55m fast bounding box filter

    // Adaptive step: check points without stalling the event loop
    final int step = length > 300 ? 3 : (length > 100 ? 2 : 1);

    for (int i = 0; i <= length - 5; i += step) {
      final candidate = path[i];

      // Fast coordinate bounding-box rejection before calculating Haversine
      if ((latestPoint.latitude - candidate.latitude).abs() > maxDegreeDiff ||
          (latestPoint.longitude - candidate.longitude).abs() > maxDegreeDiff) {
        continue;
      }

      final loopStartDist = HaversineCalculator.calculateDistanceBetweenPoints(
        latestPoint,
        candidate,
      );

      if (loopStartDist <= maxLoopDistanceKm) {
        final loopPoints = path.sublist(i);
        final area = calculatePolygonAreaSqMeters(loopPoints);

        if (area >= minLoopAreaSqMeters) {
          return TerritoryPolygon(
            id: 'poly-${DateTime.now().millisecondsSinceEpoch}',
            ownerId: ownerId,
            ownerName: ownerName,
            ownerColor: ownerColor,
            points: List.unmodifiable(loopPoints),
            capturedAt: DateTime.now(),
            areaSqMeters: area,
            clanId: clanId,
            clanName: clanName,
            ownerAvatar: ownerAvatar,
          );
        }
      }
    }

    return null;
  }
}
