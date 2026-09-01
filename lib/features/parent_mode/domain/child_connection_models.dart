import 'package:flutter/foundation.dart';

enum ConnectionRequestStatus {
  pending,
  accepted,
  declined,
  expired,
}

@immutable
class ChildAccountSummary {
  const ChildAccountSummary({
    required this.id,
    required this.odatId,
    required this.name,
    required this.avatarUrl,
    required this.completedMissionsCount,
    required this.totalMissionsCount,
    required this.fenixBalance,
    required this.screenTimeMinutesToday,
    required this.batteryLevel,
    required this.isLiveOnline,
  });

  final String id;
  final String odatId;
  final String name;
  final String avatarUrl;
  final int completedMissionsCount;
  final int totalMissionsCount;
  final int fenixBalance;
  final int screenTimeMinutesToday;
  final int batteryLevel;
  final bool isLiveOnline;
}

@immutable
class FamilyConnectionRequest {
  const FamilyConnectionRequest({
    required this.requestId,
    required this.parentId,
    required this.parentName,
    required this.childOdatId,
    required this.childName,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  final String requestId;
  final String parentId;
  final String parentName;
  final String childOdatId;
  final String childName;
  final ConnectionRequestStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  bool get isPending => status == ConnectionRequestStatus.pending;
  bool get isAccepted => status == ConnectionRequestStatus.accepted;
}
