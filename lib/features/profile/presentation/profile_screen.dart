import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/player_level.dart';
import '../../../core/models/rank_tier.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/router/nav_helpers.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/locale_store.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/widgets/widgets.dart';
import '../../clan/data/clan_repository.dart';
import '../../clan/domain/models/clan.dart';
import '../../clan/presentation/screens/clan_detail_screen.dart';
import '../../clan/presentation/widgets/create_clan_modal.dart';
import '../../friends/data/friends_repository.dart';
import '../../friends/presentation/widgets/add_friend_modal.dart';
import '../../friends/presentation/widgets/direct_chat_screen.dart';
import '../../inbox/data/inbox_repository.dart';
import '../../inbox/presentation/widgets/inbox_modal.dart';
import 'widgets/badges_modal.dart';
import 'widgets/bug_bounty_modal.dart';
import 'widgets/coins_history_modal.dart';
import 'widgets/inventory_modal.dart';
import 'widgets/pts_history_modal.dart';
import 'widgets/rank_roadmap_modal.dart';

extension _ProfileTr on String {
  String trFallback(String fallback, {Map<String, String>? namedArgs}) {
    final val = tr(this, namedArgs: namedArgs);
    if (val == this || val.startsWith('profile.')) {
      return fallback;
    }
    return val;
  }
}

