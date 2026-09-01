import 'dart:math' as math;
import '../models/defense_structure.dart';
import '../models/territory_battle.dart';
import '../models/territory_polygon.dart';

/// Server-authoritative, deterministic battle simulation engine.
abstract final class TerritoryBattleService {
  /// Calculates attacker's total combat power based on run telemetry and attack stats.
  static int calculateAttackerPower({
    required double distanceKm,
    required double avgSpeedKmh,
    required double areaSqMeters,
    int attackerLevel = 1,
  }) {
    // 1. Base attack power from runner physical exertion
    final int distancePower = (distanceKm * 40).round();
    final int speedBonus = (avgSpeedKmh * 8).round();
    final int areaScale = (math.sqrt(areaSqMeters) * 1.5).round();
    final int levelBonus = attackerLevel * 25;

    final total = distancePower + speedBonus + areaScale + levelBonus;
    return total.clamp(30, 5000);
  }

  /// Calculates defender's total defensive power based on structures and territory fortification.
  static int calculateDefenderPower({
    required TerritoryPolygon territory,
    required List<DefenseStructure> structures,
  }) {
    if (structures.isEmpty) {
      // Base territory defense without towers
      return (math.sqrt(territory.areaSqMeters) * 0.8).round().clamp(20, 200);
    }

    int totalPower = 0;
    for (final s in structures) {
      final structureRating = s.defensePower * 2 + (s.attackPower * 1.5).round() + (s.hp ~/ 4);
      totalPower += structureRating;
    }

    return totalPower.clamp(40, 10000);
  }

  /// Simulates round-by-round combat and returns deterministic [BattleResult].
  static BattleResult resolveBattle({
    required int attackerPower,
    required TerritoryPolygon territory,
    required List<DefenseStructure> structures,
    required String attackerName,
  }) {
    final defenderPower = calculateDefenderPower(
      territory: territory,
      structures: structures,
    );

    final List<BattleRoundLog> roundLogs = [];
    int remainingAttackerPower = attackerPower;
    int totalAttackerDamage = 0;
    int totalDefenderDamage = 0;
    int structuresDestroyed = 0;

    final mutableStructures = structures.map((s) => s.copyWith()).toList();

    // Round-by-round simulation (maximum 5 rounds)
    for (int round = 1; round <= 5; round++) {
      if (remainingAttackerPower <= 0) break;

      // Attacker strikes defense structure
      final int roundAttackDamage = (remainingAttackerPower * 0.35).round().clamp(10, remainingAttackerPower);
      totalAttackerDamage += roundAttackDamage;

      String targetName = 'Hudud Devori';
      int remainingHp = 0;

      if (mutableStructures.isNotEmpty) {
        final targetIndex = (round - 1) % mutableStructures.length;
        final target = mutableStructures[targetIndex];
        targetName = target.name;

        final newHp = (target.hp - roundAttackDamage).clamp(0, target.maxHp);
        mutableStructures[targetIndex] = target.copyWith(hp: newHp);
        remainingHp = newHp;

        if (newHp <= 0) {
          structuresDestroyed++;
        }
      }

      // Defender counter-strikes
      final int roundDefenderDamage = (defenderPower * 0.25).round().clamp(5, defenderPower);
      totalDefenderDamage += roundDefenderDamage;
      remainingAttackerPower = (remainingAttackerPower - roundDefenderDamage).clamp(0, attackerPower);

      roundLogs.add(BattleRoundLog(
        roundNumber: round,
        attackerDamageDealt: roundAttackDamage,
        defenderDamageDealt: roundDefenderDamage,
        targetStructureName: targetName,
        remainingStructureHp: remainingHp,
        description: '$attackerName $targetName ga $roundAttackDamage zarba berdi. Qaytgan zarba: $roundDefenderDamage',
      ));
    }

    final bool isAttackerWinner = attackerPower > defenderPower;
    final int pointsAwarded = isAttackerWinner
        ? ((territory.areaSqMeters / 15.0).round() + 100).clamp(100, 1500)
        : 25; // Consolation points for workout effort

    final String summary = isAttackerWinner
        ? '⚔️ G‘ALABA! Siz ${territory.ownerName}ning hududini muvaffaqiyatli zabt etdingiz! 🏆'
        : '🛡️ HUJUM QAYTARILDI! ${territory.ownerName}ning himoyasi juda kuchli chiqdi. Yangi yugurish bilan yana sinab ko‘ring.';

    return BattleResult(
      isAttackerWinner: isAttackerWinner,
      attackerTotalPower: attackerPower,
      defenderTotalPower: defenderPower,
      totalAttackerDamage: totalAttackerDamage,
      totalDefenderDamage: totalDefenderDamage,
      structuresDestroyed: structuresDestroyed,
      pointsAwarded: pointsAwarded,
      rounds: roundLogs,
      summaryMessage: summary,
    );
  }
}
