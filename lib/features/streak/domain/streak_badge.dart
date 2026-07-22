import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// A streak milestone badge. [days] doubles as its stable id (stored in
/// `users/{uid}.earnedBadges`).
class StreakBadge {
  const StreakBadge({
    required this.days,
    required this.name,
    required this.message,
    required this.icon,
    required this.color,
  });

  final int days;
  final String name;
  final String message;
  final IconData icon;
  final Color color;
}

/// Milestone badges, keyed by consecutive-day count (matches
/// [StreakMath.milestones]).
const List<StreakBadge> kStreakBadges = [
  StreakBadge(
    days: 3,
    name: 'Spark',
    message: '3 days in a row! You\'re building real momentum 🌱',
    icon: Icons.local_fire_department_rounded,
    color: AppColors.sportFill,
  ),
  StreakBadge(
    days: 7,
    name: 'Kindling',
    message: 'A full week of focus! Your habit is taking root 🌿',
    icon: Icons.whatshot_rounded,
    color: AppColors.personalFill,
  ),
  StreakBadge(
    days: 30,
    name: 'Steady Flame',
    message: '30 days of devotion. This is who you are now 🔥',
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFFF4CFAD),
  ),
  StreakBadge(
    days: 100,
    name: 'Inner Fire',
    message: '100 days. Extraordinary, unshakable focus 🏔️',
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFE3C78A),
  ),
];

StreakBadge? streakBadgeFor(int days) {
  for (final b in kStreakBadges) {
    if (b.days == days) return b;
  }
  return null;
}
