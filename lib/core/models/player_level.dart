import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 1 to 100 Level System for ODAT Ecosystem.
class PlayerLevel {
  const PlayerLevel({
    required this.level,
    required this.minPts,
    required this.maxPts,
    required this.title,
    required this.badgeIcon,
    required this.rewardPts,
    required this.rewardCoins,
    required this.color,
  });

  final int level; // 1 to 100
  final int minPts;
  final int maxPts;
  final String title;
  final String badgeIcon;
  final int rewardPts;
  final int rewardCoins;
  final Color color;

  /// Calculates player's level (1 to 100) from total PTS
  static int calculateLevel(int totalPts) {
    if (totalPts <= 0) return 1;
    // Formula: level = 1 + (pts / 1000)
    final rawLevel = 1 + (totalPts / 1000).floor();
    return rawLevel.clamp(1, 100);
  }

  /// Calculates points required to reach level L
  static int ptsForLevel(int lvl) {
    if (lvl <= 1) return 0;
    return (lvl - 1) * 1000;
  }

  /// Gets the level details for a specific level (1-100)
  static PlayerLevel forLevel(int lvl) {
    final clampedLevel = lvl.clamp(1, 100);
    final min = ptsForLevel(clampedLevel);
    final max = clampedLevel >= 100 ? min + 2000 : ptsForLevel(clampedLevel + 1);

    final rewardPts = (30 + (clampedLevel * 10)) * 10;
    // 3x Fenix Coin rewards (3 to 30 Coins)
    final rewardCoins = math.max(1, (clampedLevel / 10).floor()) * 3;

    String title;
    String icon;
    Color color;

    if (clampedLevel <= 5) {
      title = 'Yangi Boshlovchi $clampedLevel';
      icon = '🌱';
      color = const Color(0xFF3A7FCC);
    } else if (clampedLevel <= 15) {
      title = 'Intizom Qadami ${clampedLevel - 5}';
      icon = '🔥';
      color = const Color(0xFF4AADDC);
    } else if (clampedLevel <= 30) {
      title = 'Harakat Jangchisi ${clampedLevel - 15}';
      icon = '🥉';
      color = const Color(0xFFB0BEC5);
    } else if (clampedLevel <= 50) {
      title = 'Fokus Ustasi ${clampedLevel - 30}';
      icon = '🥈';
      color = const Color(0xFFFFB703);
    } else if (clampedLevel <= 70) {
      title = 'Oltin Qahramon ${clampedLevel - 50}';
      icon = '🥇';
      color = const Color(0xFFFFD60A);
    } else if (clampedLevel <= 85) {
      title = 'Platina Feniks ${clampedLevel - 70}';
      icon = '💎';
      color = const Color(0xFFE5E4E2);
    } else if (clampedLevel <= 98) {
      title = 'Master Donishmand ${clampedLevel - 85}';
      icon = '👑';
      color = const Color(0xFFFF0055);
    } else {
      title = 'ODAT Hukmdori';
      icon = '⚡';
      color = const Color(0xFF3A7FCC);
    }

    return PlayerLevel(
      level: clampedLevel,
      minPts: min,
      maxPts: max,
      title: title,
      badgeIcon: icon,
      rewardPts: rewardPts,
      rewardCoins: rewardCoins,
      color: color,
    );
  }

  /// Gets the current level information and next level progression
  static PlayerLevel fromTotalPts(int totalPts) {
    final currentLvl = calculateLevel(totalPts);
    return forLevel(currentLvl);
  }
}
