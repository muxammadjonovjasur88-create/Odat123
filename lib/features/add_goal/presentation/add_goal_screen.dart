import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_category.dart';
import '../../../core/models/task.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/task_repository.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/widgets.dart';
import '../../blocking/data/blocking_repository.dart';
import '../../deep_focus/data/focus_providers.dart';
import '../../deep_focus/data/focus_service.dart';
import '../../notifications/data/notification_service.dart';
import '../../workout/domain/workout.dart';
import '../../workout/presentation/workout_builder.dart';
import '../data/task_actions.dart';

/// Screen 09 — create OR edit a goal. With no [existing] task it's a create
/// form (Manual + AI tabs) that persists to Firestore; with an [existing] task
/// it's an edit form pre-filled with that task's values (Manual only), with a
/// delete option. Saving reschedules the task's reminder + background session.
class AddGoalScreen extends ConsumerStatefulWidget {
  const AddGoalScreen({super.key, this.existing});

  /// The task being edited, or null when creating a new one.
  final Task? existing;

  @override
  ConsumerState<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends ConsumerState<AddGoalScreen> {
  static const _categories = [
    AppCategory.study,
    AppCategory.sport,
    AppCategory.work,
    AppCategory.personal,
  ];
  static const _reminderOptions = <int?>[null, 5, 10, 15, 30];

  final _titleController = TextEditingController();
  // Focus duration inputs (entered by the user).
  final _workController = TextEditingController(
    text: '25',
  ); // deep-work minutes
  final _intervalWorkController = TextEditingController(
    text: '45',
  ); // sport sec
  final _setsController = TextEditingController(text: '4'); // sport sets
  bool _manual = true;
  AppCategory _category = AppCategory.study;
  DateTime? _date;
  TimeOfDay? _time;

  /// When set, the user picked an explicit end time → duration comes from the
  /// start→end range (vs an automatic duration).
  TimeOfDay? _endTime;
  bool _useEndTime = false;

  bool _blockApps = false;
  int? _reminderMinutes = 10;
  bool _saving = false;

  // ---- Goal duration fields ----
  /// 'days' = chip/number mode, 'until' = date-picker mode.
  String _durationMode = 'days';

  /// Quick-select days chip value (1,3,7,14,30) or null for custom.
  int? _quickDays;

  /// Custom number of days entered by the user.
  final _customDaysController = TextEditingController();

  /// "Until" date selected via date picker.
  DateTime? _goalEndDate;

  /// Resolves the effective goal duration in days (null = not set).
  int? get _effectiveGoalDays {
    if (_durationMode == 'days') {
      if (_quickDays != null) return _quickDays;
      final v = int.tryParse(_customDaysController.text.trim());
      return (v != null && v > 0) ? v : null;
    } else {
      // 'until' mode: compute from date to _goalEndDate (inclusive).
      final start = _date;
      final end = _goalEndDate;
      if (start == null || end == null) return null;
      final diff = end.difference(start).inDays + 1;
      return diff > 0 ? diff : null;
    }
  }

  DateTime? get _effectiveGoalEndDate {
    if (_durationMode == 'until') return _goalEndDate;
    final days = _effectiveGoalDays;
    final start = _date;
    if (days == null || start == null) return null;
    return start.add(Duration(days: days - 1));
  }

  /// Sport tasks: structured set-based workout (exercises × sets) vs the simple
  /// interval timer.
  bool _structuredSets = false;
  WorkoutPlan? _workoutPlan;

  bool get _usingWorkout => _isInterval && _structuredSets;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    if (t == null) return;
    // Pre-fill every field from the task being edited.
    _manual = true;
    _titleController.text = t.title;
    _category = t.category;
    _date = t.date;
    _time = t.startTime;
    final endMinute = t.startMinute + t.durationMinutes;
    _endTime = TimeOfDay(hour: (endMinute ~/ 60) % 24, minute: endMinute % 60);
    _blockApps = t.blockApps;
    _reminderMinutes = t.reminderMinutesBefore;
    _workController.text = '${t.workMinutes}';
    _intervalWorkController.text = '${t.intervalWorkSeconds}';
    _setsController.text = '${t.intervalSets}';
    if (t.hasWorkout) {
      _structuredSets = true;
      _workoutPlan = t.workout;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _workController.dispose();
    _intervalWorkController.dispose();
    _setsController.dispose();
    _customDaysController.dispose();
    super.dispose();
  }

  /// Sport/interval timer when the category is Sport (or the user's focus type
  /// is Sport) — matches the Focus screen's decision.
  bool get _isInterval {
    final focusType = ref.read(userProfileProvider).asData?.value?.focusType;
    return _category == AppCategory.sport || focusType == 'Sport';
  }

  int get _workMinutes =>
      (int.tryParse(_workController.text) ?? 25).clamp(5, 180);
  int get _intervalWorkSeconds =>
      (int.tryParse(_intervalWorkController.text) ?? 45).clamp(10, 600);
  int get _intervalSets =>
      (int.tryParse(_setsController.text) ?? 4).clamp(1, 20);

  Future<void> _pickGoalEndDate() async {
    final now = DateTime.now();
    final initial = _goalEndDate ?? (_date ?? now).add(const Duration(days: 6));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: (_date ?? now).add(const Duration(days: 1)),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _goalEndDate = picked);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickEndTime() async {
    final start = _time;
    final fallback = start == null
        ? const TimeOfDay(hour: 10, minute: 0)
        : TimeOfDay(hour: (start.hour + 1) % 24, minute: start.minute);
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? fallback,
    );
    if (picked != null) setState(() => _endTime = picked);
  }

