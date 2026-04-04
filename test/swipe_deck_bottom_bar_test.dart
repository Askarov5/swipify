import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipify/features/swipe_deck/swipe_deck_bottom_bar.dart';

void main() {
  group('SwipeDeckBottomBar', () {
    testWidgets('invokes onDelete and onKeep when not busy', (tester) async {
      var deleteTaps = 0;
      var keepTaps = 0;
      var undoTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwipeDeckBottomBar(
              deckBusy: false,
              canUndo: true,
              onDelete: () => deleteTaps++,
              onKeep: () => keepTaps++,
              onUndo: () => undoTaps++,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.delete));
      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.tap(find.byIcon(Icons.settings_backup_restore));
      expect(deleteTaps, 1);
      expect(keepTaps, 1);
      expect(undoTaps, 1);
    });

    testWidgets('disables delete, keep, and undo while deckBusy', (tester) async {
      var deleteTaps = 0;
      var keepTaps = 0;
      var undoTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwipeDeckBottomBar(
              deckBusy: true,
              canUndo: true,
              onDelete: () => deleteTaps++,
              onKeep: () => keepTaps++,
              onUndo: () => undoTaps++,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.delete));
      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.tap(find.byIcon(Icons.settings_backup_restore));
      expect(deleteTaps, 0);
      expect(keepTaps, 0);
      expect(undoTaps, 0);
    });

    testWidgets('disables undo when canUndo is false', (tester) async {
      var undoTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwipeDeckBottomBar(
              deckBusy: false,
              canUndo: false,
              onDelete: () {},
              onKeep: () {},
              onUndo: () => undoTaps++,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.settings_backup_restore));
      expect(undoTaps, 0);
    });
  });
}
