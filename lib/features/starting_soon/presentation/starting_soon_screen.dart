import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/task.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../blocking/data/blocking_repository.dart';
import '../../blocking/domain/blockable_app.dart';
import '../../deep_focus/data/focus_providers.dart';
import '../../deep_focus/data/focus_service.dart';

/// Screen 10 — shown ~5 minutes before a task starts. Confirms the upcoming
/// focus block and that distracting apps will be paused. "I'm ready" arms the
/// native blocker until the task ends.
class StartingSoonScreen extends ConsumerWidget {
  const StartingSoonScreen({super.key, required this.task});

  final Task task;

  int get _minutesUntil {
    final diff = task.start.difference(DateTime.now()).inMinutes;
    return diff < 1 ? 1 : diff;
  }

  Future<void> _ready(BuildContext context, WidgetRef ref) async {
    // Start the background session now (countdown + blocking + notification).
    await beginBackgroundFocusNow(
      service: ref.read(focusServiceProvider),
      taskId: task.id,
      task: task,
      settings: ref.read(blockingSettingsProvider).asData?.value,
    );
    if (context.mounted) context.go(AppRoutes.deepFocus);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final settings = ref.watch(blockingSettingsProvider).asData?.value;
    final blockedApps = kBlockableApps
        .where((a) => settings?.isBlocked(a.packageName) ?? false)
        .toList();

    return Scaffold(
      body: SafeArea(
        child: FitOrScroll(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            children: [
              const Align(alignment: Alignment.centerLeft, child: BrandLogo()),
              const Spacer(),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow,
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.notifications_active_outlined,
                  color: colors.primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'soon.title'.tr(),
                style: AppTextStyles.h1.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                (_minutesUntil == 1
                        ? 'soon.starts_in_one'
                        : 'soon.starts_in_many')
                    .tr(
                      namedArgs: {
                        'title': task.title,
                        'count': '$_minutesUntil',
                      },
                    ),
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 28),
              _SanctuaryCard(apps: blockedApps),
              const Spacer(),
              AppButton(
                label: 'soon.im_ready'.tr(),
                onPressed: () => _ready(context, ref),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.pop(),
                child: Text(
                  'soon.not_now'.tr(),
                  style: AppTextStyles.label.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SanctuaryCard extends StatelessWidget {
  const _SanctuaryCard({required this.apps});

  final List<BlockableApp> apps;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppCard(
      color: colors.tintBlue,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        children: [
          Text(
            'soon.sanctuary_mode'.tr(),
            style: AppTextStyles.overline.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'soon.sanctuary_body'.tr(),
            style: AppTextStyles.label.copyWith(color: colors.textPrimary),
          ),
          if (apps.isNotEmpty) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 18,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                for (final app in apps.take(5))
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          app.icon,
                          color: colors.textSecondary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        app.name,
                        style: AppTextStyles.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
