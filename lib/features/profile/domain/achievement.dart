import 'package:flutter/material.dart';

import '../../../core/models/user_profile.dart';

/// Progress tuple type for achievements: (current, target)
typedef AchievementProgress = (int current, int target);

/// A profile achievement, unlocked when a [UserProfile] crosses a threshold.
class Achievement {
  const Achievement({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
    required this.howToUnlock,
    required this.category,
    required this.isUnlocked,
    this.getProgress,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String description;
  final String howToUnlock;
  final String category;
  final bool Function(UserProfile) isUnlocked;
  final AchievementProgress Function(UserProfile)? getProgress;
}

final List<Achievement> kAchievements = [
  Achievement(
    id: 'first_step',
    name: 'First Step',
    icon: Icons.flag_circle_rounded,
    color: const Color(0xFFB8A79A),
    description: 'Birinchi diqqat seansini yakunlang',
    howToUnlock: 'Ilovada ilk diqqat seansingizni muvaffaqiyatli bajaring.',
    category: 'Diqqat',
    isUnlocked: _firstSession,
    getProgress: (p) => (p.totalDeepSessions.clamp(0, 1), 1),
  ),
  Achievement(
    id: 'early_bird',
    name: 'Early Bird',
    icon: Icons.wb_sunny_rounded,
    color: const Color(0xFFE7C56D),
    description: 'Ilk diqqat seansini o\'tkazing',
    howToUnlock: 'Kun davomida kamida bitta diqqat seansini (Focus Session) yakunlang.',
    category: 'Diqqat',
    isUnlocked: _hasAnySession,
    getProgress: (p) => (p.totalDeepSessions > 0 || p.streak > 0 ? 1 : 0, 1),
  ),
  Achievement(
    id: 'deep_diver',
    name: 'Deep Diver',
    icon: Icons.water_drop_rounded,
    color: const Color(0xFF8DB1C9),
    description: '10 ta chuqur seans bajarildi',
    howToUnlock: 'Jami 10 ta chuqur diqqat (Deep Focus) seansini muvaffaqiyatli yakunlang.',
    category: 'Diqqat',
    isUnlocked: _tenDeepSessions,
    getProgress: (p) => (p.totalDeepSessions.clamp(0, 10), 10),
  ),
  Achievement(
    id: 'flow_state',
    name: 'Flow State',
    icon: Icons.auto_awesome_rounded,
    color: const Color(0xFF8AAE84),
    description: '3 kunlik seriyaga erishing',
    howToUnlock: 'Ketma-ket 3 kun davomida ilovada kamida bitta seans yoki vazifani bajaring.',
    category: 'Seriya',
    isUnlocked: _threeDayStreak,
    getProgress: (p) {
      final best = p.longestStreak > p.streak ? p.longestStreak : p.streak;
      return (best.clamp(0, 3), 3);
    },
  ),
  Achievement(
    id: 'week_winner',
    name: 'Week Winner',
    icon: Icons.calendar_view_week_rounded,
    color: const Color(0xFFE2C98C),
    description: 'Haftada 300 daqiqa diqqat qiling',
    howToUnlock: 'Bir hafta ichida jami kamida 300 daqiqa diqqat seanslarini bajarib haftalik g\'olib bo\'ling.',
    category: 'Haftalik',
    isUnlocked: _fiveDaysInWeek,
    getProgress: (p) => (p.weeklyFocusMinutes.clamp(0, 300), 300),
  ),
  Achievement(
    id: 'night_owl',
    name: 'Night Owl',
    icon: Icons.nights_stay_rounded,
    color: const Color(0xFF9B97C8),
    description: '120 daqiqa umumiy diqqat vaqti',
    howToUnlock: 'Jami diqqat vaqtingizni kamida 120 daqiqaga (2 soat) yetkazing.',
    category: 'Diqqat',
    isUnlocked: _nightOwls,
    getProgress: (p) => (p.totalFocusMinutes.clamp(0, 120), 120),
  ),
  Achievement(
    id: 'focused_mind',
    name: 'Focused Mind',
    icon: Icons.psychology_rounded,
    color: const Color(0xFFCF9BB5),
    description: '180 daqiqa diqqat seansiga erishish',
    howToUnlock: 'Jami diqqat vaqtingizni kamida 180 daqiqaga (3 soat) yetkazing.',
    category: 'Natija',
    isUnlocked: _focusedMind,
    getProgress: (p) => (p.totalFocusMinutes.clamp(0, 180), 180),
  ),
  Achievement(
    id: 'zen_master',
    name: 'Zen Master',
    icon: Icons.spa_rounded,
    color: const Color(0xFF6E9A6B),
    description: '1000 umumiy ball to\'plang',
    howToUnlock: 'Vazifalar va diqqat seanslari orqali jami 1000 Zen ball to\'plang.',
    category: 'Natija',
    isUnlocked: _highPoints,
    getProgress: (p) => (p.totalPoints.clamp(0, 1000), 1000),
  ),
];

bool _hasAnySession(UserProfile p) => p.totalDeepSessions > 0 || p.streak > 0;
bool _tenDeepSessions(UserProfile p) => p.totalDeepSessions >= 10;
bool _threeDayStreak(UserProfile p) => p.longestStreak >= 3 || p.streak >= 3;
bool _highPoints(UserProfile p) => p.totalPoints >= 1000;
bool _firstSession(UserProfile p) => p.totalDeepSessions >= 1;
bool _fiveDaysInWeek(UserProfile p) => p.weeklyFocusMinutes >= 300;
bool _nightOwls(UserProfile p) => p.totalFocusMinutes >= 120;
bool _focusedMind(UserProfile p) => p.totalFocusMinutes >= 180;
