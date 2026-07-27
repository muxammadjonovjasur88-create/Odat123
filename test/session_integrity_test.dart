import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/features/honest_focus/domain/honest_focus.dart';
import 'package:flowa/features/honest_focus/domain/session_integrity.dart';

void main() {
  group('SessionIntegrity', () {
    test('100% honest session', () {
      final signals = FocusSignals(
        totalSeconds: 3000,
        awaySeconds: 0,
      );
      final score = SessionIntegrity.calculateScore(
        signals: signals,
        checkInsPresented: 5,
        checkInsMissed: 0,
      );
      expect(score, 1.0);
    });

    test('Short background time (<20s) is forgiven (100% score)', () {
      final signals = FocusSignals(
        totalSeconds: 3000,
        awaySeconds: 15,
      );
      final score = SessionIntegrity.calculateScore(
        signals: signals,
        checkInsPresented: 5,
        checkInsMissed: 0,
      );
      expect(score, 1.0);
    });

    test('Partial penalty for away time (10% away -> 0.9 score)', () {
      final signals = FocusSignals(
        totalSeconds: 3000,
        awaySeconds: 300,
      );
      final score = SessionIntegrity.calculateScore(
        signals: signals,
        checkInsPresented: 5,
        checkInsMissed: 0,
      );
      expect(score, closeTo(0.9, 0.01));
    });

    test('Partial penalty for missed check-ins (1 out of 4 missed -> 0.75 score)', () {
      final signals = FocusSignals(
        totalSeconds: 3000,
        awaySeconds: 0,
      );
      final score = SessionIntegrity.calculateScore(
        signals: signals,
        checkInsPresented: 4,
        checkInsMissed: 1,
      );
      expect(score, closeTo(0.75, 0.01));
    });

    test('Max penalty is applied (away vs missed check-ins)', () {
      final signals = FocusSignals(
        totalSeconds: 3000,
        awaySeconds: 600, // 20% away -> 0.8 integrity
      );
      final score = SessionIntegrity.calculateScore(
        signals: signals,
        checkInsPresented: 4,
        checkInsMissed: 2, // 50% missed -> 0.5 integrity
      );
      // The penalty is max(0.2, 0.5) = 0.5. Integrity = 1.0 - 0.5 = 0.5.
      expect(score, closeTo(0.5, 0.01));
    });

    test('0 score for completely fake session (e.g. 90% away)', () {
      final signals = FocusSignals(
        totalSeconds: 3000,
        awaySeconds: 2700,
      );
      final score = SessionIntegrity.calculateScore(
        signals: signals,
        checkInsPresented: 0,
        checkInsMissed: 0,
      );
      expect(score, 0.0);
    });

    test('0 score for ignoring almost all check-ins', () {
      final signals = FocusSignals(
        totalSeconds: 3000,
        awaySeconds: 0,
      );
      final score = SessionIntegrity.calculateScore(
        signals: signals,
        checkInsPresented: 5,
        checkInsMissed: 5,
      );
      expect(score, 0.0);
    });

    test('calculateSessionIntegrityScore top-level helper test', () {
      final signals = FocusSignals(
        totalSeconds: 1800,
        awaySeconds: 180, // 10% away -> 0.9
      );
      final score = calculateSessionIntegrityScore(
        signals: signals,
        checkInsPresented: 3,
        checkInsMissed: 0,
      );
      expect(score, closeTo(0.9, 0.01));
    });
  });
}
