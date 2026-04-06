import 'package:flutter_test/flutter_test.dart';
import 'package:swipify/features/swipe_deck/swipe_physics.dart';

void main() {
  group('SwipeDeckGesturePolicy', () {
    const width = 400.0;
    const distThreshold = width * SwipeDeckGesturePolicy.commitWidthFraction;

    test('distance past 30% width completes regardless of velocity', () {
      expect(
        SwipeDeckGesturePolicy.shouldCompleteSwipe(
          screenWidth: width,
          dragDx: distThreshold + 1,
          velocityPixelsPerSecond: Offset.zero,
        ),
        true,
      );
      expect(
        SwipeDeckGesturePolicy.keepIfCompleting(dragDx: distThreshold + 1),
        true,
      );
      expect(
        SwipeDeckGesturePolicy.shouldCompleteSwipe(
          screenWidth: width,
          dragDx: -(distThreshold + 1),
          velocityPixelsPerSecond: Offset.zero,
        ),
        true,
      );
      expect(
        SwipeDeckGesturePolicy.keepIfCompleting(dragDx: -(distThreshold + 1)),
        false,
      );
    });

    test('under distance with low velocity does not complete', () {
      expect(
        SwipeDeckGesturePolicy.shouldCompleteSwipe(
          screenWidth: width,
          dragDx: 100,
          velocityPixelsPerSecond: const Offset(500, 0),
        ),
        false,
      );
    });

    test('under distance but strong matching velocity completes', () {
      expect(
        SwipeDeckGesturePolicy.shouldCompleteSwipe(
          screenWidth: width,
          dragDx: 80,
          velocityPixelsPerSecond: const Offset(1200, 0),
        ),
        true,
      );
      expect(
        SwipeDeckGesturePolicy.keepIfCompleting(dragDx: 80),
        true,
      );
    });

    test('velocity opposite to drag does not complete', () {
      expect(
        SwipeDeckGesturePolicy.shouldCompleteSwipe(
          screenWidth: width,
          dragDx: 80,
          velocityPixelsPerSecond: const Offset(-1200, 0),
        ),
        false,
      );
    });

    test('tiny horizontal drag does not complete via velocity', () {
      expect(
        SwipeDeckGesturePolicy.shouldCompleteSwipe(
          screenWidth: width,
          dragDx: 20,
          velocityPixelsPerSecond: const Offset(5000, 0),
        ),
        false,
      );
    });

    test('non-positive screen width never completes', () {
      expect(
        SwipeDeckGesturePolicy.shouldCompleteSwipe(
          screenWidth: 0,
          dragDx: 100,
          velocityPixelsPerSecond: const Offset(2000, 0),
        ),
        false,
      );
    });
  });
}
