import 'package:hive/hive.dart';

part 'reminder.g.dart';

/// Repeat frequency for a reminder / goal.
@HiveType(typeId: 10)
enum RepeatType {
  @HiveField(0)
  once,
  @HiveField(1)
  daily,
  @HiveField(2)
  weekly,
}

/// A versatile Goal / Reminder / Focus item.
@HiveType(typeId: 11)
class Reminder extends HiveObject {
  Reminder({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.repeatType,
    required this.isCompleted,
    required this.createdAt,
    this.goalType = 'note',
    this.durationMinutes = 25,
    this.startTimeStr,
    this.endTimeStr,
    this.exerciseType,
    this.targetReps,
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

  @HiveField(6)
  String goalType; // 'note', 'focus', 'exercise'

  @HiveField(7)
  int durationMinutes;

  @HiveField(8)
  String? startTimeStr; // e.g. "14:00"

  @HiveField(9)
  String? endTimeStr; // e.g. "15:30"

  @HiveField(10)
  String? exerciseType; // 'SQUAT', 'PUSH_UP', 'PLANK', 'PULL_UP', 'CRUNCH'

  @HiveField(11)
  int? targetReps;

  bool get isFocusGoal => goalType == 'focus';
  bool get isExerciseGoal => goalType == 'exercise';
  bool get isNoteGoal => goalType == 'note' || goalType.isEmpty;

  Reminder copyWith({
    String? title,
    DateTime? dateTime,
    RepeatType? repeatType,
    bool? isCompleted,
    String? goalType,
    int? durationMinutes,
    String? startTimeStr,
    String? endTimeStr,
    String? exerciseType,
    int? targetReps,
  }) {
    return Reminder(
      id: id,
      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      repeatType: repeatType ?? this.repeatType,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      goalType: goalType ?? this.goalType,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      startTimeStr: startTimeStr ?? this.startTimeStr,
      endTimeStr: endTimeStr ?? this.endTimeStr,
      exerciseType: exerciseType ?? this.exerciseType,
      targetReps: targetReps ?? this.targetReps,
    );
  }

  /// Notification ID derived from the reminder id (stable across edits).
  int get notificationId => id.hashCode & 0x7fffffff;

  /// Whether the reminder's scheduled time has passed (with a 10-minute grace period).
  bool get isPast => dateTime.add(const Duration(minutes: 10)).isBefore(DateTime.now());

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'dateTime': dateTime.toIso8601String(),
        'repeatType': repeatType.name,
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
        'goalType': goalType,
        'durationMinutes': durationMinutes,
        'startTimeStr': startTimeStr,
        'endTimeStr': endTimeStr,
        'exerciseType': exerciseType,
        'targetReps': targetReps,
      };

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      dateTime: DateTime.tryParse(map['dateTime'] as String? ?? '') ?? DateTime.now(),
      repeatType: RepeatType.values.firstWhere(
        (e) => e.name == map['repeatType'],
        orElse: () => RepeatType.once,
      ),
      isCompleted: map['isCompleted'] as bool? ?? false,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      goalType: map['goalType'] as String? ?? 'note',
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 25,
      startTimeStr: map['startTimeStr'] as String?,
      endTimeStr: map['endTimeStr'] as String?,
      exerciseType: map['exerciseType'] as String?,
      targetReps: (map['targetReps'] as num?)?.toInt(),
    );
  }

  @override
  String toString() =>
      'Reminder(id: $id, title: $title, type: $goalType, dateTime: $dateTime, repeat: $repeatType, done: $isCompleted)';
}
