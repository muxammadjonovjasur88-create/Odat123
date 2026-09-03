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
            backgroundColor: const Color(0xFF3A7FCC),
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
      backgroundColor: const Color(0xFF04050D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090B18),
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
        color: const Color(0xFF090B18),
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
            color: Color(0xFF3A7FCC),
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
              iconColor: const Color(0xFF6B25CC),
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
              iconColor: const Color(0xFF4AADDC),
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
            color: const Color(0xFF090B18),
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

