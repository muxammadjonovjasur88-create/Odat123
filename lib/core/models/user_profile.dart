import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/gamification/domain/weekly_reset.dart';

/// A Flowa user, stored at `users/{uid}` in Firestore.
///
/// Created the first time a user finishes the setup-profile step (see
/// `06` requirement). Points reset weekly (Monday); [weeklyPoints] accumulates
/// during the week, [totalPoints] is lifetime.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.avatar,
    required this.focusType,
    this.streak = 0,
    this.longestStreak = 0,
    this.totalPoints = 0,
    this.weeklyPoints = 0,
    this.weeklyFocusMinutes = 0,
    this.monthlyPoints = 0,
    this.monthlyFocusMinutes = 0,
    this.totalFocusMinutes = 0,
    this.totalDeepSessions = 0,
    this.freezes = 0,
    this.freezeWeek,
    this.earnedBadges = const [],
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
  });

  final String uid;
  final String name;

  /// Avatar identifier — a default-avatar key (e.g. `leaf`) or, later, an
  /// uploaded photo URL.
  final String avatar;

  /// Primary focus chosen at setup: Study / Sport / Work / Personal.
  final String focusType;

  final int streak;
  final int longestStreak;
  final int totalPoints;
  final int weeklyPoints;
  final int weeklyFocusMinutes;

  /// Points earned within the current calendar month. Resets on the 1st.
  final int monthlyPoints;

  /// Focus minutes logged within the current calendar month.
  final int monthlyFocusMinutes;

  final int totalFocusMinutes;
  final int totalDeepSessions;

  /// Available streak freezes (auto-consumed to bridge a missed day).
  final int freezes;

  /// The week (its Monday's `yyyy-mm-dd`) the last free weekly freeze was
  /// granted, so we grant exactly one per new week.
  final String? freezeWeek;

  /// Earned milestone badges, by consecutive-day count (3/7/30/100).
  final List<int> earnedBadges;

  /// The last day the streak was kept alive (by a completion or a freeze) —
  /// drives streak continuity.
  final DateTime? lastActiveDate;
  final DateTime? createdAt;

  /// Whether this user has the Premium subscription. Defaults to false; flipped
  /// by the paywall (a placeholder until real Google Play Billing is added).
  final bool isPremium;

  /// The user's current intention ("what am I working toward"), their own
  /// reason for it ("why do I want this"), and an optional target date — shown
  /// back to them for intrinsic, meaning-over-points motivation.
  final String? goalTitle;
  final String? goalWhy;
  final DateTime? goalTargetDate;

  /// Google account metadata that can be reused on first sign-in.
  final String? email;
  final String? photoUrl;
  final String? photoBase64;
  final String? displayName;
  final String? bio;
  final String? currentWeekId;

  /// The month ID ("yyyy-MM") during which [monthlyPoints] was accumulated.
  final String? currentMonthId;

  final int likesCount;

  /// Telegram bot orqali bog'langan foydalanuvchining chat_id si.
  /// Bot /start buyrug'ini qabul qilganda Cloud Function tomonidan saqlanadi.
  final String? telegramChatId;

  /// Ushbu foydalanuvchi bilan isbotlarni ulashgan do'stlar UID ro'yxati.
  /// Ikki tomonlama: A ning sharedWith'da B bo'lsa, B ning sharedWith'da
  /// ham A bo'lishi kerak (ilovada qo'shganda ikkala tomonni yangilang).
  final List<String> sharedWith;

  /// Whether the user has set an intention to show on Home/Progress.
  bool get hasIntention => goalTitle?.trim().isNotEmpty ?? false;

  /// Whole days remaining until [goalTargetDate], or null if none set.
  int? get daysUntilGoal {
    final target = goalTargetDate;
    if (target == null) return null;
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final t = DateTime(target.year, target.month, target.day);
    return t.difference(today).inDays;
  }

  bool hasBadge(int days) => earnedBadges.contains(days);

  /// Lifetime focused hours, e.g. 342.
  double get focusHours => totalFocusMinutes / 60.0;

  /// A playful level derived from lifetime points.
  int get level => 1 + totalPoints ~/ 250;

  /// Fields written when the profile is first created. [createdAt] uses a
  /// server timestamp so it's authoritative regardless of device clock.
  Map<String, dynamic> toCreateMap() => {
    'name': name,
    'avatar': avatar,
    'focusType': focusType,
    'streak': 0,
    'longestStreak': 0,
    'totalPoints': 0,
    'weeklyPoints': 0,
    'weeklyFocusMinutes': 0,
    'monthlyPoints': 0,
    'monthlyFocusMinutes': 0,
    'totalFocusMinutes': 0,
    'currentWeekId': WeeklyReset.weekIdFor(DateTime.now()),
    'currentMonthId': MonthlyReset.monthIdFor(DateTime.now()),
    'totalDeepSessions': 0,
    'freezes': 1, // start with one free freeze
    'earnedBadges': <int>[],
    'isPremium': false,
    'email': email,
    'photoUrl': photoUrl,
    'photoBase64': photoBase64,
    'displayName': displayName,
    'bio': bio,
    'likesCount': 0,
    'sharedWith': <String>[],
    'createdAt': FieldValue.serverTimestamp(),
  };

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return UserProfile(
      uid: doc.id,
      name: (data['name'] as String?) ?? '',
      avatar: (data['avatar'] as String?) ?? 'leaf',
      focusType: (data['focusType'] as String?) ?? 'Study',
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      longestStreak: (data['longestStreak'] as num?)?.toInt() ?? 0,
      totalPoints: (data['totalPoints'] as num?)?.toInt() ?? 0,
      weeklyPoints: (data['weeklyPoints'] as num?)?.toInt() ?? 0,
      weeklyFocusMinutes: (data['weeklyFocusMinutes'] as num?)?.toInt() ?? 0,
      monthlyPoints: (data['monthlyPoints'] as num?)?.toInt() ?? 0,
      monthlyFocusMinutes:
          (data['monthlyFocusMinutes'] as num?)?.toInt() ?? 0,
      totalFocusMinutes: (data['totalFocusMinutes'] as num?)?.toInt() ?? 0,
      totalDeepSessions: (data['totalDeepSessions'] as num?)?.toInt() ?? 0,
      freezes: (data['freezes'] as num?)?.toInt() ?? 0,
      freezeWeek: data['freezeWeek'] as String?,
      earnedBadges:
          (data['earnedBadges'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      lastActiveDate: (data['lastActiveDate'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      isPremium: (data['isPremium'] as bool?) ?? false,
      goalTitle: data['goalTitle'] as String?,
      goalWhy: data['goalWhy'] as String?,
      goalTargetDate: (data['goalTargetDate'] as Timestamp?)?.toDate(),
      email: data['email'] as String?,
      photoUrl: data['photoUrl'] as String?,
      photoBase64: data['photoBase64'] as String?,
      displayName: data['displayName'] as String?,
      bio: data['bio'] as String?,
      currentWeekId: data['currentWeekId'] as String?,
      currentMonthId: data['currentMonthId'] as String?,
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      telegramChatId: data['telegramChatId'] as String?,
      sharedWith:
          (data['sharedWith'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}
