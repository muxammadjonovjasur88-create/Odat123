import 'package:flutter/material.dart';

/// Flowa's single motion language — calm, soft, and consistent everywhere.
///
/// Every duration and curve the app animates with lives here, so navigation,
/// taps, and fades all "breathe" at the same gentle pace. Keep values quiet:
/// short, eased, never bouncy or aggressive.
abstract final class AppMotion {
  AppMotion._();

  /// Screen-to-screen navigation (forward).
  static const Duration page = Duration(milliseconds: 320);

  /// Screen-to-screen navigation (back) — a touch quicker so it feels responsive.
  static const Duration pageReverse = Duration(milliseconds: 260);

  /// Tap feedback on buttons, cards, chips — barely-there, just alive.
  static const Duration tap = Duration(milliseconds: 140);

  /// Soft fade for loading spinners, empty states, and content appearing.
  static const Duration fade = Duration(milliseconds: 280);

  /// Small state changes (a dot lighting up, a color settling).
  static const Duration subtle = Duration(milliseconds: 200);

  /// Entering: gentle deceleration, like coming to rest.
  static const Curve enter = Curves.easeOutCubic;

  /// Leaving: gentle acceleration away.
  static const Curve exit = Curves.easeInCubic;

  /// Symmetric ease for reversible changes (scale, opacity, color).
  static const Curve standard = Curves.easeInOut;
}

/// True when the user has asked the OS to minimise animations
/// (Android "Remove animations" / prefers-reduced-motion). Screens should still
/// look clean and complete — they just skip the movement.
extension MotionQuery on BuildContext {
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;
}

/// App-wide scroll feel: a soft, iOS-like overscroll instead of Android's hard
/// blue glow, so reaching the end of a list feels like a gentle cushion rather
/// than a snap. Applied once on [MaterialApp.scrollBehavior].
class CalmScrollBehavior extends MaterialScrollBehavior {
  const CalmScrollBehavior();

  // Drop the glow/stretch overscroll paint — the bounce physics below is the
  // only overscroll cue we want.
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(
        decelerationRate: ScrollDecelerationRate.normal,
      );
}
