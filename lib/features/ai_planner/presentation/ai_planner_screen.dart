import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/router/nav_helpers.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/widgets.dart';
import '../../premium/data/premium_providers.dart';
import '../../premium/domain/premium.dart';
import '../domain/planned_task.dart';
import 'ai_planner_controller.dart';

/// Screen 11 — the "Zen Schedule" AI planner. The user describes their day,
/// Gemini (via the Cloud Function) proposes a schedule, and they can accept,
/// prune, or regenerate it.
class AiPlannerScreen extends ConsumerStatefulWidget {
  const AiPlannerScreen({super.key});

  @override
  ConsumerState<AiPlannerScreen> createState() => _AiPlannerScreenState();
}

class _AiPlannerScreenState extends ConsumerState<AiPlannerScreen> {
  final _goalController = TextEditingController();
  bool _editing = false;

  /// Optional planning span the user picked; null = auto-detect from the goal.
  int? _days;


  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  void _generate() {
    FocusScope.of(context).unfocus();
    setState(() => _editing = false);
    ref
        .read(aiPlannerControllerProvider.notifier)
        .generate(
          _goalController.text,
          days: _days,
          locale: context.locale.languageCode,
        );
  }

  /// Fills the input with a tapped example prompt.
  void _fillExample(String text) {
    setState(() {
      _goalController.text = text;
      _goalController.selection = TextSelection.collapsed(offset: text.length);
    });
  }

