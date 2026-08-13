import 'package:flutter/foundation.dart';

/// Single GPS coordinate point with latitude, longitude, and timestamp.
@immutable
class GpsPoint {
  const GpsPoint({
    required this.latitude,
    required this.longitude,
    this.timestamp,
  });

  final double latitude;
  final double longitude;
  final DateTime? timestamp;

  DateTime get actualTimestamp => timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': actualTimestamp.toIso8601String(),
      };

  factory GpsPoint.fromMap(Map<String, dynamic> map) {
    return GpsPoint(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GpsPoint &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;

  @override
  String toString() => 'GpsPoint($latitude, $longitude)';
}

/// Polygon territory captured when a runner completes a closed loop.
@immutable
class TerritoryPolygon {
  const TerritoryPolygon({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.ownerColor,
    required this.points,
    required this.capturedAt,
  });

  final String id;
  final String ownerId;
  final String ownerName;
  final String ownerColor; // e.g. '#00F3FF'
  final List<GpsPoint> points;
  final DateTime capturedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'ownerId': ownerId,
        'ownerName': ownerName,
        'ownerColor': ownerColor,
        'points': points.map((p) => p.toMap()).toList(),
        'capturedAt': capturedAt.toIso8601String(),
      };

  factory TerritoryPolygon.fromMap(Map<String, dynamic> map) {
    return TerritoryPolygon(
      id: map['id'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      ownerName: map['ownerName'] as String? ?? '',
      ownerColor: map['ownerColor'] as String? ?? '#00F3FF',
      points: (map['points'] as List<dynamic>?)
              ?.map((e) => GpsPoint.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      capturedAt: map['capturedAt'] != null
          ? DateTime.tryParse(map['capturedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TerritoryPolygon &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
