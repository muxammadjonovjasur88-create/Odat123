import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../features/workout/domain/workout.dart';
import '../constants/app_category.dart';

/// The focus technique used while a task runs.
enum FocusMethod {
  pomodoro('Pomodoro'),
  custom('Interval');

  const FocusMethod(this.label);
  final String label;

  static FocusMethod fromName(String? name) => values.firstWhere(
    (m) => m.name == name,
    orElse: () => FocusMethod.pomodoro,
  );
}

/// A goal/task planned on the calendar. Stored at `users/{uid}/tasks/{taskId}`.
///
/// [date] is the calendar day (local midnight); [startMinute] is minutes from
/// midnight. Keeping them separate makes "tasks on this day" a simple equality
/// query while still ordering within the day by [startMinute].
///
/// Focus durations are user-entered (see Add Goal). Deep-work tasks use
/// [workMinutes] (+ auto [breakMinutes]); sport/interval tasks use
/// [intervalWorkSeconds] × [intervalSets] (+ auto [intervalRestSeconds]).
class Task {
  const Task({
    required this.id,
    required this.title,
    required this.category,
    required this.date,
    required this.startMinute,
    required this.durationMinutes,
    this.isCompleted = false,
    this.pointsAwarded = false,
    this.blockApps = false,
    this.focusMethod = FocusMethod.pomodoro,
    this.reminderMinutesBefore,
    required this.points,
    this.workMinutes = 25,
    this.breakMinutes = 5,
    this.intervalWorkSeconds = 45,
    this.intervalRestSeconds = 15,
    this.intervalSets = 4,
    this.workout,
    this.completionPercent = 0.0,
    // Goal duration fields (optional — null means single-day / not set)
    this.goalStartDate,
    this.goalEndDate,
    this.goalDurationDays,
    this.timeWindowStart,
    this.timeWindowEnd,
    this.proofRequired = false,
  });

  final String id;
  final String title;
  final AppCategory category;

  /// Calendar day at local midnight.
  final DateTime date;

  /// Start time as minutes from midnight (e.g. 8:00 → 480).
  final int startMinute;

  /// Total length of the planned block (drives the timeline + points).
  final int durationMinutes;
  final bool isCompleted;

  /// Whether this task's points have already been written to Firestore — the
  /// idempotency guard so a task is never awarded twice (across the checkbox,
  /// the end-of-time auto-complete, and the focus-session flows).
  final bool pointsAwarded;

  /// Focus session completion ratio in [0.0, 1.0]. Persisted to Firestore
  /// after each focus session so the daily plan can show partial progress.
  /// 0.0 = not started / no session recorded yet.
  final double completionPercent;

  final bool blockApps;
  final FocusMethod focusMethod;

  /// Minutes before [start] to remind; null means no reminder.
  final int? reminderMinutesBefore;

  /// Points earned on completion (accumulate weekly).
  final int points;

  // ---- Focus configuration (entered by the user) ----
  /// Deep-work focus length in minutes.
  final int workMinutes;

  /// Deep-work break length in minutes (auto-derived from [workMinutes]).
  final int breakMinutes;

  /// Sport interval work length in seconds.
  final int intervalWorkSeconds;

  /// Sport interval rest length in seconds (auto-derived).
  final int intervalRestSeconds;

  /// Number of sport interval sets.
  final int intervalSets;

  /// Structured set-based workout plan (sport tasks); null for other tasks.
  final WorkoutPlan? workout;

  // ---- Goal duration fields (set by the user in Add Goal) ----
  /// The calendar day when the multi-day goal starts; null = single-day.
  final DateTime? goalStartDate;

  /// The calendar day when the multi-day goal ends; null = single-day.
  final DateTime? goalEndDate;

  /// How many days the goal spans (1 = today only, null = not set).
  final int? goalDurationDays;

  /// Whether this task runs the structured set-based workout mode.
  bool get hasWorkout => workout != null && workout!.exercises.isNotEmpty;

  // ---- Proof fields ----
  /// The start of the optional time window for random proof (e.g. "19:00").
  /// Null implies "all day" or unspecified.
  final String? timeWindowStart;

  /// The end of the optional time window for random proof (e.g. "22:00").
  final String? timeWindowEnd;

  /// Whether the random proof system is enabled for this task.
  final bool proofRequired;

  /// Points awarded per minute of focus.
  static const int pointsPerMinute = 1;

  /// Auto break for a deep-work session: ~1 min per 5 worked, clamped 5–10.
  static int autoBreakMinutes(int workMinutes) =>
      (workMinutes / 5).round().clamp(5, 10);

  /// Auto rest for an interval set: ~1/3 of the work, clamped 10–30s.
  static int autoRestSeconds(int workSeconds) =>
      (workSeconds / 3).round().clamp(10, 30);

  int get workSeconds => workMinutes * 60;
  int get breakSeconds => breakMinutes * 60;

