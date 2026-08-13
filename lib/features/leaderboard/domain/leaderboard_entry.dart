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
    this.photoUrl,
    this.photoBase64,
    this.region,
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
  final String? photoUrl;
  final String? photoBase64;

  /// The user's Uzbek region key (e.g. "NAVOIY"), used for regional filtering.
  /// Null if the user has not enabled location.
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
          'Friend',
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
      photoUrl: data['photoUrl'] as String?,
      photoBase64: data['photoBase64'] as String?,
      region: UzRegion.fromFirestoreKey(data['region'] as String?),
    );
  }
}
