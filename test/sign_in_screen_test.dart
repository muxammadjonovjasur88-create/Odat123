import 'package:easy_localization/easy_localization.dart';
import 'package:flowa/features/sign_in/presentation/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign-in screen shows Google-only flow', (tester) async {
    await EasyLocalization.ensureInitialized();

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: const ProviderScope(child: MaterialApp(home: SignInScreen())),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Google'), findsOneWidget);
    expect(find.textContaining('Mobile number'), findsNothing);
  });
}
