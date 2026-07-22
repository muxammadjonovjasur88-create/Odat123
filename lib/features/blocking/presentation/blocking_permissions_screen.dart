import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/blocking_service.dart';

/// Permissions screen — explains and requests the permissions app blocking
/// needs. The Accessibility service is the primary detector; on MIUI (Xiaomi)
/// the overlay also needs background pop-up + autostart, or blocking silently
/// fails.
class BlockingPermissionsScreen extends ConsumerStatefulWidget {
  const BlockingPermissionsScreen({super.key});

  @override
  ConsumerState<BlockingPermissionsScreen> createState() =>
      _BlockingPermissionsScreenState();
}

class _BlockingPermissionsScreenState
    extends ConsumerState<BlockingPermissionsScreen>
    with WidgetsBindingObserver {
  bool _accessibility = false;
  bool _usage = false;
  bool _overlay = false;
  bool _miui = false;

  BlockingService get _service => ref.read(blockingServiceProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check after the user returns from a system settings screen.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final accessibility = await _service.isAccessibilityEnabled();
    final usage = await _service.hasUsageAccess();
    final overlay = await _service.canDrawOverlays();
    final miui = await _service.isMiui();
    if (!mounted) return;
    setState(() {
      _accessibility = accessibility;
      _usage = usage;
      _overlay = overlay;
      _miui = miui;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text('perm.title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'perm.intro'.tr(),
              style: AppTextStyles.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 24),
            _PermissionTile(
              icon: Icons.accessibility_new_rounded,
              title: 'perm.accessibility_title'.tr(),
              description: 'perm.accessibility_desc'.tr(),
              granted: _accessibility,
              onGrant: _service.openAccessibilitySettings,
            ),
            _PermissionTile(
              icon: Icons.layers_outlined,
              title: 'perm.overlay_title'.tr(),
              description: 'perm.overlay_desc'.tr(),
              granted: _overlay,
              onGrant: _service.requestOverlayPermission,
            ),
            if (_miui) ...[
              _PermissionTile(
                icon: Icons.open_in_new_rounded,
                title: 'perm.miui_popup_title'.tr(),
                description: 'perm.miui_popup_desc'.tr(),
                granted: null,
                onGrant: _service.openMiuiOtherPermissions,
              ),
              _PermissionTile(
                icon: Icons.restart_alt_rounded,
                title: 'perm.miui_autostart_title'.tr(),
                description: 'perm.miui_autostart_desc'.tr(),
                granted: null,
                onGrant: _service.openAutostartSettings,
              ),
            ],
            _PermissionTile(
              icon: Icons.visibility_outlined,
              title: 'perm.usage_title'.tr(),
              description: 'perm.usage_desc'.tr(),
              granted: _usage,
              onGrant: _service.openUsageAccessSettings,
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('perm.refresh_status'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
    required this.onGrant,
  });

  final IconData icon;
  final String title;
  final String description;

  /// null = no detectable status (e.g. MIUI settings); just an action.
  final bool? granted;
  final Future<void> Function() onGrant;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isGranted = granted == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.h3.copyWith(color: colors.textPrimary),
                  ),
                ),
                if (granted != null) _StatusBadge(granted: isGranted),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: isGranted ? 'perm.open_settings'.tr() : 'perm.open'.tr(),
              variant: isGranted
                  ? AppButtonVariant.secondary
                  : AppButtonVariant.primary,
              expand: false,
              onPressed: onGrant,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.granted});

  final bool granted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = granted ? colors.primary : colors.textTertiary;
    return Row(
      children: [
        Icon(
          granted ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          granted ? 'perm.granted'.tr() : 'perm.needed'.tr(),
          style: AppTextStyles.caption.copyWith(color: color),
        ),
      ],
    );
  }
}
