import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  bool _battery = false;

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
    final battery = await _service.hasIgnoreBatteryOptimizationsPermission();
    if (!mounted) return;
    setState(() {
      _accessibility = accessibility;
      _usage = usage;
      _overlay = overlay;
      _miui = miui;
      _battery = battery;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: const FlowaAppBar(showBackButton: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'perm.intro'.tr(),
              style: AppTextStyles.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 24),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  _PermissionTile(
                    icon: Icons.battery_charging_full_rounded,
                    title: 'Batareya optimallashtirish',
                    description: 'Sozlamalar ochilgach, \'Odat\'ni toping va yoqing.',
                    granted: _battery,
                    onGrant: () async {
                      await _service.requestIgnoreBatteryOptimizationsPermission();
                      _refresh();
                    },
                  ),
                  Divider(height: 1, color: colors.border, indent: 16, endIndent: 16),
                  _PermissionTile(
                    icon: Icons.layers_outlined,
                    title: 'Boshqa ilovalar ustida ko\'rsatish',
                    description: 'Sozlamalar ochilgach, \'Odat\'ni toping va yoqing.',
                    granted: _overlay,
                    onGrant: _service.requestOverlayPermission,
                  ),
                  Divider(height: 1, color: colors.border, indent: 16, endIndent: 16),
                  _PermissionTile(
                    icon: Icons.visibility_outlined,
                    title: 'Foydalanish statistikasi',
                    description: 'Sozlamalar ochilgach, \'Odat\'ni toping va yoqing.',
                    granted: _usage,
                    onGrant: _service.openUsageAccessSettings,
                  ),
                  Divider(height: 1, color: colors.border, indent: 16, endIndent: 16),
                  _PermissionTile(
                    icon: Icons.accessibility_new_rounded,
                    title: 'Maxsus imkoniyatlar',
                    description: 'Sozlamalar ochilgach, \'Odat\'ni toping va yoqing.',
                    granted: _accessibility,
                    onGrant: _service.openAccessibilitySettings,
                  ),
                  if (_miui) ...[
                    Divider(height: 1, color: colors.border, indent: 16, endIndent: 16),
                    _PermissionTile(
                      icon: Icons.open_in_new_rounded,
                      title: 'Miui Pop-up',
                      description: 'Sozlamalar ochilgach, \'Odat\'ni toping va yoqing.',
                      granted: null,
                      onGrant: _service.openMiuiOtherPermissions,
                    ),
                    Divider(height: 1, color: colors.border, indent: 16, endIndent: 16),
                    _PermissionTile(
                      icon: Icons.restart_alt_rounded,
                      title: 'Avtomatik ishga tushish',
                      description: 'Sozlamalar ochilgach, \'Odat\'ni toping va yoqing.',
                      granted: null,
                      onGrant: _service.openAutostartSettings,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
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
  final bool? granted;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isGranted = granted == true;
    final statusColor = isGranted ? const Color(0xFF22C55E) : colors.primary;

    return InkWell(
      onTap: onGrant,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.label.copyWith(
                      color: colors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    description,
                    style: AppTextStyles.caption.copyWith(
                      color: colors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (granted != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isGranted ? Colors.transparent : statusColor.withValues(alpha: 0.1),
                  border: isGranted ? Border.all(color: statusColor.withValues(alpha: 0.5)) : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGranted ? Icons.check_rounded : Icons.add_rounded,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isGranted ? 'Berilgan' : 'Yoqish',
                      style: AppTextStyles.caption.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
