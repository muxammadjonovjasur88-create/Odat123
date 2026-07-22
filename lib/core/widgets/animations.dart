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
