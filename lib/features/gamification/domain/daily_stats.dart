import 'package:cloud_firestore/cloud_firestore.dart';

/// One day's gamification stats, stored at `users/{uid}/daily/{yyyy-MM-dd}`.
/// Powers the progress screen's daily points, deep-session count, and weekly
/// activity chart.
class DailyStats {
  const DailyStats({
    required this.date,
    this.points = 0,
    this.focusMinutes = 0,
    this.deepSessions = 0,
    this.completed = 0,
    this.total = 0,
    this.hours = const {},
  });

  final DateTime date;
  final int points;
  final int focusMinutes;
  final int deepSessions;
  final int completed;
  final int total;

  /// Focus minutes by hour-of-day (0–23) — powers the premium "most productive
  /// time of day" stat. Empty for days recorded before this was tracked.
  final Map<int, int> hours;

  factory DailyStats.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final rawHours = data['hours'];
    final hours = <int, int>{};
    if (rawHours is Map) {
      rawHours.forEach((k, v) {
        final hour = int.tryParse('$k');
        final mins = (v as num?)?.toInt();
        if (hour != null && mins != null) hours[hour] = mins;
      });
    }
    return DailyStats(
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime(2000),
      points: (data['points'] as num?)?.toInt() ?? 0,
      focusMinutes: (data['focusMinutes'] as num?)?.toInt() ?? 0,
      deepSessions: (data['deepSessions'] as num?)?.toInt() ?? 0,
      completed: (data['completed'] as num?)?.toInt() ?? 0,
      total: (data['total'] as num?)?.toInt() ?? 0,
      hours: hours,
    );
  }
}
