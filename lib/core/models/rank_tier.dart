import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Represents competitive player rank tiers in the ODAT ecosystem.
/// Advancing to next rank requires 5 Battle Wins or corresponding PTS milestone.
class RankTier {
  const RankTier({
    required this.name,
    required this.category,
    required this.subTier,
    required this.icon,
    required this.color,
    required this.minPoints,
    required this.maxPoints,
    required this.requiredWins,
    required this.description,
  });

  final String name;
  final String category; // 'BRONZA', 'KUMUSH', 'OLTIN', 'PLATINA', 'OLMOS', 'MASTER', 'AFSONA'
  final String subTier; // 'I', 'II', 'III', or ''
  final String icon;
  final Color color;
  final int minPoints;
  final int maxPoints;
  final int requiredWins; // 5 wins per stage
  final String description;

  String get localizedName {
    final catLower = category.toLowerCase();
    final key = 'ranks.$catLower';
    final translated = key.tr();
    if (translated == key) return name;
    return subTier.isNotEmpty ? '$translated $subTier' : translated;
  }

  double progress(int points) {
    if (points >= maxPoints) return 1.0;
    if (points <= minPoints) return 0.0;
    return (points - minPoints) / (maxPoints - minPoints);
  }

  int pointsNeeded(int points) {
    if (points >= maxPoints) return 0;
    return maxPoints - points;
  }

  int winsNeeded(int currentWins) {
    final idx = allTiers.indexOf(this);
    if (idx < allTiers.length - 1) {
      final next = allTiers[idx + 1];
      return math.max(0, next.requiredWins - currentWins);
    }
    return 0;
  }

  /// Returns a Material vector icon for this rank tier (no emoji needed).
  IconData get iconData {
    switch (category) {
      case 'BRONZA':  return Icons.military_tech_rounded;
      case 'KUMUSH':  return Icons.shield_rounded;
      case 'OLTIN':   return Icons.emoji_events_rounded;
      case 'PLATINA': return Icons.diamond_rounded;
      case 'OLMOS':   return Icons.hexagon_rounded;
      case 'MASTER':  return Icons.workspace_premium_rounded;
      case 'AFSONA':  return Icons.local_fire_department_rounded;
      default:        return Icons.stars_rounded;
    }
  }