/// Redesigned Zen Kinetic Cyberpunk Profile Screen for ODAT.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _showLanguageDialog() async {
    final currentCode = LocaleStore.effectiveCode();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF090B18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x334AADDC)),
        ),
        title: Row(
          children: [
            const Icon(Icons.language_rounded, color: Color(0xFF4AADDC)),
            const SizedBox(width: 10),
            Text(
              'language.title'.tr(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: kSupportedLocales.map((loc) {
            final isSelected = loc.languageCode == currentCode;
            return ListTile(
              onTap: () async {
                await context.setLocale(loc);
                await LocaleStore.save(loc.languageCode);
                if (context.mounted) Navigator.pop(context);
              },
              leading: Text(
                loc.languageCode == 'uz' ? '🇺🇿' : loc.languageCode == 'ru' ? '🇷🇺' : '🇬🇧',
                style: const TextStyle(fontSize: 22),
              ),
              title: Text(
                localeNativeName(loc.languageCode),
                style: TextStyle(
                  color: isSelected ? const Color(0xFF4AADDC) : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF4AADDC))
                  : null,
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF090B18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x44FF0055)),
        ),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Color(0xFFFF0055)),
            const SizedBox(width: 10),
            Text('profile.logout_confirm_title'.tr(), style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'profile.logout_confirm_msg'.tr(),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr(), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF0055)),
            child: Text('profile.logout'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(authRepositoryProvider).signOut();
      if (mounted) context.go(AppRoutes.welcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).asData?.value;
    final userClan = ref.watch(userClanProvider).asData?.value;
    final friends = ref.watch(friendsLeaderboardProvider).asData?.value ?? [];

    if (profile == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF04050D),
        body: Center(child: FlowaLoading()),
      );
    }

    final rankTier = RankTier.fromWinsAndPoints(
      battleWins: profile.battleWins,
      points: profile.totalPoints,
    );
    final progress = rankTier.progress(profile.totalPoints);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      bottomNavigationBar: AppBottomNav(
        current: AppNavTab.profile,
        onSelected: (tab) => goToTab(context, tab),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
          children: [
            // Top App Bar with Messages Badge
            _buildTopBar(profile),
            const SizedBox(height: 16),

            // Hero Profile Card
            _buildHeroProfileCard(profile, rankTier, progress),
            const SizedBox(height: 16),

            // Matrix Stats Grid (PTS, Coins, Streak, Distance, Battles)
            _buildStatsMatrix(profile),
            const SizedBox(height: 16),

            // Qo'shimcha Menyu (Settings style list)
            _buildUnifiedSettingsMenu(friends.length),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedSettingsMenu(int friendsCount) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121826),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E283D)),
      ),
      child: Column(
        children: [
          // Wallet & Premium
          ListTile(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push(AppRoutes.wallet);
            },
            leading: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFF59E0B)),
            title: Text('profile.premium_title'.trFallback('ODAT Premium'), style: const TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.bold, fontSize: 13)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF64748B), size: 13),
          ),
          const Divider(color: Color(0xFF1E283D), height: 1),
          // Badges
          ListTile(
            onTap: () {
              HapticFeedback.lightImpact();
              showBadgesModal(context);
            },
            leading: const Icon(Icons.military_tech_rounded, color: Color(0xFF6B25CC)),
            title: Text('profile.badges_title'.trFallback('Nishonlar & Yutuqlar'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 14),
          ),

          const Divider(color: Colors.white10, height: 1),
          // Friends
          ListTile(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('${AppRoutes.leaderboard}?tab=friends');
            },
            leading: const Icon(Icons.people_alt_rounded, color: Color(0xFF3A7FCC)),
            title: Text('profile.friends_title'.trFallback('Do‘stlar: $friendsCount ta'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _showFriendsChatModal(context),
                  icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF3A7FCC), size: 18),
                  tooltip: 'Chat',
                ),
                IconButton(
                  onPressed: () => showAddFriendModal(context),
                  icon: const Icon(Icons.person_add_rounded, color: Color(0xFF3A7FCC), size: 18),
                  tooltip: 'Qo‘shish',
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          // Bug Bounty
          ListTile(
            onTap: () => showBugBountyModal(context),
            leading: const Icon(Icons.pest_control_rounded, color: Color(0xFFFFB703)),
            title: Text('bug_bounty.title'.trFallback('Bug Bounty Dasturi'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            trailing: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('+4000 PTS', style: TextStyle(color: Color(0xFF3A7FCC), fontWeight: FontWeight.w900, fontSize: 11)),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 14),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          // Suggestions
          ListTile(
            onTap: () async {
              HapticFeedback.lightImpact();
              final uri = Uri.parse('https://t.me/salomov_2502');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            leading: const Text('💡', style: TextStyle(fontSize: 18)),
            title: Text('profile.suggestions_btn'.trFallback('Takliflaringiz (@salomov_2502)'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            trailing: const Icon(Icons.send_rounded, color: Color(0xFF4AADDC), size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(UserProfile profile) {
    final unreadCount = ref.watch(unreadMessagesCountProvider);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4AADDC), Color(0xFF3A7FCC)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'profile.header_title'.trFallback('ODAT PROFIL'),
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const Spacer(),
        // Messages Inbox Button
        Stack(
          children: [
            IconButton(
              tooltip: 'profile.tooltip_messages'.trFallback('Xabarlar'),
              icon: const Icon(Icons.mail_outline_rounded, color: Color(0xFF4AADDC), size: 22),
              onPressed: () => showInboxModal(context),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF0055),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        IconButton(
          tooltip: 'profile.tooltip_language'.trFallback('Tilni o‘zgartirish'),
          icon: const Icon(Icons.language_rounded, color: Color(0xFF4AADDC), size: 22),
          onPressed: _showLanguageDialog,
        ),
        IconButton(
          tooltip: 'profile.tooltip_settings'.trFallback('Sozlamalar'),
          icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 22),
          onPressed: () => _showSettingsModal(context, profile),
        ),
      ],
    );
  }

  Widget _buildHeroProfileCard(UserProfile profile, RankTier tier, double progress) {
    final playerLevel = PlayerLevel.fromTotalPts(profile.totalPoints);
    final levelProgress = ((profile.totalPoints - playerLevel.minPts) /
            (playerLevel.maxPts - playerLevel.minPts).clamp(1, 999999))
        .clamp(0.0, 1.0);

    return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF121826),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF1E283D), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar + Info Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  GestureDetector(
                    onTap: () => _showEditProfileModal(context, profile),
                    child: Stack(
                      children: [
                        AvatarCircle(
                          avatarKey: profile.avatar,
                          photoUrl: profile.photoUrl,
                          photoBase64: profile.photoBase64,
                          size: 72,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF4AADDC),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.black, size: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Name, ID & Badges
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                profile.displayName ?? profile.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Numeric ID Badge (Clickable to copy)
                        GestureDetector(
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            await Clipboard.setData(ClipboardData(text: profile.numericId));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('ID nusxalandi: ${profile.numericId}'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0x224AADDC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'ID: ${profile.numericId}',
                                  style: const TextStyle(
                                    color: Color(0xFF4AADDC),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.copy_rounded, color: Color(0xFF4AADDC), size: 11),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Level 1-100 Badge & Rank Tier Badge Row
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            // 1. Level 1-100 Badge (Opens Level Roadmap)
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                showRankRoadmapModal(context, initialTab: 1);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: playerLevel.color.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: playerLevel.color.withValues(alpha: 0.7)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(playerLevel.badgeIcon, style: const TextStyle(fontSize: 11.5)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${playerLevel.level}-DARAJA',
                                      style: TextStyle(
                                        color: playerLevel.color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // 2. Competitive Rank Tier badge (Opens Unvonlar Tab 0 in Rank Roadmap modal)
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                showRankRoadmapModal(context, initialTab: 0);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: tier.color.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: tier.color.withValues(alpha: 0.6)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(tier.icon, style: const TextStyle(fontSize: 11.5)),
                                    const SizedBox(width: 4),
                                    Text(
                                      tier.localizedName.toUpperCase(),
                                      style: TextStyle(
                                        color: tier.color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(Icons.arrow_forward_ios_rounded, size: 8, color: tier.color),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Level XP Progress Bar
              GestureDetector(
                onTap: () => showRankRoadmapModal(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '⭐ ${playerLevel.level}-Daraja (${playerLevel.title})',
                          style: TextStyle(color: playerLevel.color, fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          '${profile.totalPoints} / ${playerLevel.maxPts} PTS',
                          style: TextStyle(color: playerLevel.color, fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: levelProgress,
                        minHeight: 8,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation(playerLevel.color),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          playerLevel.level < 100
                              ? 'Keyingi darajaga: ${playerLevel.maxPts - profile.totalPoints} PTS kerak'
                              : 'Maksimal 100-daraja zabt etildi! ⚡',
                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                        Text(
                          '+${playerLevel.rewardCoins} 🪙  +${playerLevel.rewardPts} ⚡',
                          style: const TextStyle(color: Color(0xFFFFB703), fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
  }

  Widget _buildClanCard(UserProfile profile, Clan? clan) {
    final hasClan = clan != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          if (hasClan) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ClanDetailScreen(clan: clan)),
            );
          } else {
            context.push('${AppRoutes.leaderboard}?tab=clans');
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF090B18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasClan ? const Color(0xFF4AADDC) : const Color(0x22FFFFFF),
              width: hasClan ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0x22FFFFFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: hasClan
                      ? Text(clan.emblem, style: const TextStyle(fontSize: 22))
                      : const Icon(Icons.shield_rounded, color: Colors.white54, size: 24),
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
                          hasClan ? clan.formattedTag : 'profile.clan_none'.trFallback('KLANSIZ'),
                          style: TextStyle(
                            color: hasClan ? const Color(0xFF4AADDC) : Colors.white54,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            hasClan ? clan.name : 'profile.clan_not_member'.trFallback('Hali klanga a‘zo emassiz'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasClan
                          ? '⚡ ${clan.formattedPoints} PTS · 👥 ${'profile.clan_members'.trFallback('${clan.membersCount} a‘zo', namedArgs: {'count': clan.membersCount.toString()})}'
                          : 'profile.clan_hint'.trFallback('Klan oching yoki mavjud klanga qo‘shiling'),
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  if (hasClan) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ClanDetailScreen(clan: clan)),
                    );
                  } else {
                    showCreateClanModal(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasClan ? const Color(0x224AADDC) : const Color(0xFF4AADDC),
                  foregroundColor: hasClan ? const Color(0xFF4AADDC) : Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  hasClan ? 'profile.clan_enter'.trFallback('Klanga Kirish') : 'profile.clan_create'.trFallback('Klan Ochish'),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsMatrix(UserProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Action Row: Full-width Inventory
        GestureDetector(
          onTap: () => showInventoryModal(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFF121826),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E283D), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.backpack_rounded, color: Color(0xFF38BDF8), size: 18),
                const SizedBox(width: 8),
                Text(
                  'profile.inventory_title'.trFallback('Inventar'),
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'profile.main_metrics'.trFallback('Asosiy metrikalar'),
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.8,
          children: [
            _statItem(
              title: 'profile.streak'.trFallback('Streak'),
              value: '${profile.streak} ${'profile.days_unit'.trFallback('kun')} 🔥',
              icon: Icons.local_fire_department_rounded,
              color: const Color(0xFFF59E0B),
            ),
            _statItem(
              title: 'profile.freezes'.trFallback('Muzlatgich'),
              value: '${profile.freezes} ❄️',
              icon: Icons.ac_unit_rounded,
              color: const Color(0xFF38BDF8),
              onTap: () => showInventoryModal(context),
            ),
            _statItem(
              title: 'Qat‘iy Intizom',
              value: '${(profile.totalFocusMinutes / 60).toStringAsFixed(1)} soat',
              icon: Icons.timer_rounded,
              color: const Color(0xFF60A5FA),
            ),
            _statItem(
              title: '1v1 Winrate',
              value: '${profile.winratePercent}% (${profile.battleWins}W/${profile.battleLosses}L)',
              icon: Icons.sports_martial_arts_rounded,
              color: const Color(0xFFF43F5E),
              onTap: () {
                HapticFeedback.lightImpact();
                context.push(AppRoutes.battle);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _statItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF121826),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E283D), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFB0C4DE),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(icon, color: color, size: 14),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Badges and Friends sections removed in favor of unified settings menu

  /// Shows Direct Photo / Avatar Picker Modal Bottom Sheet
  void _showAvatarPhotoPickerSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
            Text(
              'profile.avatar_picker_title'.tr(),
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.1),
            ),
            const SizedBox(height: 18),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x224AADDC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF4AADDC)),
              ),
              title: Text('profile.avatar_camera'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('profile.avatar_camera_sub'.tr(), style: const TextStyle(color: Colors.white54, fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadProfileImage(ImageSource.camera);
              },
            ),
            const Divider(color: Colors.white10, height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x224AADDC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library_rounded, color: Color(0xFF3A7FCC)),
              ),
              title: Text('profile.avatar_gallery'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('profile.avatar_gallery_sub'.tr(), style: const TextStyle(color: Colors.white54, fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadProfileImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadProfileImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final image = await picker.pickImage(source: source, imageQuality: 85);
      if (image == null) return;

      final uid = ref.read(authStateProvider).asData?.value?.uid;
      if (uid == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF4AADDC),
          content: Text('profile.avatar_uploading'.tr(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      );

      final tempDir = Directory.systemTemp.createTempSync('odat_profile');
      final targetPath = '${tempDir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        image.path,
        targetPath,
        quality: 60,
        minWidth: 300,
        minHeight: 300,
        format: CompressFormat.jpeg,
      );

      final fileBytes = compressedFile != null ? await compressedFile.readAsBytes() : await File(image.path).readAsBytes();
      final base64String = base64Encode(fileBytes);

      await ref.read(userRepositoryProvider).updateProfile(
        uid,
        photoBase64: base64String,
      );

      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF3A7FCC),
            content: Text('profile.avatar_success'.tr(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFFFF0055), content: Text('Xatolik: $e')),
        );
      }
    }
  }

  /// Shows Friends Chat / Direct Messages Modal
  void _showFriendsChatModal(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final friendsAsync = ref.watch(friendsLeaderboardProvider);

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            decoration: const BoxDecoration(
              color: Color(0xFF090B18),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: Color(0xFF0088CC), width: 1.5)),
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
                Row(
                  children: [
                    const Icon(Icons.forum_rounded, color: Color(0xFF0088CC), size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'profile.friends_chat_title'.tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.person_add_rounded, color: Color(0xFF3A7FCC), size: 20),
                      onPressed: () {
                        Navigator.pop(ctx);
                        showAddFriendModal(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: friendsAsync.when(
                    loading: () => const Center(child: FlowaLoading()),
                    error: (e, _) => Center(child: Text('Xato: $e', style: const TextStyle(color: Colors.red))),
                    data: (friends) {
                      if (friends.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('👥', style: TextStyle(fontSize: 40)),
                              const SizedBox(height: 10),
                              Text('profile.no_friends_title'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  showAddFriendModal(context);
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3A7FCC), foregroundColor: Colors.black),
                                child: Text('profile.find_friends_btn'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: friends.length,
                        separatorBuilder: (_, _) => const Divider(color: Colors.white10, height: 1),
                        itemBuilder: (context, index) {
                          final friend = friends[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            leading: ClipOval(
                              child: AvatarCircle(
                                avatarKey: friend.avatar,
                                size: 42,
                                photoBase64: friend.photoBase64,
                                photoUrl: friend.photoUrl,
                              ),
                            ),
                            title: Text(
                              friend.name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${friend.totalPoints} PTS',
                              style: const TextStyle(color: Color(0xFFFFB703), fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            trailing: ElevatedButton.icon(
                              onPressed: () {
                                final myProfile = ref.read(userProfileProvider).asData?.value;
                                if (myProfile == null) return;
                                Navigator.pop(ctx);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => DirectChatScreen(
                                      myUid: myProfile.uid,
                                      myName: myProfile.name.isEmpty ? 'Foydalanuvchi' : myProfile.name,
                                      myAvatar: myProfile.avatar,
                                      friendUid: friend.uid,
                                      friendName: friend.name,
                                      friendAvatar: friend.avatar,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0088CC),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.send_rounded, size: 14),
                              label: Text('profile.msg_btn'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditProfileModal(BuildContext context, UserProfile profile) {
    HapticFeedback.mediumImpact();
    final bioController = TextEditingController(text: profile.bio ?? '');
    final goalController = TextEditingController(text: profile.goalTitle ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
            decoration: const BoxDecoration(
              color: Color(0xFF090B18),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: Color(0xFF4AADDC), width: 1.5)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.edit_note_rounded, color: Color(0xFF4AADDC), size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'profile.edit_title'.trFallback('Profilni Tahrirlash'),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Avatar preview and change button
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showAvatarPhotoPickerSheet(context);
                      },
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [Color(0xFF4AADDC), Color(0xFF3A7FCC)]),
                            ),
                            child: ClipOval(
                              child: AvatarCircle(
                                avatarKey: profile.avatar,
                                size: 76,
                                photoBase64: profile.photoBase64,
                                photoUrl: profile.photoUrl,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF4AADDC),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'profile.tap_to_change_photo'.trFallback('Rasmni o‘zgartirish uchun bosing'),
                      style: const TextStyle(color: Color(0xFF4AADDC), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Name Display (Locked - Card required -> Opens Shop)
                  Text('profile.name_label'.trFallback('Ism / Taxallus'), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push(AppRoutes.shop);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF090B18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFB703).withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            profile.displayName ?? profile.name,
                            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          const Icon(Icons.shopping_bag_rounded, color: Color(0xFFFFB703), size: 16),
                          const SizedBox(width: 4),
                          const Text(
                            'Karta orqali 🎫',
                            style: TextStyle(color: Color(0xFFFFB703), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Bio / Status Field
                  Text('profile.bio_label'.trFallback('Status (Bio)'), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: bioController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'profile.bio_hint'.trFallback('O‘zingiz haqingizda qisqacha yozing...'),
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: const Color(0xFF090B18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0x334AADDC))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white10)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4AADDC))),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Goal Field
                  Text('profile.goal_label'.trFallback('Bosh Maqsad'), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: goalController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'profile.goal_hint'.trFallback('Masalan: IELTS 8.0 olish yoki 10 km yugurish...'),
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: const Color(0xFF090B18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0x334AADDC))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white10)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF4AADDC))),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              setModalState(() => isSaving = true);
                              try {
                                final newBio = bioController.text.trim();
                                final newGoal = goalController.text.trim();
                                await ref.read(userRepositoryProvider).updateUserProfile(
                                  profile.uid,
                                  bio: newBio,
                                  goalTitle: newGoal,
                                );
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: const Color(0xFF3A7FCC),
                                      behavior: SnackBarBehavior.floating,
                                      content: Text('profile.profile_saved'.trFallback('Profil ma’lumotlari muvaffaqiyatli saqlandi! ✨'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(backgroundColor: const Color(0xFFFF0055), content: Text('Xatolik: $e')),
                                  );
                                }
                              } finally {
                                if (ctx.mounted) setModalState(() => isSaving = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4AADDC),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : Text('common.save'.trFallback('Saqlash ✨'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSettingsModal(BuildContext context, UserProfile profile) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF090B18),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFF4AADDC), width: 1.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.settings_suggest_rounded, color: Color(0xFF4AADDC), size: 24),
                const SizedBox(width: 10),
                Text(
                  'profile.settings_modal_title'.trFallback('SOZLAMALAR VA BOSHQARUV'),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _modalActionTile(
              icon: Icons.edit_note_rounded,
              iconColor: const Color(0xFF4AADDC),
              title: 'profile.edit_profile_tile'.trFallback('Profil Ma’lumotlarini Tahrirlash'),
              subtitle: 'profile.edit_profile_sub'.trFallback('Rasm, status (bio) va bosh maqsadni o‘zgartirish'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditProfileModal(context, profile);
              },
            ),
            const Divider(color: Colors.white10, height: 1),

            _modalActionTile(
              icon: Icons.workspace_premium_rounded,
              iconColor: const Color(0xFFFFB703),
              title: 'profile.premium_tile'.trFallback('ODAT PRO Obunasi'),
              subtitle: profile.isPremium ? 'profile.premium_sub_active'.trFallback('PRO faol — barcha imkoniyatlar ochiq ✨') : 'profile.premium_sub_upgrade'.trFallback('Cheksiz AI, maxsus nishonlar va imkoniyatlar 🚀'),
              onTap: () {
                Navigator.pop(ctx);
                context.push(
                  profile.isPremium
                      ? AppRoutes.premiumStats
                      : AppRoutes.paywall,
                );
              },
            ),
            const Divider(color: Colors.white10, height: 1),

            _modalActionTile(
              icon: Icons.logout_rounded,
              iconColor: const Color(0xFFFF0055),
              title: 'profile.logout_tile'.trFallback('Hisobdan Chiqish'),
              subtitle: 'profile.logout_sub'.trFallback('Tizimdan xavfsiz chiqish'),
              onTap: () {
                Navigator.pop(ctx);
                _confirmLogout();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _modalActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.white54, fontSize: 11),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
    );
  }
}