  /// Minutes between start and end, or null if not a valid forward range.
  int? get _rangeMinutes {
    final s = _time;
    final e = _endTime;
    if (s == null || e == null) return null;
    final start = s.hour * 60 + s.minute;
    final end = e.hour * 60 + e.minute;
    return end > start ? end - start : null;
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return _snack('addgoal.error_no_title'.tr(), isError: true);
    if (_date == null) return _snack('addgoal.error_no_date'.tr(), isError: true);
    if (_time == null) return _snack('addgoal.error_no_start'.tr(), isError: true);

    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;

    if (_usingWorkout && !(_workoutPlan?.isValid ?? false)) {
      return _snack('addgoal.error_no_exercise'.tr(), isError: true);
    }

    if (_useEndTime) {
      if (_endTime == null) return _snack('addgoal.error_no_end'.tr(), isError: true);
      if (_rangeMinutes == null) {
        return _snack('addgoal.error_end_before_start'.tr(), isError: true);
      }
    }

    final task = Task.manual(
      title: title,
      category: _category,
      date: _date!,
      startMinute: _time!.hour * 60 + _time!.minute,
      isInterval: _isInterval,
      workMinutes: _workMinutes,
      intervalWorkSeconds: _intervalWorkSeconds,
      intervalSets: _intervalSets,
      blockApps: _blockApps,
      reminderMinutesBefore: _reminderMinutes,
      workout: _usingWorkout ? _workoutPlan : null,
      rangeMinutes: _useEndTime ? _rangeMinutes : null,
      goalStartDate: _date,
      goalEndDate: _effectiveGoalEndDate,
      goalDurationDays: _effectiveGoalDays,
    );

    setState(() => _saving = true);
    try {
      if (_editing) {
        await _update(uid, task);
      } else {
        await _insert(uid, task);
      }
      if (mounted) {
        _snack(
          _editing
              ? 'addgoal.goal_updated'.tr()
              : 'addgoal.goal_created'.tr(),
        );
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('addgoal.error_save'.tr(), isError: true);
      }
    }
  }

  /// Creates a brand-new task and schedules its reminder + background auto-start.
  Future<void> _insert(String uid, Task task) async {
    final days = task.goalDurationDays ?? 1;
    for (int i = 0; i < days; i++) {
      final currentDay = task.date.add(Duration(days: i));
      final dailyTask = task.copyWith(date: currentDay);
      final id = await ref.read(taskRepositoryProvider).addTask(uid, dailyTask);
      
      // Schedule the 5-min-before reminder now (delivered even if the app is
      // closed); the id is content-based, so this de-dupes with the watcher.
      await ref.read(notificationServiceProvider).scheduleTaskReminder(dailyTask);
      
      // Background auto-start applies only to time-driven sessions. A set-based
      // workout is user-driven (you have to be there to do the reps), so it
      // isn't scheduled to start in the background.
      if (!dailyTask.hasWorkout) {
        await scheduleBackgroundFocus(
          service: ref.read(focusServiceProvider),
          taskId: id,
          task: dailyTask,
          settings: ref.read(blockingSettingsProvider).asData?.value,
        );
      }
    }
  }

