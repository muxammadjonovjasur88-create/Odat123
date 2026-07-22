import 'package:cloud_firestore/cloud_firestore.dart';

/// A minimal, public-facing view of a user for the leaderboard.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.name,
    required this.avatar,
    required this.weeklyPoints,
    required this.weeklyFocusMinutes,
    required this.totalPoints,
    required this.totalFocusMinutes,
    this.photoUrl,
    this.photoBase64,
  });

  final String uid;
  final String name;
  final String avatar;
  final int weeklyPoints;
  final int weeklyFocusMinutes;
  final int totalPoints;
  final int totalFocusMinutes;
  final String? photoUrl;
  final String? photoBase64;

  factory LeaderboardEntry.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const {};
    return LeaderboardEntry(
      uid: doc.id,
      name: (data['displayName'] as String?) ??
          (data['name'] as String?) ??
          'Friend',
      avatar: (data['avatar'] as String?) ?? 'leaf',
      weeklyPoints: (data['weeklyPoints'] as num?)?.toInt() ?? 0,
      weeklyFocusMinutes: (data['weeklyFocusMinutes'] as num?)?.toInt() ?? 0,
      totalPoints: (data['totalPoints'] as num?)?.toInt() ?? 0,
      totalFocusMinutes: (data['totalFocusMinutes'] as num?)?.toInt() ?? 0,
      photoUrl: data['photoUrl'] as String?,
      photoBase64: data['photoBase64'] as String?,
    );
  }
}
