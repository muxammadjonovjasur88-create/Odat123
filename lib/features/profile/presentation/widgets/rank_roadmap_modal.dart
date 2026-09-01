import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/player_level.dart';
import '../../../../core/models/rank_tier.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/services/user_repository.dart';

/// Shows the Interactive Neon Rank & 1-100 Levels Progression Roadmap Modal
Future<void> showRankRoadmapModal(BuildContext context, {int initialTab = 0}) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _RankRoadmapSheet(initialTab: initialTab),
  );
}

class _RankRoadmapSheet extends ConsumerStatefulWidget {
  const _RankRoadmapSheet({this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<_RankRoadmapSheet> createState() => _RankRoadmapSheetState();
}

class _RankRoadmapSheetState extends ConsumerState<_RankRoadmapSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _locallyClaimedLevels = {};
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).asData?.value;
    final currentPoints = user?.totalPoints ?? 0;
    final battleWins = user?.battleWins ?? 0;
    final currentTier = RankTier.fromWinsAndPoints(
      battleWins: battleWins,
      points: currentPoints,
    );
    final currentLevel = PlayerLevel.fromTotalPts(currentPoints);
    final allTiers = RankTier.allTiers;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF080B14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: Color(0xFF5BC8FA), width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: currentTier.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: currentTier.color),
                ),
                child: Icon(currentTier.iconData, color: currentTier.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'roadmap.title'.tr(),
                      style: const TextStyle(
                        color: Color(0xFF5BC8FA),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      '${currentTier.localizedName} ($currentPoints PTS • $battleWins G‘alaba)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white60),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tabs
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF5BC8FA),
            indicatorWeight: 3,
            labelColor: const Color(0xFF5BC8FA),
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              const Tab(text: 'Unvonlar (Tiers)'),
              Tab(text: 'Darajalar (${currentLevel.level}/100)'),
            ],
          ),
          const SizedBox(height: 12),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Unvonlar
                ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: allTiers.length,
                  itemBuilder: (context, index) {
                    final step = allTiers[index];
                    final isReached = battleWins >= step.requiredWins || currentPoints >= step.minPoints;
                    final isCurrent = currentTier == step;
                    final winsNeededForNext = step.winsNeeded(battleWins);

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timeline Line & Node
                        Column(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCurrent
                                    ? step.color
                                    : isReached
                                        ? step.color.withValues(alpha: 0.3)
                                        : const Color(0xFF131929),
                                border: Border.all(
                                  color: isReached ? step.color : Colors.white24,
                                  width: isCurrent ? 2.5 : 1.5,
                                ),
                                boxShadow: isCurrent
                                    ? [
                                        BoxShadow(
                                          color: step.color.withValues(alpha: 0.6),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: isReached
                                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                                    : const Icon(Icons.lock_rounded, color: Colors.white30, size: 14),
                              ),
                            ),
                            if (index < allTiers.length - 1)
                              Container(
                                width: 2.5,
                                height: 65,
                                color: isReached
                                    ? step.color.withValues(alpha: 0.5)
                                    : Colors.white10,
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),

                        // Tier Card
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? step.color.withValues(alpha: 0.15)
                                  : const Color(0xFF0D1220),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isCurrent
                                    ? step.color
                                    : isReached
                                        ? step.color.withValues(alpha: 0.4)
                                        : Colors.white10,
                                width: isCurrent ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: step.color.withValues(alpha: 0.18),
                                          ),
                                          child: Icon(step.iconData, color: step.color, size: 16),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          step.localizedName,
                                          style: TextStyle(
                                            color: isReached ? Colors.white : Colors.white54,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: step.color.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        step.requiredWins == 0
                                            ? 'Boshlang‘ich'
                                            : '${step.requiredWins} ta G‘alaba',
                                        style: TextStyle(
                                          color: step.color,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  step.description,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11.5,
                                  ),
                                ),
                                if (isCurrent && winsNeededForNext > 0) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Keyingi unvonga: $winsNeededForNext ta g‘alaba qoldi ⚔️',
                                    style: const TextStyle(
                                      color: Color(0xFF3B9BFF),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // Tab 2: 1-100 Darajalar
                _buildLevelsList(currentPoints, currentLevel.level, user),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _claimLevelReward(int levelNum, PlayerLevel levelInfo, UserProfile user) async {
    final badgeKey = 'lvl_reward_$levelNum';
    if (user.claimedBadges.contains(badgeKey) || _locallyClaimedLevels.contains(badgeKey) || _isClaiming) {
      return;
    }

    setState(() => _isClaiming = true);
    HapticFeedback.heavyImpact();

    try {
      final userRepo = ref.read(userRepositoryProvider);
      if (levelInfo.rewardCoins > 0) {
        await userRepo.addFenixCoins(user.uid, levelInfo.rewardCoins);
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'claimedBadges': FieldValue.arrayUnion([badgeKey]),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('coins_history')
          .add({
        'title': '⭐ $levelNum-Daraja Mukofoti',
        'category': 'Daraja bonusi',
        'amount': levelInfo.rewardCoins,
        'points': levelInfo.rewardCoins,
        'type': 'earn',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _locallyClaimedLevels.add(badgeKey));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF3B9BFF),
            content: Text('$levelNum-Daraja mukofoti olindi: +${levelInfo.rewardCoins} Fenix Coin! 🎉',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
          ),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  Future<void> _claimAllEligibleLevels(int currentLvl, UserProfile user) async {
    if (_isClaiming) return;
    setState(() => _isClaiming = true);
    HapticFeedback.heavyImpact();

    int totalCoins = 0;
    final List<String> newlyClaimed = [];

    try {
      for (int i = 1; i <= currentLvl; i++) {
        final badgeKey = 'lvl_reward_$i';
        if (!user.claimedBadges.contains(badgeKey) && !_locallyClaimedLevels.contains(badgeKey)) {
          final levelInfo = PlayerLevel.forLevel(i);
          totalCoins += levelInfo.rewardCoins;
          newlyClaimed.add(badgeKey);
        }
      }

      if (newlyClaimed.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF131929),
              content: Text('profile.all_rank_rewards_claimed'.tr()),
            ),
          );
        }
        return;
      }

      final userRepo = ref.read(userRepositoryProvider);
      if (totalCoins > 0) await userRepo.addFenixCoins(user.uid, totalCoins);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'claimedBadges': FieldValue.arrayUnion(newlyClaimed),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('coins_history')
          .add({
        'title': '⭐ Barcha Darajalar Mukofoti (${newlyClaimed.length} ta)',
        'category': 'Daraja bonusi',
        'amount': totalCoins,
        'points': totalCoins,
        'type': 'earn',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _locallyClaimedLevels.addAll(newlyClaimed));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF3B9BFF),
            content: Text('${newlyClaimed.length} ta daraja mukofoti olindi: +$totalCoins Fenix Coin! 🚀',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
          ),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  Widget _buildLevelsList(int currentPoints, int currentLvl, UserProfile? user) {
    int unclaimedCount = 0;
    if (user != null) {
      for (int i = 1; i <= currentLvl; i++) {
        final badgeKey = 'lvl_reward_$i';
        if (!user.claimedBadges.contains(badgeKey) && !_locallyClaimedLevels.contains(badgeKey)) {
          unclaimedCount++;
        }
      }
    }

    return Column(
      children: [
        if (unclaimedCount > 0 && user != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => _claimAllEligibleLevels(currentLvl, user),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5BC8FA), Color(0xFF3B9BFF)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3300FF88),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.card_giftcard_rounded, color: Colors.black, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'HAMMASINI OLISH ($unclaimedCount TA MUKOFOT) 🎁',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: 100,
            itemBuilder: (context, index) {
              final levelNum = index + 1;
              final levelInfo = PlayerLevel.forLevel(levelNum);
              final isReached = currentLvl >= levelNum;
              final isCurrent = currentLvl == levelNum;
              final badgeKey = 'lvl_reward_$levelNum';
              final isClaimed = (user?.claimedBadges.contains(badgeKey) ?? false) ||
                  _locallyClaimedLevels.contains(badgeKey);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0x225BC8FA)
                      : const Color(0xFF0D1220),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCurrent
                        ? const Color(0xFF5BC8FA)
                        : isReached
                            ? const Color(0x4400FF88)
                            : Colors.white10,
                    width: isCurrent ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isReached
                            ? levelInfo.color.withValues(alpha: 0.2)
                            : const Color(0xFF151D2F),
                        border: Border.all(
                          color: isReached ? levelInfo.color : Colors.white24,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$levelNum',
                          style: TextStyle(
                            color: isReached ? Colors.white : Colors.white38,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${levelInfo.badgeIcon} ${levelInfo.title}',
                                style: TextStyle(
                                  color: isReached ? Colors.white : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              if (isCurrent) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5BC8FA),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'HOZIRGI',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Talab: ${levelInfo.minPts} PTS',
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isReached && user != null) ...[
                      if (isClaimed) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0x2200FF88),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, color: Color(0xFF3B9BFF), size: 13),
                              SizedBox(width: 4),
                              Text(
                                'Olingan',
                                style: TextStyle(
                                  color: Color(0xFF3B9BFF),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        ElevatedButton(
                          onPressed: () => _claimLevelReward(levelNum, levelInfo, user),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B9BFF),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            '+${levelInfo.rewardPts} ⚡',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                          ),
                        ),
                      ],
                    ] else ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bolt_rounded, color: Color(0xFF5BC8FA), size: 13),
                              Text(
                                '+${levelInfo.rewardPts} PTS',
                                style: const TextStyle(
                                  color: Color(0xFF5BC8FA),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFB703), size: 13),
                              Text(
                                '+${levelInfo.rewardCoins} Coin',
                                style: const TextStyle(
                                  color: Color(0xFFFFB703),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
