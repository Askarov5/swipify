import 'dart:ui' show Offset;

/// Pure swipe completion rules for the deck (no widgets; easy to unit test).
abstract final class SwipeDeckGesturePolicy {
  /// Horizontal drag must exceed this fraction of [screenWidth] to commit
  /// (distance-only path; unchanged from original deck behavior).
  static const double commitWidthFraction = 0.3;

  /// Minimum |dx| for the velocity-assisted commit path, so vertical flings
  /// with tiny horizontal noise do not dismiss the card.
  static const double minHorizontalDragPx = 56.0;

  /// Minimum horizontal release speed (px/s) for velocity-assisted commit,
  /// together with [minHorizontalDragPx] and matching drag/velocity signs.
  static const double velocityCommitThresholdPxPerSec = 1000.0;

  /// Whether a pan that ends with [dragDx] and [velocityPixelsPerSecond]
  /// should run the fly-off animation and record a decision.
  static bool shouldCompleteSwipe({
    required double screenWidth,
    required double dragDx,
    required Offset velocityPixelsPerSecond,
  }) {
    if (screenWidth <= 0) return false;

    if (dragDx.abs() > screenWidth * commitWidthFraction) {
      return true;
    }

    if (dragDx.abs() < minHorizontalDragPx) {
      return false;
    }

    final vx = velocityPixelsPerSecond.dx;
    if (vx.abs() < velocityCommitThresholdPxPerSec) {
      return false;
    }

    if (vx.sign != dragDx.sign) {
      return false;
    }

    return true;
  }

  /// Keep (swipe right) vs delete (swipe left) when [shouldCompleteSwipe] is true.
  static bool keepIfCompleting({required double dragDx}) => dragDx > 0;
}
