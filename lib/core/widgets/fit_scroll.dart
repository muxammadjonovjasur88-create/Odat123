import 'package:flutter/material.dart';

/// Lays out a [Column] that uses `Spacer`/`Expanded` so it fills the screen when
/// there's room, but **scrolls instead of overflowing** when the screen is too
/// short (small phones, large text scale, keyboard open).
///
/// Wrap a screen's body `Column` with this instead of a bare `Padding`.
class FitOrScroll extends StatelessWidget {
  const FitOrScroll({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - padding.vertical,
            ),
            // IntrinsicHeight lets the inner Column's Spacer/Expanded work while
            // still allowing the content to grow and scroll when needed.
            child: IntrinsicHeight(child: child),
          ),
        );
      },
    );
  }
}
