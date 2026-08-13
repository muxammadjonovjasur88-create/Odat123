import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/uzbekistan_regions.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/auth_repository.dart';
import '../../../core/services/locale_store.dart';
import '../../../core/services/region_controller.dart';
import '../../../core/services/theme_mode_controller.dart';
import '../../../core/services/user_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../premium/data/premium_providers.dart';
import '../../streak/data/streak_repository.dart';
import 'feedback_sheet.dart';

/// Screen 19 — settings: profile summary, notifications, theme, blocking
/// preferences, timer styles, and logout.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final profile = ref.watch(userProfileProvider).asData?.value;
    final themeMode = ref.watch(themeModeProvider);
    final isDark =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final since = profile?.createdAt?.year ?? DateTime.now().year;

    return Scaffold(
      appBar: const FlowaAppBar(showBackButton: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AvatarCircle(
                    avatarKey: profile?.avatar ?? 'leaf',
                    size: 48,
                    photoBase64: profile?.photoBase64,
                    photoUrl: profile?.photoUrl,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.name ?? 'settings.member_default'.tr(),
                          style: AppTextStyles.h3.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'settings.member_since'.tr(
                            namedArgs: {'year': '$since'},
                          ),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _SectionLabel('settings.experience'.tr()),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  _Row(
                    icon: Icons.language_rounded,
                    title: 'settings.language'.tr(),
                    subtitle: localeNativeName(context.locale.languageCode),
                    onTap: () => _showLanguageSheet(context),
                  ),
                  Divider(
                    height: 1,
                    color: colors.border,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _ThemeRow(
                    isDark: isDark,
                    onChanged: (dark) => ref
                        .read(themeModeProvider.notifier)
                        .set(dark ? ThemeMode.dark : ThemeMode.light),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _SectionLabel('settings.focus_controls'.tr()),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  _Row(
                    icon: Icons.security_rounded,
                    title: '🔐 ${'perm.title'.tr()}',
                    subtitle: 'perm.manage_desc'.tr(),
                    onTap: () => context.push(AppRoutes.blockingPermissions),
                  ),
                  Divider(
                    height: 1,
                    color: colors.border,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _Row(
                    icon: Icons.app_blocking_rounded,
                    title: 'settings.blocking'.tr(),
                    subtitle: 'settings.blocking_sub'.tr(),
                    onTap: () => context.push(AppRoutes.blocking),
                  ),
                  Divider(
                    height: 1,
                    color: colors.border,
                    indent: 16,
                    endIndent: 16,
                  ),
                  _Row(
                    icon: Icons.help_outline_rounded,
                    title: 'Yordam va taklif',
                    subtitle: 'Fikr-mulohaza yoki muammo haqida yozing',
                    onTap: () => showFeedbackSheet(context),
                  ),
                ],
              ),
            ),
            if (ref.watch(premiumEnabledProvider)) ...[
              const SizedBox(height: 22),
              _SectionLabel('Premium'),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _Row(
                  icon: Icons.workspace_premium_rounded,
                  title: ref.watch(isPremiumProvider)
                      ? 'Flowa Premium ✓'
                      : 'Flowa Premium',
                  subtitle: ref.watch(isPremiumProvider)
                      ? 'Premium is active — thank you 🌿'
                      : 'Unlock unlimited AI, deep stats & more',
                  onTap: () => context.push(
                    ref.read(isPremiumProvider)
                        ? AppRoutes.premiumStats
                        : AppRoutes.paywall,
                  ),
                ),
              ),
            ],

            // --- Joylashuv bo'limi ---
            const SizedBox(height: 22),
            _SectionLabel('Joylashuv'),
            _LocationSection(),

            const SizedBox(height: 28),
            Center(
              child: TextButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: Text(
                  'settings.logout'.tr(),
                  style: AppTextStyles.label.copyWith(
                    color: const Color(0xFFB3504B),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {

  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.overline.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: colors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.label.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
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
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.isDark, required this.onChanged});

  final bool isDark;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.brightness_6_outlined, size: 22, color: colors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'settings.theme'.tr(),
                  style: AppTextStyles.label.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'settings.theme_current'.tr(
                    namedArgs: {
                      'mode': isDark
                          ? 'settings.mode_dark'.tr()
                          : 'settings.mode_light'.tr(),
                    },
                  ),
                  style: AppTextStyles.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isDark,
            activeTrackColor: colors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Opens the language picker. Selecting a language switches the whole app
/// immediately (easy_localization rebuilds the tree) and persists the choice
/// to Hive so it survives a restart.
void _showLanguageSheet(BuildContext context) {
  final colors = context.colors;
  final current = context.locale.languageCode;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'settings.language'.tr(),
                style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: 6),
          for (final locale in kSupportedLocales)
            _LanguageOption(
              code: locale.languageCode,
              selected: locale.languageCode == current,
              onTap: () {
                Navigator.of(sheetContext).pop();
                // Switch + persist; the app rebuilds in the new language.
                context.setLocale(locale);
                LocaleStore.save(locale.languageCode);
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.code,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                localeNativeName(code),
                style: AppTextStyles.label.copyWith(
                  color: selected ? colors.primary : colors.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, color: colors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Debug-only controls to test the streak freeze + milestone logic without
/// waiting real days. Only built in debug mode.
// ignore: unused_element
class _StreakDebugPanel extends ConsumerWidget {
  const _StreakDebugPanel();

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    String done,
    Future<void> Function(StreakRepository repo, String uid) action,
  ) async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;
    await action(ref.read(streakRepositoryProvider), uid);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(done)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    Widget btn(
      String label,
      String done,
      Future<void> Function(StreakRepository, String) a,
    ) {
      return OutlinedButton(
        onPressed: () => _run(context, ref, done, a),
        child: Text(label),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set the streak to N, then finish one task to hit the N+1 '
            'milestone. Use “simulate missed day” then “apply refresh” to '
            'watch a freeze get consumed (or the streak reset at 0 freezes).',
            style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              btn(
                'Streak → 2',
                'Streak set to 2',
                (r, u) => r.debugSetStreak(u, 2),
              ),
              btn(
                'Streak → 6',
                'Streak set to 6',
                (r, u) => r.debugSetStreak(u, 6),
              ),
              btn(
                'Streak → 29',
                'Streak set to 29',
                (r, u) => r.debugSetStreak(u, 29),
              ),
              btn(
                'Streak → 99',
                'Streak set to 99',
                (r, u) => r.debugSetStreak(u, 99),
              ),
              btn(
                '+1 freeze',
                'Freeze added',
                (r, u) => r.debugAddFreezes(u, 1),
              ),
              btn(
                'Simulate missed day',
                'Missed day set',
                (r, u) => r.debugSimulateMissedDay(u),
              ),
              btn('Apply refresh', 'Refreshed', (r, u) => r.refresh(u)),
              btn(
                'Clear badges',
                'Badges cleared',
                (r, u) => r.debugClearBadges(u),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _LocationSection — viloyat ko'rsatish va yangilash (Settings ichida)
// ---------------------------------------------------------------------------

class _LocationSection extends ConsumerWidget {
  const _LocationSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final regionState = ref.watch(regionControllerProvider);

    final (String subtitle, Color subtitleColor) = switch (regionState.status) {
      RegionStatus.initial => ('Aniqlanmagan', colors.textSecondary),
      RegionStatus.loading => ('Aniqlanmoqda...', AppColors.cyanAccent),
      RegionStatus.loaded => (
          regionState.region?.displayName ?? "Noma'lum",
          AppColors.cyanAccent,
        ),
      RegionStatus.unavailable => (
          regionState.errorMessage ?? 'Viloyat aniqlanmadi',
          colors.textSecondary,
        ),
    };

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          // Region display row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 22,
                  color: colors.primary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sizning viloyatingiz',
                        style: AppTextStyles.label.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (regionState.status == RegionStatus.loading)
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: AppColors.cyanAccent,
                              ),
                            )
                          else
                            Icon(
                              regionState.status == RegionStatus.loaded
                                  ? Icons.check_circle_rounded
                                  : Icons.info_outline_rounded,
                              size: 12,
                              color: subtitleColor,
                            ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              subtitle,
                              style: AppTextStyles.caption.copyWith(
                                color: subtitleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border, indent: 16, endIndent: 16),
          // Refresh GPS button
          InkWell(
            onTap: regionState.status == RegionStatus.loading
                ? null
                : () => ref
                    .read(regionControllerProvider.notifier)
                    .detectAndSave(),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.gps_fixed_rounded, size: 22, color: colors.primary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Joylashuvni yangilash',
                          style: AppTextStyles.label.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'GPS orqali viloyatni qayta aniqlash',
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
            ),
          ),
          // Manual region pick (fallback)
          if (regionState.status == RegionStatus.unavailable) ...{
            Divider(
                height: 1, color: colors.border, indent: 16, endIndent: 16),
            _ManualRegionRow(
              onPick: (r) =>
                  ref.read(regionControllerProvider.notifier).setManually(r),
            ),
          },
        ],
      ),
    );
  }
}

class _ManualRegionRow extends StatelessWidget {
  const _ManualRegionRow({required this.onPick});

  final ValueChanged<UzRegion> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PopupMenuButton<UzRegion>(
      onSelected: onPick,
      color: const Color(0xFF1F2638),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => UzRegion.values
          .map(
            (r) => PopupMenuItem(
              value: r,
              child: Text(
                r.displayName,
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
              ),
            ),
          )
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.list_rounded, size: 22, color: colors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Qo\'lda tanlash',
                    style: AppTextStyles.label
                        .copyWith(color: colors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'GPS ishlamaganda ro\'yxatdan tanlang',
                    style: AppTextStyles.caption
                        .copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}
