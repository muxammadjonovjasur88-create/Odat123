/// Anti-cheat validator for outdoor running/walking sessions.
abstract final class AntiCheatValidator {
  static const double maxSpeedKmh = 28.0; // Max allowed speed for human sprint (28 km/h)
  static const double minJitterKm = 0.002; // 2 meters minimum movement threshold to allow walking to register
  static const double minDistanceForAntiCheatKm = 0.025; // 25 meters needed to trigger car/scooter alert

  /// Calculates speed in km/h from distance in km and time in seconds.
  static double calculateSpeedKmh(double deltaKm, double timeDiffSec) {
    if (timeDiffSec <= 0) return 0.0;
    final hours = timeDiffSec / 3600.0;
    return deltaKm / hours;
  }

  /// Checks if the movement step is valid according to anti-cheat rules:
  /// - Returns true if valid human running/walking speed (<= 28 km/h)
  /// - Only flags as vehicle if movement is sustained and over 25 meters with speed > 28 km/h.
  static bool isValidSpeed(double deltaKm, double timeDiffSec) {
    if (deltaKm < minDistanceForAntiCheatKm) return true; // Small GPS jumps are treated as normal GPS jitter
    if (timeDiffSec < 2.0) return true; // Short sample times have high GPS noise
    final speedKmh = calculateSpeedKmh(deltaKm, timeDiffSec);
    return speedKmh <= maxSpeedKmh;
  }

  /// Checks if movement is above the noise/jitter threshold (>= 8 meters).
  static bool isSignificantMovement(double deltaKm) {
    return deltaKm >= minJitterKm;
  }
}
