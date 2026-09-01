import 'package:flutter/foundation.dart';

@immutable
class MatchedPeer {
  const MatchedPeer({
    required this.id,
    required this.odatId,
    required this.name,
    required this.avatarUrl,
    required this.primaryInterest,
    required this.currentGoal,
    required this.matchPercent,
    required this.matchReasons,
    required this.preferredTime,
    required this.areaSummary,
  });

  final String id;
  final String odatId;
  final String name;
  final String avatarUrl;
  final String primaryInterest;
  final String currentGoal;
  final int matchPercent;
  final List<String> matchReasons;
  final String preferredTime;
  final String areaSummary;
}

@immutable
class GrowthSquad {
  const GrowthSquad({
    required this.id,
    required this.name,
    required this.goalTitle,
    required this.membersCount,
    required this.maxMembers,
    required this.daysRemaining,
    required this.aggregateProgressPercent,
    required this.isJoined,
  });

  final String id;
  final String name;
  final String goalTitle;
  final int membersCount;
  final int maxMembers;
  final int daysRemaining;
  final int aggregateProgressPercent;
  final bool isJoined;
}

@immutable
class ActivityRoom {
  const ActivityRoom({
    required this.id,
    required this.title,
    required this.category,
    required this.scheduledTime,
    required this.participantsCount,
    required this.hostName,
    required this.status,
  });

  final String id;
  final String title;
  final String category;
  final String scheduledTime;
  final int participantsCount;
  final String hostName;
  final String status;
}