  DateTime get start => date.add(Duration(minutes: startMinute));
  DateTime get end => start.add(Duration(minutes: durationMinutes));
  TimeOfDay get startTime =>
      TimeOfDay(hour: startMinute ~/ 60, minute: startMinute % 60);

  bool get hasReminder => reminderMinutesBefore != null;

  Task copyWith({
    String? id,
    DateTime? date,
    bool? isCompleted,
    bool? pointsAwarded,
    double? completionPercent,
  }) => Task(
    id: id ?? this.id,
    title: title,
    category: category,
    date: date ?? this.date,
    startMinute: startMinute,
    durationMinutes: durationMinutes,
    isCompleted: isCompleted ?? this.isCompleted,
    pointsAwarded: pointsAwarded ?? this.pointsAwarded,
    blockApps: blockApps,
    focusMethod: focusMethod,
    reminderMinutesBefore: reminderMinutesBefore,
    points: points,
    workMinutes: workMinutes,
    breakMinutes: breakMinutes,
    intervalWorkSeconds: intervalWorkSeconds,
    intervalRestSeconds: intervalRestSeconds,
    intervalSets: intervalSets,
    workout: workout,
    completionPercent: completionPercent ?? this.completionPercent,
    goalStartDate: goalStartDate,
    goalEndDate: goalEndDate,
    goalDurationDays: goalDurationDays,
    timeWindowStart: timeWindowStart,
    timeWindowEnd: timeWindowEnd,
    proofRequired: proofRequired,
  );

  /// Total seconds for an interval workout: sets of work with rests between.
  static int intervalDurationSeconds({
    required int sets,
    required int workSeconds,
    required int restSeconds,
  }) => sets * workSeconds + (sets - 1).clamp(0, sets) * restSeconds;

  /// Builds a new task from the manual Add Goal form, where the user enters the
  /// focus duration(s). Computes the block length, break/rest, and points.
  factory Task.manual({
    required String title,
    required AppCategory category,
    required DateTime date,
    required int startMinute,
    required bool isInterval,
    int workMinutes = 25,
    int intervalWorkSeconds = 45,
    int intervalSets = 4,
    bool blockApps = false,
    int? reminderMinutesBefore,
    WorkoutPlan? workout,
    int? rangeMinutes,
    // Goal duration (optional)
    DateTime? goalStartDate,
    DateTime? goalEndDate,
    int? goalDurationDays,
    String? timeWindowStart,
    String? timeWindowEnd,
    bool proofRequired = false,
  }) {
    // When the user sets an explicit end time, the block length (and a deep-work
    // timer) come from the start→end range; otherwise duration is auto.
    final effectiveWork =
        (rangeMinutes != null && !isInterval && workout == null)
        ? rangeMinutes
        : workMinutes;
    final breakMinutes = autoBreakMinutes(effectiveWork);
    final restSeconds = autoRestSeconds(intervalWorkSeconds);
    final int durationMinutes;
    if (rangeMinutes != null) {
      durationMinutes = rangeMinutes;
    } else if (workout != null) {
      durationMinutes = (workout.estimatedSeconds + 59) ~/ 60;
    } else if (isInterval) {
      durationMinutes =
          (intervalDurationSeconds(
                sets: intervalSets,
                workSeconds: intervalWorkSeconds,
                restSeconds: restSeconds,
              ) +
              59) ~/
          60;
    } else {
      durationMinutes = effectiveWork;
    }
    final clamped = durationMinutes.clamp(1, 600);
    return Task(
      id: '',
      title: title,
      category: category,
      date: DateUtils.dateOnly(date),
      startMinute: startMinute,
      durationMinutes: clamped,
      blockApps: blockApps,
      focusMethod: (isInterval || workout != null)
          ? FocusMethod.custom
          : FocusMethod.pomodoro,
      reminderMinutesBefore: reminderMinutesBefore,
      points: clamped * pointsPerMinute,
      workMinutes: effectiveWork,
      breakMinutes: breakMinutes,
      intervalWorkSeconds: intervalWorkSeconds,
      intervalRestSeconds: restSeconds,
      intervalSets: intervalSets,
      workout: workout,
      goalStartDate: goalStartDate != null ? DateUtils.dateOnly(goalStartDate) : null,
      goalEndDate: goalEndDate != null ? DateUtils.dateOnly(goalEndDate) : null,
      goalDurationDays: goalDurationDays,
      timeWindowStart: timeWindowStart,
      timeWindowEnd: timeWindowEnd,
      proofRequired: proofRequired,
    );
  }

