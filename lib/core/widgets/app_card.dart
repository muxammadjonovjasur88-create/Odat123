import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_theme.dart';

/// Soft, rounded surface card with a gentle shadow — the building block for
/// almost every screen (tasks, rituals, leaderboard rows, etc.).
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.radius = 22,
    this.color,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  /// Overrides the default surface color.
  final Color? color;

  /// Optional border (e.g. for a selected card).
  final BoxBorder? border;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderRadius = BorderRadius.circular(widget.radius);

    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: widget.color ?? colors.surface,
        borderRadius: borderRadius,
        border: widget.border,
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: widget.padding, child: widget.child),
    );

    if (widget.onTap == null) return content;

    return AnimatedScale(
      scale: (_pressed && !context.reduceMotion) ? 0.98 : 1.0,
      duration: AppMotion.tap,
      curve: AppMotion.standard,
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          borderRadius: borderRadius,
          child: content,
        ),
      ),
    );
  }
}
