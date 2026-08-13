import 'dart:math' as math;
import '../models/territory_polygon.dart';

/// Haversine formula helper to compute exact distance in kilometers between two lat/lng points.
abstract final class HaversineCalculator {
  static const double _earthRadiusKm = 6371.0;

  /// Calculates the Haversine distance in kilometers between two GPS coordinates (lat/lng in degrees).
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  /// Helper to calculate distance between two [GpsPoint] objects in km.
  static double calculateDistanceBetweenPoints(GpsPoint p1, GpsPoint p2) {
    return calculateDistance(p1.latitude, p1.longitude, p2.latitude, p2.longitude);
  }

  static double _toRadians(double degree) => degree * (math.pi / 180.0);
}
