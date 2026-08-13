import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowa/core/widgets/spinning_coin.dart';

void main() {
  testWidgets('SpinningCoin renders correctly without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SpinningCoin(size: 24),
          ),
        ),
      ),
    );

    // Verify widget is present in tree
    expect(find.byType(SpinningCoin), findsOneWidget);
    expect(find.text('\$'), findsOneWidget);

    // Pump frames to verify animation controller ticks cleanly
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 1000));
  });
}
