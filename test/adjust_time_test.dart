import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/features/deep_focus/presentation/focus_session_controller.dart';
import 'package:flowa/features/gamification/domain/gamification_math.dart';

/// Yordamchi: adjustedPlannedMinutes va completionPercent ni
/// focus_providers.dart dagi formula bilan hisoblab beradi.
/// Bu formulani testda mirror qilamiz (Firebase'siz, pure test).
Map<String, dynamic> calcScoring({
  required int taskDurationMinutes, // vazifaning asl rejalashtirilgan davomiyligi
  required int taskPoints,          // task.points
  required int timeAdjustmentSeconds, // signals.timeAdjustmentSeconds
  required int focusedSeconds,      // signals.focusedSeconds
}) {
  // focus_providers.dart, line 220-227 dagi formula (BUG FIX #1 + #2):
  final adjustedPlannedMinutes =
      (taskDurationMinutes + (timeAdjustmentSeconds / 60).round()).clamp(1, 1440);
  final completionPercent = GamificationMath.calculateTaskCompletionPercent(
    plannedMinutes: adjustedPlannedMinutes,
    actualMinutes: focusedSeconds ~/ 60,
  );
  // focus_providers.dart, line 246-255:
  final adjustedBasePoints = taskDurationMinutes > 0
      ? (taskPoints * (adjustedPlannedMinutes / taskDurationMinutes)).round()
      : taskPoints;
  final points = GamificationMath.proportionalPoints(
    basePoints: adjustedBasePoints,
    completionPercent: completionPercent,
  );
  return {
    'adjustedPlannedMinutes': adjustedPlannedMinutes,
    'completionPercent': completionPercent,
    'adjustedBasePoints': adjustedBasePoints,
    'points': points,
  };
}

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // 1. applyAdjustTimeToState: uchta +5 daqiqa bosilganda timer to'g'ri
  // ─────────────────────────────────────────────────────────────────────────
  test('applyAdjustTimeToState: three +5min presses -> +15 minutes', () {
    final initial = FocusSessionState(
      taskId: 't1',
      isInterval: false,
      status: FocusRunStatus.running,
      kind: FocusKind.work,
      remainingSeconds: 20 * 60, // 20 minutes
      scheduledStart: DateTime.now(),
      scheduledEnd: DateTime.now().add(const Duration(minutes: 20)),
      phaseEndsAt: DateTime.now().add(const Duration(minutes: 20)),
      completedWork: 0,
      setNumber: 0,
      totalSets: 0,
      phaseIndex: 0,
      workSeconds: 20 * 60,
      restSeconds: 5 * 60,
      segments: const [],
      segmentIndex: 0,
      totalWorkSeconds: 0,
      completedWorkSeconds: 0,
    );

    var s = initial;
    s = FocusSessionController.applyAdjustTimeToState(s, 5 * 60);
    s = FocusSessionController.applyAdjustTimeToState(s, 5 * 60);
    s = FocusSessionController.applyAdjustTimeToState(s, 5 * 60);

    expect(s.remainingSeconds, equals(20 * 60 + 15 * 60));
    expect(s.timeAdjustmentSeconds, equals(15 * 60));
  });

  // ─────────────────────────────────────────────────────────────────────────
  // 2. ASOSIY MUAMMO TESTI: +5 daqiqa qo'shib, jami 25 daqiqa to'liq
  //    bajarilganda ochko HAQIQIY bajarilgan vaqtga to'g'ri mutanosib.
  //
  //    Muammo tavsifi:
  //      Asl vazifa: 20 min, task.points = 20
  //      Foydalanuvchi +5 qo'shdi → timer 25 daqiqaga uzaydi
  //      Foydalanuvchi 25 daqiqani to'liq bajaradi
  //
  //    Noto'g'ri xulosa (eski/xato formula):
  //      plannedMinutes = 20 (o'zgarmagan), actualMinutes = 25
  //      completionPercent = 25/20 = 1.25 → clamp(0,1) → 1.0
  //      adjustedBasePoints = 20 (o'zgarmagan)
  //      points = 20 * 1.0 = 20
  //      Lekin bu yolg'on: agar -5 qilsa ham 20 point olardi!
  //
  //    To'g'ri xulosa (mavjud tuzatilgan formula):
  //      adjustedPlannedMinutes = 20 + 5 = 25
  //      actualMinutes = 25 (yoki focusedSeconds ~/ 60)
  //      completionPercent = 25/25 = 1.0 ✓ (to'g'ri)
  //      adjustedBasePoints = 20 * (25/20) = 25 (vaqt oshganiga proporsional)
  //      points = 25 * 1.0 = 25 ✓
  // ─────────────────────────────────────────────────────────────────────────
  test(
    'Scoring: +5 min qo\'shib 25 daqiqa to\'liq bajarilganda ochko '  
    'to\'g\'ri hisoblanadi (completionPercent=1.0, points=25, NOT 20)',
    () {
      // Vazifa: 20 daqiqa, 20 ta ochko
      const taskDurationMinutes = 20;
      const taskPoints = 20;

      // Foydalanuvchi +5 daqiqa qo'shdi → timeAdjustmentSeconds = +300
      const timeAdjustmentSeconds = 5 * 60; // +300 soniya

      // Foydalanuvchi jami 25 daqiqani to'liq bajaradi (no distraction)
      const focusedSeconds = 25 * 60; // 1500 soniya

      final result = calcScoring(
        taskDurationMinutes: taskDurationMinutes,
        taskPoints: taskPoints,
        timeAdjustmentSeconds: timeAdjustmentSeconds,
        focusedSeconds: focusedSeconds,
      );

      // Kutilgan natijalar:
      expect(
        result['adjustedPlannedMinutes'],
        equals(25), // 20 + 5 = 25 daqiqa rejalashtirilgan
        reason: 'adjustedPlannedMinutes = 20 + 5 = 25 bo\'lishi kerak',
      );
      expect(
        result['completionPercent'],
        closeTo(1.0, 0.01), // 25/25 = 1.0
        reason: 'completionPercent = 25/25 = 1.0 bo\'lishi kerak (100% bajarildi)',
      );
      expect(
        result['adjustedBasePoints'],
        equals(25), // 20 * (25/20) = 25
        reason: 'adjustedBasePoints = 20 * (25/20) = 25 bo\'lishi kerak',
      );
      expect(
        result['points'],
        equals(25), // 25 * 1.0 = 25
        reason: '+5 daqiqa qo\'shib, jami 25 daqiqa bajarilganda 25 ochko berilishi kerak',
      );
    },
  );

  // ─────────────────────────────────────────────────────────────────────────
  // 3. Taqqoslash: asl 20 daqiqa o'zgartirmay to'liq bajarilsa 20 ochko
  // ─────────────────────────────────────────────────────────────────────────
  test(
    'Scoring: vaqt o\'zgartirmay 20 daqiqa to\'liq bajarilganda 20 ochko',
    () {
      final result = calcScoring(
        taskDurationMinutes: 20,
        taskPoints: 20,
        timeAdjustmentSeconds: 0,
        focusedSeconds: 20 * 60,
      );

      expect(result['adjustedPlannedMinutes'], equals(20));
      expect(result['completionPercent'], closeTo(1.0, 0.01));
      expect(result['adjustedBasePoints'], equals(20));
      expect(result['points'], equals(20));
    },
  );

  // ─────────────────────────────────────────────────────────────────────────
  // 4. -5 daqiqa: 20 daqiqalik vazifada -5 qilib, 15 daqiqa to'liq bajarilsa
  // ─────────────────────────────────────────────────────────────────────────
  test(
    'Scoring: -5 min ayirib 15 daqiqa to\'liq bajarilganda 15 ochko',
    () {
      final result = calcScoring(
        taskDurationMinutes: 20,
        taskPoints: 20,
        timeAdjustmentSeconds: -5 * 60, // -300 soniya
        focusedSeconds: 15 * 60,        // foydalanuvchi qisqartirilgan vaqtni to'liq bajaradi
      );

      expect(result['adjustedPlannedMinutes'], equals(15)); // 20 - 5 = 15
      expect(result['completionPercent'], closeTo(1.0, 0.01)); // 15/15 = 1.0
      expect(result['adjustedBasePoints'], equals(15)); // 20 * (15/20) = 15
      expect(result['points'], equals(15));
    },
  );

  // ─────────────────────────────────────────────────────────────────────────
  // 5. applyAdjustTimeToState: workSeconds ham yangilanishini tekshiramiz
  // ─────────────────────────────────────────────────────────────────────────
  test(
    'applyAdjustTimeToState: +5 min → workSeconds va timeAdjustmentSeconds yangilanadi',
    () {
      final initial = FocusSessionState(
        taskId: 't2',
        isInterval: false,
        status: FocusRunStatus.running,
        kind: FocusKind.work,
        remainingSeconds: 20 * 60,
        scheduledStart: DateTime.now(),
        scheduledEnd: DateTime.now().add(const Duration(minutes: 20)),
        phaseEndsAt: DateTime.now().add(const Duration(minutes: 20)),
        completedWork: 0,
        setNumber: 0,
        totalSets: 0,
        phaseIndex: 0,
        workSeconds: 20 * 60,
        restSeconds: 5 * 60,
        segments: const [],
        segmentIndex: 0,
        totalWorkSeconds: 0,
        completedWorkSeconds: 0,
      );

      final adjusted = FocusSessionController.applyAdjustTimeToState(initial, 5 * 60);

      // remainingSeconds va workSeconds oshishi kerak
      expect(adjusted.remainingSeconds, equals(25 * 60));
      expect(adjusted.workSeconds, equals(25 * 60),
          reason: 'workSeconds ham yangilanishi kerak (scoring uchun emas, display uchun)');
      expect(adjusted.timeAdjustmentSeconds, equals(5 * 60),
          reason: 'timeAdjustmentSeconds kumulyativ saqlanishi kerak');
    },
  );

  // ─────────────────────────────────────────────────────────────────────────
  // 6. Chala bajarilish: +5 qo'shib, faqat 20 daqiqa ishlasa
  //    (5 daqiqa qoldirilgan) — completionPercent < 1.0
  // ─────────────────────────────────────────────────────────────────────────
  test(
    'Scoring: +5 min qo\'shib, faqat 20 daqiqa ishlansa — chala (80%)',
    () {
      final result = calcScoring(
        taskDurationMinutes: 20,
        taskPoints: 20,
        timeAdjustmentSeconds: 5 * 60,
        focusedSeconds: 20 * 60, // 25 daqiqadan faqat 20 ini bajargan
      );

      expect(result['adjustedPlannedMinutes'], equals(25)); // 20 + 5
      expect(
        result['completionPercent'],
        closeTo(0.8, 0.01), // 20/25 = 0.8 (80%)
        reason: '20 min / 25 min planned = 80% bajarildi',
      );
      expect(result['adjustedBasePoints'], equals(25)); // 20*(25/20)=25
      expect(
        result['points'],
        equals(20), // 25 * 0.8 = 20
        reason: '80% bajarilganda 25*0.8=20 ochko',
      );
    },
  );
}
