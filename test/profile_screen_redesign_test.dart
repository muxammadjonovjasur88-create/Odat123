import 'package:easy_localization/easy_localization.dart';
import 'package:flowa/core/models/user_profile.dart';
import 'package:flowa/core/services/user_repository.dart';
import 'package:flowa/core/theme/app_theme.dart';
import 'package:flowa/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    EasyLocalization.logger.enableBuildModes = [];
  });

  final mockProfile = UserProfile(
    uid: 'user-123',
    name: 'Jasur Muxammadjonov',
    avatar: 'leaf',
    focusType: 'Study',
    streak: 4,
    longestStreak: 7,
    totalPoints: 450,
    totalFocusMinutes: 140,
    totalDeepSessions: 5,
    weeklyFocusMinutes: 120,
  );

  Widget buildProfileTestWidget() {
    return ProviderScope(
      overrides: [
        userProfileProvider.overrideWith((ref) => Stream.value(mockProfile)),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const ProfileScreen(),
      ),
    );
  }

  testWidgets('ProfileScreen renders user profile and stats without achievements section', (tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildProfileTestWidget());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Jasur Muxammadjonov'), findsOneWidget);

    // Scroll down
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 300));

    // Achievements should NOT be rendered on ProfileScreen
    expect(find.textContaining('First Step'), findsNothing);
    expect(find.textContaining('Week Winner'), findsNothing);
  });

  testWidgets('AchievementsGrid standalone component renders achievement cards and opens detail sheet', (tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AchievementsGrid(
              profile: mockProfile,
              filter: 'all',
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // Verify achievement cards exist in standalone AchievementsGrid
    final cardFinder = find.text('First Step');
    expect(cardFinder, findsOneWidget);

    // Tap on First Step card
    await tester.tap(cardFinder);
    await tester.pump(const Duration(milliseconds: 500));

    // Verify modal bottom sheet opened
    expect(find.byType(AchievementDetailBottomSheet), findsOneWidget);
    expect(find.text('Bu yutuqni qanday qo\'lga kiritish mumkin?'), findsOneWidget);
  });
}
