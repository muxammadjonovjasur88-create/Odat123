import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
enum BattleStatus { waiting, active, finished, cancelled }

class BattleMatch {
  const BattleMatch({
    required this.id,
    required this.hostUid,
    required this.hostName,
    required this.hostAvatar,
    this.hostPhotoUrl,
    this.hostPhotoBase64,
    this.hostScore = 0,
    this.hostReady = false,
    this.opponentUid,
    this.opponentName,
    this.opponentAvatar,
    this.opponentPhotoUrl,
    this.opponentPhotoBase64,
    this.opponentScore = 0,
    this.opponentReady = false,
    required this.exerciseType,
    this.durationSeconds = 60,
    this.wagerPoints = 100,
    this.winnerPrize = 180,
    this.commission = 20,
    this.status = BattleStatus.waiting,
    this.winnerUid,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.questions = const [],
  });

  final String id;
  final String hostUid;
  final String hostName;
  final String hostAvatar;
  final String? hostPhotoUrl;
  final String? hostPhotoBase64;
  final int hostScore;
  final bool hostReady;

  final String? opponentUid;
  final String? opponentName;
  final String? opponentAvatar;
  final String? opponentPhotoUrl;
  final String? opponentPhotoBase64;
  final int opponentScore;
  final bool opponentReady;

  final String exerciseType; // 'pushup', 'squat', 'finger_tap'
  final int durationSeconds; // 60, 180, 300
  final int wagerPoints;
  final int winnerPrize;
  final int commission;

  final BattleStatus status;
  final String? winnerUid;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final List<Map<String, dynamic>> questions; // Quiz battle questions

  bool isParticipant(String uid) => hostUid == uid || opponentUid == uid;

  String get exerciseDisplayName {
    switch (exerciseType) {
      case 'finger_tap':
        return 'Barmoqlar Jangi (Finger Tap)';
      case 'pushup':
        return 'Kamera Push-up (Otjimaniye)';
      case 'squat':
        return 'Kamera Squat (O’tirib-turish)';
      case 'plank':
        return 'Planka (Vaqt)';
      case 'quiz':
        return '🧠 Bilimlar Bellashuvi';
      default:
        return 'extra.1v1_battle'.tr();
    }
  }

  factory BattleMatch.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final statusStr = data['status'] as String? ?? 'waiting';
    final status = BattleStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => BattleStatus.waiting,
    );

    return BattleMatch(
      id: doc.id,
      hostUid: data['hostUid'] as String? ?? '',
      hostName: data['hostName'] as String? ?? 'Ishtirokchi 1',
      hostAvatar: data['hostAvatar'] as String? ?? 'shield',
      hostPhotoUrl: data['hostPhotoUrl'] as String?,
      hostPhotoBase64: data['hostPhotoBase64'] as String?,
      hostScore: (data['hostScore'] as num?)?.toInt() ?? 0,
      hostReady: data['hostReady'] as bool? ?? false,
      opponentUid: data['opponentUid'] as String?,
      opponentName: data['opponentName'] as String?,
      opponentAvatar: data['opponentAvatar'] as String?,
      opponentPhotoUrl: data['opponentPhotoUrl'] as String?,
      opponentPhotoBase64: data['opponentPhotoBase64'] as String?,
      opponentScore: (data['opponentScore'] as num?)?.toInt() ?? 0,
      opponentReady: data['opponentReady'] as bool? ?? false,
      exerciseType: data['exerciseType'] as String? ?? 'pushup',
      durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 60,
      wagerPoints: (data['wagerPoints'] as num?)?.toInt() ?? 100,
      winnerPrize: (data['winnerPrize'] as num?)?.toInt() ?? 180,
      commission: (data['commission'] as num?)?.toInt() ?? 20,
      status: status,
      winnerUid: data['winnerUid'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      finishedAt: (data['finishedAt'] as Timestamp?)?.toDate(),
      questions: (data['questions'] as List<dynamic>? ?? []).map((q) => Map<String, dynamic>.from(q as Map)).toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    'hostUid': hostUid,
    'hostName': hostName,
    'hostAvatar': hostAvatar,
    'hostPhotoUrl': hostPhotoUrl,
    'hostPhotoBase64': hostPhotoBase64,
    'hostScore': hostScore,
    'hostReady': hostReady,
    'opponentUid': opponentUid,
    'opponentName': opponentName,
    'opponentAvatar': opponentAvatar,
    'opponentPhotoUrl': opponentPhotoUrl,
    'opponentPhotoBase64': opponentPhotoBase64,
    'opponentScore': opponentScore,
    'opponentReady': opponentReady,
    'exerciseType': exerciseType,
    'durationSeconds': durationSeconds,
    'wagerPoints': wagerPoints,
    'winnerPrize': winnerPrize,
    'commission': commission,
    'status': status.name,
    'winnerUid': winnerUid,
    'createdAt': Timestamp.fromDate(createdAt),
    if (startedAt != null) 'startedAt': Timestamp.fromDate(startedAt!),
    if (finishedAt != null) 'finishedAt': Timestamp.fromDate(finishedAt!),
  };
}
