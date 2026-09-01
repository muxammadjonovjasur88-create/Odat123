import 'package:flutter/foundation.dart';

/// Single round log in territory battle
class BattleRoundLog {
  const BattleRoundLog({
    required this.roundNumber,
    required this.attackerDamageDealt,
    required this.defenderDamageDealt,
    required this.targetStructureName,
    required this.remainingStructureHp,
    required this.description,
  });

  final int roundNumber;
  final int attackerDamageDealt;
  final int defenderDamageDealt;
  final String targetStructureName;
  final int remainingStructureHp;
  final String description;
}

/// Deterministic battle outcome result
@immutable
class BattleResult {
  const BattleResult({
    required this.isAttackerWinner,
    required this.attackerTotalPower,
    required this.defenderTotalPower,
    required this.totalAttackerDamage,
    required this.totalDefenderDamage,
    required this.structuresDestroyed,
    required this.pointsAwarded,
    required this.rounds,
    required this.summaryMessage,
  });

  final bool isAttackerWinner;
  final int attackerTotalPower;
  final int defenderTotalPower;
  final int totalAttackerDamage;
  final int totalDefenderDamage;
  final int structuresDestroyed;
  final int pointsAwarded;
  final List<BattleRoundLog> rounds;
  final String summaryMessage;
}

/// Persistent battle record in Firestore `territory_battles`
@immutable
class TerritoryBattleEvent {
  const TerritoryBattleEvent({
    required this.id,
    required this.territoryId,
    required this.attackerUid,
    required this.attackerName,
    required this.defenderUid,
    required this.defenderName,
    required this.attackerPower,
    required this.defenderPower,
    required this.isAttackerWinner,
    required this.pointsTransferred,
    required this.timestamp,
    this.attackerAvatar,
    this.defenderAvatar,
    this.territoryAreaSqMeters = 0.0,
    this.structuresCount = 0,
  });

  final String id;
  final String territoryId;
  final String attackerUid;
  final String attackerName;
  final String defenderUid;
  final String defenderName;
  final int attackerPower;
  final int defenderPower;
  final bool isAttackerWinner;
  final int pointsTransferred;
  final DateTime timestamp;
  final String? attackerAvatar;
  final String? defenderAvatar;
  final double territoryAreaSqMeters;
  final int structuresCount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'territoryId': territoryId,
        'attackerUid': attackerUid,
        'attackerName': attackerName,
        'defenderUid': defenderUid,
        'defenderName': defenderName,
        'attackerPower': attackerPower,
        'defenderPower': defenderPower,
        'isAttackerWinner': isAttackerWinner,
        'pointsTransferred': pointsTransferred,
        'timestamp': timestamp.toIso8601String(),
        'attackerAvatar': attackerAvatar,
        'defenderAvatar': defenderAvatar,
        'territoryAreaSqMeters': territoryAreaSqMeters,
        'structuresCount': structuresCount,
      };

  factory TerritoryBattleEvent.fromMap(Map<String, dynamic> map, {String? id}) {
    return TerritoryBattleEvent(
      id: id ?? (map['id'] as String? ?? ''),
      territoryId: map['territoryId'] as String? ?? '',
      attackerUid: map['attackerUid'] as String? ?? '',
      attackerName: map['attackerName'] as String? ?? 'Hujumchi',
      defenderUid: map['defenderUid'] as String? ?? '',
      defenderName: map['defenderName'] as String? ?? 'Himoyachi',
      attackerPower: (map['attackerPower'] as num?)?.toInt() ?? 0,
      defenderPower: (map['defenderPower'] as num?)?.toInt() ?? 0,
      isAttackerWinner: map['isAttackerWinner'] as bool? ?? false,
      pointsTransferred: (map['pointsTransferred'] as num?)?.toInt() ?? 0,
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is String
              ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
              : DateTime.now())
          : DateTime.now(),
      attackerAvatar: map['attackerAvatar'] as String?,
      defenderAvatar: map['defenderAvatar'] as String?,
      territoryAreaSqMeters: (map['territoryAreaSqMeters'] as num?)?.toDouble() ?? 0.0,
      structuresCount: (map['structuresCount'] as num?)?.toInt() ?? 0,
    );
  }
}
