import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../domain/family_models.dart';
import '../providers/family_providers.dart';

class ParentMissionsScreen extends ConsumerStatefulWidget {
  const ParentMissionsScreen({super.key});

  @override
  ConsumerState<ParentMissionsScreen> createState() => _ParentMissionsScreenState();
}

class _ParentMissionsScreenState extends ConsumerState<ParentMissionsScreen> {
  @override
  Widget build(BuildContext context) {
    final missionsAsync = ref.watch(todayMissionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF04050D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'family.missions_title'.tr(),
          style: AppTextStyles.h2.copyWith(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF3A7FCC)),
            onPressed: () => _showCreateMissionModal(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF3A7FCC),
        onRefresh: () async => ref.invalidate(todayMissionsProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          children: [
            // Missions Progress Header
            missionsAsync.when(
              data: (missions) {
                final completed = missions.where((m) => m.isVerified).length;
                final total = missions.length;
                final ratio = total > 0 ? (completed / total) : 0.0;

                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF090B18), Color(0xFF0C1626)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFF3A7FCC).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'family.today_missions_heading'.tr(),
                            style: const TextStyle(color: Color(0xFF3A7FCC), fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                          ),
                          Text(
                            '$completed / $total ${'family.completed'.tr()}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3A7FCC)),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, st) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),

            // Missions List
            Text(
              'family.active_missions'.tr(),
              style: const TextStyle(color: Color(0xFF8B9BB4), fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.1),
            ),
            const SizedBox(height: 10),

            missionsAsync.when(
              data: (missions) => ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: missions.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final m = missions[index];
                  return _buildMissionTile(m);
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF3A7FCC))),
              error: (e, st) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateMissionModal(context),
        backgroundColor: const Color(0xFF3A7FCC),
        icon: const Icon(Icons.add_task_rounded, color: Color(0xFF04050D)),
        label: Text(
          'family.create_mission_btn'.tr(),
          style: const TextStyle(color: Color(0xFF04050D), fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _buildMissionTile(FamilyMission m) {
    Color typeColor;
    IconData typeIcon;
    switch (m.type) {
      case MissionType.study:
        typeColor = const Color(0xFFFFB703);
        typeIcon = Icons.school_rounded;
        break;
      case MissionType.reading:
        typeColor = const Color(0xFF4AADDC);
        typeIcon = Icons.auto_stories_rounded;
        break;
      case MissionType.workout:
        typeColor = const Color(0xFFFF5252);
        typeIcon = Icons.fitness_center_rounded;
        break;
      case MissionType.location:
        typeColor = const Color(0xFF3A7FCC);
        typeIcon = Icons.location_on_rounded;
        break;
      case MissionType.screenTime:
        typeColor = const Color(0xFF4AADDC);
        typeIcon = Icons.phonelink_setup_rounded;
        break;
      default:
        typeColor = Colors.white70;
        typeIcon = Icons.task_alt_rounded;
    }

    final isDone = m.isVerified;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF090B18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDone ? const Color(0xFF3A7FCC).withValues(alpha: 0.3) : Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: typeColor.withValues(alpha: 0.15),
                ),
                child: Icon(typeIcon, color: typeColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.title,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.description,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x22FFB703),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${m.rewardCoins} FC',
                  style: const TextStyle(color: Color(0xFFFFB703), fontSize: 11, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDone ? const Color(0x224AADDC) : const Color(0x224AADDC),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  m.verificationDetails ?? (isDone ? 'Bajarildi' : 'Jarayonda'),
                  style: TextStyle(
                    color: isDone ? const Color(0xFF3A7FCC) : const Color(0xFF4AADDC),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                'Muddati: ${m.deadlineTimeStr}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateMissionModal(BuildContext context) {
    MissionType selectedType = MissionType.study;
    final titleController = TextEditingController(text: 'Dars qilish (Study)');
    int coins = 40;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF090B18),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                Text(
                  'family.new_mission_title'.tr(),
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),

                // Type selector
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _typeChip(MissionType.study, 'Ta’lim 📐', selectedType, (t) => setModalState(() => selectedType = t)),
                    _typeChip(MissionType.reading, 'Kitob 📖', selectedType, (t) => setModalState(() => selectedType = t)),
                    _typeChip(MissionType.workout, 'Sport 🏋️', selectedType, (t) => setModalState(() => selectedType = t)),
                    _typeChip(MissionType.location, 'Maktab 🏫', selectedType, (t) => setModalState(() => selectedType = t)),
                    _typeChip(MissionType.screenTime, 'Ekran 📵', selectedType, (t) => setModalState(() => selectedType = t)),
                  ],
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Missiya nomi',
                    labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF090B18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),

                // Reward & Target row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Mukofot (+FC)', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [20, 40, 50].map((c) {
                              final isSel = coins == c;
                              return ChoiceChip(
                                label: Text('+$c'),
                                selected: isSel,
                                onSelected: (_) => setModalState(() => coins = c),
                                selectedColor: const Color(0xFFFFB703),
                                backgroundColor: const Color(0xFF090B18),
                                labelStyle: TextStyle(color: isSel ? const Color(0xFF04050D) : Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF3A7FCC),
                        content: Text('family.mission_assigned_toast'.tr(), style: const TextStyle(color: Color(0xFF04050D), fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A7FCC),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Center(
                    child: Text(
                      'family.assign_btn'.tr(),
                      style: const TextStyle(color: Color(0xFF04050D), fontWeight: FontWeight.w900, fontSize: 14),
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

  Widget _typeChip(MissionType type, String label, MissionType current, Function(MissionType) onSelect) {
    final isSel = current == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      onSelected: (_) => onSelect(type),
      selectedColor: const Color(0xFF3A7FCC),
      backgroundColor: const Color(0xFF090B18),
      labelStyle: TextStyle(color: isSel ? const Color(0xFF04050D) : Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
    );
  }
}
