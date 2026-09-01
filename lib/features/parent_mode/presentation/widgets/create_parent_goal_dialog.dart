import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/bouncy_scale.dart';
import '../../domain/family_goal_models.dart';
import '../providers/family_goals_provider.dart';

class CreateParentGoalDialog extends ConsumerStatefulWidget {
  const CreateParentGoalDialog({super.key});

  @override
  ConsumerState<CreateParentGoalDialog> createState() => _CreateParentGoalDialogState();
}

class _CreateParentGoalDialogState extends ConsumerState<CreateParentGoalDialog> {
  final _titleController = TextEditingController();
  final _valueController = TextEditingController(text: '20');
  FamilyGoalCategory _selectedCategory = FamilyGoalCategory.reading;
  String _scheduledTime = '20:00';
  int _rewardCoins = 2;

  String get _unit {
    switch (_selectedCategory) {
      case FamilyGoalCategory.reading:
        return 'bet';
      case FamilyGoalCategory.running:
        return 'km';
      case FamilyGoalCategory.workout:
        return 'marta';
      case FamilyGoalCategory.study:
      case FamilyGoalCategory.focus:
        return 'daqiqa';
      case FamilyGoalCategory.habit:
      case FamilyGoalCategory.custom:
        return 'marta';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1420),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF3B9BFF).withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B9BFF).withValues(alpha: 0.1),
              blurRadius: 30,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B9BFF).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_task_rounded, color: Color(0xFF3B9BFF), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'family.create_goal_title'.tr(),
                    style: AppTextStyles.h3.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Category Selector Chips
              Text(
                'family.category'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: FamilyGoalCategory.values.map((cat) {
                    final isSelected = cat == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_getCategoryLabel(cat)),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _selectedCategory = cat;
                              if (_titleController.text.isEmpty) {
                                _titleController.text = _getDefaultTitle(cat);
                              }
                            });
                          }
                        },
                        selectedColor: const Color(0xFF3B9BFF),
                        backgroundColor: const Color(0xFF162032),
                        labelStyle: TextStyle(
                          color: isSelected ? const Color(0xFF080B14) : Colors.white70,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Goal Title Field
              Text(
                'family.goal_name'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Masalan: Har kuni 20 bet kitob o\'qish',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF131929),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Target & Unit & Time in Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hajm ($_unit)',
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _valueController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF131929),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vaqt',
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: const TimeOfDay(hour: 20, minute: 0),
                            );
                            if (picked != null) {
                              setState(() {
                                final h = picked.hour.toString().padLeft(2, '0');
                                final m = picked.minute.toString().padLeft(2, '0');
                                _scheduledTime = '$h:$m';
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131929),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF3B9BFF)),
                                const SizedBox(width: 8),
                                Text(
                                  _scheduledTime,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Reward FC Slider / Buttons
              Row(
                children: [
                  const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFB703), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Mukofot: +$_rewardCoins Fenix Coin',
                    style: const TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white60, size: 20),
                    onPressed: () {
                      if (_rewardCoins > 1) setState(() => _rewardCoins--);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF3B9BFF), size: 20),
                    onPressed: () {
                      if (_rewardCoins < 10) setState(() => _rewardCoins++);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit Button
              BouncyScale(
                onTap: () {
                  final title = _titleController.text.trim().isEmpty ? _getDefaultTitle(_selectedCategory) : _titleController.text.trim();
                  final val = int.tryParse(_valueController.text.trim()) ?? 20;

                  HapticFeedback.heavyImpact();
                  ref.read(familyGoalsProvider.notifier).createGoal(
                        title: title,
                        category: _selectedCategory,
                        scheduledTime: _scheduledTime,
                        targetValue: val,
                        unit: _unit,
                        rewardCoins: _rewardCoins,
                      );

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('family.goal_created_sent_toast'.tr()),
                      backgroundColor: const Color(0xFF0F3822),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B9BFF), Color(0xFF00C853)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B9BFF).withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'family.send_goal_to_child'.tr(),
                      style: const TextStyle(color: Color(0xFF080B14), fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCategoryLabel(FamilyGoalCategory cat) {
    switch (cat) {
      case FamilyGoalCategory.reading:
        return 'Kitob';
      case FamilyGoalCategory.running:
        return 'Yugurish';
      case FamilyGoalCategory.workout:
        return 'Mashq';
      case FamilyGoalCategory.study:
        return 'O\'qish';
      case FamilyGoalCategory.focus:
        return 'Fokus';
      case FamilyGoalCategory.habit:
        return 'Odat';
      case FamilyGoalCategory.custom:
        return 'Boshqa';
    }
  }

  String _getDefaultTitle(FamilyGoalCategory cat) {
    switch (cat) {
      case FamilyGoalCategory.reading:
        return 'Har kuni 20 bet kitob o\'qish';
      case FamilyGoalCategory.running:
        return 'Haftada 3 marta 3 km yugurish';
      case FamilyGoalCategory.workout:
        return 'Har kuni 30 ta otjimaniya';
      case FamilyGoalCategory.study:
        return 'Matematika — 30 daqiqa dars';
      case FamilyGoalCategory.focus:
        return 'Chuqur fokus — 25 daqiqa';
      case FamilyGoalCategory.habit:
        return 'Xonani tartibga keltirish';
      case FamilyGoalCategory.custom:
        return 'Foydali odat bajarish';
    }
  }
}
