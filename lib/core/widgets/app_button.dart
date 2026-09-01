import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// Button variants used throughout Flowa's UI.
enum AppButtonVariant { primary, secondary }

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;

  /// Shows a spinner and disables interaction.
  final bool loading;
  final bool expand;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isPrimary = widget.variant == AppButtonVariant.primary;
    final enabled = widget.onPressed != null && !widget.loading;
    final loading = widget.loading;
    final icon = widget.icon;
    final label = widget.label;
    final expand = widget.expand;

    final Color foreground = isPrimary ? colors.onPrimary : colors.textPrimary;

    final child = loading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation(foreground),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 19, color: foreground),
                const SizedBox(width: 8),
              ],
              // Flexible + ellipsis so a long (e.g. Uzbek) label shrinks to fit
              // a narrow button instead of overflowing. Safe when the button is
              // not expanded: a loose Flexible in an unbounded Row just takes
              // its natural width.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.label.copyWith(color: foreground),
                ),
              ),
            ],
          );

    // Soft press feedback; held flat when the user prefers reduced motion.
    final scale = (_pressed && !context.reduceMotion) ? 0.97 : 1.0;

    return AnimatedScale(
      scale: scale,
      duration: AppMotion.tap,
      curve: AppMotion.standard,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          decoration: BoxDecoration(
            gradient: isPrimary ? colors.primaryGradient : null,
            color: isPrimary ? null : colors.surface,
            borderRadius: BorderRadius.circular(30),
            border: isPrimary
                ? null
                : Border.all(color: colors.border, width: 1.4),
            boxShadow: isPrimary && enabled
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 0,
            child: InkWell(
              onTap: enabled ? widget.onPressed : null,
              onHighlightChanged: enabled
                  ? (v) => setState(() => _pressed = v)
                  : null,
              borderRadius: BorderRadius.circular(30),
              splashColor: Colors.white.withValues(alpha: 0.15),
              child: Container(
                height: 56,
                width: expand ? double.infinity : null,
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: expand ? 24 : 32),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
