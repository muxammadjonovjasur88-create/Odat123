import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_repository.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/reflection_repository.dart';

/// A gentle, optional post-session reflection shown on the Goal Reached screen.
///
/// It renders as a calm, tappable card — the actual text inputs live in a
/// modal bottom sheet ([showReflectionSheet]), NOT inline. That keeps the text
/// fields out of Goal Reached's centered `IntrinsicHeight` layout (where an
/// `EditableText`'s inherited dependencies can be torn down out of order, which
/// crashes with an `_dependents.isEmpty` assertion), and lets the sheet resize
/// cleanly around the keyboard.
class ReflectionPrompt extends StatelessWidget {
  const ReflectionPrompt({super.key, required this.taskTitle});

  final String taskTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      color: colors.tintSage,
      onTap: () => showReflectionSheet(context, taskTitle: taskTitle),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.eco_rounded, size: 20, color: colors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'growth.gentle_moment_reflect'.tr(),
                  style: AppTextStyles.label.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'growth.reflect_card_subtitle'.tr(),
                  style: AppTextStyles.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
        ],
      ),
    );
  }
}

/// Opens the reflection questions in a keyboard-aware bottom sheet. Both fields
/// are optional; saving writes the note, skipping just closes.
Future<void> showReflectionSheet(
  BuildContext context, {
  required String taskTitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _ReflectionSheet(taskTitle: taskTitle),
  );
}

class _ReflectionSheet extends ConsumerStatefulWidget {
  const _ReflectionSheet({required this.taskTitle});

  final String taskTitle;

  @override
  ConsumerState<_ReflectionSheet> createState() => _ReflectionSheetState();
}

class _ReflectionSheetState extends ConsumerState<_ReflectionSheet> {
  final _wentWell = TextEditingController();
  final _distraction = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _wentWell.dispose();
    _distraction.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final wentWell = _wentWell.text.trim();
    final distraction = _distraction.text.trim();
    // Nothing written → treat Save like Skip.
    if (wentWell.isEmpty && distraction.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    if (uid != null) {
      try {
        await ref
            .read(reflectionRepositoryProvider)
            .save(
              uid,
              taskTitle: widget.taskTitle,
              wentWell: wentWell,
              distraction: distraction,
            );
      } catch (_) {
        // A reflection failing to save shouldn't disrupt the calm moment.
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('growth.thanks_for_reflecting'.tr())),
      );
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
            'growth.gentle_moment_reflect'.tr(),
            style: AppTextStyles.h2.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'growth.reflect_sheet_subtitle'.tr(),
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          AppInput(
            controller: _wentWell,
            label: 'growth.what_went_well'.tr(),
            hint: 'growth.what_went_well_hint'.tr(),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 14),
          AppInput(
            controller: _distraction,
            label: 'growth.what_distracted'.tr(),
            hint: 'growth.what_distracted_hint'.tr(),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'common.save'.tr(),
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'growth.skip'.tr(),
                  variant: AppButtonVariant.secondary,
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
