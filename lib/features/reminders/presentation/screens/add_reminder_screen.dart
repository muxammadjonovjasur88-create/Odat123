import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/reminder.dart';
import '../providers/reminders_provider.dart';

/// Modern Bottom sheet for creating or editing a Goal / Focus / Exercise / Note.
class RemindersSheet extends ConsumerStatefulWidget {
  const RemindersSheet({super.key, this.existing, this.initialGoalType});

  final Reminder? existing;
  final String? initialGoalType;

  static Future<void> show(
    BuildContext context, {
    Reminder? existing,
    String? initialGoalType,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => RemindersSheet(
        existing: existing,
        initialGoalType: initialGoalType,
      ),
    );
  }

  @override
  ConsumerState<RemindersSheet> createState() => _RemindersSheetState();
}

class _RemindersSheetState extends ConsumerState<RemindersSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _selectedGoalType = 'focus'; // 'focus', 'exercise', 'note'
  int _durationMinutes = 45;
  String _selectedExercise = 'SQUAT';
  int _targetReps = 20;

  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay(hour: (TimeOfDay.now().hour + 1) % 24, minute: TimeOfDay.now().minute);
  RepeatType _repeatType = RepeatType.once;
  bool _saving = false;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      final r = widget.existing!;
      _titleController.text = r.title;
      _selectedDate = r.dateTime;
      _repeatType = r.repeatType;
      _selectedGoalType = r.goalType;
      _durationMinutes = r.durationMinutes;
      _selectedExercise = r.exerciseType ?? 'SQUAT';
      _targetReps = r.targetReps ?? 20;
    } else {
      _selectedGoalType = widget.initialGoalType ?? 'focus';
      final now = DateTime.now();
      final minutes = ((now.minute / 15).ceil() * 15) % 60;
      final hours = now.hour + ((now.minute / 15).ceil() * 15 ~/ 60);
      _selectedDate = DateTime(
        now.year,
        now.month,
        now.day,
        hours % 24,
        minutes,
      ).add(const Duration(hours: 1));
      _startTime = TimeOfDay(hour: _selectedDate.hour, minute: _selectedDate.minute);
      final endHour = (_selectedDate.hour + 1) % 24;
      _endTime = TimeOfDay(hour: endHour, minute: _selectedDate.minute);
    }

    _slideController = AnimationController(
      vsync: this,
      duration: AppMotion.page,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: AppMotion.enter),
    );
    _fadeAnim = CurvedAnimation(
      parent: _slideController,
      curve: AppMotion.enter,
    );
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) => _datePickerTheme(context, child),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _selectedDate.hour,
        minute: _selectedDate.minute,
      ),
      builder: (context, child) => _datePickerTheme(context, child),
    );
    if (picked != null && mounted) {
      setState(() {
        _startTime = picked;
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      builder: (context, child) => _datePickerTheme(context, child),
    );
    if (picked != null && mounted) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  Widget _datePickerTheme(BuildContext context, Widget? child) {
    final colors = context.colors;
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: const Color(0xFF5BC8FA),
          surface: colors.surface,
          onSurface: colors.textPrimary,
        ),
      ),
      child: child!,
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final String startStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
    final String endStr = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}';

    try {
      final notifier = ref.read(remindersProvider.notifier);
      if (_isEditing) {
        final updated = widget.existing!.copyWith(
          title: _titleController.text.trim(),
          dateTime: _selectedDate,
          repeatType: _repeatType,
          goalType: _selectedGoalType,
          durationMinutes: _durationMinutes,
          startTimeStr: startStr,
          endTimeStr: endStr,
          exerciseType: _selectedGoalType == 'exercise' ? _selectedExercise : null,
          targetReps: _selectedGoalType == 'exercise' ? _targetReps : null,
        );
        await notifier.editReminder(updated);
      } else {
        await notifier.add(
          title: _titleController.text.trim(),
          dateTime: _selectedDate,
          repeatType: _repeatType,
          goalType: _selectedGoalType,
          durationMinutes: _durationMinutes,
          startTimeStr: startStr,
          endTimeStr: endStr,
          exerciseType: _selectedGoalType == 'exercise' ? _selectedExercise : null,
          targetReps: _selectedGoalType == 'exercise' ? _targetReps : null,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _errorMessage = 'Xato yuz berdi: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewInsetsOf(context).bottom;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1220),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: const Color(0x335BC8FA), width: 1),
          ),
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomPad),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isEditing ? 'Maqsadni tahrirlash' : '🎯 Yangi Maqsad Qo‘shish',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Goal Type Selector (3 Modes) ─────────────────────────
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131929),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x22FFFFFF)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _GoalTypeTab(
                            icon: Icons.timer_outlined,
                            label: 'Fokus',
                            isSelected: _selectedGoalType == 'focus',
                            activeColor: const Color(0xFF5BC8FA),
                            onTap: () {
                              setState(() {
                                _selectedGoalType = 'focus';
                                if (_titleController.text.isEmpty) {
                                  _titleController.text = 'Chuqur Fokus & Dars';
                                }
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: _GoalTypeTab(
                            icon: Icons.videocam_rounded,
                            label: 'Mashq (AI)',
                            isSelected: _selectedGoalType == 'exercise',
                            activeColor: const Color(0xFF3B9BFF),
                            onTap: () {
                              setState(() {
                                _selectedGoalType = 'exercise';
                                if (_titleController.text.isEmpty) {
                                  _titleController.text = '20 ta Squat mashqi';
                                }
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: _GoalTypeTab(
                            icon: Icons.edit_note_rounded,
                            label: 'Zametka',
                            isSelected: _selectedGoalType == 'note',
                            activeColor: const Color(0xFFFFB703),
                            onTap: () {
                              setState(() {
                                _selectedGoalType = 'note';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Title field ──────────────────────────────────────────
                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 120,
                    decoration: InputDecoration(
                      hintText: _selectedGoalType == 'focus'
                          ? 'Fokus maqsadi (masalan: Dasturlash, Kitob o‘qish)…'
                          : (_selectedGoalType == 'exercise'
                              ? 'Mashq maqsadi (masalan: Ertalabki otjimaniye)…'
                              : 'Eslatma / Zametka matni…'),
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      counterStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: const Color(0xFF131929),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0x335BC8FA)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0x22FFFFFF)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF5BC8FA), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Sarlavha kiriting' : null,
                  ),
                  const SizedBox(height: 14),

                  // ── MODE SPECIFIC CONFIGURATIONS ─────────────────────────

                  // 1. FOCUS MODE: Timer Duration & Time Range
                  if (_selectedGoalType == 'focus') ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1220),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x445BC8FA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lock_clock_rounded, color: Color(0xFF5BC8FA), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Fokus Davomiyligi (Hard-Lock & Ilovalar Bloklash):',
                                style: TextStyle(color: Color(0xFF5BC8FA), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [25, 45, 60, 90, 120].map((min) {
                              final sel = _durationMinutes == min;
                              return ChoiceChip(
                                label: Text('$min daqiqa'),
                                selected: sel,
                                selectedColor: const Color(0xFF5BC8FA),
                                backgroundColor: const Color(0xFF131929),
                                labelStyle: TextStyle(
                                  color: sel ? Colors.black : Colors.white70,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                                onSelected: (_) {
                                  setState(() {
                                    _durationMinutes = min;
                                    final endH = (_startTime.hour + (min ~/ 60)) % 24;
                                    final endM = (_startTime.minute + (min % 60)) % 60;
                                    _endTime = TimeOfDay(hour: endH, minute: endM);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: _pickTime,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF131929),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0x33FFFFFF)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('reminders.start_time'.tr(), style: TextStyle(color: Colors.white54, fontSize: 10)),
                                        Text(
                                          '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, color: Colors.white38, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: _pickEndTime,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF131929),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0x33FFFFFF)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('reminders.end_time'.tr(), style: TextStyle(color: Colors.white54, fontSize: 10)),
                                        Text(
                                          '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
                                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ]

                  // 2. EXERCISE MODE: AI Camera & Target Reps
                  else if (_selectedGoalType == 'exercise') ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1220),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x4439FF14)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.fitness_center_rounded, color: Color(0xFF3B9BFF), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Mashq turi va AI Tekshiruv:',
                                style: TextStyle(color: Color(0xFF3B9BFF), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              {'key': 'SQUAT', 'label': 'Squat 🏋️'},
                              {'key': 'PUSH_UP', 'label': 'Push-up 🦾'},
                              {'key': 'PLANK', 'label': 'Plank ⏱️'},
                              {'key': 'PULL_UP', 'label': 'Turnik 🧗'},
                              {'key': 'CRUNCH', 'label': 'Press ⚡'},
                            ].map((item) {
                              final sel = _selectedExercise == item['key'];
                              return ChoiceChip(
                                label: Text(item['label']!),
                                selected: sel,
                                selectedColor: const Color(0xFF3B9BFF),
                                backgroundColor: const Color(0xFF131929),
                                labelStyle: TextStyle(
                                  color: sel ? Colors.black : Colors.white70,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                                onSelected: (_) {
                                  setState(() => _selectedExercise = item['key']!);
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          Text('reminders.repeat_goal'.tr(), style: TextStyle(color: Colors.white54, fontSize: 11)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            children: [10, 15, 20, 30, 50].map((reps) {
                              final sel = _targetReps == reps;
                              return ChoiceChip(
                                label: Text('$reps ta'),
                                selected: sel,
                                selectedColor: const Color(0xFF3B9BFF),
                                backgroundColor: const Color(0xFF131929),
                                labelStyle: TextStyle(
                                  color: sel ? Colors.black : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (_) => setState(() => _targetReps = reps),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── Date & Time Row ──────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF5BC8FA)),
                          label: Text(
                            DateFormat('d MMMM, yyyy', context.locale.languageCode).format(_selectedDate),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0x33FFFFFF)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickTime,
                          icon: const Icon(Icons.alarm_rounded, size: 16, color: Color(0xFF5BC8FA)),
                          label: Text(
                            DateFormat('HH:mm').format(_selectedDate),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0x33FFFFFF)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Repeat Mode
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('reminders.repeat_label'.tr(), style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          _RepeatOption(
                            label: 'Bir marta',
                            selected: _repeatType == RepeatType.once,
                            onTap: () => setState(() => _repeatType = RepeatType.once),
                          ),
                          const SizedBox(width: 6),
                          _RepeatOption(
                            label: 'Har kuni',
                            selected: _repeatType == RepeatType.daily,
                            onTap: () => setState(() => _repeatType = RepeatType.daily),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFFFF0055), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Save Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5BC8FA),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : Text(
                              _isEditing ? 'Saqlash' : '🎯 Maqsadni Tasdiqlash',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalTypeTab extends StatelessWidget {
  const _GoalTypeTab({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: activeColor, width: 1.5) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? activeColor : Colors.white54, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepeatOption extends StatelessWidget {
  const _RepeatOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF5BC8FA) : const Color(0xFF131929),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
