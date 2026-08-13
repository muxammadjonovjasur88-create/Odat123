import 'package:cloud_firestore/cloud_firestore.dart';

/// Max members allowed in a private lobby.
const int kLobbyMemberLimit = 20;

/// Default season duration in days (2 weeks, PUBG/MLBB style).
const int kDefaultSeasonDays = 14;

/// Max past season winners stored per lobby.
const int kMaxSeasonHistory = 5;

/// A snapshot of a lobby's season winner, taken when a new season rolls over.
class LobbyWinner {
  const LobbyWinner({
    required this.uid,
    required this.name,
    required this.avatar,
    required this.points,
    this.seasonStart,
    this.seasonNumber,
  });

  final String uid;
  final String name;
  final String avatar;
  final int points;
  final DateTime? seasonStart;

  /// Which season number this winner won (1-based).
  final int? seasonNumber;

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'name': name,
    'avatar': avatar,
    'points': points,
    if (seasonStart != null) 'seasonStart': Timestamp.fromDate(seasonStart!),
    if (seasonNumber != null) 'seasonNumber': seasonNumber,
  };

  factory LobbyWinner.fromMap(Map<dynamic, dynamic> m) => LobbyWinner(
    uid: (m['uid'] as String?) ?? '',
    name: (m['name'] as String?) ?? 'A member',
    avatar: (m['avatar'] as String?) ?? 'leaf',
    points: (m['points'] as num?)?.toInt() ?? 0,
    seasonStart: (m['seasonStart'] as Timestamp?)?.toDate(),
    seasonNumber: (m['seasonNumber'] as num?)?.toInt(),
  );
}

/// A private competition lobby stored at `lobbies/{id}`. Members compete on the
/// same weekly honest points as the global leaderboard, but only with each
/// other.
///
/// Season system (PUBG/MLBB style):
/// - [seasonDurationDays]: how many days each season lasts (default 14).
/// - [seasonNumber]: current season number (1-based, increments on rollover).
/// - [seasonStart]: UTC midnight when the current season began.
/// - [seasonWinners]: ordered history of past season winners (newest first,
///   max [kMaxSeasonHistory] entries).
class Lobby {
  const Lobby({
    required this.id,
    required this.name,
    required this.code,
    required this.creatorUid,
    required this.memberUids,
    this.createdAt,
    // Legacy field kept for backwards-compat; seasonStart supersedes it.
    this.weekStart,
    this.lastWinner,
    this.seasonDurationDays = kDefaultSeasonDays,
    this.seasonNumber = 1,
    this.seasonStart,
    this.seasonWinners = const [],
  });

  final String id;
  final String name;

  /// Short join code, e.g. "FLOWA-7K2P".
  final String code;
  final String creatorUid;
  final List<String> memberUids;
  final DateTime? createdAt;

  /// Legacy: Monday of the week this lobby was counting. Kept for migration.
  final DateTime? weekStart;

  /// Legacy: Last weekly winner. Superseded by [seasonWinners].
  final LobbyWinner? lastWinner;

  /// How many days each season lasts. Set at creation time.
  final int seasonDurationDays;

  /// Current season number (1-based). Incremented on each rollover.
  final int seasonNumber;

  /// UTC midnight when the current season started.
  final DateTime? seasonStart;

  /// Past season winners, newest first. Max [kMaxSeasonHistory] entries.
  final List<LobbyWinner> seasonWinners;

  int get memberCount => memberUids.length;
  bool get isFull => memberUids.length >= kLobbyMemberLimit;
  bool isMember(String uid) => memberUids.contains(uid);
  bool isCreator(String uid) => creatorUid == uid;

  /// When the current season ends (null if seasonStart is not set).
  DateTime? get seasonEnd =>
      seasonStart?.add(Duration(days: seasonDurationDays));

  Duration? get seasonTimeLeft {
    final end = seasonEnd;
    if (end == null) return null;
    final left = end.difference(DateTime.now().toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  /// Human-readable season label, e.g. "Season 3".
  String get seasonLabel => 'Season $seasonNumber';

  /// A copyable invite line including the join code.
  String get inviteText =>
      'Join my Odat focus lobby "$name"! Open Odat → Lobbies → Join with '
      'code: $code';

  factory Lobby.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};

    // Parse season winners list (newest first).
    final winnersRaw = data['seasonWinners'];
    final winners = winnersRaw is List
        ? winnersRaw.whereType<Map>().map(LobbyWinner.fromMap).toList()
        : <LobbyWinner>[];

    // Parse legacy lastWinner for backwards compat.
    final legacyWinner = data['lastWinner'] is Map
        ? LobbyWinner.fromMap(data['lastWinner'] as Map)
        : null;

    return Lobby(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Focus Circle',
      code: (data['code'] as String?) ?? '',
      creatorUid: (data['creatorUid'] as String?) ?? '',
      memberUids:
          (data['memberUids'] as List?)?.whereType<String>().toList() ??
          const [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      weekStart: (data['weekStart'] as Timestamp?)?.toDate(),
      lastWinner: legacyWinner,
      seasonDurationDays:
          (data['seasonDurationDays'] as num?)?.toInt() ?? kDefaultSeasonDays,
      seasonNumber: (data['seasonNumber'] as num?)?.toInt() ?? 1,
      seasonStart: (data['seasonStart'] as Timestamp?)?.toDate(),
      seasonWinners: winners,
    );
  }
}
