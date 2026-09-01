import 'package:flutter/foundation.dart';

/// Role of user in ODAT ecosystem.
enum UserRole {
  personal,
  parent,
}

/// Mutual agreement between parent and child.
@immutable
class FamilyAgreement {
  const FamilyAgreement({
    required this.id,
    required this.parentUid,
    required this.childUid,
    this.shareLocation = true,
    this.shareBattery = true,
    this.shareScreenTime = true,
    this.shareStudyProgress = true,
    this.shareAiInterests = true,
    this.isAcceptedByChild = true,
    this.isAcceptedByParent = true,
    this.createdAt,
  });

  final String id;
  final String parentUid;
  final String childUid;
  final bool shareLocation;
  final bool shareBattery;
  final bool shareScreenTime;
  final bool shareStudyProgress;
  final bool shareAiInterests;
  final bool isAcceptedByChild;
  final bool isAcceptedByParent;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'parentUid': parentUid,
        'childUid': childUid,
        'shareLocation': shareLocation,
        'shareBattery': shareBattery,
        'shareScreenTime': shareScreenTime,
        'shareStudyProgress': shareStudyProgress,
        'shareAiInterests': shareAiInterests,
        'isAcceptedByChild': isAcceptedByChild,
        'isAcceptedByParent': isAcceptedByParent,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory FamilyAgreement.fromMap(Map<String, dynamic> map) {
    return FamilyAgreement(
      id: map['id'] as String? ?? '',
      parentUid: map['parentUid'] as String? ?? '',
      childUid: map['childUid'] as String? ?? '',
      shareLocation: map['shareLocation'] as bool? ?? true,
      shareBattery: map['shareBattery'] as bool? ?? true,
      shareScreenTime: map['shareScreenTime'] as bool? ?? true,
      shareStudyProgress: map['shareStudyProgress'] as bool? ?? true,
      shareAiInterests: map['shareAiInterests'] as bool? ?? true,
      isAcceptedByChild: map['isAcceptedByChild'] as bool? ?? true,
      isAcceptedByParent: map['isAcceptedByParent'] as bool? ?? true,
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'] as String) : null,
    );
  }
}

/// Real-time status of the child shown on the Parent Dashboard.
@immutable
class ChildLiveStatus {
  const ChildLiveStatus({
    required this.childUid,
    required this.name,
    required this.avatar,
    required this.batteryLevel,
    required this.isCharging,
    required this.locationName,
    required this.locationUpdatedAtStr,
    required this.todayScreenTimeMinutes,
    required this.todayStudyMinutes,
    required this.todayTasksCompleted,
    required this.todayTasksTotal,
    required this.dailyProgressPercent,
    required this.disciplineScore,
    this.isOnline = true,
  });

  final String childUid;
  final String name;
  final String avatar;
  final int batteryLevel; // 0 to 100
  final bool isCharging;
  final String locationName; // e.g. "School", "Home", "Course"
  final String locationUpdatedAtStr; // e.g. "2 min ago"
  final int todayScreenTimeMinutes;
  final int todayStudyMinutes;
  final int todayTasksCompleted;
  final int todayTasksTotal;
  final int dailyProgressPercent;
  final int disciplineScore;
  final bool isOnline;

