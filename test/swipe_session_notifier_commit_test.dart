import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipify/core/native_gallery_helper.dart';
import 'package:swipify/core/providers/impact_stats_provider.dart';
import 'package:swipify/core/providers/photo_provider.dart';
import 'package:swipify/core/providers/preferences_provider.dart';

import 'support/gallery_channel_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SwipeSessionNotifier.commitSession', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('keep-only adds IDs to reviewedIds and records commit in impact stats',
        () async {
      final mock = GalleryChannelMock()..register();
      addTearDown(mock.unregister);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final p = SwipifyPhoto(
        id: 'keep-me',
        creationTime: DateTime.utc(2024, 5, 1),
        isVideo: false,
      );
      final notifier = container.read(swipeSessionNotifierProvider.notifier);
      notifier.init([p], 'May 2024');
      notifier.recordDecision(p, delete: false);

      expect(await notifier.commitSession(), true);

      expect(container.read(reviewedIdsProvider), contains('keep-me'));
      expect(
        container.read(impactStatsProvider).commitsCompletedTotal,
        1,
      );
      expect(container.read(swipeSessionNotifierProvider).isCommitted, true);
    });

    test('delete path adds deleted IDs, impact deletes, and completes commit',
        () async {
      final mock = GalleryChannelMock(deletePhotosResponse: true)..register();
      addTearDown(mock.unregister);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final p = SwipifyPhoto(
        id: 'del-me',
        creationTime: DateTime.utc(2024, 5, 2),
        isVideo: false,
      );
      final notifier = container.read(swipeSessionNotifierProvider.notifier);
      notifier.init([p], 'May 2024');
      notifier.recordDecision(p, delete: true);

      expect(await notifier.commitSession(), true);

      expect(container.read(reviewedIdsProvider), contains('del-me'));
      final impact = container.read(impactStatsProvider);
      expect(impact.photosDeletedTotal, 1);
      expect(impact.commitsCompletedTotal, 1);
      expect(container.read(swipeSessionNotifierProvider).isCommitted, true);
    });

    test('delete failure sets keepsPersistedToLibrary; retry succeeds', () async {
      final mock = GalleryChannelMock(deletePhotosResponse: false)..register();
      addTearDown(mock.unregister);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final p = SwipifyPhoto(
        id: 'x',
        creationTime: DateTime.utc(2024, 5, 3),
        isVideo: false,
      );
      final notifier = container.read(swipeSessionNotifierProvider.notifier);
      notifier.init([p], 'May 2024');
      notifier.recordDecision(p, delete: true);

      expect(await notifier.commitSession(), false);
      var state = container.read(swipeSessionNotifierProvider);
      expect(state.keepsPersistedToLibrary, true);
      expect(state.isCommitted, false);
      expect(container.read(reviewedIdsProvider), isEmpty);

      mock.deletePhotosResponse = true;
      expect(await notifier.commitSession(), true);
      state = container.read(swipeSessionNotifierProvider);
      expect(state.isCommitted, true);
      expect(container.read(reviewedIdsProvider), contains('x'));
      expect(container.read(impactStatsProvider).commitsCompletedTotal, 1);
    });

    test('mixed keep + delete persists keeps before delete attempt', () async {
      final mock = GalleryChannelMock(deletePhotosResponse: true)..register();
      addTearDown(mock.unregister);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final keep = SwipifyPhoto(
        id: 'k',
        creationTime: DateTime.utc(2024, 5, 4),
        isVideo: false,
      );
      final del = SwipifyPhoto(
        id: 'd',
        creationTime: DateTime.utc(2024, 5, 5),
        isVideo: false,
      );
      final notifier = container.read(swipeSessionNotifierProvider.notifier);
      notifier.init([keep, del], 'May 2024');
      notifier.recordDecision(del, delete: true);
      notifier.recordDecision(keep, delete: false);

      expect(await notifier.commitSession(), true);

      final reviewed = container.read(reviewedIdsProvider);
      expect(reviewed, containsAll(['k', 'd']));
    });
  });
}
