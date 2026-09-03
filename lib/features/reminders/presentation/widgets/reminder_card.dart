import 'package:easy_localization/easy_localization.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/reminder.dart';
import '../providers/reminders_provider.dart';
import '../screens/add_reminder_screen.dart';

/// A rich Goal Card supporting Focus Timer, AI Vision Camera Exercise, and Simple Notes.
class ReminderCard extends ConsumerStatefulWidget {
  const ReminderCard({
    super.key,
    required this.reminder,
    required this.index,
  });

  final Reminder reminder;
  final int index;

  @override
  ConsumerState<ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends ConsumerState<ReminderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkController;
  late Animation<double> _checkScale;
  late Animation<double> _checkOpacity;
  bool _visible = false;

  @override
  void initState() {
    super.initState();

    _checkController = AnimationController(
      vsync: this,
      duration: AppMotion.fade,
    );
    _checkScale = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );
    _checkOpacity = CurvedAnimation(
      parent: _checkController,
      curve: AppMotion.enter,
    );

    if (widget.reminder.isCompleted) {
      _checkController.value = 1.0;
    }

    final delay = Duration(
      milliseconds: math.min(40 * widget.index, 320),
    );
    Future.delayed(delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  Future<void> _toggleComplete() async {
    final r = widget.reminder;
    if (r.isCompleted) return;

    if (r.isFocusGoal) {
      context.push(AppRoutes.strictDiscipline, extra: r.id);
      return;
    } else if (r.isExerciseGoal) {
      context.push(
        '/exercise/camera',
        extra: {
          'exerciseType': r.exerciseType ?? 'SQUAT',
          'targetReps': r.targetReps ?? 20,
          'reminderId': r.id,
        },
      );
      return;
    }

    await _checkController.forward();
    if (!mounted) return;

    try {
      await ref.read(remindersProvider.notifier).markCompleted(r.id);
    } catch (e) {
      _checkController.reverse();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xato: $e')),
        );
      }
    }
  }

  String _formattedDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final day = DateTime(dt.year, dt.month, dt.day);

    final time = DateFormat('HH:mm').format(dt);
    if (day == today) return 'Bugun, $time';
    if (day == tomorrow) return 'Ertaga, $time';
    return DateFormat('d MMM, HH:mm', 'uz').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final r = widget.reminder;

    return AnimatedOpacity(
      duration: AppMotion.fade,
      curve: AppMotion.enter,
      opacity: _visible ? 1.0 : 0.0,
      child: AnimatedSlide(
        duration: AppMotion.page,
        curve: AppMotion.enter,
        offset: _visible ? Offset.zero : const Offset(0, 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Dismissible(
            key: ValueKey(r.id),
            direction: DismissDirection.endToStart,
            background: _SwipeDeleteBackground(colors: colors),
            confirmDismiss: (dir) => _confirmDelete(context),
            onDismissed: (_) => _onDelete(),
            child: _GoalCardContent(
              reminder: r,
              formattedDate: _formattedDate(r.dateTime),
              checkScale: _checkScale,
              checkOpacity: _checkOpacity,
              onToggle: _toggleComplete,
              onEdit: () => RemindersSheet.show(context, existing: widget.reminder),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121826),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E283D), width: 1),
        ),
        title: const Text(
          'Maqsadni o‘chirish',
          style: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.bold),
        ),
        content: Text(
          '"${widget.reminder.title}" maqsadini o‘chirmoqchimisiz?',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr(), style: const TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF43F5E),
              foregroundColor: Colors.white,
            ),
            child: const Text('O‘chirish'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _onDelete() {
    ref.read(remindersProvider.notifier).deleteReminder(widget.reminder.id);
  }
}

class _GoalCardContent extends StatelessWidget {
  const _GoalCardContent({
    required this.reminder,
    required this.formattedDate,
    required this.checkScale,
    required this.checkOpacity,
    required this.onToggle,
    required this.onEdit,
  });

  final Reminder reminder;
  final String formattedDate;
  final Animation<double> checkScale;
  final Animation<double> checkOpacity;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final isFocus = reminder.isFocusGoal;
    final isExercise = reminder.isExerciseGoal;

    final Color badgeColor = isFocus
        ? const Color(0xFF38BDF8)
        : (isExercise ? const Color(0xFF8B5CF6) : const Color(0xFFF59E0B));

    final IconData badgeIcon = isFocus
        ? Icons.timer_outlined
        : (isExercise ? Icons.videocam_rounded : Icons.edit_note_rounded);

    final String badgeText = isFocus
        ? '🎯 Fokus (${reminder.durationMinutes} min)'
        : (isExercise
            ? '🏋️ Mashq (${reminder.targetReps ?? 20} ta ${reminder.exerciseType ?? "Squat"})'
            : '📝 Eslatma');

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF121826),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: reminder.isCompleted
                ? const Color(0xFF10B981).withValues(alpha: 0.4)
                : const Color(0xFF1E283D),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Type Badge + Time + Checkbox
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2335),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF222B40), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, color: badgeColor, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  formattedDate,
                  style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                if (reminder.isCompleted || (!isFocus && !isExercise && !reminder.isPast))
                  GestureDetector(
                    onTap: reminder.isCompleted ? null : onToggle,
                    behavior: HitTestBehavior.opaque,
                    child: _CheckCircle(
                      isCompleted: reminder.isCompleted,
                      scaleAnim: checkScale,
                      opacityAnim: checkOpacity,
                      primaryColor: const Color(0xFF3A7FCC),
                      borderColor: Colors.white24,
                    ),
                  )
                else if (reminder.isPast && !reminder.isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0x33FF0055),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFF0055)),
                    ),
                    child: const Text(
                      'O\'tkazib yuborildi',
                      style: TextStyle(color: Color(0xFFFF0055), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              reminder.title,
              style: TextStyle(
                color: reminder.isCompleted ? Colors.white38 : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(height: 12),

            // Mode-specific Action Buttons
            if (!reminder.isCompleted && !reminder.isPast) ...[
              if (isFocus)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Launch Deep Focus / Strict Discipline Screen
                          context.push(AppRoutes.strictDiscipline, extra: reminder.id);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4AADDC),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: Text(
                          '${reminder.durationMinutes} daqiqa Fokusni Boshlash 🚀',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                )
              else if (isExercise)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Launch AI Vision Camera screen
                          context.push(
                            '/exercise/camera',
                            extra: {
                              'exerciseType': reminder.exerciseType ?? 'SQUAT',
                              'targetReps': reminder.targetReps ?? 20,
                              'reminderId': reminder.id,
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A7FCC),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.videocam_rounded, size: 18),
                        label: Text(
                          '📸 AI Kamera orqali bajarish (${reminder.targetReps ?? 20} ta)',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({
    required this.isCompleted,
    required this.scaleAnim,
    required this.opacityAnim,
    required this.primaryColor,
    required this.borderColor,
  });

  final bool isCompleted;
  final Animation<double> scaleAnim;
  final Animation<double> opacityAnim;
  final Color primaryColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.fade,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted ? primaryColor : Colors.transparent,
        border: Border.all(
          color: isCompleted ? primaryColor : borderColor,
          width: 2,
        ),
      ),
      child: isCompleted
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.black)
          : null,
    );
  }
}

class _SwipeDeleteBackground extends StatelessWidget {
  const _SwipeDeleteBackground({required this.colors});

  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFF0055),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 6),
          Text(
            'common.delete'.tr(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
