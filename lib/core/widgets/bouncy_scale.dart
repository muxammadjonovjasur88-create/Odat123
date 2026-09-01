import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps any widget with an ultra-responsive spring bouncy scale and tactile haptic on tap.
class BouncyScale extends StatefulWidget {
  const BouncyScale({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleFactor = 0.93,
    this.enableHaptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final bool enableHaptic;

  @override
  State<BouncyScale> createState() => _BouncyScaleState();
}

class _BouncyScaleState extends State<BouncyScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap == null) return;
    _controller.forward();
    if (widget.enableHaptic) {
      HapticFeedback.selectionClick();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onTap == null) return;
    _controller.reverse();
    widget.onTap!();
  }

  void _handleTapCancel() {
    if (widget.onTap == null) return;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
