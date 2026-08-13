import 'package:easy_localization/easy_localization.dart';
import 'package:flowa/core/models/user_profile.dart';
import 'package:flowa/core/services/user_repository.dart';
import 'package:flowa/core/theme/app_theme.dart';
import 'package:flowa/features/settings/presentation/feedback_sheet.dart';
import 'package:flowa/features/settings/presentation/settings_screen.dart';
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
    name: 'Jasur',
    avatar: 'leaf',
    focusType: 'Study',
    createdAt: DateTime(2026, 1, 1),
  );

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        userProfileProvider.overrideWith((ref) => Stream.value(mockProfile)),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('uz')],
        path: 'assets/translations',
        fallbackLocale: const Locale('uz'),
        startLocale: const Locale('uz'),
        child: Builder(
          builder: (context) {
            return MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              theme: AppTheme.dark,
              home: const SettingsScreen(),
            );
          },
        ),
      ),
    );
  }

  testWidgets('SettingsScreen renders Yordam va taklif row and removes deleted sections', (tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildTestWidget());
    await tester.pump();

    // Verify "Yordam va taklif" row exists
    expect(find.text('Yordam va taklif'), findsOneWidget);
    expect(find.text('Fikr-mulohaza yoki muammo haqida yozing'), findsOneWidget);

    // Verify removed rows and headers are NOT present
    expect(find.text('Budilnik ovozi'), findsNothing);
    expect(find.text('Tasodifiy Isbot'), findsNothing);
    expect(find.text('Do\'stlarning isbotlari'), findsNothing);
    expect(find.text('Telegram ulanishi'), findsNothing);
  });

  testWidgets('FeedbackSheet component renders multi-line input and Yuborish button', (tester) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: FeedbackSheet(),
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify FeedbackSheet controls
    expect(find.byType(FeedbackSheet), findsOneWidget);
    expect(find.text('Xabaringizni yozing...'), findsOneWidget);
    expect(find.text('Yuborish'), findsOneWidget);
  });
}
