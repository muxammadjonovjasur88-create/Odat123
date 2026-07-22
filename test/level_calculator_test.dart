import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/features/gamification/domain/level_calculator.dart';

void main() {
  group('LevelCalculator', () {
    test('returns level 1 for zero focus minutes', () {
      expect(LevelCalculator.calculateLevel(0), 1);
      expect(LevelCalculator.levelProgress(0), 0.0);
      expect(LevelCalculator.minutesToNextLevel(0), 300);
    });

    test('reaches level 2 at 300 minutes', () {
      expect(LevelCalculator.calculateLevel(300), 2);
      expect(LevelCalculator.levelProgress(300), 0.0);
      expect(LevelCalculator.minutesToNextLevel(300), 600);
    });

    test('reaches level 3 at 900 minutes', () {
      expect(LevelCalculator.calculateLevel(900), 3);
      expect(LevelCalculator.levelProgress(900), 0.0);
      expect(LevelCalculator.minutesToNextLevel(900), 900);
    });
  });
}
