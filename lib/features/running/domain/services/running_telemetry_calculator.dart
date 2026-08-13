/// Telemetry calculator helpers for duration, pace, speed, calories, and points.
abstract final class RunningTelemetryCalculator {
  /// Calculates calories burned (65 kcal/km for running, 45 kcal/km for walking).
  static int calculateCalories({
    required double distanceKm,
    bool isWalking = false,
  }) {
    final kcalPerKm = isWalking ? 45 : 65;
    return (distanceKm * kcalPerKm).round();
  }

  /// Calculates average speed in km/h.
  static double calculateAverageSpeed({
    required double distanceKm,
    required int durationSeconds,
  }) {
    if (durationSeconds <= 0 || distanceKm <= 0) return 0.0;
    final hours = durationSeconds / 3600.0;
    return double.parse((distanceKm / hours).toStringAsFixed(1));
  }

  /// Formats average pace in min/km (e.g. 5'30").
  static String formatPace({
    required double distanceKm,
    required int durationSeconds,
  }) {
    if (distanceKm <= 0.05 || durationSeconds <= 0) return "0'00\"";
    final minutes = durationSeconds / 60.0;
    final paceVal = minutes / distanceKm;
    final paceMin = paceVal.floor();
    final paceSec = ((paceVal - paceMin) * 60).round();
    final formattedSec = paceSec < 10 ? '0$paceSec' : '$paceSec';
    return "$paceMin'$formattedSec\"";
  }

  /// Formats total seconds into MM:SS or HH:MM:SS.
  static String formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final mStr = minutes < 10 ? '0$minutes' : '$minutes';
    final sStr = seconds < 10 ? '0$seconds' : '$seconds';

    if (hours > 0) {
      final hStr = hours < 10 ? '0$hours' : '$hours';
      return '$hStr:$mStr:$sStr';
    }
    return '$mStr:$sStr';
  }

  /// Calculates points earned for the run session.
  /// Gives 30 points per km + 100 points completion bonus if target (e.g. 3km) is met.
  static int calculatePointsEarned({
    required double distanceKm,
    double targetKm = 3.0,
  }) {
    final basePoints = (distanceKm * 30).round();
    if (distanceKm >= targetKm) {
      return basePoints + 100;
    }
    return basePoints;
  }
}