  Future<void> _acceptAll() async {
    final ok = await ref.read(aiPlannerControllerProvider.notifier).acceptAll();
    if (ok && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('aiplan.schedule_set'.tr())));
      context.go(AppRoutes.dailyPlan);
    }
  }

  /// The result area below the input, keyed by [AiPlanState.status] so the
  /// surrounding [AnimatedSwitcher] can cross-fade between states.
  Widget _resultSection(AppColorScheme colors, AiPlanState state) {
    switch (state.status) {
      case AiPlanStatus.loading:
        return _LoadingState(colors: colors, progressText: state.progressText);
      case AiPlanStatus.limitReached:
        return _LimitReachedCard(
          onUpgrade: () => context.push(AppRoutes.paywall),
        );
      case AiPlanStatus.error:
        return _ErrorState(
          message: state.errorMessage ?? 'aiplan.error_generic'.tr(),
          onRetry: _generate,
        );
      case AiPlanStatus.ready:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.warnings.isNotEmpty) ...[
              _WarningsCard(warnings: state.warnings),
              const SizedBox(height: 16),
            ],
            _SchedulePreview(
              plan: state.plan,
              editing: _editing,
              onRemove: (i) =>
                  ref.read(aiPlannerControllerProvider.notifier).removeAt(i),
            ),
            const SizedBox(height: 20),
            _Actions(
              accepting: state.accepting,
              canAccept: state.plan.isNotEmpty,
              editing: _editing,
              onAccept: _acceptAll,
              onEdit: () => setState(() => _editing = !_editing),
              onRegenerate: () =>
                  ref.read(aiPlannerControllerProvider.notifier).regenerate(),
            ),
          ],
        );
      case AiPlanStatus.idle:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(aiPlannerControllerProvider);
    final profile = ref.watch(userProfileProvider).asData?.value;
    // Show the free-quota hint only while the premium system is on and the user
    // is free.
    final showQuota =
        ref.watch(premiumEnabledProvider) && !ref.watch(isPremiumProvider);
    final remaining = ref.watch(aiPlansRemainingProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.addGoal),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 2,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      bottomNavigationBar: AppBottomNav(
        current: AppNavTab.focus,
        onSelected: (tab) => goToTab(context, tab),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const BrandLogo(),
                AvatarCircle(
                  avatarKey: profile?.avatar ?? 'leaf',
                  size: 40,
                  photoBase64: profile?.photoBase64,
                  photoUrl: profile?.photoUrl,
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'aiplan.title'.tr(),
                  style: AppTextStyles.label.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _GoalInputCard(
              controller: _goalController,
              loading: state.status == AiPlanStatus.loading,
              selectedDays: _days,
              onDaysChanged: (d) => setState(() => _days = d),
              onGenerate: _generate,
            ),
            if (showQuota) ...[
              const SizedBox(height: 10),
              _QuotaHint(remaining: remaining),
            ],
            const SizedBox(height: 14),
            _GuideCard(onExampleTap: _fillExample),
            const SizedBox(height: 24),
            // Gently cross-fade between loading / limit / error / ready instead
            // of popping the section in and out.
            AnimatedSwitcher(
              duration: context.reduceMotion ? Duration.zero : AppMotion.fade,
              switchInCurve: AppMotion.enter,
              switchOutCurve: AppMotion.exit,
              child: KeyedSubtree(
                key: ValueKey(state.status),
                child: _resultSection(colors, state),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalInputCard extends StatelessWidget {
  const _GoalInputCard({
    required this.controller,
    required this.loading,
    required this.selectedDays,
    required this.onDaysChanged,
    required this.onGenerate,
  });

  final TextEditingController controller;
  final bool loading;
  final int? selectedDays;
  final ValueChanged<int?> onDaysChanged;
  final VoidCallback onGenerate;

  // null = auto-detect span from the goal text.
  static const _dayOptions = <int?>[null, 1, 7, 30];

  /// Localized label for a planning-span option.
  static String _spanLabel(int? value) {
    if (value == null) return 'aiplan.span_auto'.tr();
    if (value == 1) return 'aiplan.span_today'.tr();
    return 'aiplan.span_days'.tr(namedArgs: {'count': '$value'});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            maxLines: 3,
            minLines: 2,
            style: AppTextStyles.body.copyWith(color: colors.textPrimary),
            cursorColor: colors.primary,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: 'aiplan.input_hint'.tr(),
              hintStyle: AppTextStyles.body.copyWith(
                color: colors.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'aiplan.plan_over'.tr(),
                style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final value in _dayOptions) ...[
                        AppChip(
                          label: _spanLabel(value),
                          selected: selectedDays == value,
                          onTap: () => onDaysChanged(value),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'aiplan.generate'.tr(),
              icon: Icons.auto_awesome_rounded,
              expand: false,
              loading: loading,
              onPressed: loading ? null : onGenerate,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small, calm tip card explaining the planner, with tappable example prompts
/// that fill the input. Mention a time frame, and list several goals at once.
class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.onExampleTap});

  final ValueChanged<String> onExampleTap;

  static const _exampleKeys = [
    'aiplan.example_1',
    'aiplan.example_2',
    'aiplan.example_3',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      color: colors.tintSage,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                size: 18,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'aiplan.how_it_works'.tr(),
                style: AppTextStyles.label.copyWith(color: colors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'aiplan.guide_body'.tr(),
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          for (final key in _exampleKeys) ...[
            _ExampleChip(text: key.tr(), onTap: () => onExampleTap(key.tr())),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  const _ExampleChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.north_east_rounded, size: 15, color: colors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchedulePreview extends StatelessWidget {
  const _SchedulePreview({
    required this.plan,
    required this.editing,
    required this.onRemove,
  });

  final List<PlannedTask> plan;
  final bool editing;
  final ValueChanged<int> onRemove;

  /// Builds the preview rows, inserting a day header before each new date when
  /// the plan spans multiple days.
  List<Widget> _scheduleItems(AppColorScheme colors) {
    final multiDay = plan.map((t) => _dayKey(t.date)).toSet().length > 1;
    final items = <Widget>[];
    String? prevKey;
    for (var i = 0; i < plan.length; i++) {
      final task = plan[i];
      final key = _dayKey(task.date);
      if (multiDay && key != prevKey) {
        if (items.isNotEmpty) items.add(const SizedBox(height: 18));
        items.add(_DayHeader(label: _dayLabel(task.date)));
        items.add(const SizedBox(height: 10));
        prevKey = key;
      } else if (i > 0) {
        items.add(Divider(height: 24, color: colors.border));
      }
      items.add(
        _PreviewRow(task: task, editing: editing, onRemove: () => onRemove(i)),
      );
    }
    return items;
  }

  static String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  static String _dayLabel(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    final d = DateUtils.dateOnly(date);
    final diff = d.difference(today).inDays;
    if (diff == 0) return 'aiplan.day_today'.tr();
    if (diff == 1) return 'aiplan.day_tomorrow'.tr();
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${wd[d.weekday - 1]}, ${mo[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Flexible so a long title wraps instead of pushing the chip off-screen.
            Flexible(
              child: Text(
                'aiplan.schedule_title'.tr(),
                style: AppTextStyles.h2.copyWith(color: colors.textPrimary),
              ),
            ),
            const SizedBox(width: 10),
            AppChip(
              label: 'aiplan.suggested'.tr(),
              fill: AppColors.studyFill,
              foreground: AppColors.studyText,
            ),
          ],
        ),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'aiplan.schedule_intro'.tr(),
                style: AppTextStyles.body.copyWith(
                  color: colors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 18),
              ..._scheduleItems(colors),
              if (plan.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'aiplan.no_tasks_left'.tr(),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.task,
    required this.editing,
    required this.onRemove,
  });

  final PlannedTask task;
  final bool editing;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 68,
          child: Text(
            formatHm12(task.startMinute),
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                '${formatDuration(task.durationMinutes)} • '
                '${task.category.label}',
                style: AppTextStyles.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              if (task.reasoning != null && task.reasoning!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 12,
                        color: colors.primary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          task.reasoning!,
                          style: AppTextStyles.caption.copyWith(
                            color: colors.textTertiary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (editing)
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.remove_circle_outline_rounded,
              size: 22,
              color: colors.textSecondary,
            ),
          )
        else
          Icon(Icons.drag_handle_rounded, size: 22, color: colors.textTertiary),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(Icons.event_rounded, size: 16, color: colors.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTextStyles.label.copyWith(color: colors.textPrimary),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.accepting,
    required this.canAccept,
    required this.editing,
    required this.onAccept,
    required this.onEdit,
    required this.onRegenerate,
  });

  final bool accepting;
  final bool canAccept;
  final bool editing;
  final VoidCallback onAccept;
  final VoidCallback onEdit;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppButton(
          label: 'aiplan.accept_all'.tr(),
          icon: Icons.check_circle_outline_rounded,
          loading: accepting,
          onPressed: (accepting || !canAccept) ? null : onAccept,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: editing ? 'common.done'.tr() : 'aiplan.edit'.tr(),
                icon: Icons.edit_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: accepting ? null : onEdit,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                label: 'aiplan.regenerate'.tr(),
                icon: Icons.refresh_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: accepting ? null : onRegenerate,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Small line under the input showing how many free AI plans remain today.
class _QuotaHint extends StatelessWidget {
  const _QuotaHint({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(Icons.bolt_outlined, size: 15, color: colors.textSecondary),
        const SizedBox(width: 6),
        Text(
          'premium.ai_quota_left'.tr(
            namedArgs: {
              'remaining': '$remaining',
              'total': '$kFreeAiPlansPerDay',
            },
          ),
          style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

/// Gentle "you've used today's free AI plans" card with a calm upgrade path.
class _LimitReachedCard extends StatelessWidget {
  const _LimitReachedCard({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      color: kPremiumGoldSoft,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            size: 36,
            color: kPremiumGold,
          ),
          const SizedBox(height: 14),
          Text(
            kAiLimitMessage.tr(),
            textAlign: TextAlign.center,
            style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'premium.ai_limit_body'.tr(),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'premium.start'.tr(),
            icon: Icons.spa_rounded,
            expand: false,
            onPressed: onUpgrade,
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.colors, this.progressText});

  final AppColorScheme colors;
  final String? progressText;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          const FlowaLoading(size: 72),
          const SizedBox(height: 18),
          Text(
            progressText ?? 'aiplan.crafting'.tr(),
            style: AppTextStyles.body.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: colors.textTertiary),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'common.retry'.tr(),
            icon: Icons.refresh_rounded,
            expand: false,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _WarningsCard extends StatelessWidget {
  const _WarningsCard({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.personalFill,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.personalText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'aiplan.warnings_title'.tr(),
                  style: AppTextStyles.label.copyWith(color: AppColors.personalText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < warnings.length; i++) ...[
            Text(
              warnings[i],
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.personalText),
            ),
            if (i < warnings.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}
