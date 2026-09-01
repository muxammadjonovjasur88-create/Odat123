class AiSuggestedTask {
  const AiSuggestedTask({
    required this.title,
    this.dateStr,
    this.timeStr = '09:00',
    this.durationMinutes = 30,
    this.focusType = 'pomodoro',
    this.isReminder = true,
    this.repeatType = 'once', // 'once', 'daily', 'every_2_days', 'every_3_days', 'weekly'
    this.goalType = 'focus', // 'focus', 'exercise', 'note'
    this.notifyBefore1Hour = true,
    this.notifyBefore10Min = true,
  });

  final String title;
  final String? dateStr; // e.g. "2026-08-27"
  final String timeStr;
  final int durationMinutes;
  final String focusType;
  final bool isReminder;
  final String repeatType;
  final String goalType;
  final bool notifyBefore1Hour;
  final bool notifyBefore10Min;

  bool get isDaily => repeatType == 'daily';
  bool get isWeekly => repeatType == 'weekly';
  bool get isEvery2Days => repeatType == 'every_2_days';
  bool get isEvery3Days => repeatType == 'every_3_days';

  String get goalTypeBadge {
    switch (goalType.toLowerCase()) {
      case 'exercise':
      case 'sport':
        return '🏃 Mashq';
      case 'note':
      case 'zametka':
        return '📝 Zametka';
      case 'focus':
      case 'study':
      default:
        return '🎯 Fokus';
    }
  }

  String get repeatTypeBadge {
    switch (repeatType.toLowerCase()) {
      case 'daily':
        return 'Har kunlik';
      case 'every_2_days':
        return '2 kunda bir';
      case 'every_3_days':
        return '3 kunda bir';
      case 'weekly':
        return 'Haftalik';
      default:
        return '1 martalik';
    }
  }

  factory AiSuggestedTask.fromMap(Map<String, dynamic> map) {
    final rawRepeat = (map['repeatType'] as String?)?.toLowerCase() ??
        (map['repeat'] as String?)?.toLowerCase() ??
        'once';

    String normalizedRepeat = 'once';
    if (rawRepeat.contains('2') || rawRepeat.contains('ikki')) {
      normalizedRepeat = 'every_2_days';
    } else if (rawRepeat.contains('3') || rawRepeat.contains('uch')) {
      normalizedRepeat = 'every_3_days';
    } else if (rawRepeat.contains('day') || rawRepeat.contains('daily') || rawRepeat.contains('har kun')) {
      normalizedRepeat = 'daily';
    } else if (rawRepeat.contains('week') || rawRepeat.contains('hafta')) {
      normalizedRepeat = 'weekly';
    }

    final rawGoalType = (map['goalType'] as String?)?.toLowerCase() ??
        (map['type'] as String?)?.toLowerCase() ??
        ((map['focusType'] == 'sport') ? 'exercise' : 'focus');

    String normalizedGoalType = 'focus';
    if (rawGoalType.contains('sport') || rawGoalType.contains('exercise') || rawGoalType.contains('mashq')) {
      normalizedGoalType = 'exercise';
    } else if (rawGoalType.contains('note') || rawGoalType.contains('zametka') || rawGoalType.contains('eslatma')) {
      normalizedGoalType = 'note';
    }

    return AiSuggestedTask(
      title: (map['title'] as String?) ?? 'Yangi vazifa',
      dateStr: map['date'] as String?,
      timeStr: (map['time'] as String?) ?? '09:00',
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 30,
      focusType: (map['focusType'] as String?) ?? (normalizedGoalType == 'exercise' ? 'sport' : 'study'),
      isReminder: (map['isReminder'] as bool?) ?? true,
      repeatType: normalizedRepeat,
      goalType: normalizedGoalType,
      notifyBefore1Hour: (map['notifyBefore1Hour'] as bool?) ?? true,
      notifyBefore10Min: (map['notifyBefore10Min'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'date': dateStr,
    'time': timeStr,
    'durationMinutes': durationMinutes,
    'focusType': focusType,
    'isReminder': isReminder,
    'repeatType': repeatType,
    'goalType': goalType,
    'notifyBefore1Hour': notifyBefore1Hour,
    'notifyBefore10Min': notifyBefore10Min,
  };
}

class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isVoice = false,
    this.suggestedTasks = const [],
    this.imageBase64,
  });

  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isVoice;
  final List<AiSuggestedTask> suggestedTasks;
  final String? imageBase64;
}