  /// Builds a new task (no id yet) from a fixed block length — used by the AI
  /// planner. The deep-work focus length tracks the block length.
  factory Task.draft({
    required String title,
    required AppCategory category,
    required DateTime date,
    required int startMinute,
    required int durationMinutes,
    bool blockApps = false,
    FocusMethod focusMethod = FocusMethod.pomodoro,
    int? reminderMinutesBefore,
  }) {
    return Task(
      id: '',
      title: title,
      category: category,
      date: DateUtils.dateOnly(date),
      startMinute: startMinute,
      durationMinutes: durationMinutes,
      blockApps: blockApps,
      focusMethod: focusMethod,
      reminderMinutesBefore: reminderMinutesBefore,
      points: durationMinutes * pointsPerMinute,
      workMinutes: durationMinutes.clamp(5, 120),
      breakMinutes: autoBreakMinutes(durationMinutes.clamp(5, 120)),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'category': category.name,
    'date': Timestamp.fromDate(date),
    'startMinute': startMinute,
    'durationMinutes': durationMinutes,
    'isCompleted': isCompleted,
    'pointsAwarded': pointsAwarded,
    'blockApps': blockApps,
    'focusMethod': focusMethod.name,
    'reminderMinutesBefore': reminderMinutesBefore,
    'points': points,
    'workMinutes': workMinutes,
    'breakMinutes': breakMinutes,
    'intervalWorkSeconds': intervalWorkSeconds,
    'intervalRestSeconds': intervalRestSeconds,
    'intervalSets': intervalSets,
    if (workout != null) 'workout': workout!.toMap(),
    'completionPercent': completionPercent,
    'createdAt': FieldValue.serverTimestamp(),
    if (goalStartDate != null)
      'goalStartDate': Timestamp.fromDate(goalStartDate!),
    if (goalEndDate != null) 'goalEndDate': Timestamp.fromDate(goalEndDate!),
    if (goalDurationDays != null) 'goalDurationDays': goalDurationDays,
    'timeWindowStart': timeWindowStart,
    'timeWindowEnd': timeWindowEnd,
    'proofRequired': proofRequired,
  };

  /// Fields to write when EDITING an existing task. Same as [toMap] but without
  /// `createdAt` (so the original creation time is preserved) and it clears a
  /// stale `workout` when a task is changed away from set-based mode.
  Map<String, dynamic> toUpdateMap() {
    final m = toMap()..remove('createdAt');
    m['workout'] = workout?.toMap(); // explicit null removes an old workout
    // Persist goal duration even when null (removes stale values on edit).
    m['goalStartDate'] = goalStartDate != null
        ? Timestamp.fromDate(goalStartDate!)
        : null;
    m['goalEndDate'] =
        goalEndDate != null ? Timestamp.fromDate(goalEndDate!) : null;
    m['goalDurationDays'] = goalDurationDays;
    m['timeWindowStart'] = timeWindowStart;
    m['timeWindowEnd'] = timeWindowEnd;
    m['proofRequired'] = proofRequired;
    return m;
  }

  factory Task.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final duration = (data['durationMinutes'] as num?)?.toInt() ?? 25;
    return Task(
      id: doc.id,
      title: (data['title'] as String?) ?? '',
      category: AppCategory.fromName(data['category'] as String?),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime(2000),
      startMinute: (data['startMinute'] as num?)?.toInt() ?? 0,
      durationMinutes: duration,
      isCompleted: (data['isCompleted'] as bool?) ?? false,
      pointsAwarded: (data['pointsAwarded'] as bool?) ?? false,
      blockApps: (data['blockApps'] as bool?) ?? false,
      focusMethod: FocusMethod.fromName(data['focusMethod'] as String?),
      reminderMinutesBefore: (data['reminderMinutesBefore'] as num?)?.toInt(),
      points: (data['points'] as num?)?.toInt() ?? 0,
      // Fall back to the block length for tasks created before these fields.
      workMinutes: (data['workMinutes'] as num?)?.toInt() ?? duration,
      breakMinutes:
          (data['breakMinutes'] as num?)?.toInt() ?? autoBreakMinutes(duration),
      intervalWorkSeconds: (data['intervalWorkSeconds'] as num?)?.toInt() ?? 45,
      intervalRestSeconds: (data['intervalRestSeconds'] as num?)?.toInt() ?? 15,
      intervalSets: (data['intervalSets'] as num?)?.toInt() ?? 4,
      workout: data['workout'] is Map
          ? WorkoutPlan.fromMap(data['workout'] as Map)
          : null,
      completionPercent:
          (data['completionPercent'] as num?)?.toDouble() ?? 0.0,
      // Goal duration — null for tasks created before this feature.
      goalStartDate: (data['goalStartDate'] as Timestamp?)?.toDate(),
      goalEndDate: (data['goalEndDate'] as Timestamp?)?.toDate(),
      goalDurationDays: (data['goalDurationDays'] as num?)?.toInt(),
      timeWindowStart: data['timeWindowStart'] as String?,
      timeWindowEnd: data['timeWindowEnd'] as String?,
      proofRequired: data['proofRequired'] as bool? ?? false,
    );
  }
}
