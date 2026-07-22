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
import '../data/leaderboard_repository.dart';
import '../domain/leaderboard_entry.dart';
import '../domain/leaderboard_rank.dart';

final leaderboardProvider = StreamProvider<List<LeaderboardEntry>>((ref) {
  return ref
      .watch(leaderboardRepositoryProvider)
      .watchWeeklyLeaderboard(weekId: 'all-time');
});

Widget _buildErrorBanner(BuildContext context, Object error) {
  final colors = context.colors;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: AppCard(
      color: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(
        'Xato: $error',
        style: AppTextStyles.bodySmall.copyWith(
          color: colors.primaryPressed.withValues(alpha: 0.9),
        ),
      ),
    ),
  );
}

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final profile = ref.watch(userProfileProvider).asData?.value;
    final leaderboardAsync = ref.watch(leaderboardProvider);
    final currentUserId = ref.watch(authStateProvider).asData?.value?.uid;

    final entries = leaderboardAsync.asData?.value ?? const [];
    final rankedEntries = LeaderboardRepository.sortEntriesForDisplay(
      entries.toList(),
    );
    LeaderboardEntry? currentUserEntry;
    for (final entry in rankedEntries) {
      if (entry.uid == currentUserId) {
        currentUserEntry = entry;
        break;
      }
    }
    final currentRank = currentUserEntry == null
        ? null
        : calculateUserRank(entries: rankedEntries, uid: currentUserId ?? '');
    final displayCurrentUser =
        currentUserEntry ??
        (profile != null && currentUserId != null
            ? LeaderboardEntry(
                uid: profile.uid,
                name: profile.displayName ?? profile.name,
                avatar: profile.avatar,
                weeklyPoints: profile.weeklyPoints,
                weeklyFocusMinutes: profile.weeklyFocusMinutes,
                totalPoints: profile.totalPoints,
                totalFocusMinutes: profile.totalFocusMinutes,
                photoUrl: profile.photoUrl,
                photoBase64: profile.photoBase64,
              )
            : null);
    final topEntries = rankedEntries.take(50).toList();
    final rows = <_LeaderboardRowModel>[];
    for (var i = 0; i < topEntries.length; i++) {
      final entry = topEntries[i];
      rows.add(
        _LeaderboardRowModel(
          rank: i + 1,
          entry: entry,
          isCurrentUser: entry.uid == currentUserId,
        ),
      );
    }
    final hasOtherUsers = rows.any((row) => !row.isCurrentUser);
    if (displayCurrentUser != null &&
        !rows.any((row) => row.isCurrentUser) &&
        currentRank != null) {
      rows.add(
        _LeaderboardRowModel(
          rank: currentRank,
          entry: displayCurrentUser,
          isCurrentUser: true,
        ),
      );
    }

    return Scaffold(
      bottomNavigationBar: AppBottomNav(
        current: AppNavTab.stats,
        onSelected: (tab) => goToTab(context, tab),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                Expanded(
                  child: Center(
                    child: Text(
                      'Reyting'.tr(),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: AppTextStyles.h2.copyWith(
                        color: colors.textPrimary,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 20),
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.tintSage.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.emoji_events_rounded,
                      color: colors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'leaderboard.week'.tr(),
                          style: AppTextStyles.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'leaderboard.subtitle'.tr(),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (leaderboardAsync.hasError) ...[
              _buildErrorBanner(
                context,
                leaderboardAsync.error ?? 'Unknown error',
              ),
              const SizedBox(height: 12),
            ],
            if (rankedEntries.isNotEmpty) ...[
              _Podium(entries: rankedEntries.take(3).toList()),
              const SizedBox(height: 16),
            ],
            if (displayCurrentUser != null &&
                !hasOtherUsers &&
                currentRank != null) ...[
              _CurrentUserRow(
                entry: displayCurrentUser,
                rank: currentRank,
                profile: profile,
              ),
              const SizedBox(height: 12),
            ],
            if (displayCurrentUser != null && !hasOtherUsers) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'leaderboard.empty_state'.tr(),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
            ...rows.map(
              (row) => _LeaderboardRow(
                entry: row.entry,
                rank: row.rank,
                isCurrentUser: row.isCurrentUser,
                profile: profile,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = entries.isNotEmpty
        ? entries.take(3).toList()
        : const <LeaderboardEntry>[];
    final first = items.isNotEmpty ? items[0] : null;
    final second = items.length > 1 ? items[1] : null;
    final third = items.length > 2 ? items[2] : null;
    final podiumOrder = [second, first, third];
    final heights = [160.0, 172.0, 158.0];
    final accents = [
      colors.tintSage.withValues(alpha: 0.84),
      colors.primary.withValues(alpha: 0.9),
      colors.surfaceMuted.withValues(alpha: 0.82),
    ];
    final borderColors = [
      colors.primary.withValues(alpha: 0.2),
      colors.primaryPressed.withValues(alpha: 0.2),
      colors.textSecondary.withValues(alpha: 0.24),
    ];
    final medals = ['2', '1', '3'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var index = 0; index < podiumOrder.length; index++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : 8,
                right: index == 2 ? 0 : 8,
              ),
              child: _PodiumCard(
                entry: podiumOrder[index],
                color: accents[index],
                borderColor: borderColors[index],
                place: index == 0
                    ? 2
                    : index == 1
                    ? 1
                    : 3,
                medal: medals[index],
                height: heights[index],
                isCenter: index == 1,
              ),
            ),
          ),
      ],
    );
  }
}

class _LeafBadge extends StatelessWidget {
  const _LeafBadge({
    required this.label,
    required this.color,
    required this.borderColor,
    required this.size,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color borderColor;
  final double size;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _LeafClipper(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: context.colors.primary.withValues(alpha: 0.16),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _LeafClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width * 0.5, size.height * 0.08);
    path.cubicTo(
      size.width * 0.86,
      size.height * 0.12,
      size.width * 0.97,
      size.height * 0.38,
      size.width * 0.76,
      size.height * 0.48,
    );
    path.cubicTo(
      size.width * 0.9,
      size.height * 0.74,
      size.width * 0.72,
      size.height * 0.94,
      size.width * 0.5,
      size.height * 0.9,
    );
    path.cubicTo(
      size.width * 0.28,
      size.height * 0.94,
      size.width * 0.1,
      size.height * 0.74,
      size.width * 0.24,
      size.height * 0.48,
    );
    path.cubicTo(
      size.width * 0.03,
      size.height * 0.38,
      size.width * 0.14,
      size.height * 0.12,
      size.width * 0.5,
      size.height * 0.08,
    );
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({
    required this.entry,
    required this.color,
    required this.borderColor,
    required this.place,
    required this.medal,
    required this.height,
    required this.isCenter,
  });

  final LeaderboardEntry? entry;
  final Color color;
  final Color borderColor;
  final int place;
  final String medal;
  final double height;
  final bool isCenter;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final subtitle = entry == null ? '' : '${entry!.totalPoints} pts';
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 8,
            child: _LeafBadge(
              label: medal,
              color: switch (place) {
                1 => colors.primary,
                2 => colors.primaryPressed.withValues(alpha: 0.86),
                _ => colors.textSecondary.withValues(alpha: 0.8),
              },
              borderColor: colors.surface,
              size: 34,
              textColor: colors.onPrimary,
            ),
          ),
          Positioned(
            top: 42,
            child: Container(
              width: isCenter ? 66 : 58,
              height: isCenter ? 66 : 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(
                      alpha: isCenter ? 0.2 : 0.12,
                    ),
                    blurRadius: isCenter ? 18 : 14,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: AvatarCircle(
                  avatarKey: entry?.avatar ?? 'leaf',
                  size: isCenter ? 66 : 58,
                  photoBase64: entry?.photoBase64,
                  photoUrl: entry?.photoUrl,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 8,
            right: 8,
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: isCenter ? 12.5 : 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentUserRow extends StatelessWidget {
  const _CurrentUserRow({
    required this.entry,
    required this.rank,
    required this.profile,
  });

  final LeaderboardEntry entry;
  final int? rank;
  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      color: colors.tintSage,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.2),
                width: 1.2,
              ),
            ),
            child: ClipOval(
              child: AvatarCircle(
                avatarKey: entry.avatar,
                size: 46,
                photoBase64: entry.photoBase64,
                photoUrl: entry.photoUrl,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.name} • ${'leaderboard.you'.tr()}',
                  style: AppTextStyles.label.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.totalPoints} pts',
                  style: AppTextStyles.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.16),
                width: 1,
              ),
            ),
            child: Text(
              rank == null ? '' : '#$rank',
              style: AppTextStyles.caption.copyWith(color: colors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRowModel {
  const _LeaderboardRowModel({
    required this.rank,
    required this.entry,
    required this.isCurrentUser,
  });

  final int rank;
  final LeaderboardEntry entry;
  final bool isCurrentUser;
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.entry,
    required this.rank,
    required this.isCurrentUser,
    required this.profile,
  });

  final LeaderboardEntry entry;
  final int rank;
  final bool isCurrentUser;
  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderColor = isCurrentUser
        ? colors.primary.withValues(alpha: 0.24)
        : colors.border;
    return AppCard(
      color: isCurrentUser ? colors.tintSage : null,
      border: Border.all(color: borderColor, width: 1.1),
      onTap: () {
        final targetPath = isCurrentUser
            ? AppRoutes.profile
            : '${AppRoutes.profile}/${entry.uid}';
        context.push(targetPath);
      },
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isCurrentUser
                  ? colors.primary.withValues(alpha: 0.16)
                  : colors.surfaceMuted,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.border, width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: AppTextStyles.caption.copyWith(color: colors.primary),
            ),
          ),
          const SizedBox(width: 12),
          ClipOval(
            child: AvatarCircle(
              avatarKey: entry.avatar,
              size: 36,
              photoBase64: entry.photoBase64,
              photoUrl: entry.photoUrl,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: AppTextStyles.label.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.totalPoints} pts',
                  style: AppTextStyles.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${entry.totalPoints} pts',
            style: AppTextStyles.label.copyWith(color: colors.textPrimary),
          ),
        ],
      ),
    );
  }
}

String formatWeekLabel(String weekId) {
  final startDate = DateTime.parse(weekId);
  final endDate = startDate.add(const Duration(days: 6));
  final locale = Intl.getCurrentLocale();
  final startDay = DateFormat('dd', locale).format(startDate);
  final endDay = DateFormat('dd', locale).format(endDate);
  final month = switch (locale) {
    'ru' => [
      'янв',
      'фев',
      'мар',
      'апр',
      'май',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ][startDate.month - 1],
    'uz' => [
      'yan',
      'fev',
      'mart',
      'apr',
      'may',
      'iyun',
      'iyul',
      'avg',
      'sent',
      'okt',
      'noy',
      'dek',
    ][startDate.month - 1],
    _ => DateFormat.MMM(locale).format(startDate),
  };
  return '$startDay–$endDay $month';
}
