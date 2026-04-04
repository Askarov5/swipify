import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipify/features/swipe_deck/swipe_deck_progress_overlay.dart';

void main() {
  group('SwipeDeckProgressOverlay', () {
    testWidgets('shows DELETE and KEEP labels', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SwipeDeckProgressOverlay(progress: 0.42),
          ),
        ),
      );

      expect(find.text('DELETE'), findsOneWidget);
      expect(find.text('KEEP'), findsOneWidget);
    });

    testWidgets('binds LinearProgressIndicator to progress', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SwipeDeckProgressOverlay(progress: 0.75),
          ),
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.75);
    });
  });
}
