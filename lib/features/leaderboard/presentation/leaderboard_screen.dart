import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/uzbekistan_regions.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/router/nav_helpers.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/region_controller.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/leaderboard_repository.dart';
import '../domain/leaderboard_entry.dart';
import '../domain/leaderboard_rank.dart';

// ---------------------------------------------------------------------------
// Tab enum
// ---------------------------------------------------------------------------

enum LeaderboardTab { global, region }

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _globalLeaderboardProvider = StreamProvider<List<LeaderboardEntry>>((ref) {
  return ref.watch(leaderboardRepositoryProvider).watchGlobalLeaderboard();
});

final _regionalLeaderboardProvider =
    StreamProvider.family<List<LeaderboardEntry>, UzRegion>((ref, region) {
  return ref
      .watch(leaderboardRepositoryProvider)
      .watchRegionalLeaderboard(region: region);
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildErrorBanner(BuildContext context, Object error) {
  final colors = context.colors;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: AppCard(
      color: const Color(0xFF151A27),
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

// ---------------------------------------------------------------------------
// LeaderboardScreen
// ---------------------------------------------------------------------------

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  LeaderboardTab _tab = LeaderboardTab.global;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 260),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _switchTab(LeaderboardTab tab) {
    if (tab == _tab) return;
    _fadeController.reverse().then((_) {
      if (mounted) {
        setState(() => _tab = tab);
        _fadeController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final profile = ref.watch(userProfileProvider).asData?.value;
    final currentUserId = ref.watch(authStateProvider).asData?.value?.uid;
    final regionState = ref.watch(regionControllerProvider);
    final currentRegion = regionState.region;

    // Choose the right stream based on active tab.
    final AsyncValue<List<LeaderboardEntry>> leaderboardAsync = switch (_tab) {
      LeaderboardTab.global => ref.watch(_globalLeaderboardProvider),
      LeaderboardTab.region => currentRegion != null
          ? ref.watch(_regionalLeaderboardProvider(currentRegion))
          : const AsyncData([]),
    };

    final entries = leaderboardAsync.asData?.value ?? const [];
    final rankedEntries = LeaderboardRepository.sortEntriesForDisplay(entries);

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
    final displayCurrentUser = currentUserEntry ??
        (profile != null && currentUserId != null
            ? LeaderboardEntry(
                uid: profile.uid,
                name: profile.displayName ?? profile.name,
                avatar: profile.avatar,
                weeklyPoints: profile.weeklyPoints,
                weeklyFocusMinutes: profile.weeklyFocusMinutes,
                monthlyPoints: profile.monthlyPoints,
                monthlyFocusMinutes: profile.monthlyFocusMinutes,
                totalPoints: profile.totalPoints,
                totalFocusMinutes: profile.totalFocusMinutes,
                photoUrl: profile.photoUrl,
                photoBase64: profile.photoBase64,
              )
            : null);

    final listEntries = rankedEntries.length > 3
        ? rankedEntries.skip(3).take(47).toList()
        : <LeaderboardEntry>[];

    final hasOtherUsers = rankedEntries.any((e) => e.uid != currentUserId);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: const FlowaAppBar(
        showBackButton: false,
        leading: SizedBox.shrink(),
      ),
      bottomNavigationBar: AppBottomNav(
        current: AppNavTab.leaderboard,
        onSelected: (tab) => goToTab(context, tab),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tab bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: _TabBar(
                selected: _tab,
                currentRegion: currentRegion,
                regionStatus: regionState.status,
                onGlobal: () => _switchTab(LeaderboardTab.global),
                onRegion: () {
                  if (currentRegion == null) {
                    // Trigger GPS detection if not yet resolved.
                    ref
                        .read(regionControllerProvider.notifier)
                        .detectAndSave();
                  }
                  _switchTab(LeaderboardTab.region);
                },
              ),
            ),
            const SizedBox(height: 8),

            // ── Region status banner ───────────────────────────────────────
            if (_tab == LeaderboardTab.region)
              _RegionStatusBanner(
                regionState: regionState,
                onRetry: () =>
                    ref.read(regionControllerProvider.notifier).detectAndSave(),
                onManualPick: (region) =>
                    ref.read(regionControllerProvider.notifier).setManually(region),
              ),

            // ── Content ────────────────────────────────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ListView(
                  key: ValueKey(_tab),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                  children: [
                    if (leaderboardAsync.hasError) ...[
                      _buildErrorBanner(
                        context,
                        leaderboardAsync.error ?? 'Unknown error',
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Loading skeleton
                    if (leaderboardAsync.isLoading)
                      const AppCardSkeletonList()
                    else ...[
                      if (rankedEntries.isNotEmpty) ...[
                        _Podium(entries: rankedEntries.take(3).toList()),
                        const SizedBox(height: 20),
                      ],

                      if (!hasOtherUsers) ...[
                        if (displayCurrentUser != null &&
                            currentRank != null) ...[
                          _CurrentUserRow(
                            entry: displayCurrentUser,
                            rank: currentRank,
                            profile: profile,
                          ),
                          const SizedBox(height: 12),
                        ],
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            _tab == LeaderboardTab.region
                                ? 'Hali bu viloyatda boshqa foydalanuvchilar yo\'q.'
                                : 'leaderboard.empty_state'.tr(),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ] else ...[
                        for (var i = 0; i < listEntries.length; i++)
                          _LeaderboardRow(
                            entry: listEntries[i],
                            rank: i + 4,
                            isCurrentUser: listEntries[i].uid == currentUserId,
                            profile: profile,
                          ),
                        if (currentUserEntry == null &&
                            displayCurrentUser != null) ...[
                          const SizedBox(height: 12),
                          _CurrentUserRow(
                            entry: displayCurrentUser,
                            rank: currentRank,
                            profile: profile,
                          ),
                        ],
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TabBar — Global | Mening viloyatim
// ---------------------------------------------------------------------------

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.selected,
    required this.currentRegion,
    required this.regionStatus,
    required this.onGlobal,
    required this.onRegion,
  });

  final LeaderboardTab selected;
  final UzRegion? currentRegion;
  final RegionStatus regionStatus;
  final VoidCallback onGlobal;
  final VoidCallback onRegion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF151A27),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          _TabChip(
            label: 'Global',
            icon: Icons.public_rounded,
            selected: selected == LeaderboardTab.global,
            onTap: onGlobal,
          ),
          _TabChip(
            label: currentRegion?.displayName ??
                (regionStatus == RegionStatus.loading
                    ? 'Aniqlanmoqda...'
                    : 'Mening viloyatim'),
            icon: Icons.location_on_rounded,
            selected: selected == LeaderboardTab.region,
            onTap: onRegion,
            showLoading: regionStatus == RegionStatus.loading,
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.showLoading = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool showLoading;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.cyanAccent.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(
                    color: AppColors.cyanAccent.withValues(alpha: 0.5),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showLoading)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: selected
                        ? AppColors.cyanAccent
                        : context.colors.textSecondary,
                  ),
                )
              else
                Icon(
                  icon,
                  size: 14,
                  color: selected
                      ? AppColors.cyanAccent
                      : context.colors.textSecondary,
                ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: selected
                        ? AppColors.cyanAccent
                        : context.colors.textSecondary,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _RegionStatusBanner — shown in regional tab when GPS failed / unavailable
// ---------------------------------------------------------------------------

class _RegionStatusBanner extends StatelessWidget {
  const _RegionStatusBanner({
    required this.regionState,
    required this.onRetry,
    required this.onManualPick,
  });

  final RegionState regionState;
  final VoidCallback onRetry;
  final ValueChanged<UzRegion> onManualPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // If loaded — show info chip with region name
    if (regionState.status == RegionStatus.loaded &&
        regionState.region != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.location_on_rounded,
                color: AppColors.cyanAccent, size: 14),
            const SizedBox(width: 4),
            Text(
              regionState.region!.displayName,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.cyanAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // If unavailable — show error + fallback
    if (regionState.status == RegionStatus.unavailable) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: AppCard(
          color: const Color(0xFF151A27),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                regionState.errorMessage ?? 'Viloyat aniqlanmadi.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  // Retry GPS
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.gps_fixed_rounded, size: 14),
                      label: const Text('GPS qayta',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.cyanAccent,
                        side: const BorderSide(
                            color: AppColors.cyanAccent, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Manual pick
                  Expanded(
                    child: _ManualRegionButton(onPick: onManualPick),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Dropdown button to manually pick a region when GPS fails.
class _ManualRegionButton extends StatefulWidget {
  const _ManualRegionButton({required this.onPick});

  final ValueChanged<UzRegion> onPick;

  @override
  State<_ManualRegionButton> createState() => _ManualRegionButtonState();
}

class _ManualRegionButtonState extends State<_ManualRegionButton> {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<UzRegion>(
      onSelected: widget.onPick,
      color: const Color(0xFF1F2638),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => UzRegion.values
          .map((r) => PopupMenuItem(
                value: r,
                child: Text(
                  r.displayName,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white,
                  ),
                ),
              ))
          .toList(),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.purpleAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.purpleAccent.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          'Qo\'lda tanlash',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.purpleAccent,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _Podium
// ---------------------------------------------------------------------------

class _Podium extends StatelessWidget {
  const _Podium({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    final items = entries.isNotEmpty
        ? entries.take(3).toList()
        : const <LeaderboardEntry>[];
    final first = items.isNotEmpty ? items[0] : null;
    final second = items.length > 1 ? items[1] : null;
    final third = items.length > 2 ? items[2] : null;
    final podiumOrder = [second, first, third];
    final heights = [160.0, 185.0, 160.0];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var index = 0; index < podiumOrder.length; index++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : 6,
                right: index == 2 ? 0 : 6,
              ),
              child: _PodiumCard(
                entry: podiumOrder[index],
                place: index == 0
                    ? 2
                    : index == 1
                        ? 1
                        : 3,
                height: heights[index],
              ),
            ),
          ),
      ],
    );
  }
}

class _PodiumBadge extends StatelessWidget {
  const _PodiumBadge({required this.place});

  final int place;

  @override
  Widget build(BuildContext context) {
    if (place == 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.cyanAccent.withValues(alpha: 0.3),
              blurRadius: 6,
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('👑 ', style: TextStyle(fontSize: 10)),
            Text(
              '1',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    final color = place == 2 ? AppColors.cyanAccent : AppColors.purpleAccent;
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.2),
      ),
      alignment: Alignment.center,
      child: Text(
        '$place',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({
    required this.entry,
    required this.place,
    required this.height,
  });

  final LeaderboardEntry? entry;
  final int place;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isFirst = place == 1;

    Widget cardBody = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151A27),
        borderRadius: BorderRadius.circular(isFirst ? 18.5 : 20),
        border: !isFirst
            ? Border.all(
                color: place == 2
                    ? AppColors.cyanAccent
                    : AppColors.purpleAccent,
                width: 1.5,
              )
            : null,
        boxShadow: !isFirst
            ? [
                BoxShadow(
                  color: (place == 2
                          ? AppColors.cyanAccent
                          : AppColors.purpleAccent)
                      .withValues(alpha: 0.2),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _PodiumBadge(place: place),
          Container(
            width: isFirst ? 62 : 52,
            height: isFirst ? 62 : 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isFirst
                    ? AppColors.cyanAccent
                    : (place == 2
                        ? AppColors.cyanAccent
                        : AppColors.purpleAccent),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isFirst || place == 2
                          ? AppColors.cyanAccent
                          : AppColors.purpleAccent)
                      .withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: AvatarCircle(
                avatarKey: entry?.avatar ?? 'leaf',
                size: isFirst ? 62 : 52,
                photoBase64: entry?.photoBase64,
                photoUrl: entry?.photoUrl,
              ),
            ),
          ),
          Column(
            children: [
              Text(
                entry?.name ?? '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.label.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: isFirst ? 13 : 11.5,
                ),
              ),
              const SizedBox(height: 2),
              // Region chip inside podium card
              if (entry?.region != null) ...[
                Text(
                  entry!.region!.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.purpleAccent.withValues(alpha: 0.85),
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                entry != null ? '${entry!.totalPoints} pts' : '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: isFirst
                      ? AppColors.cyanAccent
                      : (place == 2
                          ? AppColors.cyanAccent
                          : AppColors.purpleAccent),
                  fontWeight: FontWeight.w600,
                  fontSize: isFirst ? 11.5 : 10.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (isFirst) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.cyanAccent.withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: AppColors.purpleAccent.withValues(alpha: 0.25),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        padding: const EdgeInsets.all(1.5),
        child: cardBody,
      );
    }

    return cardBody;
  }
}

// ---------------------------------------------------------------------------
// _CurrentUserRow
// ---------------------------------------------------------------------------

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF151A27),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.cyanAccent.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyanAccent.withValues(alpha: 0.15),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          ClipOval(
            child: AvatarCircle(
              avatarKey: entry.avatar,
              size: 42,
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
                  '${entry.name} • ${'leaderboard.you'.tr()}',
                  style: AppTextStyles.label.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${entry.totalPoints} pts',
                      style: AppTextStyles.caption.copyWith(
                        color: const Color(0xFF9E9E9E),
                      ),
                    ),
                    if (entry.region != null) ...[
                      const SizedBox(width: 8),
                      _RegionChip(region: entry.region!),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.cyanAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.cyanAccent,
                width: 1,
              ),
            ),
            child: Text(
              rank == null ? '50+' : '#$rank',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.cyanAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _LeaderboardRow
// ---------------------------------------------------------------------------

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

    return InkWell(
      onTap: () {
        final targetPath = isCurrentUser
            ? AppRoutes.profile
            : '${AppRoutes.profile}/${entry.uid}';
        context.push(targetPath);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? const Color(0xFF151A27).withValues(alpha: 0.7)
              : Colors.transparent,
          border: const Border(
            bottom: BorderSide(
              color: Color(0xFF151A27),
              width: 1,
            ),
          ),
          borderRadius: isCurrentUser ? BorderRadius.circular(12) : null,
        ),
        child: Row(
          children: [
            // Rank bubble
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrentUser
                    ? AppColors.cyanAccent.withValues(alpha: 0.15)
                    : const Color(0xFF151A27),
                border: Border.all(
                  color: isCurrentUser
                      ? AppColors.cyanAccent.withValues(alpha: 0.5)
                      : colors.border,
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '$rank',
                style: AppTextStyles.caption.copyWith(
                  color: isCurrentUser
                      ? AppColors.cyanAccent
                      : colors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ClipOval(
              child: AvatarCircle(
                avatarKey: entry.avatar,
                size: 38,
                photoBase64: entry.photoBase64,
                photoUrl: entry.photoUrl,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.label.copyWith(
                            color: Colors.white,
                            fontWeight: isCurrentUser
                                ? FontWeight.bold
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cyanAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'leaderboard.you'.tr(),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.cyanAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Region chip below name (only in global tab)
                  if (entry.region != null)
                    _RegionChip(region: entry.region!),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${entry.totalPoints} pts',
              style: AppTextStyles.label.copyWith(
                color: const Color(0xFF9E9E9E),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _RegionChip — small location badge shown next to a user's name
// ---------------------------------------------------------------------------

class _RegionChip extends StatelessWidget {
  const _RegionChip({required this.region});

  final UzRegion region;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.location_on_rounded,
          size: 10,
          color: AppColors.purpleAccent.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 2),
        Text(
          region.displayName,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.purpleAccent.withValues(alpha: 0.7),
            fontSize: 9.5,
          ),
        ),
      ],
    );
  }
}
