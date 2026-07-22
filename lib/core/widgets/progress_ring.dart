import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A circular progress ring with a soft track, used for the daily progress
/// (06) and the weekly "Consistency Peak" (08).
class ProgressRing extends StatefulWidget {
  const ProgressRing({
    super.key,
    required this.percent,
    this.size = 150,
    this.strokeWidth = 8,
    this.center,
    this.color,
    this.trackColor,
  });

  /// 0.0–1.0.
  final double percent;
  final double size;
  final double strokeWidth;
  final Widget? center;
  final Color? color;
  final Color? trackColor;

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousPercent = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: widget.percent).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
    _previousPercent = widget.percent;
  }

  @override
  void didUpdateWidget(ProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    final targetPercent = widget.percent.clamp(0.0, 1.0);
    if ((targetPercent - _previousPercent).abs() > 0.001) {
      // Only animate if percent changes significantly.
      // Start from current animation value, not from 0.
      final currentValue = _animation.value;
      _animation = Tween<double>(begin: currentValue, end: targetPercent)
          .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          );
      _previousPercent = targetPercent;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final arcColor = widget.color ?? colors.primary;
    final track = widget.trackColor ?? colors.border;

    return AnimatedBuilder(
      animation: _animation,
      child: widget.center == null ? null : Center(child: widget.center),
      builder: (context, child) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _RingPainter(
            percent: _animation.value,
            strokeWidth: widget.strokeWidth,
            color: arcColor,
            trackColor: track,
          ),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.percent,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double percent;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (percent <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * percent,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.percent != percent ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
