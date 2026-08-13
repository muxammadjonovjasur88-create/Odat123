import 'package:flowa/core/models/user_profile.dart';
import 'package:flowa/core/services/user_repository.dart';
import 'package:flowa/core/theme/app_theme.dart';
import 'package:flowa/features/streak/presentation/streak_header_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestWidget({required Stream<UserProfile?> profileStream}) {
    return ProviderScope(
      overrides: [
        userProfileProvider.overrideWith((ref) => profileStream),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: Center(
            child: StreakHeaderBadge(),
          ),
        ),
      ),
    );
  }

  testWidgets('renders streak count > 0 correctly', (tester) async {
    const profile = UserProfile(
      uid: 'u1',
      name: 'Tester',
      avatar: 'leaf',
      focusType: 'pomodoro',
      streak: 12,
    );

    await tester.pumpWidget(
      buildTestWidget(profileStream: Stream.value(profile)),
    );
    await tester.pumpAndSettle();

    expect(find.text('12'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
  });

  testWidgets('renders streak 0 correctly without error', (tester) async {
    const profile = UserProfile(
      uid: 'u1',
      name: 'Tester',
      avatar: 'leaf',
      focusType: 'pomodoro',
      streak: 0,
    );

    await tester.pumpWidget(
      buildTestWidget(profileStream: Stream.value(profile)),
    );
    await tester.pumpAndSettle();

    expect(find.text('0'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
  });

  testWidgets('handles loading / uninitialized profile state safely', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(profileStream: const Stream.empty()),
    );
    await tester.pump();

    // Default fallback to 0 streak when profile has not loaded yet
    expect(find.text('0'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
  });
}
