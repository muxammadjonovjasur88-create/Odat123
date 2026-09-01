import 'package:flutter/foundation.dart';

enum FamilyGoalStatus {
  pending,
  accepted,
  declined,
  completed,
}

enum FamilyGoalCategory {
  reading,
  running,
  workout,
  study,
  focus,
  habit,
  custom,
}

@immutable
class FamilyGoal {
  const FamilyGoal({
    required this.id,
    required this.parentId,
    required this.parentName,
    required this.childId,
    required this.title,
    required this.category,
    required this.scheduledTime, // e.g. "20:00"
    required this.targetValue, // e.g. 20 (pages), 3 (km), 30 (min)
    required this.unit, // e.g. "bet", "km", "daqiqa"
    required this.rewardCoins, // e.g. 2
    this.status = FamilyGoalStatus.pending,
    this.currentProgress = 0,
    this.isAutoVerified = false,
    this.createdAt,
    this.respondedAt,
    this.completedAt,
  });

  final String id;
  final String parentId;
  final String parentName;
  final String childId;
  final String title;
  final FamilyGoalCategory category;
  final String scheduledTime;
  final int targetValue;
  final String unit;
  final int rewardCoins;
  final FamilyGoalStatus status;
  final int currentProgress;
  final bool isAutoVerified;
  final DateTime? createdAt;
  final DateTime? respondedAt;
  final DateTime? completedAt;

  bool get isPending => status == FamilyGoalStatus.pending;
  bool get isAccepted => status == FamilyGoalStatus.accepted || status == FamilyGoalStatus.completed;
  bool get isCompleted => status == FamilyGoalStatus.completed;
  bool get isDeclined => status == FamilyGoalStatus.declined;

  double get progressRatio => targetValue > 0 ? (currentProgress / targetValue).clamp(0.0, 1.0) : 0.0;

  FamilyGoal copyWith({
    FamilyGoalStatus? status,
    int? currentProgress,
    bool? isAutoVerified,
    DateTime? respondedAt,
    DateTime? completedAt,
  }) {
    return FamilyGoal(
      id: id,
      parentId: parentId,
      parentName: parentName,
      childId: childId,
      title: title,
      category: category,
      scheduledTime: scheduledTime,
      targetValue: targetValue,
      unit: unit,
      rewardCoins: rewardCoins,
      status: status ?? this.status,
      currentProgress: currentProgress ?? this.currentProgress,
      isAutoVerified: isAutoVerified ?? this.isAutoVerified,
      createdAt: createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
