import 'package:flowa/core/theme/app_theme.dart';
import 'package:flowa/features/sign_in/presentation/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sign-in screen shows Google and Telegram options', (tester) async {
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(theme: AppTheme.dark, home: const SignInScreen())),
    );
    await tester.pump();

    // Verify Google and Telegram keys/labels are rendered
    expect(find.textContaining('google'), findsOneWidget);
    expect(find.textContaining('telegram'), findsOneWidget);
  });
}
