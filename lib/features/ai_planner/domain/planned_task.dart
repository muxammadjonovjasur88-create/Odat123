import 'package:flutter/material.dart';

import '../../../core/constants/app_category.dart';
import '../../../core/models/task.dart';

/// A single task proposed by the AI planner (before the user accepts it).
/// Mirrors the validated JSON the `generatePlan` Cloud Function returns:
/// `{ title, category, date(ISO), startTime("HH:mm"), durationMinutes }`.
class PlannedTask {
  const PlannedTask({
    required this.title,
    required this.category,
    required this.date,
    required this.startMinute,
    required this.durationMinutes,
    this.reasoning,
  });

  final String title;
  final AppCategory category;
  final DateTime date;
  final int startMinute;
  final int durationMinutes;

  /// One-sentence explanation from the AI about why this task is
  /// placed at this specific time (e.g. "Morning is your peak focus window").
  final String? reasoning;

  factory PlannedTask.fromMap(Map<String, dynamic> map) {
    final rawReasoning = (map['reasoning'] as String?)?.trim();
    return PlannedTask(
      title: (map['title'] as String?)?.trim() ?? 'Focus session',
      category: AppCategory.fromName(map['category'] as String?),
      date: _parseDate(map['date'] as String?),
      startMinute: _parseStartMinute(map['startTime'] as String?),
      durationMinutes: (map['durationMinutes'] as num?)?.round() ?? 25,
      reasoning: (rawReasoning != null && rawReasoning.isNotEmpty)
          ? rawReasoning
          : null,
    );
  }

  /// Converts an accepted suggestion into a persistable [Task].
  Task toTask() => Task.draft(
    title: title,
    category: category,
    date: date,
    startMinute: startMinute,
    durationMinutes: durationMinutes,
  );

  static DateTime _parseDate(String? iso) {
    if (iso == null) return DateUtils.dateOnly(DateTime.now());
    final parsed = DateTime.tryParse(iso);
    return DateUtils.dateOnly(parsed ?? DateTime.now());
  }

  static int _parseStartMinute(String? hhmm) {
    if (hhmm == null) return 9 * 60;
    final parts = hhmm.split(':');
    if (parts.length != 2) return 9 * 60;
    final h = int.tryParse(parts[0]) ?? 9;
    final m = int.tryParse(parts[1]) ?? 0;
    return (h.clamp(0, 23)) * 60 + m.clamp(0, 59);
  }
}
