import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/gamification/domain/weekly_reset.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.avatar,
    required this.focusType,
    this.streak = 0,
    this.longestStreak = 0,
    this.totalPoints = 0,
    this.fenixCoins = 0,
    this.weeklyPoints = 0,
    this.weeklyFocusMinutes = 0,
    this.monthlyPoints = 0,
    this.monthlyFocusMinutes = 0,
    this.totalFocusMinutes = 0,
    this.totalDeepSessions = 0,
    this.freezes = 0,
    this.freezeWeek,
    this.earnedBadges = const [],
    this.claimedBadges = const [],
    this.lastActiveDate,
    this.createdAt,
    this.isPremium = false,
    this.goalTitle,
    this.goalWhy,
    this.goalTargetDate,
    this.email,
    this.photoUrl,
    this.photoBase64,
    this.displayName,
    this.bio,
    this.currentWeekId,
    this.currentMonthId,
    this.likesCount = 0,
    this.telegramChatId,
    this.sharedWith = const [],
    this.displayId,
    this.clanId,
    this.clanName,
    this.clanTag,
    this.clanEmblem,
    this.clanRegion,
    this.isClanLeader = false,
    this.unlockedTracks = const [],
    this.battleWins = 0,
    this.battleLosses = 0,
    this.totalRunningKm = 0.0,
    this.appRole,
    this.familyRole,
    this.roleSelected = false,
  });

  // Strings
  final String uid, name, avatar, focusType;
  final String? freezeWeek, email, photoUrl, photoBase64, displayName, bio;
  final String? currentWeekId, currentMonthId, telegramChatId, displayId;
  final String? goalTitle, goalWhy;
  final String? clanId, clanName, clanTag, clanEmblem, clanRegion;
  final String? appRole, familyRole;

  // Ints
  final int streak, longestStreak, totalPoints, fenixCoins;
  final int weeklyPoints, weeklyFocusMinutes;
  final int monthlyPoints, monthlyFocusMinutes;
  final int totalFocusMinutes, totalDeepSessions;
  final int freezes, likesCount, battleWins, battleLosses;

  // Other
  final double totalRunningKm;
  final bool isPremium, isClanLeader, roleSelected;
  final DateTime? lastActiveDate, createdAt, goalTargetDate;
  final List<int> earnedBadges;
  final List<String> claimedBadges, sharedWith, unlockedTracks;

  // Getters
  int get totalBattles => battleWins + battleLosses;
  int get winratePercent =>
      totalBattles == 0 ? 0 : ((battleWins / totalBattles) * 100).round();
  double get focusHours => totalFocusMinutes / 60.0;
  int get level => 1 + totalPoints ~/ 250;
  bool get hasIntention => goalTitle?.trim().isNotEmpty ?? false;
  bool get isPersonal => appRole == 'personal';
  bool get isFamily => appRole == 'family';
  bool get isParent => appRole == 'family' && familyRole == 'parent';
  bool get isChild => appRole == 'family' && familyRole == 'child';
  bool hasBadge(int days) => earnedBadges.contains(days);
  bool hasClaimedBadge(String id) => claimedBadges.contains(id);
  bool isTrackUnlocked(String id) => isPremium || unlockedTracks.contains(id);

  String get numericId {
    if (email == 'salomovshahboz02@gmail.com' || displayId == '7777777') return '7777777';
    if (displayId?.isNotEmpty ?? false) return displayId!;
    return (1000000 + (uid.hashCode.abs() % 9000000)).toString();
  }

  int? get daysUntilGoal {
    if (goalTargetDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final t = DateTime(goalTargetDate!.year, goalTargetDate!.month, goalTargetDate!.day);
    return t.difference(today).inDays;
  }

  Map<String, dynamic> toCreateMap() => {
        'name': name,
        'avatar': avatar,
        'focusType': focusType,
        'streak': 0,
        'longestStreak': 0,
        'totalPoints': 0,
        'fenixCoins': 0,
        'weeklyPoints': 0,
        'weeklyFocusMinutes': 0,
        'monthlyPoints': 0,
        'monthlyFocusMinutes': 0,
        'totalFocusMinutes': 0,
        'currentWeekId': WeeklyReset.weekIdFor(DateTime.now()),
        'currentMonthId':
            '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
        'totalDeepSessions': 0,
        'freezes': 1,
        'freezeWeek': null,
        'earnedBadges': <int>[],
        'claimedBadges': <String>[],
        'lastActiveDate': null,
        'isPremium': false,
        'email': email,
        'photoUrl': photoUrl,
        'photoBase64': photoBase64,
        'displayName': displayName,
        'bio': bio,
        'likesCount': 0,
        'sharedWith': <String>[],
        'displayId': numericId,
        'clanId': clanId,
        'clanName': clanName,
        'clanTag': clanTag,
        'clanEmblem': clanEmblem,
        'clanRegion': clanRegion,
        'isClanLeader': isClanLeader,
        'unlockedTracks': unlockedTracks,
        'appRole': appRole,
        'familyRole': familyRole,
        'roleSelected': roleSelected,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    int i(String k) => (d[k] as num?)?.toInt() ?? 0;
    String? s(String k) => d[k] as String?;
    bool b(String k) => (d[k] as bool?) ?? false;
    DateTime? ts(String k) => (d[k] as Timestamp?)?.toDate();
    List<String> sl(String k) =>
        (d[k] as List?)?.map((e) => e.toString()).toList() ?? const [];

    return UserProfile(
      uid: doc.id,
      name: s('name') ?? '',
      avatar: s('avatar') ?? 'leaf',
      focusType: s('focusType') ?? 'Study',
      streak: i('streak'),
      longestStreak: i('longestStreak'),
      totalPoints: i('totalPoints'),
      fenixCoins: i('fenixCoins'),
      weeklyPoints: i('weeklyPoints'),
      weeklyFocusMinutes: i('weeklyFocusMinutes'),
      monthlyPoints: i('monthlyPoints'),
      monthlyFocusMinutes: i('monthlyFocusMinutes'),
      totalFocusMinutes: i('totalFocusMinutes'),
      totalDeepSessions: i('totalDeepSessions'),
      freezes: i('freezes'),
      freezeWeek: s('freezeWeek'),
      earnedBadges:
          (d['earnedBadges'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [],
      claimedBadges: sl('claimedBadges'),
      lastActiveDate: ts('lastActiveDate'),
      createdAt: ts('createdAt'),
      isPremium: b('isPremium'),
      goalTitle: s('goalTitle'),
      goalWhy: s('goalWhy'),
      goalTargetDate: ts('goalTargetDate'),
      email: s('email'),
      photoUrl: s('photoUrl'),
      photoBase64: s('photoBase64'),
      displayName: s('displayName'),
      bio: s('bio'),
      currentWeekId: s('currentWeekId'),
      currentMonthId: s('currentMonthId'),
      likesCount: i('likesCount'),
      telegramChatId: s('telegramChatId'),
      displayId: s('email') == 'salomovshahboz02@gmail.com' ? '7777777' : s('displayId'),
      clanId: s('clanId'),
      clanName: s('clanName'),
      clanTag: s('clanTag'),
      clanEmblem: s('clanEmblem'),
      clanRegion: s('clanRegion'),
      isClanLeader: b('isClanLeader'),
      sharedWith: sl('sharedWith'),
      unlockedTracks: sl('unlockedTracks'),
      battleWins: i('battleWins'),
      battleLosses: i('battleLosses'),
      totalRunningKm: (d['totalRunningKm'] as num?)?.toDouble() ??
          (d['runningDistanceKm'] as num?)?.toDouble() ??
          0.0,
      appRole: s('appRole'),
      familyRole: s('familyRole'),
      roleSelected: b('roleSelected'),
    );
  }
}
