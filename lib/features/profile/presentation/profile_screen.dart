import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/router/nav_helpers.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../premium/domain/premium.dart';
import '../../premium/presentation/premium_badge.dart';
import '../../streak/data/streak_repository.dart';
import '../../streak/domain/streak_badge.dart';
import '../../streak/domain/streak_math.dart';
import '../../streak/presentation/streak_flame.dart';
import '../domain/achievement.dart';
import '../domain/profile_display_name.dart';

/// Redesigned Production-Ready Profile Screen for Flowa.
///
/// Displays user identity, Zen level progress, lifetime stats, streak management,
/// and an interactive Achievements grid with detailed modal sheets on tap.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final profile = ref.watch(userProfileProvider).asData?.value;
    final secondaryName = profile == null
        ? null
        : secondaryProfileName(
            primaryName: profile.name,
            displayName: profile.displayName,
          );

    return Scaffold(
      bottomNavigationBar: AppBottomNav(
        current: AppNavTab.profile,
        onSelected: (tab) => goToTab(context, tab),
      ),
      body: SafeArea(
        bottom: false,
        child: profile == null
            ? const Center(child: FlowaLoading())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                children: [
                  // Top Navigation Header
                  Row(
                    children: [
                      const BrandLogo(),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Profilni tahrirlash',
                        icon: Icon(
                          Icons.edit_outlined,
                          color: colors.textSecondary,
                        ),
                        onPressed: () => context.push(AppRoutes.editProfile),
                      ),
                      IconButton(
                        tooltip: 'settings.title'.tr(),
                        icon: Icon(
                          Icons.settings_outlined,
                          color: colors.textSecondary,
                        ),
                        onPressed: () => context.push(AppRoutes.settings),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Hero Profile Header Card
                  _ProfileHeroCard(
                    profile: profile,
                    secondaryName: secondaryName,
                    onEditAvatar: () => context.push(AppRoutes.editProfile),
                  ),
                  const SizedBox(height: 20),

                  // Lifetime Statistics Grid
                  _StatsGrid(profile: profile),
                  const SizedBox(height: 24),

                  // Streak & Freeze Management Section
                  _StreakSection(profile: profile),
                ],
              ),
      ),
    );
  }
}

