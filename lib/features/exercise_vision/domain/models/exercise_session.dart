import 'package:flutter/foundation.dart';

@immutable
class ExerciseSession {
  const ExerciseSession({
    required this.id,
    required this.userId,
    required this.exerciseType,
    required this.repCount,
    required this.durationSeconds,
    required this.pointsEarned,
    required this.completedAt,
  });

  final String id;
  final String userId;
  final String exerciseType;
  final int repCount;
  final int durationSeconds;
  final int pointsEarned;
  final DateTime completedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'exerciseType': exerciseType,
        'repCount': repCount,
        'durationSeconds': durationSeconds,
        'pointsEarned': pointsEarned,
        'completedAt': completedAt.toIso8601String(),
      };

  factory ExerciseSession.fromMap(Map<String, dynamic> map, {String? id}) {
    return ExerciseSession(
      id: id ?? (map['id'] as String? ?? ''),
      userId: map['userId'] as String? ?? '',
      exerciseType: map['exerciseType'] as String? ?? 'SQUAT',
      repCount: (map['repCount'] as num?)?.toInt() ?? 0,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      pointsEarned: (map['pointsEarned'] as num?)?.toInt() ?? 0,
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
