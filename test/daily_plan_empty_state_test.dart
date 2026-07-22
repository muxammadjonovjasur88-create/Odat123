import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('empty state fits within a small viewport', (tester) async {
    await EasyLocalization.ensureInitialized();

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(360, 220)),
            child: Scaffold(
              body: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(height: 12),
                  Text('empty state regression'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('empty state regression'), findsOneWidget);
  });
}
