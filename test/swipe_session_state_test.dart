import 'package:flutter_test/flutter_test.dart';
import 'package:swipify/core/native_gallery_helper.dart';
import 'package:swipify/core/providers/photo_provider.dart';

void main() {
  group('SwipeSessionState', () {
    final p1 = SwipifyPhoto(
      id: '1',
      creationTime: DateTime.utc(2024, 6, 1),
      isVideo: false,
    );
    final p2 = SwipifyPhoto(
      id: '2',
      creationTime: DateTime.utc(2024, 6, 2),
      isVideo: true,
    );
    final p3 = SwipifyPhoto(
      id: '3',
      creationTime: DateTime.utc(2024, 6, 3),
      isVideo: false,
    );

    test('remainingAssets is prefix of length L minus decisions', () {
      final state = SwipeSessionState(
        sessionBatchOrder: [p1, p2, p3],
        decisions: const [],
      );
      expect(state.remainingAssets.map((e) => e.id), ['1', '2', '3']);
      expect(state.remainingAssets.last.id, '3');
    });

    test('remainingAssets shrinks from tail as decisions accrue', () {
      var state = SwipeSessionState(
        sessionBatchOrder: [p1, p2, p3],
        decisions: const [SwipeDecision(id: '3', isDelete: true)],
      );
      expect(state.remainingAssets.map((e) => e.id), ['1', '2']);

      state = SwipeSessionState(
        sessionBatchOrder: [p1, p2, p3],
        decisions: const [
          SwipeDecision(id: '3', isDelete: false),
          SwipeDecision(id: '2', isDelete: true),
        ],
      );
      expect(state.remainingAssets.map((e) => e.id), ['1']);
    });

    test('keepCount and deleteCount partition decisions', () {
      final state = SwipeSessionState(
        sessionBatchOrder: [p1, p2, p3],
        decisions: const [
          SwipeDecision(id: '3', isDelete: true),
          SwipeDecision(id: '2', isDelete: false),
        ],
      );
      expect(state.keepCount, 1);
      expect(state.deleteCount, 1);
    });

    test('remainingAssets empty when all decided', () {
      final state = SwipeSessionState(
        sessionBatchOrder: [p1],
        decisions: const [SwipeDecision(id: '1', isDelete: false)],
      );
      expect(state.remainingAssets, isEmpty);
    });
  });
}
