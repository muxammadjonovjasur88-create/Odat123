/// Kengaytirilgan ochko hisoblash to'liq oqim testi
///
/// Ushbu test to'plami quyidagi 4 xil holatni qamrab oladi:
///   A) Таймер o'zi 0:00 ga yetib, AVTOMATIK tugagan holat
///   B) Foydalanuvchi "Tugatish" tugmasini QO'LDA bosgan holat
///   C) Foydalanuvchi vaqtni +5/-5 orqali O'ZGARTIRGAN holat
///   D) Segmentli (45+ daqiqa, tanaffusli) seanslar
///
/// Har bir test uchun ANIQ kutilgan va haqiqiy natijalar solishtiriladi.
///
/// BUG FIXES covered:
///   #1+#2 — plannedMinutes noto'g'ri edi (signals.totalSeconds ishlatilmoqda edi,
///            endi task.durationMinutes + adjustments ishlatiladi)
///   #3    — nol hisob chiqsa task.points to'liq berilib qo'yilmoqda edi
///   #4    — segmentli sessiyada totalWorkSeconds noto'g'ri clamp
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/features/gamification/domain/gamification_math.dart';
import 'package:flowa/features/honest_focus/domain/honest_focus.dart';
import 'package:flowa/features/honest_focus/domain/session_integrity.dart';
import 'package:flowa/features/deep_focus/presentation/focus_session_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Yordamchi: completeFocusSession() ning sof hisob-kitob qismini simulatsiya.
// (UI va Firestore dan mustaqil — faqat matematika sinovi)
// ─────────────────────────────────────────────────────────────────────────────
({
  double completionPercent,
  int awardedPoints,
  bool counted,
  FocusVerdict verdict,
}) computeSessionScore({
  required FocusSignals signals,
  required int taskDurationMinutes,
  required int taskPoints,
}) {
  // 1. HonestFocus verdict
  var verdict = HonestFocus.evaluate(signals);
  var counted = HonestFocus.counts(verdict);

  // 2. Integrity score
  final integrityPercent = SessionIntegrity.calculateScore(
    signals: signals,
    checkInsPresented: signals.checkInsPresented,
    checkInsMissed: signals.checkInsMissed,
  );

  if (integrityPercent < 0.2) {
    counted = false;
    verdict = FocusVerdict.incomplete;
  }

  // 3. BUG FIX #1+#2: plannedMinutes = task reja + user adjustments
  final adjustedPlannedMinutes = (taskDurationMinutes +
          (signals.timeAdjustmentSeconds / 60).round())
      .clamp(1, 1440);

  // 4. completionPercent = actual focused / adjusted planned
  final completionPercent = GamificationMath.calculateTaskCompletionPercent(
    plannedMinutes: adjustedPlannedMinutes,
    actualMinutes: signals.focusedSeconds ~/ 60,
  );

  // 5. adjustedBasePoints
  final adjustedBasePoints = taskDurationMinutes > 0
      ? (taskPoints * (adjustedPlannedMinutes / taskDurationMinutes)).round()
      : taskPoints;

  // 6. Proportional points (BUG FIX #3: no fallback to task.points)
  final basePoints = GamificationMath.proportionalPoints(
    basePoints: adjustedBasePoints,
    completionPercent: completionPercent,
  );
  final awardedPoints = counted ? (basePoints * integrityPercent).round() : 0;

  return (
    completionPercent: completionPercent,
    awardedPoints: awardedPoints,
    counted: counted,
    verdict: verdict,
  );
}

// Yordamchi — FocusSignals yaratish
FocusSignals makeSignals({
  required bool timerCompleted,
  required int totalSeconds,
  int awaySeconds = 0,
  int distractingOpens = 0,
  int checkInsPresented = 0,
  int checkInsMissed = 0,
  int timeAdjustmentSeconds = 0,
}) {
  return FocusSignals(
    timerCompleted: timerCompleted,
    totalSeconds: totalSeconds,
    awaySeconds: awaySeconds,
    distractingOpens: distractingOpens,
    checkInsPresented: checkInsPresented,
    checkInsMissed: checkInsMissed,
    timeAdjustmentSeconds: timeAdjustmentSeconds,
  );
}

