import 'package:flutter_test/flutter_test.dart';

import 'package:flowa/features/profile/domain/achievement.dart';

void main() {
  test('adds the new simple achievements to the profile list', () {
    final names = kAchievements.map((a) => a.name).toList();

    expect(names, containsAll(<String>[
      'First Step',
      'Week Winner',
      'Night Owl',
      'Focused Mind',
    ]));
    expect(kAchievements.length, 8);
  });
}
