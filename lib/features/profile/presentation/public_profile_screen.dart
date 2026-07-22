import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../gamification/domain/level_calculator.dart';
import '../domain/profile_display_name.dart';

class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final currentUserId = ref.watch(authStateProvider).asData?.value?.uid;
    final isOwnProfile = currentUserId == userId;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('profile.public_profile'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colors.onPrimary,
        titleTextStyle: AppTextStyles.h3.copyWith(color: colors.onPrimary),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.primary.withOpacity(0.16),
              colors.background.withOpacity(0.98),
              colors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: ref
                .read(firestoreProvider)
                .collection('users')
                .doc(userId)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _ProfileSkeleton();
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  !snapshot.data!.exists) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'profile.not_found'.tr(),
                      style: AppTextStyles.body.copyWith(
                        color: colors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final profile = UserProfile.fromDoc(snapshot.data!);
              final secondaryName = secondaryProfileName(
                primaryName: profile.name,
                displayName: profile.displayName,
              );
              final level = LevelCalculator.calculateLevel(
                profile.totalFocusMinutes,
              );
              final progress = LevelCalculator.levelProgress(
                profile.totalFocusMinutes,
              );
              final hasWeekActivity =
                  profile.streak > 0 || profile.weeklyFocusMinutes > 0;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colors.primary.withOpacity(0.14),
                            colors.surface.withOpacity(0.82),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: colors.border.withOpacity(0.72),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadow,
                            blurRadius: 26,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 124,
                            height: 124,
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: hasWeekActivity
                                    ? colors.primary.withOpacity(0.9)
                                    : colors.border.withOpacity(0.7),
                                width: 2.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: hasWeekActivity
                                      ? colors.primary.withOpacity(0.18)
                                      : colors.shadow,
                                  blurRadius: 24,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: AvatarCircle(
                                avatarKey: profile.avatar,
                                size: 114,
                                photoBase64: profile.photoBase64,
                                photoUrl: profile.photoUrl,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                profile.displayName ?? profile.name,
                                style: AppTextStyles.h2.copyWith(
                                  color: colors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (level > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: colors.primary.withOpacity(0.24),
                                    ),
                                  ),
                                  child: Text(
                                    'Level $level',
                                    style: AppTextStyles.chip.copyWith(
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (secondaryName != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              secondaryName,
                              style: AppTextStyles.body.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                          if ((profile.bio ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Text(
                                profile.bio!,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (!isOwnProfile)
                      _LikeButton(
                        targetUserId: userId,
                        currentUserId: currentUserId ?? '',
                        likesCount: profile.likesCount,
                      )
                    else
                      _StaticLikePill(count: profile.likesCount),
                    const SizedBox(height: 14),
                    AppCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'profile.level'.tr(),
                                style: AppTextStyles.label.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Level $level',
                                  style: AppTextStyles.chip.copyWith(
                                    color: colors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: colors.surfaceMuted,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'profile.level_progress'.tr(
                              namedArgs: {
                                'minutes':
                                    '${LevelCalculator.minutesToNextLevel(profile.totalFocusMinutes)}',
                              },
                            ),
                            style: AppTextStyles.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _StatsGrid(
                      points: profile.totalPoints,
                      focusMinutes: profile.totalFocusMinutes,
                      streak: profile.streak,
                      longestStreak: profile.longestStreak,
                    ),

                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: colors.border.withOpacity(0.7)),
            ),
            child: Column(
              children: [
                const AppSkeleton(width: 124, height: 124, radius: 62),
                const SizedBox(height: 16),
                const AppSkeleton(width: 180, height: 20),
                const SizedBox(height: 10),
                const AppSkeleton(width: 120, height: 14),
                const SizedBox(height: 12),
                const AppSkeleton(width: 220, height: 12),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSkeleton(width: 140, height: 16),
                const SizedBox(height: 12),
                const AppSkeleton(width: double.infinity, height: 8),
                const SizedBox(height: 10),
                const AppSkeleton(width: 160, height: 12),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.18,
            children: const [
              AppSkeleton(width: double.infinity, height: 92, radius: 24),
              AppSkeleton(width: double.infinity, height: 92, radius: 24),
              AppSkeleton(width: double.infinity, height: 92, radius: 24),
              AppSkeleton(width: double.infinity, height: 92, radius: 24),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.points,
    required this.focusMinutes,
    required this.streak,
    required this.longestStreak,
  });

  final int points;
  final int focusMinutes;
  final int streak;
  final int longestStreak;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hours = focusMinutes ~/ 60;
    final minutes = focusMinutes % 60;
    final focusValue = hours <= 0
        ? '$minutes min'
        : minutes <= 0
        ? '$hours h'
        : '$hours h $minutes min';

    final cards = <_StatCardData>[
      _StatCardData(
        value: '$points',
        label: 'profile.lifetime_points'.tr(),
        icon: Icons.emoji_events_rounded,
        color: colors.tintSage,
      ),
      _StatCardData(
        value: focusValue,
        label: 'profile.focus_hours'.tr(),
        icon: Icons.timer_outlined,
        color: colors.tintBlue,
      ),
      _StatCardData(
        value: '$streak',
        label: 'profile.streak'.tr(),
        icon: Icons.local_fire_department_rounded,
        color: colors.primary.withOpacity(0.14),
      ),
      _StatCardData(
        value: '$longestStreak',
        label: 'profile.longest_streak'.tr(),
        icon: Icons.insights_rounded,
        color: colors.surfaceMuted,
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.12,
      children: cards.map((card) => _StatCard(data: card)).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _StatCardData data;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: 24,
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: data.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, size: 18, color: colors.primary),
          ),
          const SizedBox(height: 10),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            data.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: colors.textSecondary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCardData {
  const _StatCardData({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
}

class _StaticLikePill extends StatelessWidget {
  const _StaticLikePill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: colors.primary.withOpacity(0.25),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_rounded, size: 20, color: colors.primary),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: AppTextStyles.label.copyWith(color: colors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _LikeButton extends ConsumerStatefulWidget {
  const _LikeButton({
    required this.targetUserId,
    required this.currentUserId,
    required this.likesCount,
  });

  final String targetUserId;
  final String currentUserId;
  final int likesCount;

  @override
  ConsumerState<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends ConsumerState<_LikeButton>
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  bool _isLiked = false;
  late int _displayCount;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _displayCount = widget.likesCount;
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 360),
      vsync: this,
    );
    _checkIfLiked();
  }

  @override
  void didUpdateWidget(_LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.likesCount != widget.likesCount) {
      _displayCount = widget.likesCount;
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _checkIfLiked() async {
    final userRepo = ref.read(userRepositoryProvider);
    try {
      final liked = await userRepo.hasLiked(
        widget.targetUserId,
        widget.currentUserId,
      );
      if (mounted) {
        setState(() => _isLiked = liked);
      }
    } catch (_) {
      // Silently fail — show button as not liked if check fails.
    }
  }

  Future<void> _onLikeTap() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final wasLiked = _isLiked;
    final oldCount = _displayCount;
    setState(() {
      _isLiked = !_isLiked;
      _displayCount = _isLiked ? _displayCount + 1 : _displayCount - 1;
    });

    await _scaleController.forward().then((_) => _scaleController.reverse());

    try {
      final userRepo = ref.read(userRepositoryProvider);
      await userRepo.toggleLike(widget.targetUserId, widget.currentUserId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _displayCount = oldCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scale = Tween<double>(begin: 1.0, end: 1.24).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _onLikeTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: AppMotion.fade,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _isLiked
                  ? colors.primary
                  : colors.surface.withOpacity(0.76),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _isLiked
                    ? colors.primary
                    : colors.primary.withOpacity(0.24),
                width: 1.5,
              ),
              boxShadow: _isLiked
                  ? [
                      BoxShadow(
                        color: colors.primary.withOpacity(0.16),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: scale,
                  child: Icon(
                    _isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 20,
                    color: _isLiked ? colors.onPrimary : colors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: AppMotion.fade,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.15),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    _displayCount.toString(),
                    key: ValueKey<int>(_displayCount),
                    style: AppTextStyles.label.copyWith(
                      color: _isLiked ? colors.onPrimary : colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
