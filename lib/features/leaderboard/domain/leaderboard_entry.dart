import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/uzbekistan_regions.dart';
import '../../gamification/domain/weekly_reset.dart';

/// A minimal, public-facing view of a user for the leaderboard.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.name,
    required this.avatar,
    required this.weeklyPoints,
    required this.weeklyFocusMinutes,
    required this.monthlyPoints,
    required this.monthlyFocusMinutes,
    required this.totalPoints,
    required this.totalFocusMinutes,
    this.pushUpCount = 0,
    this.runningDistanceKm = 0.0,
    this.district,
    this.photoUrl,
    this.photoBase64,
    this.region,
    this.isOnline = false,
    this.appRole,
    this.familyRole,
  });

  final String uid;
  final String name;
  final String avatar;
  final int weeklyPoints;
  final int weeklyFocusMinutes;

  /// Points accumulated in the current calendar month. Resets on the 1st.
  final int monthlyPoints;
  final int monthlyFocusMinutes;

  final int totalPoints;
  final int totalFocusMinutes;
  final int pushUpCount;
  final double runningDistanceKm;
  final String? district;
  final String? photoUrl;
  final String? photoBase64;
  final bool isOnline;
  final String? appRole;
  final String? familyRole;

  // Only true parents are excluded from leaderboard — NOT children (who may also have appRole='family')
  bool get isParent =>
      familyRole == 'parent' || appRole == 'parent';

  /// The user's Uzbek region key (e.g. "NAVOIY"), used for regional filtering.
  final UzRegion? region;

  factory LeaderboardEntry.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const {};
    final docWeekId = data['currentWeekId'] as String?;
    final isCurrentWeek =
        docWeekId != null && docWeekId == WeeklyReset.weekIdFor(DateTime.now());
    final docMonthId = data['currentMonthId'] as String?;
    final isCurrentMonth =
        docMonthId != null &&
        docMonthId == MonthlyReset.monthIdFor(DateTime.now());
    return LeaderboardEntry(
      uid: doc.id,
      name: (data['displayName'] as String?) ??
          (data['name'] as String?) ??
          'Ishtirokchi',
      avatar: (data['avatar'] as String?) ?? 'leaf',
      weeklyPoints: isCurrentWeek
          ? ((data['weeklyPoints'] as num?)?.toInt() ?? 0)
          : 0,
      weeklyFocusMinutes: isCurrentWeek
          ? ((data['weeklyFocusMinutes'] as num?)?.toInt() ?? 0)
          : 0,
      monthlyPoints: isCurrentMonth
          ? ((data['monthlyPoints'] as num?)?.toInt() ?? 0)
          : 0,
      monthlyFocusMinutes: isCurrentMonth
          ? ((data['monthlyFocusMinutes'] as num?)?.toInt() ?? 0)
          : 0,
      totalPoints: (data['totalPoints'] as num?)?.toInt() ?? 0,
      totalFocusMinutes: (data['totalFocusMinutes'] as num?)?.toInt() ?? 0,
      pushUpCount: (data['pushUpCount'] as num?)?.toInt() ?? ((data['totalPushUps'] as num?)?.toInt() ?? 0),
      runningDistanceKm: (data['runningDistanceKm'] as num?)?.toDouble() ?? ((data['totalRunningKm'] as num?)?.toDouble() ?? 0.0),
      district: data['district'] as String?,
      photoUrl: data['photoUrl'] as String?,
      photoBase64: data['photoBase64'] as String?,
      region: UzRegion.fromFirestoreKey(data['region'] as String?),
      isOnline: data['isOnline'] as bool? ?? false,
      appRole: data['appRole'] as String?,
      familyRole: data['familyRole'] as String?,
    );
  }

  factory LeaderboardEntry.fromProfile(dynamic profile, [int rank = 0]) {
    bool onlineStatus = false;
    try {
      onlineStatus = profile.isOnline as bool? ?? false;
    } catch (_) {}

    String? aRole;
    String? fRole;
    try {
      aRole = profile.appRole as String?;
      fRole = profile.familyRole as String?;
    } catch (_) {}

    return LeaderboardEntry(
      uid: profile.uid as String,
      name: (profile.displayName as String?) ?? (profile.name as String?) ?? 'Foydalanuvchi',
      avatar: (profile.avatar as String?) ?? 'leaf',
      weeklyPoints: (profile.weeklyPoints as int?) ?? 0,
      weeklyFocusMinutes: (profile.weeklyFocusMinutes as int?) ?? 0,
      monthlyPoints: (profile.monthlyPoints as int?) ?? 0,
      monthlyFocusMinutes: (profile.monthlyFocusMinutes as int?) ?? 0,
      totalPoints: (profile.totalPoints as int?) ?? 0,
      totalFocusMinutes: (profile.totalFocusMinutes as int?) ?? 0,
      pushUpCount: 0,
      runningDistanceKm: (profile.totalRunningKm as double?) ?? 0.0,
      district: null,
      photoUrl: profile.photoUrl as String?,
      photoBase64: profile.photoBase64 as String?,
      region: null,
      isOnline: onlineStatus,
      appRole: aRole,
      familyRole: fRole,
    );
  }

  LeaderboardEntry copyWith({
    String? uid,
    String? name,
    String? avatar,
    int? weeklyPoints,
    int? weeklyFocusMinutes,
    int? monthlyPoints,
    int? monthlyFocusMinutes,
    int? totalPoints,
    int? totalFocusMinutes,
    int? pushUpCount,
    double? runningDistanceKm,
    String? district,
    String? photoUrl,
    String? photoBase64,
    UzRegion? region,
    int? rank,
    bool? isOnline,
  }) {
    return LeaderboardEntry(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      weeklyPoints: weeklyPoints ?? this.weeklyPoints,
      weeklyFocusMinutes: weeklyFocusMinutes ?? this.weeklyFocusMinutes,
      monthlyPoints: monthlyPoints ?? this.monthlyPoints,
      monthlyFocusMinutes: monthlyFocusMinutes ?? this.monthlyFocusMinutes,
      totalPoints: totalPoints ?? this.totalPoints,
      totalFocusMinutes: totalFocusMinutes ?? this.totalFocusMinutes,
      pushUpCount: pushUpCount ?? this.pushUpCount,
      runningDistanceKm: runningDistanceKm ?? this.runningDistanceKm,
      district: district ?? this.district,
      photoUrl: photoUrl ?? this.photoUrl,
      photoBase64: photoBase64 ?? this.photoBase64,
      region: region ?? this.region,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
