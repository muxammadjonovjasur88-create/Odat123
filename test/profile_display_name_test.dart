import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/features/profile/domain/profile_display_name.dart';

void main() {
  group('secondaryProfileName', () {
    test('returns null when display name is empty', () {
      expect(
        secondaryProfileName(primaryName: 'Aziz', displayName: ''),
        isNull,
      );
    });

    test('returns null when display name matches the main name', () {
      expect(
        secondaryProfileName(primaryName: 'Aziz', displayName: 'Aziz'),
        isNull,
      );
    });

    test('returns the display name when it differs from the main name', () {
      expect(
        secondaryProfileName(primaryName: 'Aziz', displayName: 'Aziz A.'),
        'Aziz A.',
      );
    });
  });
}
