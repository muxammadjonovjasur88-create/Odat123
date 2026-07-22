import 'package:cloud_firestore/cloud_firestore.dart';

/// Max members allowed in a private lobby.
const int kLobbyMemberLimit = 20;

/// A snapshot of a lobby's weekly winner, taken when a new week rolls over.
class LobbyWinner {
  const LobbyWinner({
    required this.uid,
    required this.name,
    required this.avatar,
    required this.points,
    this.weekStart,
  });

  final String uid;
  final String name;
  final String avatar;
  final int points;
  final DateTime? weekStart;

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'name': name,
    'avatar': avatar,
    'points': points,
    if (weekStart != null) 'weekStart': Timestamp.fromDate(weekStart!),
  };

  factory LobbyWinner.fromMap(Map<dynamic, dynamic> m) => LobbyWinner(
    uid: (m['uid'] as String?) ?? '',
    name: (m['name'] as String?) ?? 'A member',
    avatar: (m['avatar'] as String?) ?? 'leaf',
    points: (m['points'] as num?)?.toInt() ?? 0,
    weekStart: (m['weekStart'] as Timestamp?)?.toDate(),
  );
}

/// A private competition lobby stored at `lobbies/{id}`. Members compete on the
/// same weekly honest points as the global leaderboard, but only with each
/// other.
class Lobby {
  const Lobby({
    required this.id,
    required this.name,
    required this.code,
    required this.creatorUid,
    required this.memberUids,
    this.createdAt,
    this.weekStart,
    this.lastWinner,
  });

  final String id;
  final String name;

  /// Short join code, e.g. "FLOWA-7K2P".
  final String code;
  final String creatorUid;
  final List<String> memberUids;
  final DateTime? createdAt;

  /// Monday of the week this lobby is currently counting (for winner roll-over).
  final DateTime? weekStart;
  final LobbyWinner? lastWinner;

  int get memberCount => memberUids.length;
  bool get isFull => memberUids.length >= kLobbyMemberLimit;
  bool isMember(String uid) => memberUids.contains(uid);
  bool isCreator(String uid) => creatorUid == uid;

  /// A copyable invite line including the join code.
  String get inviteText =>
      'Join my Flowa focus lobby "$name"! Open Flowa → Lobbies → Join with '
      'code: $code';

  factory Lobby.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
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
      lastWinner: data['lastWinner'] is Map
          ? LobbyWinner.fromMap(data['lastWinner'] as Map)
          : null,
    );
  }
}
