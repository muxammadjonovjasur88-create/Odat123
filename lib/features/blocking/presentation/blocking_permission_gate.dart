import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../data/blocking_service.dart';

/// Which blocking prerequisite is missing (used internally by the dialog).
enum BlockingMissingPermission { detection, overlay }

/// Holds the result of a blocking permission check.
class BlockingPermissionStatus {
  const BlockingPermissionStatus({
    required this.hasAccessibility,
    required this.hasUsageAccess,
    required this.hasOverlay,
    required this.isMiui,
  });

  final bool hasAccessibility;
  final bool hasUsageAccess;
  final bool hasOverlay;
  final bool isMiui;

  /// Bloklash ISHLATILISHI uchun minimum zarur ruxsat:
  /// Accessibility YOKI UsageAccess (kamida biri) kerak + Overlay kerak.
  bool get canBlock => (hasAccessibility || hasUsageAccess) && hasOverlay;

  /// Foydalanuvchiga ko'rsatish kerak bo'lgan birinchi muammo.
  BlockingMissingPermission? get primaryIssue {
    if (!hasAccessibility && !hasUsageAccess) {
      return BlockingMissingPermission.detection;
    }
    if (!hasOverlay) return BlockingMissingPermission.overlay;
    return null;
  }
}

/// Checks all blocking-related permissions and returns the status.
/// Call this before starting a blocking session.
Future<BlockingPermissionStatus> checkBlockingPermissions(
  BlockingService service,
) async {
  final hasA11y = await service.isAccessibilityEnabled();
  final hasUsage = await service.hasUsageAccess();
  final hasOverlay = await service.canDrawOverlays();
  final isMiui = await service.isMiui();
  return BlockingPermissionStatus(
    hasAccessibility: hasA11y,
    hasUsageAccess: hasUsage,
    hasOverlay: hasOverlay,
    isMiui: isMiui,
  );
}

/// Shows a dialog if blocking permissions are missing, then either:
/// - Opens the relevant settings screen (user taps "Enable"), or
/// - Returns false so the caller can skip blocking entirely.
///
/// Returns `true` if all required permissions are already granted (no dialog
/// shown), or `false` if at least one is missing (dialog was shown).
///
/// The caller should wait for the return value and re-check permissions after
/// the user returns from settings, or simply proceed without blocking.
Future<bool> ensureBlockingPermissions(
  BuildContext context,
  WidgetRef ref, {
  bool silent = false,
}) async {
  final service = ref.read(blockingServiceProvider);
  final status = await checkBlockingPermissions(service);

  if (status.canBlock) return true;
  if (silent) return false;

  if (!context.mounted) return false;

  final issue = status.primaryIssue;
  if (issue == null) return true;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _BlockingPermissionDialog(
      issue: issue,
      service: service,
      isMiui: status.isMiui,
    ),
  );

  return false; // let the caller re-check after dialog
}

class _BlockingPermissionDialog extends StatelessWidget {
  const _BlockingPermissionDialog({
    required this.issue,
    required this.service,
    required this.isMiui,
  });

  final BlockingMissingPermission issue;
  final BlockingService service;
  final bool isMiui;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final (icon, title, body, buttonText, onPressed) = switch (issue) {
      BlockingMissingPermission.detection => (
          Icons.accessibility_new_rounded,
          'Accessibility xizmatini yoqing',
          'Odat bloklash funksiyasini ishlatish uchun '
              'Accessibility xizmatiga ruxsat kerak.\n\n'
              'Sozlamalar → Maxsus imkoniyatlar → Odat → Yoqish.',
          'SOZLAMALARNI OCHISH ⚙️',
          () async {
            Navigator.of(context).pop();
            await service.openAccessibilitySettings();
          },
        ),
      BlockingMissingPermission.overlay => (
          Icons.layers_rounded,
          '"Boshqa ilovalar ustiga chizish" ruxsati',
          'Bloklash ekrani chiqishi uchun Odat "Boshqa ilovalar ustiga '
              'chizish" ruxsatiga muhtoj.\n\n'
              'Sozlamalar → Ilova ruxsatlari → Maxsus ruxsatlar → '
              'Boshqa ilovalar ustiga chizish → Odat → Yoqish.',
          'RUXSATNI BERISH ✨',
          () async {
            Navigator.of(context).pop();
            await service.requestOverlayPermission();
          },
        ),
    };

    return AlertDialog(
      backgroundColor: const Color(0xFF090B18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFF4AADDC), width: 1.2)),
      icon: Icon(icon, color: const Color(0xFF4AADDC), size: 40),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
        textAlign: TextAlign.center,
      ),
      content: Text(
        body,
        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4AADDC),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Bloklashsiz davom etish',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
