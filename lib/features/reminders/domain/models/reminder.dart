import 'package:hive/hive.dart';

part 'reminder.g.dart';

/// Repeat frequency for a reminder.
@HiveType(typeId: 10)
enum RepeatType {
  @HiveField(0)
  once,
  @HiveField(1)
  daily,
  @HiveField(2)
  weekly,
}

/// A standalone reminder (budilnik) — independent of Focus/Pomodoro sessions.
@HiveType(typeId: 11)
class Reminder extends HiveObject {
  Reminder({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.repeatType,
    required this.isCompleted,
    required this.createdAt,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  DateTime dateTime;

  @HiveField(3)
  RepeatType repeatType;

  @HiveField(4)
  bool isCompleted;

  @HiveField(5)
  final DateTime createdAt;

  Reminder copyWith({
    String? title,
    DateTime? dateTime,
    RepeatType? repeatType,
    bool? isCompleted,
  }) {
    return Reminder(
      id: id,
      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      repeatType: repeatType ?? this.repeatType,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
    );
  }

  /// Notification ID derived from the reminder id (stable across edits).
  int get notificationId => id.hashCode & 0x7fffffff;

  /// Whether the reminder's scheduled time has passed.
  bool get isPast => dateTime.isBefore(DateTime.now());

  @override
  String toString() =>
      'Reminder(id: $id, title: $title, dateTime: $dateTime, repeat: $repeatType, done: $isCompleted)';
}
