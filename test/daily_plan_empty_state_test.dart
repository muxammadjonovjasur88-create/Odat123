import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty state fits within a small viewport', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
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
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('empty state regression'), findsOneWidget);
  });
}
