import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/models/reminder.dart';
import '../providers/reminders_provider.dart';

/// Bottom sheet for creating or editing a [Reminder].
///
/// Call via [RemindersSheet.show].
class RemindersSheet extends ConsumerStatefulWidget {
  const RemindersSheet({super.key, this.existing});

  /// Pass a reminder to pre-fill the form for editing.
  final Reminder? existing;

  static Future<void> show(BuildContext context, {Reminder? existing}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => RemindersSheet(existing: existing),
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

  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
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
    } else {
      // Round up to next 15-minute mark.
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

  // ── Date / time pickers ───────────────────────────────────────────────────

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

  Widget _datePickerTheme(BuildContext context, Widget? child) {
    final colors = context.colors;
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: colors.primary,
          surface: colors.surface,
          onSurface: colors.textPrimary,
        ),
      ),
      child: child!,
    );
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Validate: one-time reminders must be in the future.
    if (_repeatType == RepeatType.once &&
        _selectedDate.isBefore(DateTime.now())) {
      setState(() => _errorMessage = 'Vaqt o\'tib ketgan. Kelajakdagi vaqt tanlang.');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final notifier = ref.read(remindersProvider.notifier);
      if (_isEditing) {
        final updated = widget.existing!.copyWith(
          title: _titleController.text.trim(),
          dateTime: _selectedDate,
          repeatType: _repeatType,
        );
        await notifier.editReminder(updated);
      } else {
        await notifier.add(
          title: _titleController.text.trim(),
          dateTime: _selectedDate,
          repeatType: _repeatType,
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomPad = MediaQuery.viewInsetsOf(context).bottom;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: colors.border, width: 0.8),
            ),
          ),
          padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomPad),
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
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title
                Text(
                  _isEditing ? 'Eslatmani tahrirlash' : 'Yangi eslatma',
                  style: AppTextStyles.h2.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: 20),

                // ── Title field ──────────────────────────────────────────
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 120,
                  decoration: InputDecoration(
                    hintText: 'Eslatma matni…',
                    hintStyle: TextStyle(color: colors.textTertiary),
                    counterStyle: TextStyle(color: colors.textTertiary),
                    filled: true,
                    fillColor: colors.surfaceMuted,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: AppTextStyles.body.copyWith(color: colors.textPrimary),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Sarlavha kiriting' : null,
                  onFieldSubmitted: (_) => _save(),
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'^\s+')),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Quick Select ──────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _RepeatChip(
                        label: 'Bugun',
                        selected: _isToday(_selectedDate),
                        colors: colors,
                        onTap: () {
                          final now = DateTime.now();
                          setState(() {
                            _selectedDate = DateTime(
                              now.year,
                              now.month,
                              now.day,
                              _selectedDate.hour,
                              _selectedDate.minute,
                            );
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _RepeatChip(
                        label: 'Ertaga',
                        selected: _isTomorrow(_selectedDate),
                        colors: colors,
                        onTap: () {
                          final now = DateTime.now();
                          final tomorrow = now.add(const Duration(days: 1));
                          setState(() {
                            _selectedDate = DateTime(
                              tomorrow.year,
                              tomorrow.month,
                              tomorrow.day,
                              _selectedDate.hour,
                              _selectedDate.minute,
                            );
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Date & Time row ──────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _PickerTile(
                        icon: Icons.calendar_today_rounded,
                        label: _formatDate(_selectedDate),
                        colors: colors,
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PickerTile(
                        icon: Icons.access_time_rounded,
                        label: _formatTime(_selectedDate),
                        colors: colors,
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Repeat ────────────────────────────────────────────────
                Text(
                  'TAKRORLANISH',
                  style: AppTextStyles.overline.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: RepeatType.values.map((type) {
                    final selected = _repeatType == type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _RepeatChip(
                        label: _repeatLabel(type),
                        selected: selected,
                        colors: colors,
                        onTap: () => setState(() => _repeatType = type),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // ── Error message ─────────────────────────────────────────
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _errorMessage!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: const Color(0xFFFF5252),
                      ),
                    ),
                  ),

                // ── Save button ───────────────────────────────────────────
                AppButton(
                  label: _isEditing ? 'Saqlash' : 'Eslatma qo\'shish',
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                  expand: true,
                  icon: _isEditing ? Icons.save_rounded : Icons.add_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return 'Bugun';
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (dt.day == tomorrow.day &&
        dt.month == tomorrow.month &&
        dt.year == tomorrow.year) {
      return 'Ertaga';
    }
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _repeatLabel(RepeatType type) {
    switch (type) {
      case RepeatType.once:
        return 'Bir marta';
      case RepeatType.daily:
        return 'Har kuni';
      case RepeatType.weekly:
        return 'Har hafta';
    }
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  bool _isTomorrow(DateTime dt) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return dt.year == tomorrow.year && dt.month == tomorrow.month && dt.day == tomorrow.day;
  }
}

// ── Date / time picker tile ───────────────────────────────────────────────

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final AppColorScheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.tap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.label.copyWith(color: colors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Repeat chip ────────────────────────────────────────────────────────────

class _RepeatChip extends StatelessWidget {
  const _RepeatChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final AppColorScheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.subtle,
        curve: AppMotion.standard,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? colors.primaryGradient : null,
          color: selected ? null : colors.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.transparent : colors.border,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.chip.copyWith(
            color: selected ? Colors.white : colors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
