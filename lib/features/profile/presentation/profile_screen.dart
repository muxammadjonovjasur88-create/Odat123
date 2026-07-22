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

/// Screen 18 — the user's profile: identity, lifetime stats, achievements, and
/// a settings list.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  Row(
                    children: [
                      const BrandLogo(),
                      const Spacer(),
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
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: () => context.push(AppRoutes.editProfile),
                      child: Stack(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.border, width: 1.4),
                            ),
                            child: ClipOval(
                              child: AvatarCircle(
                                avatarKey: profile.avatar,
                                size: 88,
                                photoBase64: profile.photoBase64,
                                photoUrl: profile.photoUrl,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: colors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            profile.name,
                            style: AppTextStyles.h2.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        if (kPremiumEnabled && profile.isPremium) ...[
                          const SizedBox(width: 8),
                          const PremiumBadge(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'profile.zen_master_level'.tr(
                        namedArgs: {'level': '${profile.level}'},
                      ),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  if (secondaryName != null) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        secondaryName,
                        style: AppTextStyles.body.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  if ((profile.bio ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          profile.bio!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _StatTile(
                        value: '${profile.totalPoints}',
                        label: 'profile.lifetime_points'.tr(),
                      ),
                      const SizedBox(width: 12),
                      _StatTile(
                        value: '${profile.longestStreak}',
                        label: 'profile.longest_streak'.tr(),
                      ),
                      const SizedBox(width: 12),
                      _StatTile(
                        value: profile.focusHours.toStringAsFixed(0),
                        label: 'profile.focus_hours'.tr(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'profile.streak'.tr(),
                    style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  _StreakSection(profile: profile),
                  const SizedBox(height: 28),
                  Text(
                    'profile.achievements'.tr(),
                    style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  _AchievementRow(profile: profile),
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Text(
              value,
              style: AppTextStyles.h2.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: colors.textSecondary,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreakFlame(streak: profile.streak, size: 30),
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
              const SizedBox(width: 10),
              StreakFreezeChip(count: profile.freezes),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'profile.freeze_explainer'.tr(),
              style: AppTextStyles.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              height: 38,
              child: AppButton(
                label: 'profile.buy_freeze'.tr(
                  namedArgs: {'cost': '${StreakMath.freezeCost}'},
                ),
                expand: false,
                onPressed: () => _buyFreeze(context, ref),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _BadgeRow(profile: profile),
        ],
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (i, b) in kStreakBadges.indexed)
          FadeSlideIn(
            delay: FadeSlideIn.stagger(i, stepMs: 70),
            child: Tooltip(
              message: '${b.name}: ${b.message}',
              child: Container(
                width: 72,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: profile.hasBadge(b.days)
                      ? b.color.withValues(alpha: 0.9)
                      : colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: profile.hasBadge(b.days)
                        ? colors.primary.withValues(alpha: 0.22)
                        : colors.border,
                  ),
                  boxShadow: profile.hasBadge(b.days)
                      ? [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: profile.hasBadge(b.days)
                            ? colors.surface.withValues(alpha: 0.9)
                            : colors.border,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        b.icon,
                        size: 22,
                        color: profile.hasBadge(b.days)
                            ? colors.primary
                            : colors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${b.days}d',
                      style: AppTextStyles.caption.copyWith(
                        color: profile.hasBadge(b.days)
                            ? colors.textPrimary
                            : colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 9,
      crossAxisSpacing: 9,
      childAspectRatio: 0.63,
      padding: const EdgeInsets.symmetric(vertical: 2),
      children: [
        for (final (i, a) in kAchievements.indexed)
          FadeSlideIn(
            delay: FadeSlideIn.stagger(i, stepMs: 70),
            child: Tooltip(
              message: a.description,
              child: Container(
                padding: const EdgeInsets.fromLTRB(7, 8, 7, 8),
                decoration: BoxDecoration(
                  color: a.isUnlocked(profile)
                      ? a.color.withValues(alpha: 0.88)
                      : a.color.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: a.isUnlocked(profile)
                        ? colors.primary.withValues(alpha: 0.2)
                        : a.color.withValues(alpha: 0.3),
                  ),
                  boxShadow: a.isUnlocked(profile)
                      ? [
                          BoxShadow(
                            color: a.color.withValues(alpha: 0.22),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: a.isUnlocked(profile)
                            ? colors.surface.withValues(alpha: 0.94)
                            : colors.surface.withValues(alpha: 0.78),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        a.icon,
                        color: a.isUnlocked(profile)
                            ? colors.primary
                            : a.color.withValues(alpha: 0.7),
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      a.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: a.isUnlocked(profile)
                            ? colors.textPrimary
                            : colors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 8.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

