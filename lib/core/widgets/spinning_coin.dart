import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A subtle, premium 3D rotating gold coin widget used to display points/coins.
/// Rotates around the Y-axis continuously with a smooth perspective transform.
class SpinningCoin extends StatefulWidget {
  const SpinningCoin({
    super.key,
    this.size = 20.0,
    this.duration = const Duration(milliseconds: 2400),
  });

  final double size;
  final Duration duration;

  @override
  State<SpinningCoin> createState() => _SpinningCoinState();
}

class _SpinningCoinState extends State<SpinningCoin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = _controller.value * 2 * math.pi;
        final cosVal = math.cos(angle).abs();

        // Dynamic 3D light reflection based on rotation angle
        final highlightColor = Color.lerp(
          const Color(0xFFFFB300), // Amber edge
          const Color(0xFFFFF59D), // Bright gold shine
          cosVal,
        )!;

        final baseColor = Color.lerp(
          const Color(0xFFFF8F00), // Deep gold
          const Color(0xFFFFC107), // Amber face
          cosVal,
        )!;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // 3D perspective
            ..rotateY(angle),
          alignment: Alignment.center,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  highlightColor,
                  baseColor,
                  const Color(0xFFFF6F00), // Outer rim depth
                ],
                stops: const [0.0, 0.7, 1.0],
                center: const Alignment(-0.25, -0.25),
                radius: 0.85,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.35 * cosVal),
                  blurRadius: 5,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Container(
              width: widget.size * 0.65,
              height: widget.size * 0.65,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFFDE7).withValues(alpha: 0.75 * cosVal),
                  width: math.max(1.0, widget.size * 0.06),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '\$',
                style: TextStyle(
                  color: const Color(0xFF4E342E),
                  fontWeight: FontWeight.w900,
                  fontSize: widget.size * 0.42,
                  height: 1.0,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
