import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/growth_providers.dart';

/// The user's intention shown as the PRIMARY indicator — goal meaning over
/// points. When set: "{n} days until {goal} · {x}% of your plan done", with the
/// user's own "why" reflected back for intrinsic motivation. When unset: a gentle
/// invitation to set one.
class IntentionCard extends ConsumerWidget {
  const IntentionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final profile = ref.watch(userProfileProvider).asData?.value;
    if (profile == null) return const SizedBox.shrink();

    if (!profile.hasIntention) {
      return AppCard(
        onTap: () => showIntentionSheet(context, profile),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.tintSage,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.flag_outlined, color: colors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'growth.set_your_intention'.tr(),
                    style: AppTextStyles.label.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'growth.working_toward_why'.tr(),
                    style: AppTextStyles.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_rounded, color: colors.textSecondary),
          ],
        ),
      );
    }

    final planPct = (ref.watch(planProgressProvider) * 100).round();
    final days = profile.daysUntilGoal;

    return AppCard(
      onTap: () => showIntentionSheet(context, profile),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                days != null
                    ? (days > 0
                          ? (days == 1
                                ? 'growth.days_until_one'.tr(
                                    namedArgs: {'count': '$days'},
                                  )
                                : 'growth.days_until_many'.tr(
                                    namedArgs: {'count': '$days'},
                                  ))
                          : (days == 0
                                ? 'growth.goal_is_today'.tr()
                                : 'growth.goal_date_passed'.tr()))
                    : 'growth.your_intention'.tr(),
                style: AppTextStyles.label.copyWith(color: colors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            profile.goalTitle ?? '',
            style: AppTextStyles.h2.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 14),
          _PlanProgressBar(fraction: planPct / 100),
          const SizedBox(height: 8),
          Text(
            'growth.plan_done'.tr(namedArgs: {'percent': '$planPct'}),
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          if ((profile.goalWhy?.trim().isNotEmpty) ?? false) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.tintSage,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.favorite_outline_rounded,
                    size: 16,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      profile.goalWhy!.trim(),
                      style: AppTextStyles.body.copyWith(
                        color: colors.textPrimary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanProgressBar extends StatelessWidget {
  const _PlanProgressBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          Container(height: 10, color: colors.surfaceMuted),
          FractionallySizedBox(
            widthFactor: fraction.clamp(0.0, 1.0),
            child: Container(height: 10, color: colors.primary),
          ),
        ],
      ),
    );
  }
}

/// Opens the intention editor. Saves the goal, the user's own reason, and an
/// optional target date to their profile.
Future<void> showIntentionSheet(BuildContext context, UserProfile profile) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _SetIntentionSheet(profile: profile),
  );
}

class _SetIntentionSheet extends ConsumerStatefulWidget {
  const _SetIntentionSheet({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_SetIntentionSheet> createState() => _SetIntentionSheetState();
}

class _SetIntentionSheetState extends ConsumerState<_SetIntentionSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.profile.goalTitle ?? '',
  );
  late final TextEditingController _why = TextEditingController(
    text: widget.profile.goalWhy ?? '',
  );
  late DateTime? _date = widget.profile.goalTargetDate;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _why.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 14)),
      firstDate: now,
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save({bool clear = false}) async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .setAspiration(
            uid,
            title: clear ? null : _title.text.trim(),
            why: clear ? null : _why.text.trim(),
            targetDate: clear ? null : _date,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('growth.could_not_save'.tr())),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + insets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'growth.your_intention'.tr(),
            style: AppTextStyles.h2.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'growth.keep_reason_close'.tr(),
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          AppInput(
            controller: _title,
            label: 'growth.working_toward_label'.tr(),
            hint: 'growth.working_toward_hint'.tr(),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          AppInput(
            controller: _why,
            label: 'growth.why_label'.tr(),
            hint: 'growth.why_hint'.tr(),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          _FieldBox(
            label: 'growth.target_date_label'.tr(),
            value: _date == null
                ? 'growth.pick_a_date'.tr()
                : '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-'
                      '${_date!.day.toString().padLeft(2, '0')}',
            isPlaceholder: _date == null,
            onTap: _pickDate,
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'growth.save_intention'.tr(),
            loading: _saving,
            onPressed: _saving ? null : () => _save(),
          ),
          if (widget.profile.hasIntention) ...[
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: _saving ? null : () => _save(clear: true),
                child: Text(
                  'growth.clear_intention'.tr(),
                  style: AppTextStyles.label.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldBox extends StatelessWidget {
  const _FieldBox({
    required this.label,
    required this.value,
    required this.isPlaceholder,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool isPlaceholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.overline.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: 8),
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
                Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  value,
                  style: AppTextStyles.body.copyWith(
                    color: isPlaceholder
                        ? colors.textTertiary
                        : colors.textPrimary,
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
