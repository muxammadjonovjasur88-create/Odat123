import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A built-in avatar option. Photo upload can be added later (image_picker +
/// Firebase Storage); for now users pick one of these calm default avatars,
/// and [DefaultAvatar.key] is stored in `users/{uid}.avatar`.
class DefaultAvatar {
  const DefaultAvatar(
    this.key,
    this.icon,
    this.background,
    this.foreground, {
    this.isPremium = false,
  });

  final String key;
  final IconData icon;
  final Color background;
  final Color foreground;

  /// Premium-only cosmetic avatar (gated behind the subscription).
  final bool isPremium;
}

const List<DefaultAvatar> kDefaultAvatars = [
  DefaultAvatar(
    'leaf',
    Icons.spa_rounded,
    AppColors.sportFill,
    AppColors.sportText,
  ),
  DefaultAvatar(
    'sun',
    Icons.wb_sunny_rounded,
    AppColors.personalFill,
    AppColors.personalText,
  ),
  DefaultAvatar(
    'moon',
    Icons.nightlight_round,
    AppColors.studyFill,
    AppColors.studyText,
  ),
  DefaultAvatar(
    'mountain',
    Icons.terrain_rounded,
    AppColors.wellnessFill,
    AppColors.wellnessText,
  ),
  DefaultAvatar(
    'wave',
    Icons.waves_rounded,
    AppColors.studyFill,
    AppColors.studyText,
  ),
  DefaultAvatar(
    'flower',
    Icons.local_florist_rounded,
    AppColors.personalFill,
    AppColors.personalText,
  ),
  // ---- Premium-only cosmetic avatars (gold tones) ----
  DefaultAvatar(
    'crown',
    Icons.workspace_premium_rounded,
    Color(0xFFEFE0B8),
    Color(0xFF8A6D2B),
    isPremium: true,
  ),
  DefaultAvatar(
    'star',
    Icons.star_rounded,
    Color(0xFFEFE0B8),
    Color(0xFF8A6D2B),
    isPremium: true,
  ),
  DefaultAvatar(
    'gem',
    Icons.diamond_rounded,
    Color(0xFFD7E7EC),
    Color(0xFF3A6B78),
    isPremium: true,
  ),
];

DefaultAvatar avatarForKey(String key) => kDefaultAvatars.firstWhere(
  (a) => a.key == key,
  orElse: () => kDefaultAvatars.first,
);

/// The freely-selectable avatars (non-premium).
List<DefaultAvatar> get kFreeAvatars =>
    kDefaultAvatars.where((a) => !a.isPremium).toList();

/// The premium-only avatars.
List<DefaultAvatar> get kPremiumAvatars =>
    kDefaultAvatars.where((a) => a.isPremium).toList();