/// Hero Card featuring User Avatar, Level Progress Bar, Name, and Bio
class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.profile,
    required this.secondaryName,
    required this.onEditAvatar,
  });

  final UserProfile profile;
  final String? secondaryName;
  final VoidCallback onEditAvatar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final level = profile.level;
    final currentPointsInLevel = profile.totalPoints % 250;
    final progressToNextLevel = currentPointsInLevel / 250.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onEditAvatar,
            child: Stack(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        colors.primary,
                        colors.primary.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                  child: ClipOval(
                    child: AvatarCircle(
                      avatarKey: profile.avatar,
                      size: 86,
                      photoBase64: profile.photoBase64,
                      photoUrl: profile.photoUrl,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.surface, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // User Name & Premium Badge
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  profile.name,
                  style: AppTextStyles.h2.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (kPremiumEnabled && profile.isPremium) ...[
                const SizedBox(width: 8),
                const PremiumBadge(),
              ],
            ],
          ),

          if (secondaryName != null) ...[
            const SizedBox(height: 4),
            Text(
              secondaryName!,
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],

          if ((profile.bio ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                profile.bio!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Level Progress Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.workspace_premium_rounded,
                            size: 18,
                            color: Color(0xFFE7C56D),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'profile.zen_master_level'.tr(
                                namedArgs: {'level': '$level'},
                              ),
                              style: AppTextStyles.label.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$currentPointsInLevel / 250 ball',
                      style: AppTextStyles.caption.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progressToNextLevel.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: colors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Statistics 2x2 Grid displaying key metrics
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.1,
      children: [
        _StatCard(
          icon: Icons.stars_rounded,
          iconColor: const Color(0xFFE7C56D),
          value: '${profile.totalPoints}',
          label: 'profile.lifetime_points'.tr(),
        ),
        _StatCard(
          icon: Icons.timer_rounded,
          iconColor: const Color(0xFF8DB1C9),
          value: profile.focusHours.toStringAsFixed(1),
          label: 'profile.focus_hours'.tr(),
        ),
        _StatCard(
          icon: Icons.local_fire_department_rounded,
          iconColor: const Color(0xFFFF7A00),
          value: '${profile.longestStreak}',
          label: 'profile.longest_streak'.tr(),
        ),
        _StatCard(
          icon: Icons.center_focus_strong_rounded,
          iconColor: const Color(0xFF8AAE84),
          value: '${profile.totalDeepSessions}',
          label: 'Chuqur seanslar',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: AppTextStyles.h3.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: colors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Streak & Freeze Card Section
class _StreakSection extends ConsumerWidget {
  const _StreakSection({required this.profile});

  final UserProfile profile;

  Future<void> _buyFreeze(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;
    final result = await ref.read(streakRepositoryProvider).buyFreeze(uid);
    if (!context.mounted) return;
    final message = switch (result) {
      BuyFreezeResult.ok => 'profile.freeze_added'.tr(),
      BuyFreezeResult.notEnoughPoints => 'profile.freeze_not_enough'.tr(
        namedArgs: {'cost': '${StreakMath.freezeCost}'},
      ),
      BuyFreezeResult.full => 'profile.freeze_full'.tr(),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreakFlame(streak: profile.streak, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.streak > 0
                          ? 'common.days_streak'.tr(
                              namedArgs: {'count': '${profile.streak}'},
                            )
                          : 'profile.no_active_streak'.tr(),
                      style: AppTextStyles.h3.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'profile.longest_days'.tr(
                        namedArgs: {'count': '${profile.longestStreak}'},
                      ),
                      style: AppTextStyles.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StreakFreezeChip(count: profile.freezes),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'profile.freeze_explainer'.tr(),
            style: AppTextStyles.caption.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: AppButton(
              label: 'profile.buy_freeze'.tr(
                namedArgs: {'cost': '${StreakMath.freezeCost}'},
              ),
              expand: false,
              onPressed: () => _buyFreeze(context, ref),
            ),
          ),
          const SizedBox(height: 16),

          // Streak Milestone Badges Row
          Text(
            'Seriya nishonlari',
            style: AppTextStyles.label.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _StreakBadgeRow(profile: profile),
        ],
      ),
    );
  }
}

class _StreakBadgeRow extends StatelessWidget {
  const _StreakBadgeRow({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (i, b) in kStreakBadges.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            Tooltip(
              message: '${b.name}: ${b.message}',
              child: Container(
                width: 76,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: profile.hasBadge(b.days)
                      ? b.color.withValues(alpha: 0.9)
                      : colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: profile.hasBadge(b.days)
                        ? colors.primary.withValues(alpha: 0.3)
                        : colors.border,
                  ),
                  boxShadow: profile.hasBadge(b.days)
                      ? [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: profile.hasBadge(b.days)
                            ? colors.surface.withValues(alpha: 0.9)
                            : colors.border,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        b.icon,
                        size: 20,
                        color: profile.hasBadge(b.days)
                            ? colors.primary
                            : colors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${b.days} kun',
                      style: AppTextStyles.caption.copyWith(
                        color: profile.hasBadge(b.days)
                            ? colors.textPrimary
                            : colors.textTertiary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ProfileFilterChip extends StatelessWidget {
  const ProfileFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : colors.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: isSelected ? Colors.white : colors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// Achievements Grid View Component
class AchievementsGrid extends StatelessWidget {
  const AchievementsGrid({
    super.key,
    required this.profile,
    required this.filter,
  });

  final UserProfile profile;
  final String filter;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final filteredAchievements = kAchievements.where((a) {
      if (filter == 'unlocked') return a.isUnlocked(profile);
      if (filter == 'locked') return !a.isUnlocked(profile);
      return true;
    }).toList();

    if (filteredAchievements.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 48,
              color: colors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'Ushbu bo\'limda yutuqlar topilmadi',
              style: AppTextStyles.body.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Diqqat seanslarini bajarib yangi marralarni zabt eting!',
              style: AppTextStyles.caption.copyWith(
                color: colors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredAchievements.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final a = filteredAchievements[index];
        final isUnlocked = a.isUnlocked(profile);
        final progress = a.getProgress?.call(profile);

        return AchievementCard(
          achievement: a,
          isUnlocked: isUnlocked,
          progress: progress,
          onTap: () => showAchievementDetail(context, a, profile),
        );
      },
    );
  }

  void showAchievementDetail(
    BuildContext context,
    Achievement a,
    UserProfile profile,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AchievementDetailBottomSheet(
        achievement: a,
        profile: profile,
      ),
    );
  }
}

/// Interactive Card representing a single achievement item
class AchievementCard extends StatelessWidget {
  const AchievementCard({
    super.key,
    required this.achievement,
    required this.isUnlocked,
    required this.progress,
    required this.onTap,
  });

  final Achievement achievement;
  final bool isUnlocked;
  final AchievementProgress? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: isUnlocked
          ? colors.surface
          : colors.surfaceMuted.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isUnlocked
              ? achievement.color.withValues(alpha: 0.4)
              : colors.border,
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Icon container
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isUnlocked
                          ? achievement.color.withValues(alpha: 0.2)
                          : colors.border.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      boxShadow: isUnlocked
                          ? [
                              BoxShadow(
                                color: achievement.color.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      isUnlocked ? achievement.icon : Icons.lock_rounded,
                      color: isUnlocked ? achievement.color : colors.textTertiary,
                      size: 22,
                    ),
                  ),

                  // Category tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      achievement.category,
                      style: AppTextStyles.caption.copyWith(
                        color: colors.textTertiary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Title
              Text(
                achievement.name,
                style: AppTextStyles.label.copyWith(
                  color: isUnlocked ? colors.textPrimary : colors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),

              // Description or Progress
              if (isUnlocked) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 12,
                      color: Color(0xFF4CAF50),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Qo\'lga kiritildi',
                        style: AppTextStyles.caption.copyWith(
                          color: const Color(0xFF4CAF50),
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (progress != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (progress!.$1 / progress!.$2).clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: colors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            achievement.color.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${progress!.$1}/${progress!.$2}',
                      style: AppTextStyles.caption.copyWith(
                        color: colors.textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  achievement.description,
                  style: AppTextStyles.caption.copyWith(
                    color: colors.textTertiary,
                    fontSize: 10.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal Bottom Sheet displaying rich achievement details, unlocking requirements, and current progress
class AchievementDetailBottomSheet extends StatelessWidget {
  const AchievementDetailBottomSheet({
    super.key,
    required this.achievement,
    required this.profile,
  });

  final Achievement achievement;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isUnlocked = achievement.isUnlocked(profile);
    final progress = achievement.getProgress?.call(profile);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Big Hero Icon Container
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: isUnlocked
                    ? achievement.color.withValues(alpha: 0.2)
                    : colors.surfaceMuted,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isUnlocked
                      ? achievement.color.withValues(alpha: 0.5)
                      : colors.border,
                  width: 2,
                ),
                boxShadow: isUnlocked
                    ? [
                        BoxShadow(
                          color: achievement.color.withValues(alpha: 0.3),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Icon(
                  isUnlocked ? achievement.icon : Icons.lock_rounded,
                  size: 42,
                  color: isUnlocked ? achievement.color : colors.textTertiary,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Category Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                achievement.category.toUpperCase(),
                style: AppTextStyles.caption.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Achievement Name
            Text(
              achievement.name,
              style: AppTextStyles.h2.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),

            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isUnlocked
                    ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                    : Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUnlocked
                        ? Icons.check_circle_rounded
                        : Icons.lock_outline_rounded,
                    size: 14,
                    color: isUnlocked ? const Color(0xFF4CAF50) : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isUnlocked ? 'Qo\'lga kiritilgan' : 'Qulflangan',
                    style: AppTextStyles.caption.copyWith(
                      color: isUnlocked ? const Color(0xFF4CAF50) : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Requirement Section Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.help_outline_rounded,
                        size: 18,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bu yutuqni qanday qo\'lga kiritish mumkin?',
                          style: AppTextStyles.label.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    achievement.howToUnlock,
                    style: AppTextStyles.body.copyWith(
                      color: colors.textSecondary,
                      height: 1.35,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),

          // Progress Section if Locked
          if (!isUnlocked && progress != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Joriy progress:',
                        style: AppTextStyles.label.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${progress.$1} / ${progress.$2}',
                        style: AppTextStyles.label.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (progress.$1 / progress.$2).clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: colors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isUnlocked) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tabriklaymiz! Siz ushbu yutuqni muvaffaqiyatli qo\'lga kiritgansiz.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Primary Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Tushunarli',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}
