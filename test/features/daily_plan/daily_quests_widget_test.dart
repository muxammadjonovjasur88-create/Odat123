import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flowa/core/router/app_routes.dart';
import 'package:flowa/core/theme/app_theme.dart';
import 'package:flowa/features/daily_plan/presentation/daily_quests_widget.dart';

void main() {
  group('DailyQuestsWidget — widget tests', () {
    Widget buildWrapper() {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: DailyQuestsWidget(),
            ),
          ),
          GoRoute(
            path: AppRoutes.library,
            builder: (context, state) => const Scaffold(
              body: Text('Library Screen Placeholder'),
            ),
          ),
        ],
      );

      return MaterialApp.router(
        theme: AppTheme.dark,
        routerConfig: router,
      );
    }

    testWidgets('renders daily quest cards and opens Coming Soon bottom sheet on Yugurish tap', (tester) async {
      await tester.pumpWidget(buildWrapper());
      await tester.pumpAndSettle();

      expect(find.byType(DailyQuestsWidget), findsOneWidget);

      // Tap the first quest card (Yugurish)
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // "Tez orada!" bottom sheet should appear
      expect(find.text('Tez orada!'), findsOneWidget);
      expect(find.text('Tushunarli'), findsOneWidget);

      // Dismiss the bottom sheet
      await tester.tap(find.text('Tushunarli'));
      await tester.pumpAndSettle();

      expect(find.text('Tez orada!'), findsNothing);
    });

    testWidgets('navigates to LibraryScreen on Kitob o\'qish tap', (tester) async {
      await tester.pumpWidget(buildWrapper());
      await tester.pumpAndSettle();

      // Tap the second quest card (Kitob o'qish)
      await tester.tap(find.byType(InkWell).at(1));
      await tester.pumpAndSettle();

      // Should navigate to Library screen and NOT show Coming Soon bottom sheet
      expect(find.text('Tez orada!'), findsNothing);
      expect(find.text('Library Screen Placeholder'), findsOneWidget);
    });
  });
}