  String get formattedScreenTime {
    final h = todayScreenTimeMinutes ~/ 60;
    final m = todayScreenTimeMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  String get formattedStudyTime {
    final h = todayStudyMinutes ~/ 60;
    final m = todayStudyMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}

/// Mission category types supported in Family Missions.
enum MissionType {
  study,
  reading,
  workout,
  location,
  screenTime,
  habit,
  custom,
}

/// Status of a Family Mission.
enum MissionStatus {
  active,
  inProgress,
  submitted,
  verified,
  completed,
  expired,
}

/// Verification method required to confirm mission completion.
enum VerificationMethod {
  aiQuiz,
  cameraPose,
  safeZoneGeofence,
  screenTimeCheck,
  habitCheck,
  parentManual,
}

/// A Parent-created Mission assigned to child.
@immutable
class FamilyMission {
  const FamilyMission({
    required this.id,
    required this.familyId,
    required this.parentId,
    required this.childId,
    required this.type,
    required this.title,
    required this.description,
    required this.targetValue, // e.g. 45 (minutes), 30 (reps), 20 (pages)
    required this.verificationMethod,
    required this.rewardCoins,
    this.currentProgress = 0,
    this.status = MissionStatus.active,
    this.deadlineTimeStr = '21:00',
    this.verificationDetails,
    this.createdAt,
    this.completedAt,
  });

  final String id;
  final String familyId;
  final String parentId;
  final String childId;
  final MissionType type;
  final String title;
  final String description;
  final int targetValue;
  final VerificationMethod verificationMethod;
  final int rewardCoins;
  final int currentProgress;
  final MissionStatus status;
  final String deadlineTimeStr;
  final String? verificationDetails;
  final DateTime? createdAt;
  final DateTime? completedAt;

  bool get isVerified => status == MissionStatus.verified || status == MissionStatus.completed;
  double get progressRatio => targetValue > 0 ? (currentProgress / targetValue).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'familyId': familyId,
        'parentId': parentId,
        'childId': childId,
        'type': type.name,
        'title': title,
        'description': description,
        'targetValue': targetValue,
        'verificationMethod': verificationMethod.name,
        'rewardCoins': rewardCoins,
        'currentProgress': currentProgress,
        'status': status.name,
        'deadlineTimeStr': deadlineTimeStr,
        'verificationDetails': verificationDetails,
        'createdAt': createdAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory FamilyMission.fromMap(Map<String, dynamic> map) {
    return FamilyMission(
      id: map['id'] as String? ?? '',
      familyId: map['familyId'] as String? ?? '',
      parentId: map['parentId'] as String? ?? '',
      childId: map['childId'] as String? ?? '',
      type: MissionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MissionType.custom,
      ),
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      targetValue: (map['targetValue'] as num?)?.toInt() ?? 0,
      verificationMethod: VerificationMethod.values.firstWhere(
        (e) => e.name == map['verificationMethod'],
        orElse: () => VerificationMethod.parentManual,
      ),
      rewardCoins: (map['rewardCoins'] as num?)?.toInt() ?? 0,
      currentProgress: (map['currentProgress'] as num?)?.toInt() ?? 0,
      status: MissionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MissionStatus.active,
      ),
      deadlineTimeStr: map['deadlineTimeStr'] as String? ?? '21:00',
      verificationDetails: map['verificationDetails'] as String?,
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'] as String) : null,
      completedAt: map['completedAt'] != null ? DateTime.tryParse(map['completedAt'] as String) : null,
    );
  }
}

/// Safe zone configured by parent.
@immutable
class SafeZone {
  const SafeZone({
    required this.id,
    required this.name,
    required this.iconName,
    required this.address,
    this.notifyOnArrival = true,
    this.notifyOnDeparture = true,
  });

  final String id;
  final String name;
  final String iconName;
  final String address;
  final bool notifyOnArrival;
  final bool notifyOnDeparture;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'iconName': iconName,
        'address': address,
        'notifyOnArrival': notifyOnArrival,
        'notifyOnDeparture': notifyOnDeparture,
      };

  factory SafeZone.fromMap(Map<String, dynamic> map) {
    return SafeZone(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      iconName: map['iconName'] as String? ?? 'place',
      address: map['address'] as String? ?? '',
      notifyOnArrival: map['notifyOnArrival'] as bool? ?? true,
      notifyOnDeparture: map['notifyOnDeparture'] as bool? ?? true,
    );
  }
}

/// Extra time request when child reaches app limit.
enum ExtraTimeStatus {
  pending,
  approved,
  declined,
}

@immutable
class ExtraTimeRequest {
  const ExtraTimeRequest({
    required this.id,
    required this.childUid,
    required this.childName,
    required this.packageName,
    required this.appName,
    required this.requestedMinutes,
    required this.todayUsageMinutes,
    required this.dailyLimitMinutes,
    this.status = ExtraTimeStatus.pending,
    this.createdAt,
  });

  final String id;
  final String childUid;
  final String childName;
  final String packageName;
  final String appName;
  final int requestedMinutes;
  final int todayUsageMinutes;
  final int dailyLimitMinutes;
  final ExtraTimeStatus status;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'childUid': childUid,
        'childName': childName,
        'packageName': packageName,
        'appName': appName,
        'requestedMinutes': requestedMinutes,
        'todayUsageMinutes': todayUsageMinutes,
        'dailyLimitMinutes': dailyLimitMinutes,
        'status': status.name,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory ExtraTimeRequest.fromMap(Map<String, dynamic> map) {
    return ExtraTimeRequest(
      id: map['id'] as String? ?? '',
      childUid: map['childUid'] as String? ?? '',
      childName: map['childName'] as String? ?? '',
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? '',
      requestedMinutes: (map['requestedMinutes'] as num?)?.toInt() ?? 0,
      todayUsageMinutes: (map['todayUsageMinutes'] as num?)?.toInt() ?? 0,
      dailyLimitMinutes: (map['dailyLimitMinutes'] as num?)?.toInt() ?? 0,
      status: ExtraTimeStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ExtraTimeStatus.pending,
      ),
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'] as String) : null,
    );
  }
}

