import 'package:flutter/foundation.dart';

enum PlaceEventType {
  arrival,
  departure,
}

@immutable
class FamilyPlace {
  const FamilyPlace({
    required this.id,
    required this.name,
    required this.iconName,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.notifyOnArrival = true,
    this.notifyOnDeparture = true,
    required this.address,
    this.createdAt,
  });

  final String id;
  final String name;
  final String iconName;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool notifyOnArrival;
  final bool notifyOnDeparture;
  final String address;
  final DateTime? createdAt;

  FamilyPlace copyWith({
    String? name,
    String? iconName,
    double? radiusMeters,
    bool? notifyOnArrival,
    bool? notifyOnDeparture,
    String? address,
  }) {
    return FamilyPlace(
      id: id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      notifyOnArrival: notifyOnArrival ?? this.notifyOnArrival,
      notifyOnDeparture: notifyOnDeparture ?? this.notifyOnDeparture,
      address: address ?? this.address,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'iconName': iconName,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
        'notifyOnArrival': notifyOnArrival,
        'notifyOnDeparture': notifyOnDeparture,
        'address': address,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory FamilyPlace.fromMap(Map<String, dynamic> map) {
    return FamilyPlace(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      iconName: map['iconName'] as String? ?? 'place',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      radiusMeters: (map['radiusMeters'] as num?)?.toDouble() ?? 100.0,
      notifyOnArrival: map['notifyOnArrival'] as bool? ?? true,
      notifyOnDeparture: map['notifyOnDeparture'] as bool? ?? true,
      address: map['address'] as String? ?? '',
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'] as String) : null,
    );
  }
}

@immutable
class PlaceEvent {
  const PlaceEvent({
    required this.id,
    required this.placeId,
    required this.placeName,
    required this.type,
    required this.timeStr,
    required this.timestamp,
    required this.batteryLevel,
  });

  final String id;
  final String placeId;
  final String placeName;
  final PlaceEventType type;
  final String timeStr;
  final DateTime timestamp;
  final int batteryLevel;

  bool get isArrival => type == PlaceEventType.arrival;

  Map<String, dynamic> toMap() => {
        'id': id,
        'placeId': placeId,
        'placeName': placeName,
        'type': type.name,
        'timeStr': timeStr,
        'timestamp': timestamp.toIso8601String(),
        'batteryLevel': batteryLevel,
      };

  factory PlaceEvent.fromMap(Map<String, dynamic> map) {
    return PlaceEvent(
      id: map['id'] as String? ?? '',
      placeId: map['placeId'] as String? ?? '',
      placeName: map['placeName'] as String? ?? '',
      type: PlaceEventType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PlaceEventType.arrival,
      ),
      timeStr: map['timeStr'] as String? ?? '',
      timestamp: map['timestamp'] != null ? DateTime.parse(map['timestamp'] as String) : DateTime.now(),
      batteryLevel: (map['batteryLevel'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class RouteHistoryPoint {
  const RouteHistoryPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.timeStr,
    required this.batteryLevel,
    this.placeName,
    this.isOfflineGap = false,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String timeStr;
  final int batteryLevel;
  final String? placeName;
  final bool isOfflineGap;

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toIso8601String(),
        'timeStr': timeStr,
        'batteryLevel': batteryLevel,
        'placeName': placeName,
        'isOfflineGap': isOfflineGap,
      };

  factory RouteHistoryPoint.fromMap(Map<String, dynamic> map) {
    return RouteHistoryPoint(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      timestamp: map['timestamp'] != null ? DateTime.parse(map['timestamp'] as String) : DateTime.now(),
      timeStr: map['timeStr'] as String? ?? '',
      batteryLevel: (map['batteryLevel'] as num?)?.toInt() ?? 0,
      placeName: map['placeName'] as String?,
      isOfflineGap: map['isOfflineGap'] as bool? ?? false,
    );
  }
}

@immutable
class DayRouteHistory {
  const DayRouteHistory({
    required this.date,
    required this.totalDistanceKm,
    required this.points,
    required this.events,
  });

  final DateTime date;
  final double totalDistanceKm;
  final List<RouteHistoryPoint> points;
  final List<PlaceEvent> events;

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'totalDistanceKm': totalDistanceKm,
        'points': points.map((p) => p.toMap()).toList(),
        'events': events.map((e) => e.toMap()).toList(),
      };

  factory DayRouteHistory.fromMap(Map<String, dynamic> map) {
    return DayRouteHistory(
      date: map['date'] != null ? DateTime.parse(map['date'] as String) : DateTime.now(),
      totalDistanceKm: (map['totalDistanceKm'] as num?)?.toDouble() ?? 0.0,
      points: (map['points'] as List?)?.map((p) => RouteHistoryPoint.fromMap(p as Map<String, dynamic>)).toList() ?? [],
      events: (map['events'] as List?)?.map((e) => PlaceEvent.fromMap(e as Map<String, dynamic>)).toList() ?? [],
    );
  }
}
