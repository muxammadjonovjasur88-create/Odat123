import 'package:flutter/foundation.dart';
import '../services/territory_geometry_service.dart';
import 'defense_structure.dart';

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
    final lat = (map['latitude'] ?? map['lat'] ?? 0.0) as num;
    final lng = (map['longitude'] ?? map['lng'] ?? 0.0) as num;
    return GpsPoint(
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is String
              ? DateTime.tryParse(map['timestamp'] as String)
              : null)
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
    this.areaSqMeters = 0.0,
    this.status = 'owned', // 'owned', 'contested', 'under_attack'
    this.clanId,
    this.clanName,
    this.ownerAvatar,
    this.centroid,
    this.defenseStructures = const [],
  });

  final String id;
  final String ownerId;
  final String ownerName;
  final String ownerColor; // e.g. '#5BC8FA'
  final List<GpsPoint> points;
  final DateTime capturedAt;
  final double areaSqMeters;
  final String status;
  final String? clanId;
  final String? clanName;
  final String? ownerAvatar;
  final GpsPoint? centroid;
  final List<DefenseStructure> defenseStructures;

  /// Visual center of mass for placing owner logo/avatar
  GpsPoint get actualCentroid =>
      centroid ?? TerritoryGeometryService.calculateCentroid(points);

  /// Defense tower capacity based on territory area:
  /// < 500 m² -> 1 tower
  /// 500 - 2,500 m² -> 3 towers
  /// > 2,500 m² -> 5 towers
  int get defenseCapacity {
    if (areaSqMeters < 500) return 1;
    if (areaSqMeters < 2500) return 3;
    return 5;
  }

  /// Total defensive power sum of all structures
  int get totalDefensePower {
    if (defenseStructures.isEmpty) return 15; // Base defense
    return defenseStructures.fold<int>(
      0,
      (sum, s) => sum + s.defensePower + (s.hp ~/ 10),
    );
  }

  /// Highest structure level in territory
  int get highestDefenseLevel {
    if (defenseStructures.isEmpty) return 0;
    return defenseStructures
        .map((s) => s.level)
        .reduce((a, b) => a > b ? a : b);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'ownerId': ownerId,
        'ownerName': ownerName,
        'ownerColor': ownerColor,
        'points': points.map((p) => p.toMap()).toList(),
        'capturedAt': capturedAt.toIso8601String(),
        'areaSqMeters': areaSqMeters,
        'status': status,
        'clanId': clanId,
        'clanName': clanName,
        'ownerAvatar': ownerAvatar,
        'centroidLat': actualCentroid.latitude,
        'centroidLng': actualCentroid.longitude,
      };

  factory TerritoryPolygon.fromMap(Map<String, dynamic> map, {String? id}) {
    final pts = (map['points'] as List<dynamic>?)
            ?.map((e) => GpsPoint.fromMap(e as Map<String, dynamic>))
            .toList() ??
        const [];

    GpsPoint? centroid;
    if (map['centroidLat'] != null && map['centroidLng'] != null) {
      centroid = GpsPoint(
        latitude: (map['centroidLat'] as num).toDouble(),
        longitude: (map['centroidLng'] as num).toDouble(),
      );
    }

    return TerritoryPolygon(
      id: id ?? (map['id'] as String? ?? ''),
      ownerId: map['ownerId'] as String? ?? (map['uid'] as String? ?? ''),
      ownerName:
          map['ownerName'] as String? ?? (map['userName'] as String? ?? ''),
      ownerColor: map['ownerColor'] as String? ?? '#5BC8FA',
      points: pts,
      capturedAt: map['capturedAt'] != null
          ? (map['capturedAt'] is String
              ? DateTime.tryParse(map['capturedAt'] as String) ?? DateTime.now()
              : DateTime.now())
          : DateTime.now(),
      areaSqMeters: (map['areaSqMeters'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? 'owned',
      clanId: map['clanId'] as String?,
      clanName: map['clanName'] as String? ?? (map['clanTag'] as String?),
      ownerAvatar: map['ownerAvatar'] as String?,
      centroid: centroid,
    );
  }

  TerritoryPolygon copyWith({
    String? status,
    List<DefenseStructure>? defenseStructures,
    String? ownerId,
    String? ownerName,
    String? ownerColor,
    String? ownerAvatar,
  }) {
    return TerritoryPolygon(
      id: id,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      ownerColor: ownerColor ?? this.ownerColor,
      points: points,
      capturedAt: capturedAt,
      areaSqMeters: areaSqMeters,
      status: status ?? this.status,
      clanId: clanId,
      clanName: clanName,
      ownerAvatar: ownerAvatar ?? this.ownerAvatar,
      centroid: centroid,
      defenseStructures: defenseStructures ?? this.defenseStructures,
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
