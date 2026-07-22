import 'package:flutter/material.dart';

import '../../../core/models/user_profile.dart';

/// A profile achievement, unlocked when a [UserProfile] crosses a threshold.
class Achievement {
  const Achievement({
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
    required this.isUnlocked,
  });

  final String name;
  final IconData icon;
  final Color color;
  final String description;
  final bool Function(UserProfile) isUnlocked;
}

final List<Achievement> kAchievements = [
  Achievement(
    name: 'Early Bird',
    icon: Icons.wb_sunny_rounded,
    color: const Color(0xFFE7C56D),
    description: 'Complete your first focus session',
    isUnlocked: _hasAnySession,
  ),
  Achievement(
    name: 'Deep Diver',
    icon: Icons.water_drop_rounded,
    color: const Color(0xFF8DB1C9),
    description: 'Complete 10 deep sessions',
    isUnlocked: _tenDeepSessions,
  ),
  Achievement(
    name: 'Flow State',
    icon: Icons.auto_awesome_rounded,
    color: const Color(0xFF8AAE84),
    description: 'Reach a 3-day streak',
    isUnlocked: _threeDayStreak,
  ),
  Achievement(
    name: 'Zen Master',
    icon: Icons.spa_rounded,
    color: const Color(0xFF6E9A6B),
    description: 'Earn 1000 total points',
    isUnlocked: _highPoints,
  ),
  Achievement(
    name: 'First Step',
    icon: Icons.flag_circle_rounded,
    color: const Color(0xFFB8A79A),
    description: 'Finish your first focus session',
    isUnlocked: _firstSession,
  ),
  Achievement(
    name: 'Week Winner',
    icon: Icons.calendar_view_week_rounded,
    color: const Color(0xFFE2C98C),
    description: 'Complete focus on 5 days in a week',
    isUnlocked: _fiveDaysInWeek,
  ),
  Achievement(
    name: 'Night Owl',
    icon: Icons.nights_stay_rounded,
    color: const Color(0xFF9B97C8),
    description: 'Finish a session after 22:00',
    isUnlocked: _nightOwls,
  ),
  Achievement(
    name: 'Focused Mind',
    icon: Icons.psychology_rounded,
    color: const Color(0xFFCF9BB5),
    description: 'Reach 180 minutes of focus in one day',
    isUnlocked: _focusedMind,
  ),
];

bool _hasAnySession(UserProfile p) => p.totalDeepSessions > 0 || p.streak > 0;
bool _tenDeepSessions(UserProfile p) => p.totalDeepSessions >= 10;
bool _threeDayStreak(UserProfile p) => p.longestStreak >= 3;
bool _highPoints(UserProfile p) => p.totalPoints >= 1000;
bool _firstSession(UserProfile p) => p.totalDeepSessions >= 1;
bool _fiveDaysInWeek(UserProfile p) => p.weeklyFocusMinutes >= 300;
bool _nightOwls(UserProfile p) => p.totalFocusMinutes >= 120; // simple proxy for a later evening session
bool _focusedMind(UserProfile p) => p.totalFocusMinutes >= 180;
