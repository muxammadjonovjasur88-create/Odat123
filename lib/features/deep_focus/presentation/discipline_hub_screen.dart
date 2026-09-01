import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/widgets/bouncy_scale.dart';
import '../data/deep_sleep_service.dart';

class DisciplineHubScreen extends ConsumerStatefulWidget {
  const DisciplineHubScreen({super.key});

  @override
  ConsumerState<DisciplineHubScreen> createState() => _DisciplineHubScreenState();
}

class _DisciplineHubScreenState extends ConsumerState<DisciplineHubScreen> {
  int _sleepMinutes = 0;
  int _restMinutes = 0;
  int _usageMinutes = 0;
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    _loadSleepStatus();
  }

  Future<void> _loadSleepStatus() async {
    final stats = await ref.read(deepSleepServiceProvider).getSleepStats();
    final unclaimed = await ref.read(deepSleepServiceProvider).getUnclaimedSleepMinutes();
    if (mounted) {
      setState(() {
        _sleepMinutes = unclaimed;
        _restMinutes = stats.restMinutes;
        _usageMinutes = stats.usageMinutes;
      });
    }
  }

  Future<void> _claimSleepBonus() async {
    final user = ref.read(userProfileProvider).asData?.value;
    if (user == null || _sleepMinutes <= 0) return;

    setState(() => _isClaiming = true);
    HapticFeedback.heavyImpact();

    try {
      final claimedPts = await ref.read(deepSleepServiceProvider).claimSleepPoints(user.uid);
      if (mounted) {
        setState(() => _sleepMinutes = 0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF3B9BFF),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Row(
              children: [
                const Text('🌙', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '+$claimedPts PTS Tungi ekran mukofoti hisobingizga qo‘shildi! 🎉',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (_) {}
    if (mounted) setState(() => _isClaiming = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1220),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Text('🛡️', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'Intizom & Diqqat Markazi',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 17,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 80),
        children: [
          // 🛡️ INTIZOM ASOSIY USKUNALARI (GRID)
          _buildDisciplineToolsGrid(),
          const SizedBox(height: 18),

          // 🌙 TUNGI EKRAN ASOSIY STATISTIKA VA MUKOFOT KARTASI
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B1040), Color(0xFF09061A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF7B2FFF), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B2FFF).withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Text('✨', style: TextStyle(fontSize: 22)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tungi "Ekran Yo‘q" Rejimi',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7B2FFF).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF7B2FFF)),
                      ),
                      child: const Text(
                        '1 MIN = 1 PTS',
                        style: TextStyle(
                          color: Color(0xFFD8B4FE),
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Kechki soat 22:00 dan ertalab 07:00 gacha telefon ekranini yoqmasdan dam olsangiz, har 1 daqiqa uchun 1 PTS mukofot beriladi. Chuqur va sog‘lom uyqu — muvaffaqiyat garovidir!',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Text('😴 ', style: TextStyle(fontSize: 16)),
                              Text(
                                'Dam oldingiz (Ekran o‘chiq):',
                                style: TextStyle(color: Colors.white70, fontSize: 12.5),
                              ),
                            ],
                          ),
                          Text(
                            '${_restMinutes ~/ 60} soat ${_restMinutes % 60} daq',
                            style: const TextStyle(
                              color: Color(0xFF3B9BFF),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Text('📱 ', style: TextStyle(fontSize: 16)),
                              Text(
                                'Telefon ishlatildi:',
                                style: TextStyle(color: Colors.white70, fontSize: 12.5),
                              ),
                            ],
                          ),
                          Text(
                            '${_usageMinutes ~/ 60} soat ${_usageMinutes % 60} daq',
                            style: const TextStyle(
                              color: Color(0xFFFF0055),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'To‘plangan Mukofot PTS:',
                            style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '+$_sleepMinutes PTS',
                            style: const TextStyle(
                              color: Color(0xFF5BC8FA),
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _sleepMinutes > 0 && !_isClaiming ? _claimSleepBonus : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B2FFF),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white12,
                      disabledForegroundColor: Colors.white30,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isClaiming
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _sleepMinutes > 0
                                ? '+$_sleepMinutes PTS MUKOFOTNI OLISH 🎁'
                                : 'MUKOFOT MAVJUD EMAS (TUNGI VAQTDA TO‘PLANADI)',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                          ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 📚 TUNGI EKRANNING FOYDALARI VA MASLAHATLAR
          _buildInfoSection(
            title: 'Sog‘lom Uyqu Qoidalari',
            icon: Icons.spa_rounded,
            color: const Color(0xFF3B9BFF),
            items: [
              '🌙 Soat 22:00 dan keyin moviy (ko‘k) nur melatonin ishlab chiqarilishini to‘xtatadi.',
              '🧘 Uxlashdan 30 daqiqa oldin telefonni chetga qo‘ying va xonani shamollating.',
              '📖 Ekran o‘rniga qog‘oz kitob mutolaa qilish miyani tinchlantiradi va uyqu sifatini 40% ga oshiradi.',
              '⚡ Har kecha 7-8 soatlik to‘liq uyqu kunduzgi diqqat va intizomni 2 barobar kuchaytiradi.',
            ],
          ),

          const SizedBox(height: 16),

          _buildInfoSection(
            title: 'Ball To‘plash Tizimi',
            icon: Icons.stars_rounded,
            color: const Color(0xFFFFB703),
            items: [
              '🕒 Tungi davr: 22:00 — 07:00 (Jami 9 soat / 540 daqiqa).',
              '💎 Har 1 daqiqa telefon ishlatilmagan vaqt uchun +1 PTS beriladi.',
              '🏆 1 kechada maksimal 540 PTS gacha to‘plashingiz mumkin.',
              '☀️ Ertalab uyg‘onganingizda ushbu ekranga kirib "Mukofotni olish" tugmasini bosing.',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1220),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildDisciplineToolsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'INTIZOM VA DIQQAT USKUNALARI',
          style: TextStyle(
            color: Color(0xFF3B9BFF),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _disciplineToolCard(
              icon: Icons.shield_rounded,
              iconColor: const Color(0xFF7B2FFF),
              title: 'Qat’iy Intizom',
              subtitle: 'Fokus rejimini yoqish',
              onTap: () => context.push(AppRoutes.strictDiscipline),
            ),
            const SizedBox(width: 10),
            _disciplineToolCard(
              icon: Icons.block_rounded,
              iconColor: const Color(0xFFFF0055),
              title: 'Ilovalar Cheklovi',
              subtitle: 'Bloklash va limitlar',
              onTap: () => context.push(AppRoutes.appLimits),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _disciplineToolCard(
              icon: Icons.phonelink_setup_rounded,
              iconColor: const Color(0xFF5BC8FA),
              title: 'Ekran Vaqti',
              subtitle: 'Raqamli salomatlik',
              onTap: () => context.push(AppRoutes.digitalWellbeing),
            ),
            const SizedBox(width: 10),
            _disciplineToolCard(
              icon: Icons.bedtime_rounded,
              iconColor: const Color(0xFFFFB703),
              title: 'Raqamli Detoks',
              subtitle: 'Dam olish taymeri',
              onTap: () => context.push(AppRoutes.digitalDetox),
            ),
          ],
        ),
      ],
    );
  }

  Widget _disciplineToolCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: BouncyScale(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1220),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: iconColor.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