  static const List<RankTier> allTiers = [
    // 🥉 BRONZA (0 - 10 wins)
    RankTier(
      name: 'Bronza I',
      category: 'BRONZA',
      subTier: 'I',
      icon: '🥉',
      color: Color(0xFFCD7F32),
      minPoints: 0,
      maxPoints: 150,
      requiredWins: 0,
      description: 'Dastlabki intizom va duel maydonidagi ilk qadam',
    ),
    RankTier(
      name: 'Bronza II',
      category: 'BRONZA',
      subTier: 'II',
      icon: '🥉',
      color: Color(0xFFCD7F32),
      minPoints: 150,
      maxPoints: 300,
      requiredWins: 5,
      description: '5 ta g‘alaba qozongan faol jangchi',
    ),
    RankTier(
      name: 'Bronza III',
      category: 'BRONZA',
      subTier: 'III',
      icon: '🥉',
      color: Color(0xFFD38D47),
      minPoints: 300,
      maxPoints: 500,
      requiredWins: 10,
      description: '10 ta g‘alaba bilan mustahkamlangan poydevor',
    ),

    // 🥈 KUMUSH (15 - 25 wins)
    RankTier(
      name: 'Kumush I',
      category: 'KUMUSH',
      subTier: 'I',
      icon: '🥈',
      color: Color(0xFFB0BEC5),
      minPoints: 500,
      maxPoints: 850,
      requiredWins: 15,
      description: '15 ta duelda g‘olib bo‘lgan irodali sportchi',
    ),
    RankTier(
      name: 'Kumush II',
      category: 'KUMUSH',
      subTier: 'II',
      icon: '🥈',
      color: Color(0xFFCFD8DC),
      minPoints: 850,
      maxPoints: 1300,
      requiredWins: 20,
      description: '20 ta g‘alaba bilan barqaror natija ko‘rsatuvchi',
    ),
    RankTier(
      name: 'Kumush III',
      category: 'KUMUSH',
      subTier: 'III',
      icon: '🥈',
      color: Color(0xFFECEFF1),
      minPoints: 1300,
      maxPoints: 2000,
      requiredWins: 25,
      description: '25 ta g‘alaba — Oltin ligaga asosiy da’vogar',
    ),

    // 🥇 OLTIN (30 - 40 wins)
    RankTier(
      name: 'Oltin I',
      category: 'OLTIN',
      subTier: 'I',
      icon: '🥇',
      color: Color(0xFFFFB703),
      minPoints: 2000,
      maxPoints: 3200,
      requiredWins: 30,
      description: '30 ta duel g‘olibi — tajribali klan a’zosi',
    ),
    RankTier(
      name: 'Oltin II',
      category: 'OLTIN',
      subTier: 'II',
      icon: '🥇',
      color: Color(0xFFFFC300),
      minPoints: 3200,
      maxPoints: 5000,
      requiredWins: 35,
      description: '35 ta g‘alaba bilan yuqori ligada mustahkam o‘rin',
    ),
    RankTier(
      name: 'Oltin III',
      category: 'OLTIN',
      subTier: 'III',
      icon: '🥇',
      color: Color(0xFFFFD60A),
      minPoints: 5000,
      maxPoints: 8000,
      requiredWins: 40,
      description: '40 ta g‘alaba sohibi — yetakchi jangchi',
    ),

    // 💎 PLATINA (45 - 55 wins)
    RankTier(
      name: 'Platina I',
      category: 'PLATINA',
      subTier: 'I',
      icon: '💎',
      color: Color(0xFF5BC8FA),
      minPoints: 8000,
      maxPoints: 12000,
      requiredWins: 45,
      description: '45 ta g‘alaba — elita qatoridagi kuchli raqib',
    ),
    RankTier(
      name: 'Platina II',
      category: 'PLATINA',
      subTier: 'II',
      icon: '💎',
      color: Color(0xFF5BC8FA),
      minPoints: 12000,
      maxPoints: 18000,
      requiredWins: 50,
      description: '50 ta duel g‘olibi — yuqori toifadagi professional',
    ),
    RankTier(
      name: 'Platina III',
      category: 'PLATINA',
      subTier: 'III',
      icon: '💎',
      color: Color(0xFF18FFFF),
      minPoints: 18000,
      maxPoints: 25000,
      requiredWins: 55,
      description: '55 ta g‘alaba — Olmos ligasi arafasidagi titan',
    ),

    // 🔷 OLMOS (60 wins)
    RankTier(
      name: 'Olmos',
      category: 'OLMOS',
      subTier: '',
      icon: '🔷',
      color: Color(0xFF7000FF),
      minPoints: 25000,
      maxPoints: 40000,
      requiredWins: 60,
      description: '60 ta g‘alaba bilan har qanday to‘siqni oson yenguvchi',
    ),

    // 👑 MASTER (75 wins)
    RankTier(
      name: 'Master',
      category: 'MASTER',
      subTier: '',
      icon: '👑',
      color: Color(0xFFFF0055),
      minPoints: 40000,
      maxPoints: 75000,
      requiredWins: 75,
      description: '75 ta jang g‘olibi — butun ODAT jamoasi ustozi',
    ),

    // 🔥 AFSONA (100+ wins)
    RankTier(
      name: 'Fenix Afsonasi',
      category: 'AFSONA',
      subTier: '',
      icon: '🔥',
      color: Color(0xFFFF4500),
      minPoints: 75000,
      maxPoints: 200000,
      requiredWins: 100,
      description: '100+ g‘alaba — ODAT olamining mutlaq chempioni',
    ),
  ];

  static RankTier fromPoints(int points) {
    for (int i = allTiers.length - 1; i >= 0; i--) {
      if (points >= allTiers[i].minPoints) {
        return allTiers[i];
      }
    }
    return allTiers.first;
  }

  /// Calculates rank from Battle Wins (5 wins per tier) with points fallback
  static RankTier fromWinsAndPoints({required int battleWins, required int points}) {
    if (battleWins > 0) {
      for (int i = allTiers.length - 1; i >= 0; i--) {
        if (battleWins >= allTiers[i].requiredWins) {
          return allTiers[i];
        }
      }
    }
    return fromPoints(points);
  }
}
