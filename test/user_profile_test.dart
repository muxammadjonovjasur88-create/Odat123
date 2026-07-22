import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/core/models/user_profile.dart';

void main() {
  test('profile map stores displayName, bio and photoUrl', () {
    final profile = UserProfile(
      uid: 'u1',
      name: 'Mina',
      avatar: 'leaf',
      focusType: 'Study',
      displayName: 'Mina Zen',
      bio: 'Deep work lover',
      photoUrl: 'https://example.com/avatar.png',
    );

    final data = profile.toCreateMap();

    expect(data['displayName'], 'Mina Zen');
    expect(data['bio'], 'Deep work lover');
    expect(data['photoUrl'], 'https://example.com/avatar.png');
  });
}
