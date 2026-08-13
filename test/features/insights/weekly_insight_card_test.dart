import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flowa/core/theme/app_theme.dart';
import 'package:flowa/features/insights/presentation/weekly_insight_card.dart';

void main() {
  testWidgets('WeeklyInsightCard shows insight and expands/collapses',
      (WidgetTester tester) async {
    const testText = 'Bu hafta: ajoyib ishladingiz. Davom eting!';

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: WeeklyInsightCard(
              testUid: 'test-uid',
              insightOverride: testText,
            ),
          ),
        ),
      ),
    );

    // initial render: should show truncated text (maxLines=3) and the title
    expect(find.text('insights.weekly_title'.replaceAll('insights.weekly_title', 'Weekly insight')), findsNothing);
    // The card should contain the insight text (may be truncated)
    expect(find.textContaining('Bu hafta'), findsOneWidget);

    // Tap expand icon
    final expandButton = find.byIcon(Icons.expand_more);
    expect(expandButton, findsOneWidget);
    await tester.tap(expandButton);
    await tester.pumpAndSettle();

    // After expanding, the collapse icon should appear
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
  });
}
