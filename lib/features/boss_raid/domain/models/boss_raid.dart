import 'package:cloud_firestore/cloud_firestore.dart';

enum BossStatus { active, defeated, expired }

class BossRaid {
  const BossRaid({
    required this.id,
    required this.bossName,
    required this.bossTitle,
    required this.bossAvatar,
    required this.maxHp,
    required this.currentHp,
    required this.targetPushUps,
    required this.currentPushUps,
    required this.targetRunningKm,
    required this.currentRunningKm,
    required this.targetFocusMinutes,
    required this.currentFocusMinutes,
    required this.rewardPoints,
    required this.rewardCoins,
    required this.status,
    required this.expiresAt,
    this.participants = const [],
  });

  final String id;
  final String bossName;
  final String bossTitle;
  final String bossAvatar;
  final int maxHp;
  final int currentHp;

  final int targetPushUps;
  final int currentPushUps;

  final double targetRunningKm;
  final double currentRunningKm;

  final int targetFocusMinutes;
  final int currentFocusMinutes;

  final int rewardPoints;
  final int rewardCoins;
  final BossStatus status;
  final DateTime expiresAt;
  final List<String> participants;

  double get hpPercent => maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;
  bool get isDefeated => currentHp <= 0 || status == BossStatus.defeated;

  factory BossRaid.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final statusStr = data['status'] as String? ?? 'active';
    final status = BossStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => BossStatus.active,
    );

    return BossRaid(
      id: doc.id,
      bossName: data['bossName'] as String? ?? 'Dangasalik Titani',
      bossTitle: data['bossTitle'] as String? ?? 'Daraja 5 • Haftalik Mega Boss',
      bossAvatar: data['bossAvatar'] as String? ?? 'dragon',
      maxHp: (data['maxHp'] as num?)?.toInt() ?? 1000,
      currentHp: (data['currentHp'] as num?)?.toInt() ?? 1000,
      targetPushUps: (data['targetPushUps'] as num?)?.toInt() ?? 300,
      currentPushUps: (data['currentPushUps'] as num?)?.toInt() ?? 0,
      targetRunningKm: (data['targetRunningKm'] as num?)?.toDouble() ?? 15.0,
      currentRunningKm: (data['currentRunningKm'] as num?)?.toDouble() ?? 0.0,
      targetFocusMinutes: (data['targetFocusMinutes'] as num?)?.toInt() ?? 180,
      currentFocusMinutes: (data['currentFocusMinutes'] as num?)?.toInt() ?? 0,
      rewardPoints: (data['rewardPoints'] as num?)?.toInt() ?? 500,
      rewardCoins: (data['rewardCoins'] as num?)?.toInt() ?? 100,
      status: status,
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 3)),
      participants: List<String>.from(data['participants'] as List<dynamic>? ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'bossName': bossName,
    'bossTitle': bossTitle,
    'bossAvatar': bossAvatar,
    'maxHp': maxHp,
    'currentHp': currentHp,
    'targetPushUps': targetPushUps,
    'currentPushUps': currentPushUps,
    'targetRunningKm': targetRunningKm,
    'currentRunningKm': currentRunningKm,
    'targetFocusMinutes': targetFocusMinutes,
    'currentFocusMinutes': currentFocusMinutes,
    'rewardPoints': rewardPoints,
    'rewardCoins': rewardCoins,
    'status': status.name,
    'expiresAt': Timestamp.fromDate(expiresAt),
    'participants': participants,
  };
}
