import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/auth_repository.dart';
import '../../../../core/services/user_repository.dart';
import '../../../../core/widgets/bouncy_scale.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/boss_raid_repository.dart';
import '../../domain/models/boss_raid.dart';

class BossRaidScreen extends ConsumerStatefulWidget {
  const BossRaidScreen({super.key});

  @override
  ConsumerState<BossRaidScreen> createState() => _BossRaidScreenState();
}

class _BossRaidScreenState extends ConsumerState<BossRaidScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  int _lastDamageDealt = 0;
  bool _showDamage = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  int _pendingDamage = 0;
  bool _isFlushingDamage = false;
  Timer? _damageFlushTimer;

  void _dealDamage(BossRaid boss, String type, int amount) {
    final profile = ref.read(userProfileProvider).asData?.value;
    final uid = profile?.uid ?? ref.read(authStateProvider).asData?.value?.uid ?? 'guest';
    HapticFeedback.heavyImpact();

    final singleDmg = switch (type) {
      'pushup' => amount * 2,
      'running' => (amount * 10),
      'focus' => (amount ~/ 2).clamp(1, 9999),
      _ => amount,
    };

    // 1. Instant optimistic UI feedback
    setState(() {
      _lastDamageDealt += singleDmg;
      _pendingDamage += amount;
      _showDamage = true;
    });

    if (!_shakeController.isAnimating) {
      _shakeController.forward(from: 0);
    }

    // 2. Debounced asynchronous attack flush to Firestore
    _damageFlushTimer?.cancel();
    _damageFlushTimer = Timer(const Duration(milliseconds: 250), () async {
      if (_pendingDamage <= 0 || _isFlushingDamage) return;
      _isFlushingDamage = true;
      final amountToSend = _pendingDamage;
      _pendingDamage = 0;

      try {
        await ref.read(bossRaidRepositoryProvider).attackBoss(
          raidId: boss.id,
          uid: uid,
          actionType: type,
          amount: amountToSend,
          clanId: profile?.clanId,
        );
      } catch (_) {
      } finally {
        _isFlushingDamage = false;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            setState(() {
              _showDamage = false;
              _lastDamageDealt = 0;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).asData?.value;
    final bossAsync = ref.watch(activeBossRaidProvider);
    final fallbackBoss = BossRaid(
      id: profile?.clanId != null ? 'clan_boss_${profile!.clanId}' : 'weekly_boss_default',
      bossName: profile?.clanName != null ? '[${profile!.clanName}] Qora Titani' : 'Dangasalik Titani',
      bossTitle: profile?.clanName != null ? 'Klan Darajasi 5 • Jamoaviy Klan Bossi' : 'Daraja 5 • Haftalik Mega Boss',
      bossAvatar: '🐉',
      maxHp: 2000,
      currentHp: 1850,
      targetPushUps: 500,
      currentPushUps: 120,
      targetRunningKm: 30.0,
      currentRunningKm: 12.5,
      targetFocusMinutes: 300,
      currentFocusMinutes: 90,
      rewardPoints: 1000,
      rewardCoins: 250,
      status: BossStatus.active,
      expiresAt: DateTime.now().add(const Duration(days: 3)),
      participants: const [],
    );

    final boss = bossAsync.asData?.value ?? fallbackBoss;

    return Scaffold(
      backgroundColor: const Color(0xFF04050D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090B18),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            const Icon(Icons.shield_moon_rounded, color: Color(0xFFFF0055), size: 22),
            const SizedBox(width: 8),
            Text(
              'boss_raid.screen_title'.tr(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
                  // Boss Avatar Card with Glow
                  AnimatedBuilder(
                    animation: _shakeController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          _shakeController.isAnimating ? (10 * (0.5 - _shakeController.value)) : 0,
                          0,
                        ),
                        child: child,
                      );
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF0055).withValues(alpha: 0.4),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF0055), Color(0xFF8B0022)],
                            ),
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          alignment: Alignment.center,
                          child: Text(boss.bossAvatar, style: const TextStyle(fontSize: 60)),
                        ),
                        if (_showDamage)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: AnimatedOpacity(
                              opacity: _showDamage ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 300),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF0055),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Text(
                                  '-$_lastDamageDealt DMG 💥',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    boss.bossName,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    boss.bossTitle,
                    style: const TextStyle(color: Color(0xFFFF0055), fontSize: 12, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 20),

                  // Boss HP Bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090B18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x33FF0055)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('boss_raid.hp_label'.tr(), style: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 11, fontWeight: FontWeight.bold)),
                            Text(
                              '${boss.currentHp} / ${boss.maxHp} HP (${(boss.hpPercent * 100).toInt()}%)',
                              style: const TextStyle(color: Color(0xFFFF0055), fontSize: 13, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: boss.hpPercent,
                            minHeight: 14,
                            backgroundColor: const Color(0xFF04050D),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF0055)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Team Objectives Matrix
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090B18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x334AADDC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'boss_raid.team_goals'.tr(),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 12),
                        _buildObjectiveRow('boss_raid.pushup_label'.tr(), '${boss.currentPushUps} / ${boss.targetPushUps} ta', boss.currentPushUps / boss.targetPushUps, const Color(0xFF4AADDC)),
                        const SizedBox(height: 10),
                        _buildObjectiveRow('boss_raid.running_label'.tr(), '${boss.currentRunningKm.toStringAsFixed(1)} / ${boss.targetRunningKm.toStringAsFixed(1)} km', (boss.currentRunningKm / boss.targetRunningKm).clamp(0.0, 1.0), const Color(0xFFFF5500)),
                        const SizedBox(height: 10),
                        _buildObjectiveRow('boss_raid.focus_label'.tr(), '${boss.currentFocusMinutes} / ${boss.targetFocusMinutes} daq', (boss.currentFocusMinutes / boss.targetFocusMinutes).clamp(0.0, 1.0), const Color(0xFF3A7FCC)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const SizedBox(height: 16),

                  // Real Workout Info Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1829),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x444AADDC)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Color(0xFF4AADDC), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Hujum Qanday Qilinadi?',
                              style: TextStyle(color: Color(0xFF4AADDC), fontWeight: FontWeight.w900, fontSize: 12),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Klan a’zolari real hayotda push-up, yugurish va chuqur diqqat seanslarini bajarganlarida, Bossga avtomatik jamoaviy zarba beriladi!',
                          style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Mega Reward Box: 2000 PTS + 5 Fenix Coins
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF221A0F), Color(0xFF161005)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFB703), width: 1.2),
                      boxShadow: const [
                        BoxShadow(color: Color(0x33FFB703), blurRadius: 10),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.military_tech_rounded, color: Color(0xFFFFB703), size: 36),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🏆 G‘ALABA MUKOFOROTI (HAR BIR O‘YINCHIGA)',
                                style: TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.w900, fontSize: 10.5, letterSpacing: 0.5),
                              ),
                              SizedBox(height: 3),
                              Text(
                                '+2000 ⚡ PTS  &  +5 🔥 Fenix Coin',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

  Widget _buildObjectiveRow(String title, String progressText, double percent, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
            Text(progressText, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percent.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: const Color(0xFF04050D),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
