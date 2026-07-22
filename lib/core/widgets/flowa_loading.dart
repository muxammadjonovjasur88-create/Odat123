import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// Flowa's calm, on-brand loading indicator: the leaf symbol resting in a soft
/// sage circle, gently "breathing" — scaling up and down in a slow, seamless
/// loop. Quiet and Zen, never a harsh spinning ring.
///
/// Respects prefers-reduced-motion: when animations are disabled it shows the
/// same leaf, held still, so the screen still reads as clean and intentional.
class FlowaLoading extends StatefulWidget {
  const FlowaLoading({super.key, this.size = 84});

  /// Diameter of the sage circle; the leaf scales with it.
  final double size;

  @override
  State<FlowaLoading> createState() => _FlowaLoadingState();
}

class _FlowaLoadingState extends State<FlowaLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // One calm breath in ~1.7s; reverse gives the exhale, so a full cycle is a
    // slow, even ~3.4s — like breathing.
    duration: const Duration(milliseconds: 1700),
  );

  late final Animation<double> _breath = Tween<double>(
    begin: 0.9,
    end: 1.08,
  ).animate(CurvedAnimation(parent: _controller, curve: AppMotion.standard));

  bool _animating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Starts/stops the loop based on the current reduced-motion setting. Called
  /// from didChangeDependencies so it reacts if the setting changes live.
  void _sync() {
    final shouldAnimate = !context.reduceMotion;
    if (shouldAnimate && !_animating) {
      _controller.repeat(reverse: true);
      _animating = true;
    } else if (!shouldAnimate && _animating) {
      _controller.stop();
      _controller.value = 1.0; // rest at full, calm size
      _animating = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final leaf = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: colors.tintSage, shape: BoxShape.circle),
      child: Icon(
        Icons.eco_rounded,
        size: widget.size * 0.46,
        color: colors.primary,
      ),
    );

    // Reduced motion → static leaf, no ticker driving it.
    if (context.reduceMotion) return leaf;

    return ScaleTransition(scale: _breath, child: leaf);
  }
}

/// A full-screen calm wait: [FlowaLoading] centred on the app's cream (theme)
/// background, with an optional soft label. Use wherever a whole screen would
/// otherwise sit blank/frozen (startup auth check, profile load, session warm-up).
class FlowaLoadingScreen extends StatelessWidget {
  const FlowaLoadingScreen({super.key, this.label});

  /// Optional quiet line under the leaf (e.g. a localized "one moment"). Keep it
  /// minimal or omit entirely.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FlowaLoading(),
            if (label != null) ...[
              const SizedBox(height: 22),
              Text(
                label!,
                style: AppTextStyles.overline.copyWith(
                  color: colors.textTertiary,
                  letterSpacing: 2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
