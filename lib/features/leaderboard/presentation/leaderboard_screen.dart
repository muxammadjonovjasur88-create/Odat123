import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/uzbekistan_regions.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/router/nav_helpers.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/region_controller.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/widgets.dart';
import '../../clan/data/clan_repository.dart';
import '../../clan/domain/models/clan.dart';
import '../../clan/presentation/screens/clan_detail_screen.dart';
import '../../clan/presentation/widgets/clan_emblem_view.dart';
import '../../clan/presentation/widgets/create_clan_modal.dart';
import '../../friends/data/friends_repository.dart';
import '../../friends/presentation/widgets/add_friend_modal.dart';
import '../../friends/presentation/widgets/direct_chat_screen.dart';
import '../../inbox/data/inbox_repository.dart';
import '../../inbox/domain/models/app_message.dart';
import '../data/leaderboard_repository.dart';
import '../domain/leaderboard_entry.dart';
import '../domain/leaderboard_rank.dart';

// ---------------------------------------------------------------------------
// Tab enum
// ---------------------------------------------------------------------------

enum LeaderboardTab { global, region, friends, clans }

enum LeaderboardCategory {
  points, // 🏆 Umumiy Chempionlar
  ironTitans, // 🦾 Temir Tanlar (Turnik, Press, Squat, Pushup)
  marathon, // 🏃 Marafonchilar (GPS Masofa)
  wisdom, // 📚 Zukko Kitobxonlar (Mutolaa & Fokus)
  streakMasters, // 🔥 Muntazamlik (Streak)
  weeklyMomentum, // ⚡ Haftalik Tezkor O'sish
}

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
// LeaderboardScreen
// ---------------------------------------------------------------------------

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key, this.initialTab});

  final LeaderboardTab? initialTab;

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  LeaderboardTab _tab = LeaderboardTab.global;
  LeaderboardCategory _category = LeaderboardCategory.points;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;
  final TextEditingController _clanSearchController = TextEditingController();
  String _clanSearchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null) {
      _tab = widget.initialTab!;
    }
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
    _clanSearchController.dispose();
    super.dispose();
  }

  void _switchTab(LeaderboardTab tab) {
    if (tab == _tab) return;
    HapticFeedback.selectionClick();
    _fadeController.reverse().then((_) {
      if (mounted) {
        setState(() => _tab = tab);
        _fadeController.forward();
      }
    });
  }

  void _switchCategory(LeaderboardCategory cat) {
    if (cat == _category) return;
    HapticFeedback.selectionClick();
    setState(() => _category = cat);
  }

  Widget _categoryChip(String label, LeaderboardCategory cat) {
    final isSelected = _category == cat;
    return GestureDetector(
      onTap: () => _switchCategory(cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E283D) : const Color(0xFF121826),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF1E283D),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrizeChip(String rankLabel, String prizeLabel, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$rankLabel: ',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            prizeLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final profile = ref.watch(userProfileProvider).asData?.value;
    final currentUserId = ref.watch(authStateProvider).asData?.value?.uid;
    final regionState = ref.watch(regionControllerProvider);
    final currentRegion = regionState.region;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: const FlowaAppBar(
        showBackButton: false,
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: _TabBar(
                selected: _tab,
                currentRegion: currentRegion,
                onSelectTab: _switchTab,
              ),
            ),
            const SizedBox(height: 8),

            // ── Body based on selected tab ─────────────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: switch (_tab) {
                  LeaderboardTab.global || LeaderboardTab.region => _buildUserLeaderboard(
                      context, profile, currentUserId, currentRegion),
                  LeaderboardTab.friends => _buildFriendsTab(context, currentUserId),
                  LeaderboardTab.clans => _buildClansTab(context, profile),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Global & Regional Users Leaderboard
  // -------------------------------------------------------------------------
  Widget _buildUserLeaderboard(
    BuildContext context,
    UserProfile? profile,
    String? currentUserId,
    UzRegion? currentRegion,
  ) {
    final AsyncValue<List<LeaderboardEntry>> leaderboardAsync = switch (_tab) {
      LeaderboardTab.global => ref.watch(_globalLeaderboardProvider),
      _ => currentRegion != null
          ? ref.watch(_regionalLeaderboardProvider(currentRegion))
          : const AsyncData([]),
    };

    final entries = leaderboardAsync.asData?.value ?? const [];
    final sortedEntries = List<LeaderboardEntry>.from(entries);
    switch (_category) {
      case LeaderboardCategory.ironTitans:
        sortedEntries.sort((a, b) => b.pushUpCount.compareTo(a.pushUpCount));
        break;
      case LeaderboardCategory.marathon:
        sortedEntries.sort((a, b) => b.runningDistanceKm.compareTo(a.runningDistanceKm));
        break;
      case LeaderboardCategory.wisdom:
        sortedEntries.sort((a, b) => b.weeklyFocusMinutes.compareTo(a.weeklyFocusMinutes));
        break;
      case LeaderboardCategory.streakMasters:
        sortedEntries.sort((a, b) => (b.monthlyPoints).compareTo(a.monthlyPoints));
        break;
      case LeaderboardCategory.weeklyMomentum:
        sortedEntries.sort((a, b) => b.weeklyPoints.compareTo(a.weeklyPoints));
        break;
      case LeaderboardCategory.points:
        sortedEntries.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
        break;
    }
    final rankedEntries = sortedEntries;

    final isParent = (profile?.appRole == 'family' && profile?.familyRole == 'parent') || (profile?.isParent ?? false);

    LeaderboardEntry? currentUserEntry;
    if (!isParent) {
      for (final entry in rankedEntries) {
        if (entry.uid == currentUserId) {
          currentUserEntry = entry;
          break;
        }
      }
    }

    final currentRank = (isParent || currentUserEntry == null)
        ? null
        : calculateUserRank(entries: rankedEntries, uid: currentUserId ?? '');

    final displayCurrentUser = isParent
        ? null
        : (currentUserEntry ??
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
                    appRole: profile.appRole,
                    familyRole: profile.familyRole,
                  )
                : null));

    final listEntries = rankedEntries.length > 3
        ? rankedEntries.skip(3).take(47).toList()
        : <LeaderboardEntry>[];

    return Column(
      children: [
        // Smart Category Selector Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _categoryChip('🏆 ${'leaderboard_tabs.champions'.tr()}', LeaderboardCategory.points),
                const SizedBox(width: 8),
                _categoryChip('🦾 ${'leaderboard_tabs.iron_titans'.tr()}', LeaderboardCategory.ironTitans),
                const SizedBox(width: 8),
                _categoryChip('🏃 ${'leaderboard_tabs.marathon'.tr()}', LeaderboardCategory.marathon),
                const SizedBox(width: 8),
                _categoryChip('📚 Zukko Kitobxonlar', LeaderboardCategory.wisdom),
                const SizedBox(width: 8),
                _categoryChip('🔥 Streak Ustozlari', LeaderboardCategory.streakMasters),
                const SizedBox(width: 8),
                _categoryChip('⚡ Tezkor O‘sish', LeaderboardCategory.weeklyMomentum),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),

        Expanded(
          child: leaderboardAsync.when(
            loading: () => const Center(child: FlowaLoading()),
            error: (err, _) => Center(child: Text('Xatolik: $err', style: const TextStyle(color: Colors.red))),
            data: (rawList) {
              if (rankedEntries.isEmpty) {
                return const Center(
                  child: Text(
                    'Hozircha ma’lumotlar yo‘q',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }

              return RefreshIndicator(
                color: const Color(0xFF4AADDC),
                backgroundColor: const Color(0xFF090B18),
                onRefresh: () async => ref.refresh(_globalLeaderboardProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    // Podium (Top 3)
                    _Podium(
                      entries: rankedEntries.take(3).toList(),
                      currentUserId: currentUserId,
                    ),
                    const SizedBox(height: 16),

                    // Current User Floating Card
                    if (displayCurrentUser != null) ...[
                      _CurrentUserStickyCard(
                        entry: displayCurrentUser,
                        rank: currentRank,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Rest of Leaderboard list (4..50)
                    ...listEntries.asMap().entries.map((entry) {
                      final itemRank = entry.key + 4;
                      final item = entry.value;
                      return _LeaderboardRow(
                        entry: item,
                        rank: itemRank,
                        isCurrentUser: item.uid == currentUserId,
                        profile: profile,
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Friends Leaderboard Tab
  // -------------------------------------------------------------------------
  Widget _buildFriendsTab(BuildContext context, String? currentUserId) {
    final friendsAsync = ref.watch(friendsLeaderboardProvider);

    return Column(
      children: [
        // Action Banner
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0x1539FF14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x3339FF14)),
                ),
                child: Row(
                  children: [
                    const Text('👥', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'friends_ranking.weekly_banner'.tr(),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => showAddFriendModal(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3A7FCC),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: Text('friends_ranking.add_btn'.tr(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context.push(AppRoutes.communityHub),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4AADDC),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.people_outline_rounded, size: 18),
                      label: Text('community.card_title'.tr(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: friendsAsync.when(
            loading: () => const Center(child: FlowaLoading()),
            error: (e, _) => Center(child: Text('Xato: $e', style: const TextStyle(color: Colors.red))),
            data: (friendsList) {
              if (friendsList.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🤝', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        const Text(
                          'Hali do‘stlar qo‘shilmagan',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Do‘stlaringizni taklif qiling va ularning natijalari bilan bellashing!',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => showAddFriendModal(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3A7FCC),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.person_add_rounded),
                          label: Text('friends.search_invite'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final nonSelfFriends = friendsList.where((f) => f.uid != currentUserId).toList();
              if (nonSelfFriends.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🤝', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        const Text(
                          'Hali do‘stlar qo‘shilmagan',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Do‘stlaringizni taklif qiling va ularning natijalari bilan bellashing!',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => showAddFriendModal(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3A7FCC),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.person_add_rounded),
                          label: Text('friends.search_invite'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: nonSelfFriends.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final entry = nonSelfFriends[index];
                  return _LeaderboardRow(
                    entry: entry,
                    rank: index + 1,
                    isCurrentUser: false,
                    profile: null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Clans Leaderboard Tab
  // -------------------------------------------------------------------------
  Widget _buildClansTab(BuildContext context, UserProfile? profile) {
    final clansAsync = ref.watch(topClansProvider);
    final myClan = ref.watch(userClanProvider).asData?.value;

    return Column(
      children: [

        // Search Bar for Clans
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _clanSearchController,
            onChanged: (val) => setState(() => _clanSearchQuery = val.trim().toLowerCase()),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'clan.search_hint'.tr(),
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF4AADDC), size: 20),
              suffixIcon: _clanSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                      onPressed: () {
                        _clanSearchController.clear();
                        setState(() => _clanSearchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF090B18),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0x22FFFFFF))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0x22FFFFFF))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4AADDC))),
            ),
          ),
        ),

        if (myClan == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => showCreateClanModal(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4AADDC),
                  foregroundColor: Colors.black,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.shield_rounded, size: 18),
                label: Text('clan.create_new_clan_btn'.tr(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),
              ),
            ),
          ),

        Expanded(
          child: clansAsync.when(
            loading: () => const Center(child: FlowaLoading()),
            error: (e, _) => Center(child: Text('Xato: $e', style: const TextStyle(color: Colors.red))),
            data: (clansList) {
              // Merge userClan if not present
              final mergedList = List<Clan>.from(clansList);
              if (myClan != null && !mergedList.any((c) => c.id == myClan.id)) {
                mergedList.insert(0, myClan);
              }

              // Filter by query
              final filteredList = _clanSearchQuery.isEmpty
                  ? mergedList
                  : mergedList.where((c) {
                      final nameMatch = c.name.toLowerCase().contains(_clanSearchQuery);
                      final tagMatch = c.tag.toLowerCase().contains(_clanSearchQuery);
                      final descMatch = c.description.toLowerCase().contains(_clanSearchQuery);
                      return nameMatch || tagMatch || descMatch;
                    }).toList();

              if (filteredList.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🏰', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          _clanSearchQuery.isNotEmpty ? 'Qidiruv bo‘yicha klan topilmadi' : 'Hali klanlar yaratilmagan',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _clanSearchQuery.isNotEmpty
                              ? 'Boshqa kalit so‘z orqali qidirib ko‘ring'
                              : 'Birinchi bo‘lib o‘z klaningizni oching va do‘stlaringizni taklif qiling!',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        if (_clanSearchQuery.isEmpty) ...[
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => showCreateClanModal(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4AADDC),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.shield_rounded),
                            label: Text('leaderboard.create_first_clan'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: filteredList.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final clan = filteredList[index];
                  final isMyClan = clan.memberUids.contains(profile?.uid) || clan.id == myClan?.id;
                  return _ClanCard(
                    clan: clan,
                    rank: index + 1,
                    isMyClan: isMyClan,
                    user: profile,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _ClanCard Widget
// ---------------------------------------------------------------------------

class _ClanCard extends ConsumerWidget {
  const _ClanCard({
    required this.clan,
    required this.rank,
    required this.isMyClan,
    required this.user,
  });

  final Clan clan;
  final int rank;
  final bool isMyClan;
  final UserProfile? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color rankColor;
    if (rank == 1) {
      rankColor = const Color(0xFFFFB703);
    } else if (rank == 2) {
      rankColor = const Color(0xFFB0BEC5);
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32);
    } else {
      rankColor = Colors.white54;
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => ClanDetailScreen(clan: clan)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isMyClan ? const Color(0xFF111E36) : const Color(0xFF090B18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isMyClan ? const Color(0xFF4AADDC) : const Color(0x22FFFFFF),
            width: isMyClan ? 1.5 : 1,
          ),
          boxShadow: isMyClan
              ? [
                  BoxShadow(
                    color: const Color(0xFF4AADDC).withValues(alpha: 0.15),
                    blurRadius: 16,
                  )
                ]
              : null,
        ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: rankColor.withValues(alpha: 0.5)),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Emblem
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0x22FFFFFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: ClanEmblemView(emblem: clan.emblem, size: 28),
            ),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      clan.formattedTag,
                      style: const TextStyle(
                        color: Color(0xFF4AADDC),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        clan.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${'clan.leader'.tr()} ${clan.leaderName} · 👥 ${clan.membersCount} ${'clan.members'.tr()}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Points & Action
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${clan.formattedPoints} PTS',
                style: const TextStyle(
                  color: Color(0xFFFFB703),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              if (user != null)
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    if (isMyClan) {
                      await ref.read(clanRepositoryProvider).leaveClan(clanId: clan.id, user: user!);
                    } else {
                      await ref.read(clanRepositoryProvider).joinClan(clanId: clan.id, user: user!);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isMyClan ? const Color(0x33FF0055) : const Color(0x334AADDC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isMyClan ? const Color(0xFFFF0055) : const Color(0xFF4AADDC),
                      ),
                    ),
                    child: Text(
                      isMyClan ? 'clan.leave'.tr() : 'clan.join'.tr(),
                      style: TextStyle(
                        color: isMyClan ? const Color(0xFFFF0055) : const Color(0xFF4AADDC),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TabBar Widget
// ---------------------------------------------------------------------------

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.selected,
    required this.currentRegion,
    required this.onSelectTab,
  });

  final LeaderboardTab selected;
  final UzRegion? currentRegion;
  final ValueChanged<LeaderboardTab> onSelectTab;

  Widget _tabItem(String label, LeaderboardTab tab, IconData icon) {
    final isSelected = selected == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelectTab(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1B2335) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? Border.all(color: const Color(0xFF222B40)) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFF8FAFC) : const Color(0xFF94A3B8),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF121826),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E283D)),
      ),
      child: Row(
        children: [
          _tabItem('leaderboard_tabs.global'.tr(), LeaderboardTab.global, Icons.public_rounded),
          _tabItem(currentRegion?.localizedName(context.locale.languageCode) ?? 'regions.regions'.tr(), LeaderboardTab.region, Icons.location_on_rounded),
          _tabItem('leaderboard_tabs.friends'.tr(), LeaderboardTab.friends, Icons.people_alt_rounded),
          _tabItem('leaderboard_tabs.clans'.tr(), LeaderboardTab.clans, Icons.shield_rounded),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _Podium
// ---------------------------------------------------------------------------

class _Podium extends StatelessWidget {
  const _Podium({
    required this.entries,
    required this.currentUserId,
  });

  final List<LeaderboardEntry> entries;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place
          Expanded(
            child: second != null
                ? _PodiumSlot(
                    entry: second,
                    rank: 2,
                    pedestalHeight: 85,
                    accentColor: const Color(0xFFB0BEC5),
                    isCurrentUser: second.uid == currentUserId,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),

          // 1st Place (Center, tallest)
          Expanded(
            child: first != null
                ? _PodiumSlot(
                    entry: first,
                    rank: 1,
                    pedestalHeight: 110,
                    accentColor: const Color(0xFFFFB703),
                    isCurrentUser: first.uid == currentUserId,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),

          // 3rd Place
          Expanded(
            child: third != null
                ? _PodiumSlot(
                    entry: third,
                    rank: 3,
                    pedestalHeight: 70,
                    accentColor: const Color(0xFFCD7F32),
                    isCurrentUser: third.uid == currentUserId,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({
    required this.entry,
    required this.rank,
    required this.pedestalHeight,
    required this.accentColor,
    required this.isCurrentUser,
  });

  final LeaderboardEntry entry;
  final int rank;
  final double pedestalHeight;
  final Color accentColor;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showUserDetailSheet(context, entry),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar with crown / medal
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: AvatarCircle(
                    avatarKey: entry.avatar,
                    size: rank == 1 ? 52 : 44,
                    photoBase64: entry.photoBase64,
                    photoUrl: entry.photoUrl,
                  ),
                ),
              ),
              Positioned(
                top: -12,
                child: Text(
                  rank == 1 ? '👑' : rank == 2 ? '🥈' : '🥉',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Name
          Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: rank == 1 ? 13 : 11.5,
            ),
          ),
          const SizedBox(height: 2),

          // Points
          Text(
            '${formatCompactNumber(entry.totalPoints)} PTS',
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),

          // Pedestal
          Container(
            width: double.infinity,
            height: pedestalHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  accentColor.withValues(alpha: 0.25),
                  accentColor.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$rank',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: rank == 1 ? 26 : 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 0.8),
                    ),
                    child: Text(
                      rank == 1
                          ? '💻 Noutbuk'
                          : rank == 2
                              ? '📱 Smartfon'
                              : '💵 500k so‘m',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: rank == 1 ? 9.5 : (rank == 2 ? 9 : 8.5),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CurrentUserStickyCard
// ---------------------------------------------------------------------------

class _CurrentUserStickyCard extends StatelessWidget {
  const _CurrentUserStickyCard({
    required this.entry,
    required this.rank,
  });

  final LeaderboardEntry entry;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x334AADDC), Color(0x3339FF14)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4AADDC), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x224AADDC),
            blurRadius: 14,
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
                  '${entry.name} (${'leaderboard_tabs.you'.tr()})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '⚡ ${formatCompactNumber(entry.totalPoints)} PTS',
                  style: const TextStyle(
                    color: Color(0xFF4AADDC),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF4AADDC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              rank == null ? 'TOP 50+' : '#$rank',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 12,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showUserDetailSheet(context, entry),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isCurrentUser
                ? const Color(0x224AADDC)
                : const Color(0xFF090B18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCurrentUser
                  ? const Color(0x664AADDC)
                  : const Color(0x15FFFFFF),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF090B18),
                  border: Border.all(color: Colors.white12),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Stack(
                children: [
                  ClipOval(
                    child: AvatarCircle(
                      avatarKey: entry.avatar,
                      size: 38,
                      photoBase64: entry.photoBase64,
                      photoUrl: entry.photoUrl,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: entry.isOnline ? const Color(0xFF3A7FCC) : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF090B18), width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.region != null)
                      Text(
                        '📍 ${entry.region!.displayName}',
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${formatCompactNumber(entry.totalPoints)} PTS',
                    style: const TextStyle(
                      color: Color(0xFFFFB703),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  if (rank == 4)
                    _buildRowPrizeBadge('🎧 Quloqchin', const Color(0xFF4AADDC))
                  else if (rank == 5)
                    _buildRowPrizeBadge('👕 Futbolka', const Color(0xFF3A7FCC))
                  else if (rank == 6)
                    _buildRowPrizeBadge('☕ Bakal', const Color(0xFFFF0055))
                  else if (rank == 7)
                    _buildRowPrizeBadge('⌚ Qo‘l soati', const Color(0xFFFFCC00)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildRowPrizeBadge(String title, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// Shows user profile detail, friend request, direct messaging, and 1v1 battle challenge modal
void _showUserDetailSheet(BuildContext context, LeaderboardEntry entry) {
  HapticFeedback.lightImpact();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Consumer(
      builder: (context, ref, _) {
        final myProfile = ref.watch(userProfileProvider).asData?.value;
        final isSelf = myProfile?.uid == entry.uid;

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          decoration: const BoxDecoration(
            color: Color(0xFF090B18),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Color(0xFF4AADDC), width: 1.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              AvatarCircle(
                avatarKey: entry.avatar,
                size: 64,
                photoBase64: entry.photoBase64,
                photoUrl: entry.photoUrl,
              ),
              const SizedBox(height: 10),
              Text(
                entry.name,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              if (entry.region != null)
                Text(
                  '📍 ${entry.region!.displayName}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              const SizedBox(height: 16),

              // Mini Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statBadge('⚡ Jami Ballar', '${formatCompactNumber(entry.totalPoints)} PTS', const Color(0xFFFFB703)),
                  _statBadge('🏃 Yugurish', '${entry.runningDistanceKm.toStringAsFixed(1)} KM', const Color(0xFF4AADDC)),
                  _statBadge('💪 Mashq', '${entry.pushUpCount}', const Color(0xFF3A7FCC)),
                ],
              ),
              const SizedBox(height: 20),

              if (!isSelf && myProfile != null) ...[
                // Check if already friends
                Builder(
                  builder: (context) {
                    final friendsList = ref.watch(friendsLeaderboardProvider).asData?.value ?? [];
                    final isFriend = friendsList.any((f) => f.uid == entry.uid);

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Send Direct Message Button
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DirectChatScreen(
                                    myUid: myProfile.uid,
                                    myName: myProfile.name,
                                    myAvatar: myProfile.avatar,
                                    friendUid: entry.uid,
                                    friendName: entry.name,
                                    friendAvatar: entry.avatar,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0088CC),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: Text('Xabar yozish (${entry.name})', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Add or Remove Friend Button
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: isFriend
                              ? OutlinedButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    try {
                                      await ref.read(friendsRepositoryProvider).removeFriend(myProfile.uid, entry.uid);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: const Color(0xFFFF0055),
                                            content: Text('${entry.name} do‘stlar safidan o‘chirildi.'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(backgroundColor: const Color(0xFFFF0055), content: Text('$e')),
                                        );
                                      }
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFFF4444),
                                    side: const BorderSide(color: Color(0xFFFF4444), width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  icon: const Icon(Icons.person_remove_rounded, size: 18),
                                  label: Text('friends.unfriend'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                )
                              : OutlinedButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    try {
                                      await ref.read(friendsRepositoryProvider).addFriend(myProfile.uid, entry.uid);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: const Color(0xFF3A7FCC),
                                            content: Text('🤝 ${entry.name} do‘stlar safiga qo‘shildi!'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(backgroundColor: const Color(0xFFFF0055), content: Text('$e')),
                                        );
                                      }
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF3A7FCC),
                                    side: const BorderSide(color: Color(0xFF3A7FCC), width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                                  label: Text('friends.send_request'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),

                // 1v1 Battle Challenge
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push(AppRoutes.battle);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF0055),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.sports_martial_arts_rounded, size: 18),
                    label: Text('friends.challenge_1v1'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

Widget _statBadge(String label, String value, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF090B18),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Column(
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
      ],
    ),
  );
}

void _showDirectMessageDialog(
  BuildContext context,
  WidgetRef ref,
  UserProfile me,
  LeaderboardEntry target,
) {
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF090B18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF0088CC)),
      ),
      title: Row(
        children: [
          const Icon(Icons.mail_outline_rounded, color: Color(0xFF0088CC)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${target.name}ga xabar',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Xabaringizni yozing...',
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: const Color(0xFF090B18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('common.cancel'.tr(), style: const TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: () {
            final text = controller.text.trim();
            if (text.isEmpty) return;
            Navigator.pop(ctx);

            ref.read(inboxRepositoryProvider.notifier).addMessage(
              AppMessage(
                id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
                title: '${me.name} (Siz) -> ${target.name}',
                body: text,
                type: MessageType.friend,
                icon: '💬',
                createdAt: DateTime.now(),
                isRead: true,
              ),
            );

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF0088CC),
                content: Text('Xabar ${target.name}ga yuborildi! ✉️'),
              ),
            );
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0088CC)),
          child: Text('common.send'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}
