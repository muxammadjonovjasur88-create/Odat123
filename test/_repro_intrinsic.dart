import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TextField inside IntrinsicHeight, then torn down', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: IntrinsicHeight(
              child: Column(
                children: const [
                  Spacer(),
                  TextField(),
                  Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    // Tear the subtree down (like navigating away from Goal Reached).
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
