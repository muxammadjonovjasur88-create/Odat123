import 'package:flutter/foundation.dart';
import 'territory_polygon.dart';

@immutable
class RunSession {
  const RunSession({
    required this.id,
    required this.userId,
    required this.exerciseType,
    required this.startedAt,
    required this.endedAt,
    required this.distanceKm,
    required this.durationSeconds,
    required this.caloriesBurned,
    required this.avgSpeedKmh,
    required this.avgPaceMinKm,
    required this.gpsPath,
    required this.territoriesGained,
    required this.pointsEarned,
  });

  final String id;
  final String userId;
  final String exerciseType; // 'RUNNING' or 'WALKING'
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceKm;
  final int durationSeconds;
  final int caloriesBurned;
  final double avgSpeedKmh;
  final String avgPaceMinKm;
  final List<GpsPoint> gpsPath;
  final List<TerritoryPolygon> territoriesGained;
  final int pointsEarned;

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'exerciseType': exerciseType,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'distanceKm': distanceKm,
        'durationSeconds': durationSeconds,
        'caloriesBurned': caloriesBurned,
        'avgSpeedKmh': avgSpeedKmh,
        'avgPaceMinKm': avgPaceMinKm,
        'gpsPath': gpsPath.map((p) => p.toMap()).toList(),
        'territoriesGained': territoriesGained.map((t) => t.toMap()).toList(),
        'pointsEarned': pointsEarned,
      };

  factory RunSession.fromMap(Map<String, dynamic> map, {String? id}) {
    return RunSession(
      id: id ?? (map['id'] as String? ?? ''),
      userId: map['userId'] as String? ?? '',
      exerciseType: map['exerciseType'] as String? ?? 'RUNNING',
      startedAt: map['startedAt'] != null
          ? DateTime.tryParse(map['startedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      endedAt: map['endedAt'] != null
          ? DateTime.tryParse(map['endedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      caloriesBurned: (map['caloriesBurned'] as num?)?.toInt() ?? 0,
      avgSpeedKmh: (map['avgSpeedKmh'] as num?)?.toDouble() ?? 0.0,
      avgPaceMinKm: map['avgPaceMinKm'] as String? ?? "0'00\"",
      gpsPath: (map['gpsPath'] as List<dynamic>?)
              ?.map((e) => GpsPoint.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      territoriesGained: (map['territoriesGained'] as List<dynamic>?)
              ?.map((e) => TerritoryPolygon.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      pointsEarned: (map['pointsEarned'] as num?)?.toInt() ?? 0,
    );
  }
}