  /// Overwrites the edited task in Firestore (preserving completion + creation
  /// time) and reschedules its reminder + background session to the new values.
  Future<void> _update(String uid, Task task) async {
    final existing = widget.existing!;
    final updated = task.copyWith(
      id: existing.id,
      isCompleted: existing.isCompleted,
      pointsAwarded: existing.pointsAwarded,
    );
    await ref
        .read(taskRepositoryProvider)
        .updateTask(uid, existing.id, updated);
    await syncTaskSchedule(ref, updated, previous: existing);
  }

  Future<void> _confirmDelete() async {
    final t = widget.existing;
    if (t == null) return;
    final ok = await confirmDeleteTask(context, title: t.title);
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await deleteTaskCompletely(ref, t);
      if (mounted) {
        _snack('addgoal.goal_deleted'.tr(), isError: false);
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('addgoal.error_delete'.tr(), isError: true);
      }
    }
  }

  void _snack(String message, {bool isError = false}) {
    AppNotification.show(
      context,
      message: message,
      icon: isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
      type: isError ? NotificationType.error : NotificationType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing ? 'addgoal.title_edit'.tr() : 'addgoal.title_new'.tr(),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The Manual/AI toggle is only for creating; editing is manual.
              if (!_editing) ...[
                _SegmentedTabs(
                  manual: _manual,
                  onChanged: (m) => setState(() => _manual = m),
                ),
                const SizedBox(height: 24),
              ],
              if (_manual) _manualForm(colors) else _aiPanel(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _manualForm(AppColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Label('addgoal.goal_title'.tr()),
              const SizedBox(height: 10),
              AppInput(
                controller: _titleController,
                hint: 'addgoal.goal_title_hint'.tr(),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 22),
              _Label('addgoal.category'.tr()),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in _categories)
                    AppChip.category(
                      c,
                      selected: _category == c,
                      onTap: () => setState(() => _category = c),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _FieldBox(
                      label: 'addgoal.date'.tr(),
                      value: _date == null ? 'mm/dd/yy' : _formatDate(_date!),
                      isPlaceholder: _date == null,
                      icon: Icons.calendar_today_rounded,
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _FieldBox(
                      label: 'addgoal.start'.tr(),
                      value: _time == null
                          ? '--:-- --'
                          : formatHm12(_time!.hour * 60 + _time!.minute),
                      isPlaceholder: _time == null,
                      icon: Icons.schedule_rounded,
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'addgoal.set_end_time'.tr(),
                          style: AppTextStyles.label.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _useEndTime
                              ? 'addgoal.end_time_on'.tr()
                              : 'addgoal.end_time_off'.tr(),
                          style: AppTextStyles.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _useEndTime,
                    activeTrackColor: colors.primary,
                    onChanged: (v) => setState(() => _useEndTime = v),
                  ),
                ],
              ),
              if (_useEndTime) ...[
                const SizedBox(height: 12),
                _FieldBox(
                  label: 'addgoal.end'.tr(),
                  value: _endTime == null
                      ? '--:-- --'
                      : formatHm12(_endTime!.hour * 60 + _endTime!.minute),
                  isPlaceholder: _endTime == null,
                  icon: Icons.schedule_rounded,
                  onTap: _pickEndTime,
                ),
                const SizedBox(height: 10),
                _autoNote(
                  colors,
                  Icons.timelapse_rounded,
                  _rangeMinutes == null
                      ? 'addgoal.pick_end_after_start'.tr()
                      : 'addgoal.duration_note'.tr(
                          namedArgs: {'min': '${_rangeMinutes!}'},
                        ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _goalDurationCard(colors),
        const SizedBox(height: 16),
        _BlockToggle(
          value: _blockApps,
          onChanged: (v) => setState(() => _blockApps = v),
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Label('addgoal.reminder'.tr()),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final option in _reminderOptions)
                    AppChip(
                      label: option == null
                          ? 'addgoal.reminder_none'.tr()
                          : 'addgoal.reminder_min'.tr(
                              namedArgs: {'min': '$option'},
                            ),
                      selected: _reminderMinutes == option,
                      onTap: () => setState(() => _reminderMinutes = option),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_isInterval) ...[
          const SizedBox(height: 16),
          _sportSection(colors),
        ] else if (!_useEndTime) ...[
          const SizedBox(height: 16),
          _deepWorkCard(colors),
        ],
        const SizedBox(height: 28),
        AppButton(
          label: _editing
              ? 'addgoal.save_changes'.tr()
              : 'addgoal.create_goal'.tr(),
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
        if (_editing) ...[
          const SizedBox(height: 6),
          Center(
            child: TextButton.icon(
              onPressed: _saving ? null : _confirmDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: Color(0xFFB3504B),
              ),
              label: Text(
                'addgoal.delete_goal'.tr(),
                style: AppTextStyles.label.copyWith(
                  color: const Color(0xFFB3504B),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Goal duration card ────────────────────────────────────────────────────

  static const _quickDayOptions = [1, 3, 7, 14, 30];

  Widget _goalDurationCard(AppColorScheme colors) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('addgoal.duration_how_long'.tr()),
          const SizedBox(height: 12),
          // Mode toggle
          Row(
            children: [
              _DurationModeChip(
                label: 'addgoal.duration_mode_days'.tr(),
                selected: _durationMode == 'days',
                onTap: () => setState(() => _durationMode = 'days'),
                colors: colors,
              ),
              const SizedBox(width: 10),
              _DurationModeChip(
                label: 'addgoal.duration_mode_until'.tr(),
                selected: _durationMode == 'until',
                onTap: () => setState(() => _durationMode = 'until'),
                colors: colors,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_durationMode == 'days') ..._buildDaysSection(colors)
          else ..._buildUntilSection(colors),
        ],
      ),
    );
  }

  List<Widget> _buildDaysSection(AppColorScheme colors) {
    return [
      Text(
        'addgoal.duration_days_label'.tr(),
        style: AppTextStyles.body.copyWith(color: colors.textSecondary),
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final d in _quickDayOptions)
            _DayChip(
              days: d,
              selected: _quickDays == d,
              colors: colors,
              onTap: () => setState(() {
                _quickDays = d;
                _customDaysController.clear();
              }),
            ),
          // "Other" custom input chip
          _CustomDayChip(
            controller: _customDaysController,
            selected: _quickDays == null && _customDaysController.text.isNotEmpty,
            colors: colors,
            onTap: () => setState(() => _quickDays = null),
            onChanged: (_) => setState(() => _quickDays = null),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildUntilSection(AppColorScheme colors) {
    final dateStr = _goalEndDate == null
        ? 'addgoal.duration_pick_date'.tr()
        : _formatDate(_goalEndDate!);
    return [
      Text(
        'addgoal.duration_until_label'.tr(),
        style: AppTextStyles.body.copyWith(color: colors.textSecondary),
      ),
      const SizedBox(height: 14),
      _FieldBox(
        label: 'addgoal.duration_end_date'.tr(),
        value: dateStr,
        isPlaceholder: _goalEndDate == null,
        icon: Icons.event_rounded,
        onTap: _pickGoalEndDate,
      ),
      if (_effectiveGoalDays != null) ...[
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              Icons.timelapse_rounded,
              size: 16,
              color: colors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              'addgoal.duration_days_note'.tr(
                namedArgs: {'count': '${_effectiveGoalDays!}'},
              ),
              style: AppTextStyles.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    ];
  }

  /// Deep-work session: user types the focus minutes; break is auto.
  Widget _deepWorkCard(AppColorScheme colors) {
    final breakMin = Task.autoBreakMinutes(_workMinutes);
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('addgoal.focus_duration'.tr()),
          const SizedBox(height: 12),
          SizedBox(
            width: 160,
            child: AppInput(
              label: 'addgoal.minutes'.tr(),
              controller: _workController,
              hint: '25',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 14),
          _autoNote(
            colors,
            Icons.local_cafe_outlined,
            'addgoal.break_note'.tr(namedArgs: {'min': '$breakMin'}),
          ),
        ],
      ),
    );
  }

  /// Sport: pick structured set-based workout or the simple interval timer.
  Widget _sportSection(AppColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppCategory.sport.fill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.format_list_numbered_rounded,
                  size: 20,
                  color: AppCategory.sport.foreground,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'addgoal.structured_sets'.tr(),
                      style: AppTextStyles.label.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'addgoal.structured_sets_hint'.tr(),
                      style: AppTextStyles.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _structuredSets,
                activeTrackColor: colors.primary,
                onChanged: (v) => setState(() => _structuredSets = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_structuredSets)
          WorkoutBuilder(
            initialPlan: widget.existing?.workout,
            onChanged: (p) => _workoutPlan = p,
          )
        else
          _intervalCard(colors),
      ],
    );
  }

  /// Sport interval: user types work seconds + sets; rest is auto.
  Widget _intervalCard(AppColorScheme colors) {
    final rest = Task.autoRestSeconds(_intervalWorkSeconds);
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('addgoal.interval_training'.tr()),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppInput(
                  label: 'addgoal.work_sec'.tr(),
                  controller: _intervalWorkController,
                  hint: '45',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AppInput(
                  label: 'addgoal.sets'.tr(),
                  controller: _setsController,
                  hint: '4',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _autoNote(
            colors,
            Icons.air_rounded,
            'addgoal.rest_note'.tr(namedArgs: {'sec': '$rest'}),
          ),
        ],
      ),
    );
  }

  Widget _autoNote(AppColorScheme colors, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _aiPanel(AppColorScheme colors) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 44, color: colors.primary),
          const SizedBox(height: 18),
          Text(
            'addgoal.ai_title'.tr(),
            style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 10),
          Text(
            'addgoal.ai_subtitle'.tr(),
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'addgoal.ai_open'.tr(),
            icon: Icons.arrow_forward_rounded,
            onPressed: () => context.push(AppRoutes.aiPlanner),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.month)}/${two(d.day)}/${two(d.year % 100)}';
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.manual, required this.onChanged});

  final bool manual;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _seg(context, 'addgoal.tab_manual'.tr(), manual, () => onChanged(true)),
          _seg(
            context,
            'addgoal.tab_ai'.tr(),
            !manual,
            () => onChanged(false),
          ),
        ],
      ),
    );
  }

  Widget _seg(
    BuildContext context,
    String label,
    bool active,
    VoidCallback onTap,
  ) {
    final colors = context.colors;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: active ? colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: colors.shadow,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.label.copyWith(
                color: active ? colors.textPrimary : colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.overline.copyWith(
        color: context.colors.textSecondary,
      ),
    );
  }
}

