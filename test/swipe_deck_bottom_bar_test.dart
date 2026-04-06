import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipify/features/swipe_deck/swipe_deck_bottom_bar.dart';

void main() {
  group('SwipeDeckBottomBar', () {
    testWidgets('invokes onDelete onKeep onApplyDeletes when not busy',
        (tester) async {
      var deleteTaps = 0;
      var keepTaps = 0;
      var applyTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwipeDeckBottomBar(
              deckBusy: false,
              canApplyDeletes: true,
              pendingDeleteCount: 2,
              onDelete: () => deleteTaps++,
              onKeep: () => keepTaps++,
              onApplyDeletes: () => applyTaps++,
            ),
          ),
        ),
      );

      expect(find.text('Delete(2)'), findsOneWidget);

      await tester.tap(find.byTooltip('Mark for delete'));
      await tester.tap(find.byTooltip(
        'Remove delete list from library and leave. You can resume this batch later.',
      ));
      await tester.tap(find.byIcon(Icons.skip_next));
      expect(deleteTaps, 1);
      expect(keepTaps, 1);
      expect(applyTaps, 1);
    });

    testWidgets('disables delete keep and apply while deckBusy', (tester) async {
      var deleteTaps = 0;
      var keepTaps = 0;
      var applyTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwipeDeckBottomBar(
              deckBusy: true,
              canApplyDeletes: true,
              pendingDeleteCount: 1,
              onDelete: () => deleteTaps++,
              onKeep: () => keepTaps++,
              onApplyDeletes: () => applyTaps++,
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Mark for delete'));
      await tester.tap(find.byTooltip(
        'Remove delete list from library and leave. You can resume this batch later.',
      ));
      await tester.tap(find.byIcon(Icons.skip_next));
      expect(deleteTaps, 0);
      expect(keepTaps, 0);
      expect(applyTaps, 0);
    });

    testWidgets('disables apply when canApplyDeletes is false', (tester) async {
      var applyTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwipeDeckBottomBar(
              deckBusy: false,
              canApplyDeletes: false,
              pendingDeleteCount: 1,
              onDelete: () {},
              onKeep: () {},
              onApplyDeletes: () => applyTaps++,
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip(
        'Remove delete list from library and leave. You can resume this batch later.',
      ));
      expect(applyTaps, 0);
    });

    testWidgets('hides Delete(n) label when pendingDeleteCount is 0',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwipeDeckBottomBar(
              deckBusy: false,
              canApplyDeletes: false,
              pendingDeleteCount: 0,
              onDelete: () {},
              onKeep: () {},
              onApplyDeletes: () {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Delete('), findsNothing);
    });
  });
}
