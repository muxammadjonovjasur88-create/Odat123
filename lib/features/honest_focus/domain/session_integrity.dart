import 'dart:math';
import 'package:flutter/foundation.dart';
import 'honest_focus.dart';

abstract final class SessionIntegrity {
  SessionIntegrity._();

  /// Calculates a strict integrity score (0.0 to 1.0) based on native away time
  /// and missed UI check-ins.
  ///
  /// * Native `awaySeconds` flawlessly distinguishes app-switching (penalized)
  ///   from screen-off (allowed).
  /// * `checkInsMissed` ensures the user is actively working if the screen is on.
  static double calculateScore({
    required FocusSignals signals,
    required int checkInsPresented,
    required int checkInsMissed,
  }) {
    if (signals.totalSeconds <= 0) {
      debugPrint('[SessionIntegrity] totalSeconds<=0 → returning 1.0');
      return 1.0;
    }

    // Short background sessions (< 20s) shouldn't impact score
    int effectiveAway = signals.awaySeconds < 20 ? 0 : signals.awaySeconds;
    
    // 1. Calculate away penalty (using native awaySeconds)
    final double awayRatio = effectiveAway / signals.totalSeconds;

    // 2. Calculate missed check-in penalty
    double missedRatio = 0.0;
    if (checkInsPresented > 0) {
      missedRatio = checkInsMissed / checkInsPresented;
    }

    // Combine penalties
    final double penalty = max(awayRatio, missedRatio);
    
    // Integrity is what remains
    double integrity = (1.0 - penalty).clamp(0.0, 1.0);

    // If integrity is too low (e.g. < 20%), they get 0 points to prevent farming
    if (integrity < 0.20) {
      debugPrint(
        '[SessionIntegrity] integrity=$integrity < 0.20 → returning 0.0 '
        '(awayRatio=${awayRatio.toStringAsFixed(2)}, '
        'missedRatio=${missedRatio.toStringAsFixed(2)}, '
        'effectiveAway=$effectiveAway, totalSec=${signals.totalSeconds})',
      );
      return 0.0;
    }

    debugPrint(
      '[SessionIntegrity] calculateScore → integrity=${integrity.toStringAsFixed(2)} '
      '(awayRatio=${awayRatio.toStringAsFixed(2)}, '
      'missedRatio=${missedRatio.toStringAsFixed(2)}, '
      'effectiveAway=$effectiveAway, totalSec=${signals.totalSeconds}, '
      'checkIns: $checkInsPresented presented, $checkInsMissed missed)',
    );

    return integrity;
  }
}

/// Pure function to calculate session integrity score (0.0 to 1.0)
/// based on background away periods and missed UI check-ins.
double calculateSessionIntegrityScore({
  required FocusSignals signals,
  required int checkInsPresented,
  required int checkInsMissed,
}) {
  return SessionIntegrity.calculateScore(
    signals: signals,
    checkInsPresented: checkInsPresented,
    checkInsMissed: checkInsMissed,
  );
}