class _FieldBox extends StatelessWidget {
  const _FieldBox({
    required this.label,
    required this.value,
    required this.isPlaceholder,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool isPlaceholder;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: colors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      color: isPlaceholder
                          ? colors.textTertiary
                          : colors.textPrimary,
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

// ─────────────────────────────────────────────────────────────────────────────
// Duration picker helper widgets
// ─────────────────────────────────────────────────────────────────────────────

/// A mode-selector pill (e.g. "Necha kun" / "Qachongacha").
class _DurationModeChip extends StatelessWidget {
  const _DurationModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surfaceMuted,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: selected ? Colors.white : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// A quick-select day chip (1, 3, 7, 14, 30 days).
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.days,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final int days;
  final bool selected;
  final AppColorScheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$days',
              style: AppTextStyles.h3.copyWith(
                color: selected ? Colors.white : colors.textPrimary,
                fontSize: 20,
              ),
            ),
            Text(
              'kun',
              style: AppTextStyles.caption.copyWith(
                color: selected ? Colors.white70 : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A "boshqa" chip that expands into a number input field.
class _CustomDayChip extends StatelessWidget {
  const _CustomDayChip({
    required this.controller,
    required this.selected,
    required this.colors,
    required this.onTap,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool selected;
  final AppColorScheme colors;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? colors.primary.withValues(alpha: 0.12) : colors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? colors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 44,
              child: TextField(
                controller: controller,
                onTap: onTap,
                onChanged: onChanged,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: selected ? colors.primary : colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: '...',
                  hintStyle: AppTextStyles.body.copyWith(
                    color: colors.textTertiary,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'kun',
              style: AppTextStyles.caption.copyWith(
                color: selected ? colors.primary : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockToggle extends StatelessWidget {
  const _BlockToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppCategory.sport.fill,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.do_not_disturb_on_outlined,
              size: 20,
              color: AppCategory.sport.foreground,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'addgoal.block_distractions'.tr(),
                  style: AppTextStyles.label.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'addgoal.block_distractions_hint'.tr(),
                  style: AppTextStyles.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: colors.primary,
          ),
        ],
      ),
    );
  }
}
