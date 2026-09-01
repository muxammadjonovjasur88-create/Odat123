import 'dart:math' as math;
import '../models/territory_polygon.dart';
import 'haversine_calculator.dart';

/// Pure Geospatial Service for Territory Generation, Collision Detection,
/// Centroid Calculation, and Loop Verification.
abstract final class TerritoryGeometryService {
  static const double earthRadiusMeters = 6378137.0;

  /// Verifies if a point lies strictly inside a polygon using Ray-Casting algorithm.
  static bool isPointInPolygon(GpsPoint point, List<GpsPoint> polygon) {
    if (polygon.length < 3) return false;

    // Quick bounding box pre-filter
    double minLat = polygon[0].latitude;
    double maxLat = polygon[0].latitude;
    double minLng = polygon[0].longitude;
    double maxLng = polygon[0].longitude;

    for (final p in polygon) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    if (point.latitude < minLat ||
        point.latitude > maxLat ||
        point.longitude < minLng ||
        point.longitude > maxLng) {
      return false;
    }

    // Ray-Casting (Even-Odd rule)
    bool inside = false;
    final int n = polygon.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;

      final intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }

    return inside;
  }

  /// Calculates the visual centroid (center of mass) of a polygon for placing
  /// the owner logo / avatar in the center.
  static GpsPoint calculateCentroid(List<GpsPoint> polygon) {
    if (polygon.isEmpty) return const GpsPoint(latitude: 0, longitude: 0);
    if (polygon.length == 1) return polygon.first;
    if (polygon.length == 2) {
      return GpsPoint(
        latitude: (polygon[0].latitude + polygon[1].latitude) / 2.0,
        longitude: (polygon[0].longitude + polygon[1].longitude) / 2.0,
      );
    }

    double signedArea = 0.0;
    double cx = 0.0;
    double cy = 0.0;
    final int n = polygon.length;

    for (int i = 0; i < n; i++) {
      final x0 = polygon[i].longitude;
      final y0 = polygon[i].latitude;
      final x1 = polygon[(i + 1) % n].longitude;
      final y1 = polygon[(i + 1) % n].latitude;

      final a = (x0 * y1) - (x1 * y0);
      signedArea += a;
      cx += (x0 + x1) * a;
      cy += (y0 + y1) * a;
    }

    signedArea *= 0.5;

    if (signedArea.abs() < 1e-9) {
      // Fallback to geometric average if polygon is degenerate
      double sumLat = 0.0;
      double sumLng = 0.0;
      for (final p in polygon) {
        sumLat += p.latitude;
        sumLng += p.longitude;
      }
      return GpsPoint(
        latitude: sumLat / polygon.length,
        longitude: sumLng / polygon.length,
      );
    }

    cx /= (6.0 * signedArea);
    cy /= (6.0 * signedArea);

    final centroid = GpsPoint(latitude: cy, longitude: cx);

    // If irregular concave polygon makes centroid fall outside, pick nearest interior point
    if (!isPointInPolygon(centroid, polygon)) {
      double sumLat = 0.0;
      double sumLng = 0.0;
      for (final p in polygon) {
        sumLat += p.latitude;
        sumLng += p.longitude;
      }
      return GpsPoint(
        latitude: sumLat / polygon.length,
        longitude: sumLng / polygon.length,
      );
    }

    return centroid;
  }

  /// Checks if two segments AB and CD intersect
  static bool _segmentsIntersect(
    GpsPoint a,
    GpsPoint b,
    GpsPoint c,
    GpsPoint d,
  ) {
    double ccw(GpsPoint p1, GpsPoint p2, GpsPoint p3) {
      return (p3.latitude - p1.latitude) * (p2.longitude - p1.longitude) -
          (p2.latitude - p1.latitude) * (p3.longitude - p1.longitude);
    }

    final ccw1 = ccw(a, c, d);
    final ccw2 = ccw(b, c, d);
    final ccw3 = ccw(a, b, c);
    final ccw4 = ccw(a, b, d);

    return ((ccw1 > 0 && ccw2 < 0) || (ccw1 < 0 && ccw2 > 0)) &&
        ((ccw3 > 0 && ccw4 < 0) || (ccw3 < 0 && ccw4 > 0));
  }

  /// Detects if two polygons intersect (route crossing or area overlap)
  static bool doPolygonsIntersect(List<GpsPoint> polyA, List<GpsPoint> polyB) {
    if (polyA.length < 3 || polyB.length < 3) return false;

    // 1. Check if any vertex of A is inside B
    for (final p in polyA) {
      if (isPointInPolygon(p, polyB)) return true;
    }

    // 2. Check if any vertex of B is inside A
    for (final p in polyB) {
      if (isPointInPolygon(p, polyA)) return true;
    }

    // 3. Check if any edge of A intersects any edge of B
    for (int i = 0; i < polyA.length; i++) {
      final a1 = polyA[i];
      final a2 = polyA[(i + 1) % polyA.length];

      for (int j = 0; j < polyB.length; j++) {
        final b1 = polyB[j];
        final b2 = polyB[(j + 1) % polyB.length];

        if (_segmentsIntersect(a1, a2, b1, b2)) return true;
      }
    }

    return false;
  }

  /// Calculates geodesic area in square meters using spherical excess formula
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

    return (total.abs() * earthRadiusMeters * earthRadiusMeters) / 2.0;
  }

  /// Verifies if runner has returned to the START point within the configured finish radius
  static bool isLoopClosedAtStart({
    required GpsPoint startPoint,
    required GpsPoint currentPoint,
    double finishRadiusMeters = 25.0,
    double minTotalDistanceMeters = 150.0,
    double currentDistanceRanMeters = 0.0,
  }) {
    // 1. Must satisfy minimum total distance ran (prevents standing in place)
    if (currentDistanceRanMeters < minTotalDistanceMeters) return false;

    // 2. Geographic distance from current GPS position to original START point
    final distKm = HaversineCalculator.calculateDistanceBetweenPoints(
      startPoint,
      currentPoint,
    );
    final distMeters = distKm * 1000.0;

    return distMeters <= finishRadiusMeters;
  }

  /// Ramer-Douglas-Peucker route simplification algorithm
  static List<GpsPoint> simplifyRoute(List<GpsPoint> points, {double tolerance = 0.00005}) {
    if (points.length <= 4) return points;

    double perpendicularDistance(GpsPoint p, GpsPoint lineStart, GpsPoint lineEnd) {
      final double dx = lineEnd.longitude - lineStart.longitude;
      final double dy = lineEnd.latitude - lineStart.latitude;
      final double mag = math.sqrt(dx * dx + dy * dy);
      if (mag < 1e-9) {
        return math.sqrt(math.pow(p.longitude - lineStart.longitude, 2) +
            math.pow(p.latitude - lineStart.latitude, 2));
      }
      final double u = ((p.longitude - lineStart.longitude) * dx +
              (p.latitude - lineStart.latitude) * dy) /
          (mag * mag);
      final double clampedU = u.clamp(0.0, 1.0);
      final double ix = lineStart.longitude + clampedU * dx;
      final double iy = lineStart.latitude + clampedU * dy;
      return math.sqrt(
          math.pow(p.longitude - ix, 2) + math.pow(p.latitude - iy, 2));
    }

    void rdp(int start, int end, List<bool> keep) {
      double maxDist = 0.0;
      int index = start;

      for (int i = start + 1; i < end; i++) {
        final dist = perpendicularDistance(points[i], points[start], points[end]);
        if (dist > maxDist) {
          maxDist = dist;
          index = i;
        }
      }

      if (maxDist > tolerance) {
        keep[index] = true;
        rdp(start, index, keep);
        rdp(index, end, keep);
      }
    }

    final keep = List<bool>.filled(points.length, false);
    keep[0] = true;
    keep[points.length - 1] = true;

    rdp(0, points.length - 1, keep);

    final result = <GpsPoint>[];
    for (int i = 0; i < points.length; i++) {
      if (keep[i]) result.add(points[i]);
    }
    return result;
  }
}
