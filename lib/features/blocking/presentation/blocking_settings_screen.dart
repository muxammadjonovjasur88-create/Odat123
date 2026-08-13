import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/router/nav_helpers.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/blocking_repository.dart';
import '../data/blocking_service.dart';
import '../domain/blocking_settings.dart';
import '../domain/installed_app.dart';

/// Screen 15 — choose which of the REAL installed apps to block during focus
/// sessions. The list comes from the device (native PackageManager); selections
/// are saved to Firestore and read by the native blocker when a session starts.
class BlockingSettingsScreen extends ConsumerStatefulWidget {
  const BlockingSettingsScreen({super.key});

  @override
  ConsumerState<BlockingSettingsScreen> createState() =>
      _BlockingSettingsScreenState();
}

class _BlockingSettingsScreenState
    extends ConsumerState<BlockingSettingsScreen> {
  String _query = '';
  Set<String> _optimisticBlocked = {};
  bool _isSaving = false;

  String? get _uid => ref.read(authStateProvider).asData?.value?.uid;

  Future<void> _save(BlockingSettings next) async {
    final uid = _uid;
    if (uid == null) return;
    
    // Store optimistic update for immediate UI feedback
    _optimisticBlocked = next.blockedPackages;
    
    try {
      setState(() => _isSaving = true);
      await ref.read(blockingRepositoryProvider).save(uid, next);
      // Invalidate the live provider so UI refreshes with the new state.
      ref.invalidate(blockingSettingsProvider);
    } catch (e) {
      if (mounted) {
        _optimisticBlocked = {};
        AppNotification.show(
          context,
          message: 'blocking.save_error'.tr(),
          icon: Icons.error_outline_rounded,
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final settings =
        ref.watch(blockingSettingsProvider).asData?.value ??
        const BlockingSettings();
    final appsAsync = ref.watch(installedAppsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('blocking.title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'blocking.permissions'.tr(),
            icon: const Icon(Icons.shield_outlined),
            onPressed: () => context.push(AppRoutes.blockingPermissions),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        current: AppNavTab.dashboard,
        onSelected: (tab) => goToTab(context, tab),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            // Make-it-work banner → permissions (accessibility + MIUI).
            AppCard(
              color: colors.tintBlue,
              onTap: () => context.push(AppRoutes.blockingPermissions),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'blocking.grant_permissions_banner'.tr(),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'blocking.help_me_focus'.tr(),
                          style: AppTextStyles.label.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'blocking.help_me_focus_sub'.tr(),
                          style: AppTextStyles.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch.adaptive(
                    value: settings.alwaysBlock,
                    activeTrackColor: colors.primary,
                    onChanged: (v) => _save(settings.copyWith(alwaysBlock: v)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Soft friction (default) vs hard block (strict mode, opt-in).
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      settings.strictMode
                          ? Icons.lock_rounded
                          : Icons.spa_rounded,
                      size: 20,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'blocking.strict_mode'.tr(),
                          style: AppTextStyles.label.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          settings.strictMode
                              ? 'blocking.strict_mode_on_sub'.tr()
                              : 'blocking.strict_mode_off_sub'.tr(),
                          style: AppTextStyles.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch.adaptive(
                    value: settings.strictMode,
                    activeTrackColor: colors.primary,
                    onChanged: (v) => _save(settings.copyWith(strictMode: v)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppInput(
              hint: 'blocking.search_apps'.tr(),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 16),
            Text(
              'blocking.choose_apps_hint'.tr(),
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            ...appsAsync.when(
              loading: () => const [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: FlowaLoading(size: 64)),
                ),
              ],
              error: (e, _) => [
                AppErrorView(
                  message: 'blocking.read_apps_error'.tr(),
                  onRetry: () => ref.invalidate(installedAppsProvider),
                ),
              ],
              data: (apps) {
                final q = _query.trim().toLowerCase();
                final filtered = q.isEmpty
                    ? apps
                    : apps
                          .where((a) => a.name.toLowerCase().contains(q))
                          .toList();
                if (filtered.isEmpty) {
                  return [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          q.isEmpty
                              ? 'blocking.no_apps_found'.tr()
                              : 'blocking.no_apps_match'.tr(
                                  namedArgs: {'query': _query},
                                ),
                          style: AppTextStyles.body.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ];
                }
                return [
                  for (final app in filtered)
                    _AppRow(
                      app: app,
                      blocked: _optimisticBlocked.isNotEmpty
                          ? _optimisticBlocked.contains(app.packageName)
                          : settings.isBlocked(app.packageName),
                      isLoading: _isSaving,
                      onChanged: (on) {
                        final next = {...settings.blockedPackages};
                        if (on) {
                          next.add(app.packageName);
                        } else {
                          next.remove(app.packageName);
                        }
                        _save(settings.copyWith(blockedPackages: next));
                      },
                    ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.app,
    required this.blocked,
    required this.onChanged,
    this.isLoading = false,
  });

  final InstalledApp app;
  final bool blocked;
  final ValueChanged<bool> onChanged;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 44,
                height: 44,
                child: app.icon != null
                    ? Image.memory(
                        app.icon!,
                        width: 44,
                        height: 44,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => const _FallbackIcon(),
                      )
                    : const _FallbackIcon(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                app.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label.copyWith(color: colors.textPrimary),
              ),
            ),
            Switch.adaptive(
              value: blocked,
              activeTrackColor: colors.primary,
              onChanged: isLoading ? null : onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      color: colors.surfaceMuted,
      child: Icon(Icons.android_rounded, color: colors.textSecondary, size: 22),
    );
  }
}
