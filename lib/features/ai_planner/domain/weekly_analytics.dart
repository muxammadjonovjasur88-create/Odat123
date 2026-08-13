import '../../gamification/domain/daily_stats.dart';

/// Structured weekly analytics data calculated from real Firestore daily stats.
class WeeklyAnalytics {
  const WeeklyAnalytics({
    required this.rates,
    required this.completionPercentage,
    required this.totalCompleted,
    required this.totalTasks,
  });

  /// Mon..Sun completion rates (each between 0.0 and 1.0) for the bar chart.
  final List<double> rates;

  /// Overall completion percentage (0..100%).
  final int completionPercentage;

  /// Total completed tasks this week.
  final int totalCompleted;

  /// Total planned tasks this week.
  final int totalTasks;

  /// Pure function to compute weekly analytics from 7 daily stats (Monday to Sunday).
  static WeeklyAnalytics compute(List<DailyStats> weekStats) {
    var completedSum = 0;
    var totalSum = 0;
    final ratesList = <double>[];

    for (final stat in weekStats) {
      completedSum += stat.completed;
      totalSum += stat.total;

      if (stat.total > 0) {
        ratesList.add((stat.completed / stat.total).clamp(0.0, 1.0));
      } else if (stat.completed > 0) {
        ratesList.add(1.0);
      } else {
        ratesList.add(0.0);
      }
    }

    // Guarantee exactly 7 days
    while (ratesList.length < 7) {
      ratesList.add(0.0);
    }

    final pct = totalSum > 0
        ? ((completedSum / totalSum) * 100).round().clamp(0, 100)
        : (completedSum > 0 ? 100 : 0);

    return WeeklyAnalytics(
      rates: ratesList.take(7).toList(),
      completionPercentage: pct,
      totalCompleted: completedSum,
      totalTasks: totalSum,
    );
  }
}