/// AI Study Verification result.
@immutable
class AiStudyVerification {
  const AiStudyVerification({
    required this.id,
    required this.childUid,
    required this.subject,
    required this.topic,
    required this.durationMinutes,
    required this.score,
    required this.totalQuestions,
    required this.verdict,
    required this.verifiedAtStr,
  });

  final String id;
  final String childUid;
  final String subject;
  final String topic;
  final int durationMinutes;
  final int score;
  final int totalQuestions;
  final String verdict;
  final String verifiedAtStr;

  int get percentage => totalQuestions > 0 ? ((score / totalQuestions) * 100).round() : 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'childUid': childUid,
        'subject': subject,
        'topic': topic,
        'durationMinutes': durationMinutes,
        'score': score,
        'totalQuestions': totalQuestions,
        'verdict': verdict,
        'verifiedAtStr': verifiedAtStr,
      };

  factory AiStudyVerification.fromMap(Map<String, dynamic> map) {
    return AiStudyVerification(
      id: map['id'] as String? ?? '',
      childUid: map['childUid'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      topic: map['topic'] as String? ?? '',
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 0,
      score: (map['score'] as num?)?.toInt() ?? 0,
      totalQuestions: (map['totalQuestions'] as num?)?.toInt() ?? 0,
      verdict: map['verdict'] as String? ?? '',
      verifiedAtStr: map['verifiedAtStr'] as String? ?? '',
    );
  }
}

/// Safety timeline event.
@immutable
class SafetyTimelineEvent {
  const SafetyTimelineEvent({
    required this.timeStr,
    required this.title,
    required this.location,
    required this.type,
  });

  final String timeStr;
  final String title;
  final String location;
  final String type;

  Map<String, dynamic> toMap() => {
        'timeStr': timeStr,
        'title': title,
        'location': location,
        'type': type,
      };

  factory SafetyTimelineEvent.fromMap(Map<String, dynamic> map) {
    return SafetyTimelineEvent(
      timeStr: map['timeStr'] as String? ?? '',
      title: map['title'] as String? ?? '',
      location: map['location'] as String? ?? '',
      type: map['type'] as String? ?? '',
    );
  }
}

/// Longitudinal interest profile.
@immutable
class LearningInterest {
  const LearningInterest({
    required this.category,
    required this.levelStr, // "High", "Medium", "Emerging"
    required this.trendStr, // "Rising ↑", "Stable →"
    required this.percentage,
    required this.weeksObserved,
    required this.evidenceSummary,
  });

  final String category;
  final String levelStr;
  final String trendStr;
  final int percentage;
  final int weeksObserved;
  final String evidenceSummary;

  Map<String, dynamic> toMap() => {
        'category': category,
        'levelStr': levelStr,
        'trendStr': trendStr,
        'percentage': percentage,
        'weeksObserved': weeksObserved,
        'evidenceSummary': evidenceSummary,
      };

  factory LearningInterest.fromMap(Map<String, dynamic> map) {
    return LearningInterest(
      category: map['category'] as String? ?? '',
      levelStr: map['levelStr'] as String? ?? '',
      trendStr: map['trendStr'] as String? ?? '',
      percentage: (map['percentage'] as num?)?.toInt() ?? 0,
      weeksObserved: (map['weeksObserved'] as num?)?.toInt() ?? 0,
      evidenceSummary: map['evidenceSummary'] as String? ?? '',
    );
  }
}

/// Fenix Wallet Model supporting Available, Savings, and Goals.
@immutable
class FenixWalletModel {
  const FenixWalletModel({
    required this.totalBalance,
    required this.availableCoins,
    required this.savingsVaultCoins,
    required this.todayEarnedCoins,
    required this.goals,
  });

  final int totalBalance;
  final int availableCoins;
  final int savingsVaultCoins;
  final int todayEarnedCoins;
  final List<SavingsGoal> goals;
}

/// A target goal created by child or parent.
@immutable
class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.title,
    required this.targetCoins,
    required this.savedCoins,
    required this.iconName,
    this.isParentAgreed = true,
  });

  final String id;
  final String title;
  final int targetCoins;
  final int savedCoins;
  final String iconName;
  final bool isParentAgreed;

  double get progress => targetCoins > 0 ? (savedCoins / targetCoins).clamp(0.0, 1.0) : 0.0;
}