void main() {
  // ════════════════════════════════════════════════════════════════════════════
  // A) AVTOMATIK TUGAGAN HOLAT — timer 0:00 ga yetdi
  // ════════════════════════════════════════════════════════════════════════════
  group('A) Avtomatik tugash (timer 0:00 ga yetdi)', () {
    test(
        'A1: 60 daqiqali seans to\'liq tugasa — 100% completion, to\'liq ball',
        () {
      // 60 daqiqali seans. Foydalanuvchi butun vaqt davomida fokusda bo'ldi.
      const taskDurationMinutes = 60;
      const taskPoints = 60; // 1 ball/daqiqa

      final signals = makeSignals(
        timerCompleted: true,
        totalSeconds: 60 * 60, // 3600s real o'tgan
        awaySeconds: 0,
      );

      final result = computeSessionScore(
        signals: signals,
        taskDurationMinutes: taskDurationMinutes,
        taskPoints: taskPoints,
      );

      expect(result.completionPercent, closeTo(1.0, 0.01),
          reason: 'To\'liq bajarilgan — 100% bo\'lishi kerak');
      expect(result.verdict, FocusVerdict.full);
      expect(result.counted, isTrue);
      // adjustedBasePoints = 60 * (60/60) = 60, proportional = 60, integrity 1.0
      expect(result.awardedPoints, 60);
    });

    test(
        'A2: 30 daqiqali seans to\'liq tugasa — 100% completion, to\'liq ball',
        () {
      const taskDurationMinutes = 30;
      const taskPoints = 30;

      final signals = makeSignals(
        timerCompleted: true,
        totalSeconds: 30 * 60, // 1800s
        awaySeconds: 0,
      );

      final result = computeSessionScore(
        signals: signals,
        taskDurationMinutes: taskDurationMinutes,
        taskPoints: taskPoints,
      );

      expect(result.completionPercent, closeTo(1.0, 0.01));
      expect(result.verdict, FocusVerdict.full);
      expect(result.awardedPoints, 30);
    });

    test(
        'A3: Avtomatik tugash, lekin 10% vaqt boshqa ilovada — partial',
        () {
      const taskDurationMinutes = 60;
      const taskPoints = 60;

      final signals = makeSignals(
        timerCompleted: true,
        totalSeconds: 3600,
        awaySeconds: 360, // 10% = 360s boshqa ilova
        distractingOpens: 0,
      );

      final result = computeSessionScore(
        signals: signals,
        taskDurationMinutes: taskDurationMinutes,
        taskPoints: taskPoints,
      );

      // focusedSeconds = 3600 - 360 = 3240 (54 daqiqa)
      // completionPercent = 54/60 = 0.9
      expect(result.completionPercent, closeTo(0.9, 0.01));
      expect(result.counted, isTrue);
      // integrityPercent = 1.0 - 0.1 = 0.9
      // proportionalPoints(60, 0.9) = 54, * 0.9 = ~49
      expect(result.awardedPoints, closeTo(49, 2));
    });

    test('A4: Avtomatik tugash, 60% vaqt chetda — incomplete (no points)', () {
      const taskDurationMinutes = 60;
      const taskPoints = 60;

      final signals = makeSignals(
        timerCompleted: true,
        totalSeconds: 3600,
        awaySeconds: 2160, // 60% away → brokenAwayRatio ≥ 0.5
      );

      final result = computeSessionScore(
        signals: signals,
        taskDurationMinutes: taskDurationMinutes,
        taskPoints: taskPoints,
      );

      expect(result.verdict, FocusVerdict.incomplete);
      expect(result.counted, isFalse);
      expect(result.awardedPoints, 0);
    });

    test('A5: 5 distraction opens — incomplete verdict', () {
      final signals = makeSignals(
        timerCompleted: true,
        totalSeconds: 3600,
        awaySeconds: 0,
        distractingOpens: 5, // brokenOpens sahifasi
      );

      final result = computeSessionScore(
        signals: signals,
        taskDurationMinutes: 60,
        taskPoints: 60,
      );

      expect(result.verdict, FocusVerdict.incomplete);
      expect(result.awardedPoints, 0);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // B) QO'LDA TUGATISH — foydalanuvchi "Tugatish" tugmasini bosdi
  // ════════════════════════════════════════════════════════════════════════════
  group('B) Qo\'lda tugatish (foydalanuvchi tugmani bosdi)', () {
    test('B1: 60 daqiqa rejalashtirilgan, 30 daqiqa bajarildi', () {
      // BUG FIX #1 uchun asosiy test:
      // Avvalgi kodda plannedMinutes = signals.totalSeconds ~/ 60 = 30 (noto'g'ri)
      // Bu completionPercent = 30/30 = 1.0 (noto'g'ri!) berardi
      // Endi: plannedMinutes = task.durationMinutes = 60
      //       completionPercent = 30/60 = 0.5 (to'g'ri!)
      const taskDurationMinutes = 60;
      const taskPoints = 60;

      final signals = makeSignals(
        timerCompleted: false, // qo'lda tugatildi
        totalSeconds: 30 * 60, // 30 daqiqa real o'tgan
        awaySeconds: 0,
      );

      final result = computeSessionScore(
        signals: signals,
        taskDurationMinutes: taskDurationMinutes,
        taskPoints: taskPoints,
      );

      // timerCompleted=false → incomplete
      expect(result.verdict, FocusVerdict.incomplete,
          reason:
              'Qo\'lda erta tugatilgan → timerCompleted=false → incomplete');
      expect(result.counted, isFalse);
      expect(result.awardedPoints, 0,
          reason: 'Incomplete seans → 0 ball');

      // completionPercent to'g'ri: 30/60 = 0.5 (avval 1.0 edi — BUG FIX nazorati)
      expect(result.completionPercent, closeTo(0.5, 0.01),
          reason:
              'BUG FIX #1: plannedMinutes=60 (task reja), actual=30 → 0.5');
    });

    test('B2: 30 daqiqa rejalashtirilgan, 5 daqiqa bajarildi', () {
      const taskDurationMinutes = 30;
      const taskPoints = 30;

      final signals = makeSignals(
        timerCompleted: false,
        totalSeconds: 5 * 60, // 5 daqiqa
        awaySeconds: 0,
      );

      final result = computeSessionScore(
        signals: signals,
        taskDurationMinutes: taskDurationMinutes,
        taskPoints: taskPoints,
      );

      expect(result.verdict, FocusVerdict.incomplete);
      expect(result.awardedPoints, 0);
      // completionPercent = 5/30 ≈ 0.167
      expect(result.completionPercent, closeTo(5 / 30, 0.01));
    });

    test(
        'B3: Qo\'lda tugatish, nol ball fallback yo\'q (BUG FIX #3)',
        () {
      // Avvalgi kodda: if (expectedGained == 0 && task.points > 0) expectedGained = task.points
      // Bu 2 daqiqa bajarganda ham to'liq 60 ball berib qo'ymoqda edi!
      const taskDurationMinutes = 60;
      const taskPoints = 60;

      final signals = makeSignals(
        timerCompleted: true, // timer tamom deb ko'ring
        totalSeconds: 2 * 60, // 2 daqiqa real o'tgan
        awaySeconds: 0,
      );

      final result = computeSessionScore(
        signals: signals,
        taskDurationMinutes: taskDurationMinutes,
        taskPoints: taskPoints,
      );

      // completionPercent = 2/60 ≈ 0.033 < minCompletionPercentForPoints (0.1)
      // → proportionalPoints returns 0 → awardedPoints = 0
      expect(result.completionPercent, closeTo(2 / 60, 0.01));
      // BUG FIX #3: bo'lmagan fallback → 0 ball, avval 60 ball berardi!
      expect(result.awardedPoints, 0,
          reason:
              'BUG FIX #3: 3% completion < minThreshold(10%) → 0 ball');
    });

    test(
        'B4: 60 daqiqa → 45 daqiqa bajarildi (yetarlicha) → ball olish kerak',
        () {
      // timerCompleted=true, 45/60 = 75% → full verdict if away=0
      const taskDurationMinutes = 60;
      const taskPoints = 60;

      final signals = makeSignals(
        timerCompleted: true,
        totalSeconds: 45 * 60,
        awaySeconds: 0,
      );

      final result = computeSessionScore(
        signals: signals,
        taskDurationMinutes: taskDurationMinutes,
        taskPoints: taskPoints,
      );

      expect(result.completionPercent, closeTo(0.75, 0.01));
      expect(result.verdict, FocusVerdict.full);
      expect(result.counted, isTrue);
      // adjustedBasePoints = 60, proportional = 60*0.75 = 45, integrity=1.0 → 45
      expect(result.awardedPoints, 45);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // C) VAQT O'ZGARTIRISH — foydalanuvchi +5/-5 bosdi
  // ════════════════════════════════════════════════════════════════════════════
  group('C) Vaqt o\'zgartirish (+5/-5 daqiqa)', () {
    test('C1: +5 daqiqa qo\'shdi, keyin to\'liq bajardi — 100% bo\'lishi kerak',
        () {
      // Reja: 60 daqiqa. User +5 qo'shdi → 65 daqiqa reja.
      // To'liq bajardi (65 daqiqa, timerCompleted=true)
      const taskDurationMinutes = 60;
      const taskPoints = 60;
      const timeAdj = 5 * 60; // +300 sekund

      final signals = makeSignals(
        timerCompleted: true,
        totalSeconds: 65 * 60, // 65 daqiqa real o'tgan
        awaySeconds: 0,
        timeAdjustmentSeconds: timeAdj,
      );

      final result = computeSessionScore(
        signals: signals,
        taskDurationMinutes: taskDurationMinutes,
        taskPoints: taskPoints,
      );

      // adjustedPlannedMinutes = 60 + 5 = 65
      // completionPercent = 65/65 = 1.0
      expect(result.completionPercent, closeTo(1.0, 0.01),
          reason: '+5 daqiqa qo\'shildi va to\'liq bajarildi → 100%');
      expect(result.verdict, FocusVerdict.full);
      expect(result.counted, isTrue);
      // adjustedBasePoints = 60 * (65/60) = 65, proportional = 65
      expect(result.awardedPoints, 65);
    });

    test('C2: -5 daqiqa olib tashladi, keyin to\'liq bajardi — 100% bo\'lishi kerak',
        () {
      const taskDurationMinutes = 60;
      const taskPoints = 60;
      const timeAdj = -5 * 60; // -300 sekund

      final signals = makeSignals(
        timerCompleted: true,
        totalSeconds: 55 * 60,
        awaySeconds: 0,
        timeAdjustmentSeconds: timeAdj,
      );

      final result = computeSessionScore(
        signals: signals,
        taskDurationMinutes: taskDurationMinutes,
        taskPoints: taskPoints,
      );

      // adjustedPlannedMinutes = 60 + (-5) = 55
      // completionPercent = 55/55 = 1.0
      expect(result.completionPercent, closeTo(1.0, 0.01));
      expect(result.verdict, FocusVerdict.full);
      // adjustedBasePoints = 60 * (55/60) = 55, awarded = 55
      expect(result.awardedPoints, 55);
    });

    test('C3: +5 daqiqa qo\'shdi, yarim yo\'lda tugatdi', () {
      // Reja: 60 + 5 = 65 daqiqa. User 32 daqiqada tugatdi.
      const taskDurationMinutes = 60;
      const taskPoints = 60;
      const timeAdj = 5 * 60; // +300 sekund

      final signals = makeSignals(
        timerCompleted: false, // qo'lda erta tugatdi
        totalSeconds: 32 * 60,
        awaySeconds: 0,
        timeAdjustmentSeconds: timeAdj,
      );

      final result = computeSessionScore(
        signals: signals,
        taskDurationMinutes: taskDurationMinutes,
        taskPoints: taskPoints,
      );

      // timerCompleted=false → incomplete → 0 ball
      expect(result.verdict, FocusVerdict.incomplete);
      expect(result.awardedPoints, 0);
      // completionPercent = 32/65 ≈ 0.492
      expect(result.completionPercent, closeTo(32 / 65, 0.01));
    });

    test(
        'C4: BUG FIX #1 regresion — signals.totalSeconds != task.durationMinutes',
        () {
      // ASOSIY REGRESION TEST:
      // Avvalgi kodda: plannedMinutes = signals.totalSeconds ~/ 60 = 45
      // Bu completionPercent = 45/45 = 1.0 (NOTO'G'RI!)
      // Endi: plannedMinutes = task.durationMinutes = 60
      //       completionPercent = 45/60 = 0.75 (TO'G'RI)
      const taskDurationMinutes = 60;
      const taskPoints = 60;

      final signals = makeSignals(
        timerCompleted: false,
        totalSeconds: 45 * 60, // 45 daqiqa real o'tgan
        awaySeconds: 0,
        timeAdjustmentSeconds: 0,
      );

      final result = computeSessionScore(
        signals: signals,
        taskDurationMinutes: taskDurationMinutes,
        taskPoints: taskPoints,
      );

      // ESKI (NOTO'G'RI): completionPercent = 1.0 → awardedPoints = 60
      // YANGI (TO'G'RI): completionPercent = 45/60 = 0.75 → 0 (incomplete)
      expect(result.completionPercent, closeTo(0.75, 0.01),
          reason:
              'BUG FIX #1: plannedMinutes=60, actual=45 → 0.75 (avval 1.0 edi)');
      expect(result.verdict, FocusVerdict.incomplete);
      expect(result.awardedPoints, 0);
    });

    test('C5: +10 daqiqa, timerCompleted=true, 10% away', () {
      const taskDurationMinutes = 30;
      const taskPoints = 30;
      const timeAdj = 10 * 60;

      final signals = makeSignals(
        timerCompleted: true,
        totalSeconds: 40 * 60,
        awaySeconds: 4 * 60, // 10% boshqa ilova
        timeAdjustmentSeconds: timeAdj,
      );

      final result = computeSessionScore(
        signals: signals,
        taskDurationMinutes: taskDurationMinutes,
        taskPoints: taskPoints,
      );

      // adjustedPlannedMinutes = 30 + 10 = 40
      // focusedSeconds = 2400 - 240 = 2160 (36 daqiqa)
      // completionPercent = 36/40 = 0.9
      expect(result.completionPercent, closeTo(0.9, 0.01));
      expect(result.counted, isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // D) SEGMENTLI SEANSLAR (45+ daqiqa, tanaffusli)
  // ════════════════════════════════════════════════════════════════════════════
  group('D) Segmentli seanslar (45+ daqiqa)', () {
    test('D1: 45 daqiqa → yagona blok (segmentlanmaydi)', () {
      final segs = buildDeepFocusSegments(45 * 60);
      expect(segs.length, 1);
      expect(segs[0].kind, FocusKind.work);
      expect(segs[0].seconds, 45 * 60);
    });

    test('D2: 90 daqiqa → W(45) R(5) W(45) = 3 segment', () {
      final segs = buildDeepFocusSegments(90 * 60);
      expect(segs.length, 3);
      expect(segs[0].kind, FocusKind.work);
      expect(segs[0].seconds, 45 * 60);
      expect(segs[1].kind, FocusKind.rest);
      expect(segs[1].seconds, 5 * 60);
      expect(segs[2].kind, FocusKind.work);
      expect(segs[2].seconds, 45 * 60);
    });

    test('D3: 120 daqiqa → W(45) R(5) W(45) R(5) W(30) = 5 segment', () {
      final segs = buildDeepFocusSegments(120 * 60);
      expect(segs.length, 5);
      expect(segs[0].kind, FocusKind.work);
      expect(segs[0].seconds, 45 * 60);
      expect(segs[1].kind, FocusKind.rest);
      expect(segs[2].kind, FocusKind.work);
      expect(segs[2].seconds, 45 * 60);
      expect(segs[3].kind, FocusKind.rest);
      expect(segs[4].kind, FocusKind.work);
      expect(segs[4].seconds, 30 * 60);
    });

    test('D4: 120 daqiqa seansda totalWorkSeconds to\'g\'ri = 120 daqiqa', () {
      final segs = buildDeepFocusSegments(120 * 60);
      final totalWork =
          segs.where((s) => s.isWork).fold(0, (sum, s) => sum + s.seconds);
      expect(totalWork, 120 * 60);
    });

    test('D5: 120 daqiqa seansda hamma ish tugaganda — 100% completion', () {
      const taskDurationMinutes = 120;
      const taskPoints = 120;

      // totalSeconds = 120 daqiqa ish + 10 daqiqa tanaffus = 130 daqiqa real
      final signals = makeSignals(
        timerCompleted: true,
        totalSeconds: 130 * 60,
        awaySeconds: 0,
      );

      final result = computeSessionScore(
        signals: signals,
        taskDurationMinutes: taskDurationMinutes,
        taskPoints: taskPoints,
      );

      // focusedSeconds = 7800 → actualMinutes = 130
      // adjustedPlannedMinutes = 120
      // completionPercent = clamp(130/120, 0,1) = 1.0
      expect(result.completionPercent, closeTo(1.0, 0.01));
      expect(result.verdict, FocusVerdict.full);
      expect(result.awardedPoints, 120);
    });

    test('D6: Segmentli — yarim yo\'lda tugatdi (65/120 daqiqa)', () {
      const taskDurationMinutes = 120;
      const taskPoints = 120;

      final signals = makeSignals(
        timerCompleted: false,
        totalSeconds: 65 * 60,
        awaySeconds: 0,
      );

      final result = computeSessionScore(
        signals: signals,
        taskDurationMinutes: taskDurationMinutes,
        taskPoints: taskPoints,
      );

      expect(result.verdict, FocusVerdict.incomplete);
      expect(result.awardedPoints, 0);
      expect(result.completionPercent, closeTo(65 / 120, 0.01));
    });

    test('D7: Segmentli — +5 daqiqa o\'zgartirib, to\'liq bajardi', () {
      const taskDurationMinutes = 120;
      const taskPoints = 120;
      const timeAdj = 5 * 60;

      final signals = makeSignals(
        timerCompleted: true,
        totalSeconds: 135 * 60, // 125 work + 10 rest
        awaySeconds: 0,
        timeAdjustmentSeconds: timeAdj,
      );

      final result = computeSessionScore(
        signals: signals,
        taskDurationMinutes: taskDurationMinutes,
        taskPoints: taskPoints,
      );

      // adjustedPlannedMinutes = 120 + 5 = 125
      // actualMinutes = 135 → completionPercent = clamp(135/125) = 1.0
      expect(result.completionPercent, closeTo(1.0, 0.01));
      expect(result.verdict, FocusVerdict.full);
      // adjustedBasePoints = 120 * (125/120) = 125, awarded = 125
      expect(result.awardedPoints, 125);
    });

    test(
        'D8: BUG FIX #4 — applyAdjustTimeToState totalWorkSeconds to\'g\'ri hisob',
        () {
      // 120 daqiqali sessiya, birinchi 45-min work segmentida +5 daqiqa qo'shilsa
      final now = DateTime.now();
      const seg1 = FocusSegment(kind: FocusKind.work, seconds: 45 * 60);
      const seg2 = FocusSegment(kind: FocusKind.rest, seconds: 5 * 60);
      const seg3 = FocusSegment(kind: FocusKind.work, seconds: 45 * 60);
      const seg4 = FocusSegment(kind: FocusKind.rest, seconds: 5 * 60);
      const seg5 = FocusSegment(kind: FocusKind.work, seconds: 30 * 60);

      final s = FocusSessionState(
        taskId: 'test-task',
        isInterval: false,
        status: FocusRunStatus.running,
        kind: FocusKind.work,
        remainingSeconds: 45 * 60,
        scheduledStart: now,
        scheduledEnd: now.add(const Duration(hours: 2)),
        phaseEndsAt: now.add(const Duration(minutes: 45)),
        completedWork: 0,
        setNumber: 0,
        totalSets: 0,
        phaseIndex: 0,
        workSeconds: 45 * 60,
        restSeconds: 5 * 60,
        segments: [seg1, seg2, seg3, seg4, seg5],
        segmentIndex: 0,
        totalWorkSeconds: 120 * 60, // 7200 s
        completedWorkSeconds: 0,
        actualSessionStart: now.subtract(const Duration(seconds: 10)),
      );

      // +5 daqiqa (300 sekund) qo'shamiz
      final updated = FocusSessionController.applyAdjustTimeToState(s, 300);

      // totalWorkSeconds = 7200 + 300 = 7500
      // BUG FIX #4: avval clamp(60,...) edi — 60 dan kichraymasligi kerak deb
      // noto'g'ri edi. Endi clamp(0,...) — to'g'ri.
      expect(updated.totalWorkSeconds, 7500);
      // Birinchi segment = 45*60 + 300 = 3000
      expect(updated.segments[0].seconds, 3000);
      expect(updated.timeAdjustmentSeconds, 300);
    });

    test('D9: applyAdjustTimeToState — -5 daqiqa, totalWorkSeconds kamaytirishi',
        () {
      final now = DateTime.now();
      const seg1 = FocusSegment(kind: FocusKind.work, seconds: 45 * 60);
      const seg2 = FocusSegment(kind: FocusKind.rest, seconds: 5 * 60);
      const seg3 = FocusSegment(kind: FocusKind.work, seconds: 45 * 60);

      final s = FocusSessionState(
        taskId: 'test-task',
        isInterval: false,
        status: FocusRunStatus.running,
        kind: FocusKind.work,
        remainingSeconds: 45 * 60,
        scheduledStart: now,
        scheduledEnd: now.add(const Duration(hours: 2)),
        phaseEndsAt: now.add(const Duration(minutes: 45)),
        completedWork: 0,
        setNumber: 0,
        totalSets: 0,
        phaseIndex: 0,
        workSeconds: 45 * 60,
        restSeconds: 5 * 60,
        segments: [seg1, seg2, seg3],
        segmentIndex: 0,
        totalWorkSeconds: 90 * 60, // 5400 s
        completedWorkSeconds: 0,
        actualSessionStart: now.subtract(const Duration(seconds: 10)),
      );

      final updated = FocusSessionController.applyAdjustTimeToState(s, -300);

      // totalWorkSeconds = 5400 - 300 = 5100
      expect(updated.totalWorkSeconds, 5100);
      // Birinchi segment = 2700 - 300 = 2400
      expect(updated.segments[0].seconds, 2400);
      expect(updated.timeAdjustmentSeconds, -300);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // E) QURBONLIK HOLATLARI (Edge cases)
  // ════════════════════════════════════════════════════════════════════════════
  group('E) Qurbonlik holatlari (edge cases)', () {
    test('E1: totalSeconds=0 → integrity 1.0, awardedPoints=0', () {
      final signals = makeSignals(
        timerCompleted: false,
        totalSeconds: 0,
      );

      final integrity = SessionIntegrity.calculateScore(
        signals: signals,
        checkInsPresented: 0,
        checkInsMissed: 0,
      );
      expect(integrity, 1.0);

      final result = computeSessionScore(
        signals: signals,
        taskDurationMinutes: 60,
        taskPoints: 60,
      );
      expect(result.verdict, FocusVerdict.incomplete);
      expect(result.awardedPoints, 0);
      expect(result.completionPercent, 0.0);
    });

    test('E2: timeAdjustmentSeconds o\'ta katta → clamp(1, 1440)', () {
      final signals = makeSignals(
        timerCompleted: true,
        totalSeconds: 3600,
        awaySeconds: 0,
        timeAdjustmentSeconds: 200000, // 3333 daqiqa — mantiqsiz
      );

      final result = computeSessionScore(
        signals: signals,
        taskDurationMinutes: 60,
        taskPoints: 60,
      );

      // adjustedPlannedMinutes = clamp(60 + 3333, 1, 1440) = 1440
      // focusedMinutes = 60 → completionPercent = 60/1440 ≈ 0.042 < 0.1 → 0 pts
      expect(result.completionPercent, closeTo(60 / 1440, 0.01));
      expect(result.awardedPoints, 0);
    });

    test('E3: 1 daqiqali mini seans to\'liq bajarilsa — to\'g\'ri ball', () {
      final result = computeSessionScore(
        signals: makeSignals(
            timerCompleted: true, totalSeconds: 60, awaySeconds: 0),
        taskDurationMinutes: 1,
        taskPoints: 1,
      );

      expect(result.completionPercent, closeTo(1.0, 0.01));
      expect(result.verdict, FocusVerdict.full);
      expect(result.awardedPoints, 1);
    });

    test('E4: Hisob zanjiri monotonligi — uzun seans ko\'proq ball beradi', () {
      final r30 = computeSessionScore(
        signals: makeSignals(
            timerCompleted: true, totalSeconds: 30 * 60, awaySeconds: 0),
        taskDurationMinutes: 30,
        taskPoints: 30,
      );
      final r60 = computeSessionScore(
        signals: makeSignals(
            timerCompleted: true, totalSeconds: 60 * 60, awaySeconds: 0),
        taskDurationMinutes: 60,
        taskPoints: 60,
      );
      final r120 = computeSessionScore(
        signals: makeSignals(
            timerCompleted: true, totalSeconds: 120 * 60, awaySeconds: 0),
        taskDurationMinutes: 120,
        taskPoints: 120,
      );

      expect(r30.awardedPoints, lessThan(r60.awardedPoints));
      expect(r60.awardedPoints, lessThan(r120.awardedPoints));
    });

    test('E5: integrity < 0.2 → counted=false, 0 ball', () {
      // 90% missed check-ins → missedRatio=0.9 → integrity=0.1 < 0.2
      final result = computeSessionScore(
        signals: makeSignals(
          timerCompleted: true,
          totalSeconds: 3600,
          awaySeconds: 0,
          checkInsPresented: 10,
          checkInsMissed: 9, // 90% missed
        ),
        taskDurationMinutes: 60,
        taskPoints: 60,
      );

      expect(result.counted, isFalse);
      expect(result.awardedPoints, 0);
    });

    test(
        'E6: 100 daqiqali seans, 20% missed check-ins + 10% away → proportional',
        () {
      final signals = makeSignals(
        timerCompleted: true,
        totalSeconds: 6000,
        awaySeconds: 600, // 10%
        checkInsPresented: 5,
        checkInsMissed: 1, // 20%
      );

      final integ = SessionIntegrity.calculateScore(
        signals: signals,
        checkInsPresented: signals.checkInsPresented,
        checkInsMissed: signals.checkInsMissed,
      );
      expect(integ, closeTo(0.8, 0.01));

      final result = computeSessionScore(
        signals: signals,
        taskDurationMinutes: 100,
        taskPoints: 100,
      );

      // focusedSeconds = 6000-600 = 5400 → actualMinutes = 90
      // adjustedPlannedMinutes = 100
      // completionPercent = 90/100 = 0.9
      expect(result.completionPercent, closeTo(0.9, 0.01));
      // awayRatio=0.1 < brokenAwayRatio(0.5), distractingOpens=0 → full
      expect(result.verdict, FocusVerdict.full);
      // basePoints = 100 * 0.9 = 90, awarded = 90 * 0.8 = 72
      expect(result.awardedPoints, closeTo(72, 2));
    });
  });
}
