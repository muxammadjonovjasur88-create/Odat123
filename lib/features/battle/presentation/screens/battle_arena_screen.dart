import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/user_profile.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/user_repository.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/battle_repository.dart';
import '../../domain/models/battle_match.dart';

class BattleArenaScreen extends ConsumerWidget {
  const BattleArenaScreen({super.key});

  void _startRandomMatch(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(userProfileProvider).asData?.value;
    if (profile == null) return;

    if (profile.totalPoints < 50) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFFF0055),
          behavior: SnackBarBehavior.floating,
          content: Text('battle.min_points_required'.tr(args: ['50', '${profile.totalPoints}'])),
        ),
      );
      return;
    }

    String selectedExercise = 'pushup';
    int selectedDuration = 60;
    int selectedWager = 50;
    int playerAge = 16;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
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
                const Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: Color(0xFF4AADDC), size: 28),
                    SizedBox(width: 10),
                    Text(
                      '⚡ Tezkor Tasodifiy Jang',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 1. Choose Exercise
                Text('battle.select_exercise'.tr(), style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _exerciseChip('pushup', 'Push-up 📹', Icons.fitness_center_rounded, selectedExercise, (val) => setModalState(() => selectedExercise = val)),
                    _exerciseChip('squat', 'Squat 📹', Icons.directions_run_rounded, selectedExercise, (val) => setModalState(() => selectedExercise = val)),
                    _exerciseChip('finger_tap', '⚡ Tap', Icons.touch_app_rounded, selectedExercise, (val) => setModalState(() => selectedExercise = val)),
                    _exerciseChip('quiz', '🧠 Bilimlar', Icons.menu_book_rounded, selectedExercise, (val) => setModalState(() => selectedExercise = val)),
                  ],
                ),
                if (selectedExercise == 'quiz') ...[
                  const SizedBox(height: 12),
                  Text('battle.age_prompt'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF090B18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF4AADDC), width: 1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Masalan: 16',
                        hintStyle: TextStyle(color: Colors.white24),
                      ),
                      onChanged: (val) {
                        playerAge = int.tryParse(val) ?? 16;
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // 2. Choose Duration
                Text('battle.match_duration'.tr(), style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _durationChip(60, '⏱️ 1 daqiqa', selectedDuration, (val) => setModalState(() => selectedDuration = val)),
                    const SizedBox(width: 8),
                    _durationChip(180, '⏱️ 3 daqiqa', selectedDuration, (val) => setModalState(() => selectedDuration = val)),
                    const SizedBox(width: 8),
                    _durationChip(300, '⏱️ 5 daqiqa', selectedDuration, (val) => setModalState(() => selectedDuration = val)),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Choose Wager
                Text('battle.stake_pts'.tr(), style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [50, 100, 250, 500].map((pts) {
                    final isSel = selectedWager == pts;
                    return ChoiceChip(
                      selected: isSel,
                      onSelected: (_) => setModalState(() => selectedWager = pts),
                      label: Text('$pts ⚡ PTS', style: TextStyle(color: isSel ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      selectedColor: const Color(0xFF4AADDC),
                      backgroundColor: const Color(0xFF090B18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      _launchRandomMatchmaking(context, ref, profile, selectedExercise, selectedDuration, selectedWager, playerAge);
                    },
                    icon: const Icon(Icons.flash_on_rounded),
                    label: Text('battle.start_battle'.tr(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4AADDC),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _launchRandomMatchmaking(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
    String exerciseType,
    int durationSeconds,
    int wagerPoints,
    int playerAge,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF090B18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF4AADDC), width: 1.5),
        ),
        content: const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(color: Color(0xFF4AADDC), strokeWidth: 3),
              ),
              SizedBox(height: 20),
              Text(
                '⚡ Raqib qidirilmoqda...',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Tizim eng mos jangchini ulamoqda...',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await Future.delayed(const Duration(milliseconds: 1500));
      final battleId = await ref.read(battleRepositoryProvider).findOrCreateRandomMatch(
        user: profile,
        exerciseType: exerciseType,
        durationSeconds: durationSeconds,
        wagerPoints: wagerPoints,
        playerAge: playerAge,
      );
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        context.push('${AppRoutes.battle}/$battleId');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF0055),
            content: Text('Xatolik: $e'),
          ),
        );
      }
    }
  }

  void _showCreateBattleDialog(BuildContext context, WidgetRef ref) {
    final profile = ref.read(userProfileProvider).asData?.value;
    if (profile == null) return;

    if (profile.totalPoints < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFFF0055),
          behavior: SnackBarBehavior.floating,
          content: Text('battle.create_min_points'.tr(args: ['10', '${profile.totalPoints}'])),
        ),
      );
      return;
    }

    String selectedExercise = 'pushup';
    int selectedDuration = 60;
    int selectedWager = (profile.totalPoints >= 100 ? 100 : profile.totalPoints);
    int playerAge = 16;
    final customWagerController = TextEditingController(text: '$selectedWager');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final totalPot = selectedWager * 2;
          final winnerPrize = (totalPot * 0.9).toInt();
          final commission = totalPot - winnerPrize;

          return Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
            decoration: const BoxDecoration(
              color: Color(0xFF090B18),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: Color(0xFFFF0055), width: 1.5)),
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
                    const Icon(Icons.sports_martial_arts_rounded, color: Color(0xFFFF0055), size: 28),
                    const SizedBox(width: 10),
                    Text(
                      'extra.battle_new_1v1'.tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Live Pot & Prize Info Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0x22FF0055),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x66FF0055)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('battle.wager_amount'.tr(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          Text('-$selectedWager PTS', style: const TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.w900, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('battle.winner_prize'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('+$winnerPrize PTS', style: const TextStyle(color: Color(0xFF3A7FCC), fontWeight: FontWeight.w900, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('battle.platform_commission'.tr(), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          Text('$commission PTS', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Custom Wager Input Field
                Text('battle.enter_wager_prompt'.tr(), style: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: customWagerController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'battle.enter_custom_pts'.tr(),
                    labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                    hintText: 'Masalan: 50, 150, 700...',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                    prefixIcon: const Icon(Icons.bolt_rounded, color: Color(0xFFFFB703)),
                    suffixText: '⚡ PTS',
                    suffixStyle: const TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: const Color(0xFF090B18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val) ?? 0;
                    setModalState(() => selectedWager = parsed);
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [25, 50, 100, 200, 500, 1000, 2500].map((pts) {
                    final isSel = selectedWager == pts;
                    return ChoiceChip(
                      selected: isSel,
                      onSelected: (_) {
                        setModalState(() {
                          selectedWager = pts;
                          customWagerController.text = '$pts';
                        });
                      },
                      label: Text('$pts ⚡', style: TextStyle(color: isSel ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      selectedColor: const Color(0xFFFFB703),
                      backgroundColor: const Color(0xFF090B18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                Text('battle.choose_exercise_type'.tr(), style: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _exerciseChip('pushup', 'Push-up 📹', Icons.fitness_center_rounded, selectedExercise, (val) => setModalState(() => selectedExercise = val)),
                    _exerciseChip('squat', 'Squat 📹', Icons.directions_run_rounded, selectedExercise, (val) => setModalState(() => selectedExercise = val)),
                    _exerciseChip('finger_tap', '⚡ Tap', Icons.touch_app_rounded, selectedExercise, (val) => setModalState(() => selectedExercise = val)),
                    _exerciseChip('quiz', '🧠 Bilimlar', Icons.menu_book_rounded, selectedExercise, (val) => setModalState(() => selectedExercise = val)),
                  ],
                ),
                if (selectedExercise == 'quiz') ...[
                  const SizedBox(height: 12),
                  const Text('Yoshingizni kiriting:', style: TextStyle(color: Color(0xFF8B9BB4), fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF090B18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFF0055), width: 1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Masalan: 16',
                        hintStyle: TextStyle(color: Colors.white24),
                      ),
                      onChanged: (val) {
                        setModalState(() => playerAge = int.tryParse(val) ?? 16);
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Match Duration selector
                Text('battle.match_duration'.tr(), style: TextStyle(color: Color(0xFF8B9BB4), fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _durationChip(60, '⏱️ 1 daqiqa', selectedDuration, (val) => setModalState(() => selectedDuration = val)),
                    const SizedBox(width: 8),
                    _durationChip(180, '⏱️ 3 daqiqa', selectedDuration, (val) => setModalState(() => selectedDuration = val)),
                    const SizedBox(width: 8),
                    _durationChip(300, '⏱️ 5 daqiqa', selectedDuration, (val) => setModalState(() => selectedDuration = val)),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: selectedWager <= 0 || selectedWager > profile.totalPoints
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            try {
                              final battleId = await ref.read(battleRepositoryProvider).createBattle(
                                host: profile,
                                exerciseType: selectedExercise,
                                durationSeconds: selectedDuration,
                                wagerPoints: selectedWager,
                                playerAge: playerAge,
                              );
                              if (context.mounted) {
                                context.push('${AppRoutes.battle}/$battleId');
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFFFF0055),
                                    content: Text(e.toString()),
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF0055),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white12,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      selectedWager > profile.totalPoints
                          ? 'Ballaringiz yetarli emas (Mavjud: ${profile.totalPoints} PTS)'
                          : 'Jangni boshlash ($selectedWager ⚡ PTS) ⚔️',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _exerciseChip(String id, String title, IconData icon, String selected, Function(String) onSelect) {
    final isSelected = selected == id;
    return InkWell(
      onTap: () => onSelect(id),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF261019) : const Color(0xFF080D17),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? const Color(0xFFFF0055) : const Color(0x22FFFFFF), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFFF0055) : Colors.white70, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).asData?.value;
    final battlesAsync = ref.watch(waitingBattlesStreamProvider);
    final myBattlesAsync = profile != null
        ? ref.watch(myBattlesStreamProvider(profile.uid))
        : const AsyncValue<List<BattleMatch>>.data([]);

    return Scaffold(
      backgroundColor: const Color(0xFF04050D),
      appBar: const FlowaAppBar(
        showBackButton: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateBattleDialog(context, ref),
        backgroundColor: const Color(0xFFFF0055),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 24),
        label: Text('battle.create_btn'.tr(namedArgs: {'wager': '100'}), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 1. Header Banner
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF24101A), Color(0xFF0A0E17)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x66FF0055)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sports_kabaddi_rounded, color: Color(0xFFFF0055), size: 40),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'battle.arena_banner_title'.tr(),
                            style: const TextStyle(color: Color(0xFFFF0055), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'battle.arena_banner_sub'.tr(),
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'battle.arena_banner_desc'.tr(),
                            style: const TextStyle(color: Color(0xFFFFB703), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 1.5 Quick Random Matchmaking Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: GestureDetector(
                  onTap: () => _startRandomMatch(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4AADDC), Color(0xFF0066FF)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x555BC8FA),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.black26,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '⚡ TEZKOR TASODIFIY JANG',
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.8),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '3 soniyada raqib bilan to‘g‘ridan-to‘g‘ri bellashing!',
                                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 2. My Created / Joined Battles Section (Separated & Highlighted in Red)
            myBattlesAsync.when(
              data: (myBattles) {
                if (myBattles.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                return SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 10, 20, 6),
                        child: Row(
                          children: [
                            Text('🔴', style: TextStyle(fontSize: 14)),
                            SizedBox(width: 6),
                            Text(
                              'SIZ YARATGAN JANG XONALARI',
                              style: TextStyle(color: Color(0xFFFF0055), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                            ),
                          ],
                        ),
                      ),
                      ...myBattles.map((b) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: _buildMyBattleCard(context, ref, b, profile),
                      )),
                      const SizedBox(height: 12),
                    ],
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),

            // 3. Open Public Battles Section Header
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    Text('⚔️', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text(
                      'OCHIQ BELLASHUVLAR',
                      style: TextStyle(color: Color(0xFF4AADDC), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Open Public Battles List (Excludes user's own battles)
            battlesAsync.when(
              data: (allBattles) {
                final publicBattles = allBattles.where((b) => b.hostUid != profile?.uid).toList();

                if (publicBattles.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined, color: Colors.white.withValues(alpha: 0.3), size: 52),
                            const SizedBox(height: 10),
                            const Text(
                              'Hozircha ochiq bellashuvlar yo‘q',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Pastdagi + tugmasi orqali yangi jang yarating!',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final battle = publicBattles[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildPublicBattleCard(context, ref, battle, profile),
                        );
                      },
                      childCount: publicBattles.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: FlowaLoading()),
                ),
              ),
              error: (err, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelBattleDialog(BuildContext context, WidgetRef ref, BattleMatch battle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF090B18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFF0055), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF0055)),
            const SizedBox(width: 8),
            Text('battle.delete_room_title'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        content: Text(
          'battle.delete_room_confirm'.tr(namedArgs: {'wager': battle.wagerPoints.toString()}),
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.back'.tr(), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final profile = ref.read(userProfileProvider).asData?.value;
              if (profile == null) return;
              try {
                await ref.read(battleRepositoryProvider).cancelBattle(
                      battleId: battle.id,
                      uid: profile.uid,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF3A7FCC),
                      content: Text('battle.room_deleted_refunded'.tr(namedArgs: {'wager': battle.wagerPoints.toString()})),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF0055),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('common.delete'.tr(), style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  /// User's own battle card (Highlighted in Red / Crimson Neon)
  Widget _buildMyBattleCard(BuildContext context, WidgetRef ref, BattleMatch battle, dynamic profile) {
    final isActive = battle.status == BattleStatus.active;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C0E16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFF0055), width: 1.8),
        boxShadow: const [BoxShadow(color: Color(0x33FF0055), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0x33FF0055),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              battle.exerciseType == 'pushup'
                  ? Icons.fitness_center_rounded
                  : (battle.exerciseType == 'squat' ? Icons.directions_run_rounded : Icons.touch_app_rounded),
              color: const Color(0xFFFF0055),
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        battle.hostName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF0055),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text('battle.your_room_tag'.tr(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${battle.exerciseDisplayName} • ${battle.wagerPoints} ⚡ Garov',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF4D6D), size: 22),
            tooltip: 'Xonani o‘chirish',
            visualDensity: VisualDensity.compact,
            onPressed: () => _showCancelBattleDialog(context, ref, battle),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: () {
              context.push('${AppRoutes.battle}/${battle.id}');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF0055),
              foregroundColor: Colors.white,
              elevation: 4,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              isActive ? 'JANGGA KIRISH ⚡' : 'KIRISH',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  /// Open public battle card (Cyan / Blue theme)
  Widget _buildPublicBattleCard(BuildContext context, WidgetRef ref, BattleMatch battle, dynamic profile) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF090B18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x334AADDC), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0x224AADDC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              battle.exerciseType == 'pushup'
                  ? Icons.fitness_center_rounded
                  : (battle.exerciseType == 'squat' ? Icons.directions_run_rounded : Icons.touch_app_rounded),
              color: const Color(0xFF4AADDC),
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        battle.hostName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0x224AADDC),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0x444AADDC)),
                      ),
                      child: Text('battle.open_tag'.tr(), style: const TextStyle(color: Color(0xFF4AADDC), fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${battle.exerciseDisplayName} • ${battle.wagerPoints} ⚡ Garov',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              try {
                if (profile == null) return;
                await ref.read(battleRepositoryProvider).joinBattle(
                  battleId: battle.id,
                  opponent: profile,
                );
                if (context.mounted) {
                  context.push('${AppRoutes.battle}/${battle.id}');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFFFF0055),
                      content: Text(e.toString()),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4AADDC),
              foregroundColor: Colors.black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'KIRISH (${battle.wagerPoints} ⚡)',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _durationChip(
    int seconds,
    String label,
    int selectedSeconds,
    ValueChanged<int> onSelected,
  ) {
    final isSel = selectedSeconds == seconds;
    return Expanded(
      child: InkWell(
        onTap: () => onSelected(seconds),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFFFFB703) : const Color(0xFF090B18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSel ? const Color(0xFFFFB703) : const Color(0x33FFFFFF),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSel ? Colors.black : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 11.5,
            ),
          ),
        ),
      ),
    );
  }
}
