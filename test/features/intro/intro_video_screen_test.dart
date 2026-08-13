import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flowa/features/intro/presentation/intro_video_screen.dart';

void main() {
  testWidgets('IntroVideoScreen does NOT contain any Skip button or text',
      (WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const IntroVideoScreen(),
        ),
        GoRoute(
          path: '/welcome',
          builder: (context, state) => const Scaffold(body: Text('Welcome')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
      ),
    );

    // Verify "O'tkazib yuborish" text and Skip button are not present anywhere
    expect(find.text("O'tkazib yuborish"), findsNothing);
    expect(find.text("Skip"), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });
}
