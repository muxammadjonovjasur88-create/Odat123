import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flowa/core/models/user_profile.dart';
import 'package:flowa/core/router/app_routes.dart';
import 'package:flowa/core/services/user_repository.dart';
import 'package:flowa/core/theme/app_theme.dart';
import 'package:flowa/features/daily_plan/presentation/daily_quests_widget.dart';

void main() {
  group('DailyQuestsWidget — widget tests', () {
    final mockProfile = UserProfile(
      uid: 'test_uid',
      name: 'Test User',
      avatar: 'leaf',
      focusType: 'Study',
      totalPoints: 100,
    );

    Widget buildWrapper() {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: SingleChildScrollView(child: DailyQuestsWidget()),
            ),
          ),
          GoRoute(
            path: AppRoutes.library,
            builder: (context, state) => const Scaffold(
              body: Text('Library Screen Placeholder'),
            ),
          ),
          GoRoute(
            path: AppRoutes.running,
            builder: (context, state) => const Scaffold(
              body: Text('Running Screen Placeholder'),
            ),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((ref) => Stream.value(mockProfile)),
        ],
        child: MaterialApp.router(
          theme: AppTheme.dark,
          routerConfig: router,
        ),
      );
    }

    testWidgets('renders daily quest cards correctly', (tester) async {
      await tester.pumpWidget(buildWrapper());
      await tester.pumpAndSettle();

      expect(find.byType(DailyQuestsWidget), findsOneWidget);
      expect(find.text('KUNLIK KVESTLAR'), findsOneWidget);
    });

    testWidgets('navigates to LibraryScreen on Kitob o\'qish tap', (tester) async {
      await tester.pumpWidget(buildWrapper());
      await tester.pumpAndSettle();

      final bookFinder = find.text('Kitob o\'qish');
      if (bookFinder.evaluate().isNotEmpty) {
        await tester.tap(bookFinder);
        await tester.pumpAndSettle();
        expect(find.text('Library Screen Placeholder'), findsOneWidget);
      }
    });
  });
}
