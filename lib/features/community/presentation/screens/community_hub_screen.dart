import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../domain/community_models.dart';

class CommunityHubScreen extends ConsumerStatefulWidget {
  const CommunityHubScreen({super.key});

  @override
  ConsumerState<CommunityHubScreen> createState() => _CommunityHubScreenState();
}

class _CommunityHubScreenState extends ConsumerState<CommunityHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04050D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'community.hub_title'.tr(),
              style: AppTextStyles.h2.copyWith(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
            ),
            Text(
              'community.hub_subtitle'.tr(),
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF3A7FCC),
          indicatorWeight: 3,
          labelColor: const Color(0xFF3A7FCC),
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: [
            Tab(text: 'community.tab_find_people'.tr()),
            Tab(text: 'community.tab_squads'.tr()),
            Tab(text: 'community.tab_activity_rooms'.tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFindPeopleTab(),
          _buildSquadsTab(),
          _buildActivityRoomsTab(),
        ],
      ),
    );
  }

  Widget _buildFindPeopleTab() {
    final peers = [
      const MatchedPeer(
        id: 'p1',
        odatId: 'ODAT-8K3N41',
        name: 'Jasurbek',
        avatarUrl: '',
        primaryInterest: '🏃 Yugurish (Running)',
        currentGoal: 'Birinchi 5 km yugurish',
        matchPercent: 92,
        matchReasons: ['Yugurish ✓', '5K Maqsad ✓', 'Kechki 18:30 ✓', 'Toshkent ✓'],
        preferredTime: '18:30 (Har kuni)',
        areaSummary: 'Toshkent • Chilonzor',
      ),
      const MatchedPeer(
        id: 'p2',
        odatId: 'ODAT-4M9P22',
        name: 'Bekzod',
        avatarUrl: '',
        primaryInterest: '🤖 Robototexnika (ESP32 / Arduino)',
        currentGoal: 'Chiziq bo‘yicha harakatlanuvchi robot',
        matchPercent: 88,
        matchReasons: ['Robototexnika ✓', 'Dasturlash ✓', 'Elektronika ✓'],
        preferredTime: '16:00 (Dam olish kunlari)',
        areaSummary: 'Toshkent • Yunusobod',
      ),
      const MatchedPeer(
        id: 'p3',
        odatId: 'ODAT-6X7L99',
        name: 'Madina',
        avatarUrl: '',
        primaryInterest: '🇬🇧 Ingliz tili (IELTS Speaking)',
        currentGoal: 'Har kuni 20 min speaking amaliyoti',
        matchPercent: 85,
        matchReasons: ['English ✓', 'Speaking ✓', 'Erta tonggi jadval ✓'],
        preferredTime: '08:00 (Ertalab)',
        areaSummary: 'Samarqand',
      ),
    ];

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(18),
      itemCount: peers.length,
      itemBuilder: (context, idx) {
        final p = peers[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF090B18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF3A7FCC).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF18263E),
                    child: Text(
                      p.name.substring(0, 1),
                      style: const TextStyle(color: Color(0xFF3A7FCC), fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                            const SizedBox(width: 6),
                            Text('(${p.odatId})', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(p.primaryInterest, style: const TextStyle(color: Color(0xFF4AADDC), fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0x224AADDC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF3A7FCC).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '${p.matchPercent}% Mos',
                      style: const TextStyle(color: Color(0xFF3A7FCC), fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Maqsad: "${p.currentGoal}"', style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontStyle: FontStyle.italic)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: p.matchReasons.map((r) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141F32),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(r, style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF3A7FCC),
                            content: Text('${p.name}ga birgalikda mashq qilish taklifi yuborildi!'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3A7FCC),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Birga boshlash 🤝',
                        style: TextStyle(color: Color(0xFF04050D), fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSquadsTab() {
    final squads = [
      const GrowthSquad(
        id: 'sq1',
        name: '30-Kunlik Qat’iy Intizom',
        goalTitle: 'Ekran vaqtini 50% kamaytirish & Fokus',
        membersCount: 4,
        maxMembers: 5,
        daysRemaining: 18,
        aggregateProgressPercent: 78,
        isJoined: true,
      ),
      const GrowthSquad(
        id: 'sq2',
        name: 'Har Kuni 20 Bet Kitob',
        goalTitle: 'Oyiga 2 ta professional kitob mutolaasi',
        membersCount: 3,
        maxMembers: 5,
        daysRemaining: 24,
        aggregateProgressPercent: 62,
        isJoined: false,
      ),
    ];

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(18),
      itemCount: squads.length,
      itemBuilder: (context, idx) {
        final sq = squads[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF090B18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFB703).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(sq.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0x22FFB703),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${sq.membersCount}/${sq.maxMembers} kishi',
                      style: const TextStyle(color: Color(0xFFFFB703), fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(sq.goalTitle, style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Jamoaviy Natija', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Text('${sq.aggregateProgressPercent}%', style: const TextStyle(color: Color(0xFF3A7FCC), fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: sq.aggregateProgressPercent / 100,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3A7FCC)),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sq.isJoined ? const Color(0xFF1B2C46) : const Color(0xFFFFB703),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    sq.isJoined ? 'Jamoa Chatini Ochish' : 'Jamoaga Qo‘shilish (+3 FC)',
                    style: TextStyle(
                      color: sq.isJoined ? Colors.white : const Color(0xFF04050D),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityRoomsTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF090B18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF4AADDC).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.directions_run_rounded, color: Color(0xFF4AADDC), size: 22),
                  SizedBox(width: 8),
                  Text('5 km Kechki Yugurish Sessiyasi', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Vaqt: Bugun 18:30 • Ishtirokchilar: 3 kishi', style: TextStyle(color: Colors.white54, fontSize: 11.5)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4AADDC),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Xonaga Kirish 🚀',
                  style: TextStyle(color: Color(0xFF04050D), fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
