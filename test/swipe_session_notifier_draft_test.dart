import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipify/core/native_gallery_helper.dart';
import 'package:swipify/core/providers/photo_provider.dart';
import 'package:swipify/core/providers/preferences_provider.dart';

/// Same key shape as [SwipeSessionNotifier] private `_draftPrefsKey`.
String draftPrefsKey(String batchId) =>
    'swipify_swipe_draft_${batchId.hashCode}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SwipeSessionNotifier.tryRestoreDraft', () {
    late SharedPreferences prefs;
    late ProviderContainer container;

    tearDown(() {
      container.dispose();
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
    });

    test('restores valid draft order and decisions', () {
      final batchId = 'May 2024';
      final p1 = SwipifyPhoto(
        id: 'a',
        creationTime: DateTime.utc(2024, 5, 1),
        isVideo: false,
      );
      final p2 = SwipifyPhoto(
        id: 'b',
        creationTime: DateTime.utc(2024, 5, 2),
        isVideo: false,
      );
      final batch = PhotoBatch(
        id: batchId,
        title: batchId,
        assets: [p1, p2],
        allAssetIds: ['a', 'b'],
        totalCount: 2,
        reviewedCount: 0,
        isFullyReviewed: false,
      );
      final library = [p1, p2];

      prefs.setString(
        draftPrefsKey(batchId),
        jsonEncode({
          'o': ['a', 'b'],
          'dec': [
            {'id': 'b', 'del': true},
          ],
          'kp': false,
        }),
      );

      final notifier = container.read(swipeSessionNotifierProvider.notifier);
      notifier.init([p1, p2], batchId);
      notifier.tryRestoreDraft(batch, library);

      final state = container.read(swipeSessionNotifierProvider);
      expect(state.sessionBatchOrder.map((e) => e.id), ['a', 'b']);
      expect(state.decisions, hasLength(1));
      expect(state.decisions.single.id, 'b');
      expect(state.decisions.single.isDelete, true);
      expect(state.remainingAssets.map((e) => e.id), ['a']);
    });

    test('invalid JSON removes draft and leaves init state', () {
      final batchId = 'Jun 2024';
      prefs.setString(draftPrefsKey(batchId), '{');

      final p = SwipifyPhoto(
        id: 'a',
        creationTime: DateTime.utc(2024, 6, 1),
        isVideo: false,
      );
      final batch = PhotoBatch(
        id: batchId,
        title: batchId,
        assets: [p],
        allAssetIds: ['a'],
        totalCount: 1,
        reviewedCount: 0,
        isFullyReviewed: false,
      );

      final notifier = container.read(swipeSessionNotifierProvider.notifier);
      notifier.init([p], batchId);
      notifier.tryRestoreDraft(batch, [p]);

      expect(prefs.getString(draftPrefsKey(batchId)), isNull);
      expect(
        container.read(swipeSessionNotifierProvider).decisions,
        isEmpty,
      );
    });

    test('order id not in batch.allAssetIds removes draft', () {
      final batchId = 'Jul 2024';
      prefs.setString(
        draftPrefsKey(batchId),
        jsonEncode({
          'o': ['a', 'ghost'],
          'dec': <Map<String, dynamic>>[],
          'kp': false,
        }),
      );

      final p = SwipifyPhoto(
        id: 'a',
        creationTime: DateTime.utc(2024, 7, 1),
        isVideo: false,
      );
      final batch = PhotoBatch(
        id: batchId,
        title: batchId,
        assets: [p],
        allAssetIds: ['a'],
        totalCount: 1,
        reviewedCount: 0,
        isFullyReviewed: false,
      );

      final notifier = container.read(swipeSessionNotifierProvider.notifier);
      notifier.init([p], batchId);
      notifier.tryRestoreDraft(batch, [p]);

      expect(prefs.getString(draftPrefsKey(batchId)), isNull);
    });

    test('wrong decision sequence vs stack order removes draft', () {
      final batchId = 'Aug 2024';
      prefs.setString(
        draftPrefsKey(batchId),
        jsonEncode({
          'o': ['a', 'b'],
          'dec': [
            {'id': 'a', 'del': true},
          ],
          'kp': false,
        }),
      );

      final p1 = SwipifyPhoto(
        id: 'a',
        creationTime: DateTime.utc(2024, 8, 1),
        isVideo: false,
      );
      final p2 = SwipifyPhoto(
        id: 'b',
        creationTime: DateTime.utc(2024, 8, 2),
        isVideo: false,
      );
      final batch = PhotoBatch(
        id: batchId,
        title: batchId,
        assets: [p1, p2],
        allAssetIds: ['a', 'b'],
        totalCount: 2,
        reviewedCount: 0,
        isFullyReviewed: false,
      );

      final notifier = container.read(swipeSessionNotifierProvider.notifier);
      notifier.init([p1, p2], batchId);
      notifier.tryRestoreDraft(batch, [p1, p2]);

      expect(prefs.getString(draftPrefsKey(batchId)), isNull);
    });
  });
}
