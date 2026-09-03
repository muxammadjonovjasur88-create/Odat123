import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/user_profile.dart';
import '../../../../core/services/user_repository.dart';

import 'dart:math' as math;

const List<String> kOfficialBadgeIds = [
  'streak_3',
  'streak_7',
  'streak_14',
  'streak_30',
  'streak_100',
  'streak_365',
  'run_first',
  'run_10km',
  'territory_conqueror',
  'pushup_master_50',
  'run_100km',
  'book_reader_1',
  'book_scholar_5',
  'pvp_first_win',
  'pvp_warrior_10',
  'clan_member',
  'clan_leader',
  'focus_100min',
  'points_10k',
  'focus_100h',
  'level_50_master',
];

/// Renders the rich, animated Badges & Achievements Modal
Future<void> showBadgesModal(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _BadgesModalSheet(),
  );
}

class _BadgesModalSheet extends ConsumerStatefulWidget {
  const _BadgesModalSheet();

  @override
  ConsumerState<_BadgesModalSheet> createState() => _BadgesModalSheetState();
}

class _BadgesModalSheetState extends ConsumerState<_BadgesModalSheet>
    with SingleTickerProviderStateMixin {
  String _selectedCategory = 'all';
  final Set<String> _locallyClaimedBadges = {};
  bool _isClaiming = false;

  final List<Map<String, dynamic>> _badgeDefinitions = [
    // --- INTIZOM & STREAK ---
    {
      'id': 'streak_3',
      'category': 'discipline',
      'title': 'Boshlang‘ich Qadam',
      'desc': '3 kun ketma-ket ilovaga kirib odatlarni bajaring',
      'icon': '🌱',
      'reward': 150,
      'target': 3,
      'unit': 'kun',
      'checkUnlocked': (UserProfile p) => math.max(p.streak, p.longestStreak) >= 3,
      'getProgress': (UserProfile p) => math.max(p.streak, p.longestStreak),
    },
    {
      'id': 'streak_7',
      'category': 'discipline',
      'title': 'Bir Haftalik Temir Iroda',
      'desc': '7 kun ketma-ket uzluksiz maqsadlar sari harakat qiling',
      'icon': '🔥',
      'reward': 400,
      'target': 7,
      'unit': 'kun',
      'checkUnlocked': (UserProfile p) => math.max(p.streak, p.longestStreak) >= 7,
      'getProgress': (UserProfile p) => math.max(p.streak, p.longestStreak),
    },
    {
      'id': 'streak_14',
      'category': 'discipline',
      'title': '2 Haftalik Odat',
      'desc': '14 kunlik uzluksiz intizom va faollik zanjiri',
      'icon': '⚡',
      'reward': 800,
      'target': 14,
      'unit': 'kun',
      'checkUnlocked': (UserProfile p) => math.max(p.streak, p.longestStreak) >= 14,
      'getProgress': (UserProfile p) => math.max(p.streak, p.longestStreak),
    },
    {
      'id': 'streak_30',
      'category': 'discipline',
      'title': 'Oltin Oy',
      'desc': '30 kunlik to‘liq intizom! Siz yangi odatni to‘liq shakllantirdingiz',
      'icon': '👑',
      'reward': 2000,
      'target': 30,
      'unit': 'kun',
      'checkUnlocked': (UserProfile p) => math.max(p.streak, p.longestStreak) >= 30,
      'getProgress': (UserProfile p) => math.max(p.streak, p.longestStreak),
    },
    {
      'id': 'streak_100',
      'category': 'discipline',
      'title': 'Afsonaviy Yuzlik',
      'desc': '100 kunlik tengsiz qat’iyat va o‘zgarmas temir intizom',
      'icon': '💎',
      'reward': 5000,
      'target': 100,
      'unit': 'kun',
      'checkUnlocked': (UserProfile p) => math.max(p.streak, p.longestStreak) >= 100,
      'getProgress': (UserProfile p) => math.max(p.streak, p.longestStreak),
    },
    {
      'id': 'streak_365',
      'category': 'discipline',
      'title': '1 Yillik Afsona',
      'desc': '365 kun ketma-ket biror kun uzmasdan intizom zanjirini saqlang',
      'icon': '👑',
      'reward': 20000,
      'target': 365,
      'unit': 'kun',
      'checkUnlocked': (UserProfile p) => math.max(p.streak, p.longestStreak) >= 365,
      'getProgress': (UserProfile p) => math.max(p.streak, p.longestStreak),
    },

    // --- SPORT & YUGURISH ---
    {
      'id': 'run_first',
      'category': 'sport',
      'title': 'Birinchi Qadam',
      'desc': 'Xarita orqali birinchi yugurish mashqini muvaffaqiyatli yakunlang',
      'icon': '👟',
      'reward': 200,
      'target': 1,
      'unit': 'km',
      'checkUnlocked': (UserProfile p) => p.totalRunningKm >= 1.0,
      'getProgress': (UserProfile p) => p.totalRunningKm.floor().clamp(0, 1),
    },
    {
      'id': 'run_10km',
      'category': 'sport',
      'title': 'Chaqqon Marafonchi',
      'desc': 'Jami 10 km dan ortiq yugurish masofasini zabt eting',
      'icon': '🏃‍♂️',
      'reward': 600,
      'target': 10,
      'unit': 'km',
      'checkUnlocked': (UserProfile p) => p.totalRunningKm >= 10.0,
      'getProgress': (UserProfile p) => p.totalRunningKm.floor().clamp(0, 10),
    },
    {
      'id': 'territory_conqueror',
      'category': 'sport',
      'title': 'Hudud Zabtkori',
      'desc': 'Xaritada bosh va oxirini tutashtirib birinchi hududni o‘z nomingizga oling',
      'icon': '🚩',
      'reward': 500,
      'target': 1,
      'unit': 'hudud',
      'checkUnlocked': (UserProfile p) => p.totalRunningKm >= 3.0,
      'getProgress': (UserProfile p) => p.totalRunningKm >= 3.0 ? 1 : 0,
    },
    {
      'id': 'pushup_master_50',
      'category': 'sport',
      'title': 'Push-Up Chempioni',
      'desc': 'AI Vision yoki mashg‘ulotda 50 tadan ortiq otjimaniye bajaring',
      'icon': '🦾',
      'reward': 350,
      'target': 50,
      'unit': 'marta',
      'checkUnlocked': (UserProfile p) => p.battleWins >= 3 || p.totalDeepSessions >= 3,
      'getProgress': (UserProfile p) => (math.max(p.battleWins, p.totalDeepSessions) * 20).clamp(0, 50),
    },
    {
      'id': 'run_100km',
      'category': 'sport',
      'title': 'Marafon Qiroli',
      'desc': 'Jami 100 km dan ortiq yugurish masofasini zabt eting',
      'icon': '🏆',
      'reward': 10000,
      'target': 100,
      'unit': 'km',
      'checkUnlocked': (UserProfile p) => p.totalRunningKm >= 100.0,
      'getProgress': (UserProfile p) => p.totalRunningKm.floor().clamp(0, 100),
    },

    // --- KUTUBXONA & MUTOLAA ---
    {
      'id': 'book_reader_1',
      'category': 'books',
      'title': 'Kitobxonlikka Qadam',
      'desc': 'Kutubxonadagi birinchi interaktiv kurs yoki darslikni yakunlang',
      'icon': '📖',
      'reward': 250,
      'target': 1,
      'unit': 'kurs',
      'checkUnlocked': (UserProfile p) => p.unlockedTracks.isNotEmpty || p.claimedBadges.any((b) => b.startsWith('course_')),
      'getProgress': (UserProfile p) => (p.unlockedTracks.isNotEmpty || p.claimedBadges.any((b) => b.startsWith('course_'))) ? 1 : 0,
    },
    {
      'id': 'book_scholar_5',
      'category': 'books',
      'title': 'Zukko Kitobxon',
      'desc': '5 ta turli xil kurs va darsliklarni muvaffaqiyatli yakunlang',
      'icon': '📚',
      'reward': 1000,
      'target': 5,
      'unit': 'kurs',
      'checkUnlocked': (UserProfile p) => p.claimedBadges.where((b) => b.startsWith('course_')).length >= 5,
      'getProgress': (UserProfile p) => p.claimedBadges.where((b) => b.startsWith('course_')).length.clamp(0, 5),
    },

    // --- 1V1 JANG & PVP ---
    {
      'id': 'pvp_first_win',
      'category': 'pvp',
      'title': 'extra.1v1_battle'.tr(),
      'desc': 'extra.battle_1v1_desc_1'.tr(),
      'icon': '⚔️',
      'reward': 300,
      'target': 1,
      'unit': 'g‘alaba',
      'checkUnlocked': (UserProfile p) => p.battleWins >= 1,
      'getProgress': (UserProfile p) => p.battleWins.clamp(0, 1),
    },
    {
      'id': 'pvp_warrior_10',
      'category': 'pvp',
      'title': 'Yengilmas Jangchi',
      'desc': '10 ta 1v1 duellarda g‘alaba qozonib sovrinli o‘rinlarni oling',
      'icon': '🛡️',
      'reward': 1200,
      'target': 10,
      'unit': 'g‘alaba',
      'checkUnlocked': (UserProfile p) => p.battleWins >= 10,
      'getProgress': (UserProfile p) => p.battleWins.clamp(0, 10),
    },

    // --- KLAN & JAMOA ---
    {
      'id': 'clan_member',
      'category': 'clan',
      'title': 'Ittifoqdosh',
      'desc': 'Ixtiyoriy kuchli klanga a’zo bo‘lib, birga rivojlaning',
      'icon': '🦅',
      'reward': 400,
      'target': 1,
      'unit': 'klan',
      'checkUnlocked': (UserProfile p) => p.clanId != null && p.clanId!.isNotEmpty,
      'getProgress': (UserProfile p) => (p.clanId != null && p.clanId!.isNotEmpty) ? 1 : 0,
    },
    {
      'id': 'clan_leader',
      'category': 'clan',
      'title': 'Klan Sardori',
      'desc': 'O‘z klangingizni yarating va safdoshlaringizni boshqaring',
      'icon': '🎖️',
      'reward': 1500,
      'target': 1,
      'unit': 'klan',
      'checkUnlocked': (UserProfile p) => p.isClanLeader == true,
      'getProgress': (UserProfile p) => p.isClanLeader == true ? 1 : 0,
    },

    // --- FOKUS & MAHSULDORLIK ---
    {
      'id': 'focus_100min',
      'category': 'focus',
      'title': 'Diqqat Markazida',
      'desc': '100 daqiqa chuqur fokus seansida chalg‘imasdan ishlang',
      'icon': '🧘‍♂️',
      'reward': 300,
      'target': 100,
      'unit': 'daqiqa',
      'checkUnlocked': (UserProfile p) => p.totalFocusMinutes >= 100,
      'getProgress': (UserProfile p) => p.totalFocusMinutes.clamp(0, 100),
    },
    {
      'id': 'focus_100h',
      'category': 'focus',
      'title': 'Zen Fokus Donishmandi',
      'desc': '100 soatdan ortiq qat’iy intizom rejimida fokus qiling',
      'icon': '🧠',
      'reward': 15000,
      'target': 6000,
      'unit': 'daqiqa',
      'checkUnlocked': (UserProfile p) => p.totalFocusMinutes >= 6000,
      'getProgress': (UserProfile p) => p.totalFocusMinutes.clamp(0, 6000),
    },
    {
      'id': 'points_10k',
      'category': 'focus',
      'title': 'Magnat',
      'desc': 'Hisobingizda 10,000 dan ortiq chaqmoqcha ball jamlang',
      'icon': '🌟',
      'reward': 2500,
      'target': 10000,
      'unit': 'PTS',
      'checkUnlocked': (UserProfile p) => p.totalPoints >= 10000,
      'getProgress': (UserProfile p) => p.totalPoints.clamp(0, 10000),
    },
    {
      'id': 'level_50_master',
      'category': 'discipline',
      'title': 'Elita Jangchi (50-Daraja)',
      'desc': 'Profil darajangizni 50-darajaga ko‘taring',
      'icon': '⚡',
      'reward': 25000,
      'target': 50,
      'unit': 'daraja',
      'checkUnlocked': (UserProfile p) => (1 + (p.totalPoints / 1000).floor()) >= 50,
      'getProgress': (UserProfile p) => (1 + (p.totalPoints / 1000).floor()).clamp(1, 50),
    },
  ];

  Future<void> _claimReward(Map<String, dynamic> badge, UserProfile profile) async {
    final badgeId = badge['id'] as String;
    final reward = badge['reward'] as int;

    if (_locallyClaimedBadges.contains(badgeId) || profile.hasClaimedBadge(badgeId) || _isClaiming) {
      return;
    }

    setState(() {
      _isClaiming = true;
      _locallyClaimedBadges.add(badgeId);
    });
    HapticFeedback.heavyImpact();

    try {
      final success = await ref.read(userRepositoryProvider).claimBadge(profile.uid, badgeId, reward);
      if (mounted && success) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF3A7FCC),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFF3A7FCC), Color(0xFF4AADDC)]),
                  ),
                  child: Icon(_badgeIconData(badge['id'] as String), color: const Color(0xFF090B18), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'badges.congrats_toast'.tr(namedArgs: {'reward': '$reward'}),
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  void _showDetailSheet(Map<String, dynamic> badge, UserProfile profile) {
    final badgeId = badge['id'] as String;
    final isUnlocked = (badge['checkUnlocked'] as bool Function(UserProfile))(profile);
    final isClaimed = profile.hasClaimedBadge(badgeId) || _locallyClaimedBadges.contains(badgeId);
    final reward = badge['reward'] as int;
    final progress = (badge['getProgress'] as int Function(UserProfile))(profile);
    final target = badge['target'] as int;
    final unit = badge['unit'] as String;
    final title = 'badges.${badgeId}_title'.tr() != 'badges.${badgeId}_title'
        ? 'badges.${badgeId}_title'.tr()
        : badge['title'] as String;
    final desc = 'badges.${badgeId}_desc'.tr() != 'badges.${badgeId}_desc'
        ? 'badges.${badgeId}_desc'.tr()
        : badge['desc'] as String;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF090B18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: Color(0x446B25CC)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isClaimed
                      ? [const Color(0x444AADDC), const Color(0x114AADDC)]
                      : isUnlocked
                          ? [const Color(0x557B2FFF), const Color(0x226B25CC)]
                          : [const Color(0x22FFFFFF), const Color(0x05FFFFFF)],
                ),
                border: Border.all(
                  color: isClaimed
                      ? const Color(0xFF3A7FCC)
                      : isUnlocked
                          ? const Color(0xFF6B25CC)
                          : Colors.white24,
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(
                  _badgeIconData(badge['id'] as String),
                  color: isClaimed
                      ? const Color(0xFF3A7FCC)
                      : isUnlocked
                          ? const Color(0xFF6B25CC)
                          : Colors.white24,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
            ),
            const SizedBox(height: 16),

            // Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('profile.main_metrics'.tr(), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    Text('$progress / $target $unit', style: const TextStyle(color: Color(0xFF4AADDC), fontWeight: FontWeight.bold, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (progress / target).clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFF090B18),
                    valueColor: AlwaysStoppedAnimation<Color>(isUnlocked ? const Color(0xFF3A7FCC) : const Color(0xFF6B25CC)),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Claim / Action Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isClaimed || !isUnlocked || _isClaiming
                    ? null
                    : () {
                        Navigator.of(ctx).pop();
                        _claimReward(badge, profile);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isClaimed
                      ? const Color(0x3300FF88)
                      : isUnlocked
                          ? const Color(0xFF6B25CC)
                          : const Color(0x22FFFFFF),
                  foregroundColor: isClaimed
                      ? const Color(0xFF3A7FCC)
                      : isUnlocked
                          ? Colors.white
                          : Colors.white38,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: isUnlocked && !isClaimed ? 8 : 0,
                ),
                child: Text(
                  isClaimed
                      ? 'badges.claimed_done'.tr()
                      : isUnlocked
                          ? 'badges.claim_btn'.tr(namedArgs: {'reward': '$reward'})
                          : 'badges.in_progress'.tr(namedArgs: {
                              'progress': '$progress',
                              'target': '$target',
                              'unit': unit,
                            }),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).asData?.value;
    if (profile == null) return const SizedBox.shrink();

    final filtered = _selectedCategory == 'all'
        ? _badgeDefinitions
        : _badgeDefinitions.where((b) => b['category'] == _selectedCategory).toList();

    final claimedCount = _badgeDefinitions.where((b) => profile.hasClaimedBadge(b['id'] as String) || _locallyClaimedBadges.contains(b['id'] as String)).length;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: Color(0xFF090D17),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Color(0x557B2FFF), width: 1.5)),
      ),
      child: Column(
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0x337B2FFF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.military_tech_rounded, color: Color(0xFF6B25CC), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'badges.modal_title'.tr(),
                              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              'badges.claimed_label'.tr(namedArgs: {'count': '$claimedCount'}),
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x224AADDC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF3A7FCC).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '$claimedCount / ${_badgeDefinitions.length}',
                        style: const TextStyle(color: Color(0xFF3A7FCC), fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Categories Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _categoryChip('all', 'badges.cat_all'.tr()),
                      _categoryChip('discipline', 'badges.cat_discipline'.tr()),
                      _categoryChip('sport', 'badges.cat_sport'.tr()),
                      _categoryChip('books', 'badges.cat_books'.tr()),
                      _categoryChip('pvp', 'badges.cat_pvp'.tr()),
                      _categoryChip('clan', 'badges.cat_clan'.tr()),
                      _categoryChip('focus', 'badges.cat_focus'.tr()),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // Badges Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.28,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, idx) {
                final badge = filtered[idx];
                final badgeId = badge['id'] as String;
                final isUnlocked = (badge['checkUnlocked'] as bool Function(UserProfile))(profile);
                final isClaimed = profile.hasClaimedBadge(badgeId) || _locallyClaimedBadges.contains(badgeId);
                final reward = badge['reward'] as int;

                return InkWell(
                  onTap: () => _showDetailSheet(badge, profile),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: isClaimed
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0x224AADDC), Color(0x0A00FF88)],
                            )
                          : isUnlocked
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0x337B2FFF), Color(0x117B2FFF)],
                                )
                              : null,
                      color: (isClaimed || isUnlocked) ? null : const Color(0xFF0E1424),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isClaimed
                            ? const Color(0xFF3A7FCC).withValues(alpha: 0.6)
                            : isUnlocked
                                ? const Color(0xFF6B25CC).withValues(alpha: 0.6)
                                : Colors.white10,
                        width: isUnlocked || isClaimed ? 1.6 : 1,
                      ),
                      boxShadow: isUnlocked && !isClaimed
                          ? [
                              BoxShadow(
                                color: const Color(0xFF6B25CC).withValues(alpha: 0.25),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isClaimed
                                    ? const Color(0x3300FF88)
                                    : isUnlocked
                                        ? const Color(0x337B2FFF)
                                        : const Color(0x11FFFFFF),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  _badgeIconData(badge['id'] as String),
                                  color: isClaimed
                                      ? const Color(0xFF3A7FCC)
                                      : isUnlocked
                                          ? const Color(0xFF6B25CC)
                                          : Colors.white38,
                                  size: 20,
                                ),
                              ),
                            ),
                            if (isClaimed)
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF3A7FCC), size: 18)
                            else if (isUnlocked)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFB703),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'OCHIQ',
                                  style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900),
                                ),
                              )
                            else
                              const Icon(Icons.lock_outline_rounded, color: Colors.white24, size: 16),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              badge['title'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isClaimed
                                    ? const Color(0xFF3A7FCC)
                                    : isUnlocked
                                        ? Colors.white
                                        : Colors.white38,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isClaimed ? 'Olingan' : '+$reward PTS',
                              style: TextStyle(
                                color: isClaimed
                                    ? const Color(0xFF3A7FCC)
                                    : isUnlocked
                                        ? const Color(0xFFFFB703)
                                        : Colors.white24,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String id, String label) {
    final isSel = _selectedCategory == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: isSel,
        onSelected: (_) => setState(() => _selectedCategory = id),
        label: Text(
          label,
          style: TextStyle(
            color: isSel ? Colors.black : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        selectedColor: const Color(0xFF6B25CC),
        backgroundColor: const Color(0xFF090B18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  IconData _badgeIconData(String id) {
    switch (id) {
      case 'streak_3':    return Icons.eco_rounded;
      case 'streak_7':    return Icons.local_fire_department_rounded;
      case 'streak_14':   return Icons.bolt_rounded;
      case 'streak_30':   return Icons.workspace_premium_rounded;
      case 'streak_100':  return Icons.diamond_rounded;
      case 'streak_365':  return Icons.military_tech_rounded;
      case 'run_first':   return Icons.directions_run_rounded;
      case 'run_10km':    return Icons.speed_rounded;
      case 'territory_conqueror': return Icons.flag_rounded;
      case 'pushup_master_50':    return Icons.fitness_center_rounded;
      case 'run_100km':   return Icons.emoji_events_rounded;
      case 'book_reader_1': return Icons.menu_book_rounded;
      case 'book_scholar_5': return Icons.auto_stories_rounded;
      case 'pvp_first_win':  return Icons.sports_martial_arts_rounded;
      case 'pvp_warrior_10': return Icons.shield_rounded;
      case 'clan_member':    return Icons.groups_rounded;
      case 'clan_leader':    return Icons.stars_rounded;
      case 'focus_100min':   return Icons.self_improvement_rounded;
      case 'focus_100h':     return Icons.psychology_rounded;
      case 'points_10k':     return Icons.trending_up_rounded;
      case 'level_50_master': return Icons.bolt_rounded;
      default: return Icons.verified_rounded;
    }
  }
}
