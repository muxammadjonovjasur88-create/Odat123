import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/reminder.dart';
import '../providers/reminders_provider.dart';
import '../screens/add_reminder_screen.dart';

/// A single reminder card with:
/// * Slide + fade entrance animation (driven by [index]).
/// * Checkmark micro-animation on completion.
/// * Swipe-to-dismiss (handled by the parent [Dismissible]).
/// * Repeat badge and status colour coded by state.
class ReminderCard extends ConsumerStatefulWidget {
  const ReminderCard({
    super.key,
    required this.reminder,
    required this.index,
  });

  final Reminder reminder;

  /// Position in the list — used to stagger the entrance animation.
  final int index;

  @override
  ConsumerState<ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends ConsumerState<ReminderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkController;
  late Animation<double> _checkScale;
  late Animation<double> _checkOpacity;

  // Entrance slide+fade driven by index stagger.
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

    // Stagger entrance: delay by 40ms × index, clamped to 320ms max.
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

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _toggleComplete() async {
    final r = widget.reminder;
    if (r.isCompleted) return; // already done — no undo in this version

    // Animate checkmark immediately for snappy feel.
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

  Color _statusColor(AppColorScheme c, Reminder r) {
    if (r.isCompleted) return c.primary;
    if (r.isPast) return const Color(0xFFFF5252);
    return c.textSecondary;
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

  String _repeatBadge(RepeatType type) {
    switch (type) {
      case RepeatType.once:
        return '';
      case RepeatType.daily:
        return 'Har kuni';
      case RepeatType.weekly:
        return 'Har hafta';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final r = widget.reminder;
    final statusColor = _statusColor(colors, r);
    final repeatLabel = _repeatBadge(r.repeatType);

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
            child: _CardContent(
              reminder: r,
              colors: colors,
              statusColor: statusColor,
              repeatLabel: repeatLabel,
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
        backgroundColor: context.colors.surface,
        title: Text(
          'Eslatmani o\'chirish',
          style: AppTextStyles.h3.copyWith(color: context.colors.textPrimary),
        ),
        content: Text(
          '"${widget.reminder.title}" eslatmasini o\'chirmoqchimisiz?',
          style: AppTextStyles.body.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Bekor qilish',
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'O\'chirish',
              style: TextStyle(color: Color(0xFFFF5252)),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _onDelete() {
    ref.read(remindersProvider.notifier).deleteReminder(widget.reminder.id).catchError(
      (Object e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('O\'chirishda xato: $e')),
          );
        }
        return null;
      },
    );
  }
}

// ── Sub-widget: Card content ──────────────────────────────────────────────

class _CardContent extends StatelessWidget {
  const _CardContent({
    required this.reminder,
    required this.colors,
    required this.statusColor,
    required this.repeatLabel,
    required this.formattedDate,
    required this.checkScale,
    required this.checkOpacity,
    required this.onToggle,
    required this.onEdit,
  });

  final Reminder reminder;
  final AppColorScheme colors;
  final Color statusColor;
  final String repeatLabel;
  final String formattedDate;
  final Animation<double> checkScale;
  final Animation<double> checkOpacity;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    // A nice accent line on the left to indicate urgency.
    final bool isUrgent = !reminder.isCompleted &&
        reminder.dateTime.difference(DateTime.now()).inHours < 2 &&
        !reminder.isPast;

    final Color accentColor = reminder.isCompleted
        ? colors.border
        : (reminder.isPast
            ? const Color(0xFFFF5252)
            : (isUrgent ? colors.primary : colors.tintSage));

    final String timeStr = DateFormat('HH:mm').format(reminder.dateTime);
    final String dateStr = formattedDate.split(',').first;

    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Accent Line
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left side: Time and Date
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              timeStr,
                              style: AppTextStyles.h2.copyWith(
                                color: reminder.isCompleted
                                    ? colors.textSecondary
                                    : colors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateStr,
                              style: AppTextStyles.caption.copyWith(
                                color: reminder.isCompleted
                                    ? colors.border
                                    : colors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        // Divider
                        Container(
                          width: 1,
                          height: 40,
                          color: colors.border,
                        ),
                        const SizedBox(width: 14),

                        // Title & meta
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                reminder.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.h3.copyWith(
                                  color: reminder.isCompleted
                                      ? colors.textSecondary
                                      : colors.textPrimary,
                                  decoration: reminder.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  fontSize: 16,
                                ),
                              ),
                              if (repeatLabel.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                _RepeatBadge(
                                  label: repeatLabel,
                                  primary: colors.primary,
                                  tintSage: colors.tintSage,
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Animated check button
                        GestureDetector(
                          onTap: onToggle,
                          behavior: HitTestBehavior.opaque,
                          child: _CheckCircle(
                            isCompleted: reminder.isCompleted,
                            scaleAnim: checkScale,
                            opacityAnim: checkOpacity,
                            primaryColor: colors.primary,
                            borderColor: reminder.isPast ? const Color(0xFFFF5252) : colors.border,
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Edit popup menu
                        if (!reminder.isCompleted)
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert_rounded,
                                size: 18,
                                color: colors.textSecondary,
                              ),
                              color: colors.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: colors.border, width: 0.6),
                              ),
                              padding: EdgeInsets.zero,
                              onSelected: (value) {
                                if (value == 'edit') onEdit();
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_rounded,
                                          size: 16, color: colors.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Tahrirlash',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: colors.textPrimary,
                                        ),
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sub-widget: Animated check circle ────────────────────────────────────


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
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Empty circle border.
          AnimatedOpacity(
            duration: AppMotion.subtle,
            opacity: isCompleted ? 0.0 : 1.0,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 1.6),
              ),
            ),
          ),
          // Filled check circle (animated in).
          ScaleTransition(
            scale: scaleAnim,
            child: FadeTransition(
              opacity: opacityAnim,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [primaryColor, AppColors.purpleAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widget: Repeat badge ──────────────────────────────────────────────

class _RepeatBadge extends StatelessWidget {
  const _RepeatBadge({
    required this.label,
    required this.primary,
    required this.tintSage,
  });

  final String label;
  final Color primary;
  final Color tintSage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: tintSage,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.overline.copyWith(
          color: primary,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Sub-widget: Swipe delete background ──────────────────────────────────

class _SwipeDeleteBackground extends StatelessWidget {
  const _SwipeDeleteBackground({required this.colors});

  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5252).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_rounded, color: Color(0xFFFF5252), size: 26),
          SizedBox(height: 2),
          Text(
            "O'chirish",
            style: TextStyle(
              color: Color(0xFFFF5252),
              fontSize: 11,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}
