/// Anti-cheat validator for outdoor running/walking sessions.
abstract final class AntiCheatValidator {
  static const double maxSpeedKmh = 25.0; // Max allowed speed for running/walking (25 km/h)
  static const double minJitterKm = 0.004; // 4 meters minimum movement threshold to ignore GPS jitter

  /// Calculates speed in km/h from distance in km and time in seconds.
  static double calculateSpeedKmh(double deltaKm, double timeDiffSec) {
    if (timeDiffSec <= 0) return 0.0;
    final hours = timeDiffSec / 3600.0;
    return deltaKm / hours;
  }

  /// Checks if the movement step is valid according to anti-cheat rules:
  /// - Returns true if valid running/walking speed (<= 25 km/h)
  /// - Returns false if speed > 25 km/h (indicates car, bicycle, or fake GPS spoofing)
  static bool isValidSpeed(double deltaKm, double timeDiffSec) {
    if (deltaKm < minJitterKm) return true; // Jitter is ignored, but valid
    if (timeDiffSec <= 0) return true;
    final speedKmh = calculateSpeedKmh(deltaKm, timeDiffSec);
    return speedKmh <= maxSpeedKmh;
  }

  /// Checks if movement is above the noise/jitter threshold (>= 4 meters).
  static bool isSignificantMovement(double deltaKm) {
    return deltaKm >= minJitterKm;
  }
}
