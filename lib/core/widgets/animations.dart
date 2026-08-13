import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Gentle entrance: fades + slides its [child] up on first build. Use [delay]
/// (e.g. via [stagger]) to cascade items in a list. Calm by design — a soft
/// ease-out over ~360ms with a small upward slide.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 360),
    this.offset = const Offset(0, 0.06),
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Start offset as a fraction of the child's size (slides to zero).
  final Offset offset;
  final Curve curve;

  /// Staggered delay for the item at [index], capped so long lists stay snappy.
  static Duration stagger(int index, {int stepMs = 45, int maxMs = 400}) =>
      Duration(milliseconds: (index * stepMs).clamp(0, maxMs));

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _shown = true);
      });
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) setState(() => _shown = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _shown ? Offset.zero : widget.offset,
      duration: widget.duration,
      curve: widget.curve,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: widget.duration,
        curve: widget.curve,
        child: widget.child,
      ),
    );
  }
}

/// A whole number that smoothly counts to [value] whenever it changes — e.g.
/// points awarded or a progress percentage. Counts up from 0 on first build.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOutCubic,
    this.textAlign,
  });

  final int value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;
  final Curve curve;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, v, _) => Text(
        '$prefix${v.round()}$suffix',
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}

/// A one-shot calm "pop" — scales + fades its [child] in from slightly small,
/// for moments worth noticing (e.g. the points badge on Goal Reached).
class PopIn extends StatelessWidget {
  const PopIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 520),
    this.beginScale = 0.86,
    this.curve = Curves.easeOutBack,
  });

  final Widget child;
  final Duration duration;
  final double beginScale;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: curve,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: beginScale + (1 - beginScale) * t,
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Task completion micro-animations
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps [child] and plays a one-shot "pop" scale + 4 small star particles
/// when [triggered] flips from false → true. Designed for the task completion
/// status bubble on the Daily Plan screen.
///
/// Particles are small (4–6 px) dots scattered at ±45°/135° — subtle enough
/// to match Flowa's minimalist style.
class TaskCheckAnimation extends StatefulWidget {
  const TaskCheckAnimation({
    super.key,
    required this.triggered,
    required this.child,
    this.color = const Color(0xFF4CAF50),
  });

  /// When this becomes true the animation fires once.
  final bool triggered;

  /// The bubble/icon to show inside.
  final Widget child;

  /// Particle & glow color — defaults to green matching the app primary.
  final Color color;

  @override
  State<TaskCheckAnimation> createState() => _TaskCheckAnimationState();
}

class _TaskCheckAnimationState extends State<TaskCheckAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  /// Guards so the animation fires only once per completion.
  bool _fired = false;

  @override
  void didUpdateWidget(TaskCheckAnimation old) {
    super.didUpdateWidget(old);
    if (widget.triggered && !old.triggered && !_fired) {
      _fired = true;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value; // 0 → 1

        // Pop: quick overshoot then settle.
        final popScale = t < 0.3
            ? 1.0 + 0.28 * (t / 0.3) // grows to 1.28
            : 1.0 + 0.28 * (1 - (t - 0.3) / 0.7); // settles back

        // Particle spread: starts at 0, expands to max radius, fades out.
        final particleRadius = 28.0 * Curves.easeOut.transform(t);
        final particleOpacity = t < 0.6 ? 1.0 : 1.0 - (t - 0.6) / 0.4;

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // The actual bubble — scaled.
            Transform.scale(scale: popScale, child: widget.child),

            // 4 star particles at 45°, 135°, 225°, 315°.
            if (widget.triggered)
              ...List.generate(4, (i) {
                final angle = math.pi / 4 + i * math.pi / 2;
                final dx = math.cos(angle) * particleRadius;
                final dy = math.sin(angle) * particleRadius;
                return Positioned(
                  left: 29 + dx, // 29 ≈ half of 58 (bubble size)
                  top: 29 + dy,
                  child: Opacity(
                    opacity: particleOpacity.clamp(0.0, 1.0),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: widget.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Streak increase burst animation
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps [child] and plays a one-shot burst pulse when [streak] increases.
/// A quick scale-up (1.0 → 1.35) then settle (1.35 → 1.0) in ~450ms, plus
/// a glow that fades. Safe to use inside any layout — the bounding box stays
/// unchanged because the transform is applied with [Transform.scale].
class StreakBumpAnimation extends StatefulWidget {
  const StreakBumpAnimation({
    super.key,
    required this.streak,
    required this.child,
    this.color = const Color(0xFFE08A4B),
  });

  final int streak;
  final Widget child;
  final Color color;

  @override
  State<StreakBumpAnimation> createState() => _StreakBumpAnimationState();
}

class _StreakBumpAnimationState extends State<StreakBumpAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  late int _prevStreak = widget.streak;

  @override
  void didUpdateWidget(StreakBumpAnimation old) {
    super.didUpdateWidget(old);
    if (widget.streak > _prevStreak) {
      _prevStreak = widget.streak;
      _c.forward(from: 0);
    } else {
      _prevStreak = widget.streak;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        // Quick rise then ease back.
        final scale = t < 0.4
            ? 1.0 + 0.35 * (t / 0.4)
            : 1.0 + 0.35 * (1 - Curves.easeOut.transform((t - 0.4) / 0.6));
        final glow = t < 0.5 ? t / 0.5 : 1.0 - (t - 0.5) / 0.5;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Glow halo behind the icon.
            if (t > 0)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.55 * glow),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            Transform.scale(scale: scale, child: child),
          ],
        );
      },
      child: widget.child,
    );
  }
}
