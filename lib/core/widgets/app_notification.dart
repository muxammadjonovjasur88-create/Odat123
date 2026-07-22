import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// A beautiful, zen-style snack notification with optional icon and actions.
class AppNotification extends StatelessWidget {
  const AppNotification({
    super.key,
    required this.message,
    this.icon,
    this.type = NotificationType.neutral,
    this.duration = const Duration(seconds: 3),
  });

  final String message;
  final IconData? icon;
  final NotificationType type;
  final Duration duration;

  /// Shows this notification using ScaffoldMessenger.
  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    NotificationType type = NotificationType.neutral,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(_buildSnackBar(
        message: message,
        icon: icon,
        type: type,
      ));
  }

  static SnackBar _buildSnackBar({
    required String message,
    IconData? icon,
    required NotificationType type,
  }) {
    return SnackBar(
      content: AppNotification(
        message: message,
        icon: icon,
        type: type,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bgColor = _bgColor(colors);
    final textColor = _textColor(colors);
    final iconColor = _iconColor(colors);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _borderColor(colors),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.body.copyWith(color: textColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _bgColor(AppColorScheme colors) {
    return switch (type) {
      NotificationType.success => colors.primary.withValues(alpha: 0.1),
      NotificationType.error => const Color(0xFFB3504B).withValues(alpha: 0.1),
      NotificationType.warning => const Color(0xFFFFA500).withValues(alpha: 0.1),
      NotificationType.neutral => colors.surface,
    };
  }

  Color _textColor(AppColorScheme colors) {
    return switch (type) {
      NotificationType.success => colors.primary,
      NotificationType.error => const Color(0xFFB3504B),
      NotificationType.warning => const Color(0xFFFFA500),
      NotificationType.neutral => colors.textPrimary,
    };
  }

  Color _iconColor(AppColorScheme colors) {
    return switch (type) {
      NotificationType.success => colors.primary,
      NotificationType.error => const Color(0xFFB3504B),
      NotificationType.warning => const Color(0xFFFFA500),
      NotificationType.neutral => colors.textSecondary,
    };
  }

  Color _borderColor(AppColorScheme colors) {
    return switch (type) {
      NotificationType.success => colors.primary.withValues(alpha: 0.3),
      NotificationType.error => const Color(0xFFB3504B).withValues(alpha: 0.3),
      NotificationType.warning => const Color(0xFFFFA500).withValues(alpha: 0.3),
      NotificationType.neutral => colors.border,
    };
  }
}

enum NotificationType { success, error, warning, neutral }
