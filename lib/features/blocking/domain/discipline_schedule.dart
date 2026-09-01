import 'package:flutter/foundation.dart';
import 'app_usage_info.dart';

/// A scheduled discipline window (e.g. Study Mode 19:00 - 22:00, Bedtime 23:00 - 07:00).
@immutable
class DisciplineSchedule {
  const DisciplineSchedule({
    required this.id,
    required this.title,
    required this.daysOfWeek, // 1 = Mon, 7 = Sun
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.blockedPackages,
    this.disciplineLevel = DisciplineLevel.strict,
    this.isActive = true,
  });

  final String id;
  final String title;
  final List<int> daysOfWeek;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final List<String> blockedPackages;
  final DisciplineLevel disciplineLevel;
  final bool isActive;

  String get formattedTimeWindow {
    final sH = startHour.toString().padLeft(2, '0');
    final sM = startMinute.toString().padLeft(2, '0');
    final eH = endHour.toString().padLeft(2, '0');
    final eM = endMinute.toString().padLeft(2, '0');
    return '$sH:$sM - $eH:$eM';
  }

  bool isCurrentlyActive(DateTime now) {
    if (!isActive) return false;
    if (!daysOfWeek.contains(now.weekday)) return false;

    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = endHour * 60 + endMinute;
    final currentMinutes = now.hour * 60 + now.minute;

    if (endMinutes >= startMinutes) {
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    } else {
      // Crosses midnight (e.g. 23:00 - 07:00)
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'daysOfWeek': daysOfWeek,
        'startHour': startHour,
        'startMinute': startMinute,
        'endHour': endHour,
        'endMinute': endMinute,
        'blockedPackages': blockedPackages,
        'disciplineLevel': disciplineLevel.name,
        'isActive': isActive,
      };

  factory DisciplineSchedule.fromMap(Map<String, dynamic> map) {
    return DisciplineSchedule(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Discipline Schedule',
      daysOfWeek: (map['daysOfWeek'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? [1, 2, 3, 4, 5, 6, 7],
      startHour: (map['startHour'] as num?)?.toInt() ?? 19,
      startMinute: (map['startMinute'] as num?)?.toInt() ?? 0,
      endHour: (map['endHour'] as num?)?.toInt() ?? 22,
      endMinute: (map['endMinute'] as num?)?.toInt() ?? 0,
      blockedPackages: (map['blockedPackages'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      disciplineLevel: DisciplineLevel.values.firstWhere(
        (e) => e.name == map['disciplineLevel'],
        orElse: () => DisciplineLevel.strict,
      ),
      isActive: map['isActive'] as bool? ?? true,
    );
  }
}
