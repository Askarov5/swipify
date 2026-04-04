import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipify/core/native_gallery_helper.dart';
import 'package:swipify/core/providers/photo_provider.dart';
import 'package:swipify/features/swipe_deck/swipe_batch_finished_view.dart';

void main() {
  testWidgets('SwipeBatchFinishedView shows Back to Library when committed',
      (tester) async {
    final state = SwipeSessionState(
      sessionBatchOrder: const [],
      decisions: const [],
      isCommitted: true,
      activeBatchId: 'batch',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          swipeSessionNotifierProvider.overrideWith(
            () => _SeededSwipeSessionNotifier(state),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SwipeBatchFinishedView(deckBusy: false),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Back to Library'), findsOneWidget);
    expect(find.text('Saved!'), findsOneWidget);
  });

  testWidgets(
      'SwipeBatchFinishedView shows confirm delete when uncommitted with deletes',
      (tester) async {
    final photo = SwipifyPhoto(
      id: 'id1',
      creationTime: DateTime(2024, 1, 1),
      isVideo: false,
    );
    final state = SwipeSessionState(
      sessionBatchOrder: [photo],
      decisions: const [
        SwipeDecision(id: 'id1', isDelete: true),
      ],
      isCommitted: false,
      activeBatchId: 'batch',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          swipeSessionNotifierProvider.overrideWith(
            () => _SeededSwipeSessionNotifier(state),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SwipeBatchFinishedView(deckBusy: false),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('Confirm & Delete'), findsOneWidget);
    expect(find.text('To Delete: 1'), findsOneWidget);
  });
}

class _SeededSwipeSessionNotifier extends SwipeSessionNotifier {
  _SeededSwipeSessionNotifier(this._seed);
  final SwipeSessionState _seed;

  @override
  SwipeSessionState build() => _seed;
}
