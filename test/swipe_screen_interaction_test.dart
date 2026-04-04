import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipify/core/library_thumbnail_cache.dart';
import 'package:swipify/core/native_gallery_helper.dart';
import 'package:swipify/core/providers/photo_provider.dart';
import 'package:swipify/core/providers/preferences_provider.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/features/library/library_review_screen.dart';
import 'package:swipify/features/swipe_deck/swipe_deck_stack.dart';
import 'package:swipify/features/swipe_deck/swipe_screen.dart';

import 'support/gallery_channel_mock.dart';
import 'support/test_image_bytes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSwipeScreen(
    WidgetTester tester, {
    required PhotoBatch batch,
    GalleryChannelMock? galleryMock,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final mock = galleryMock ??
        GalleryChannelMock(
          requestPermissionResponse: 'authorized',
          fetchLibraryMetadataResponse: batch.assets
              .map(
                (e) => {
                  'id': e.id,
                  'creationTime': e.creationTime.millisecondsSinceEpoch,
                  'isVideo': e.isVideo,
                },
              )
              .toList(),
          fileBytes: kTestPng1x1,
          thumbnailBytes: kTestPng1x1,
        );
    mock.register();
    addTearDown(mock.unregister);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: SwipifyTheme.darkTheme,
          home: SwipeScreen(batch: batch),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpAndSettle();
  }

  PhotoBatch batchTwo() {
    final p1 = SwipifyPhoto(
      id: 's1',
      creationTime: DateTime.utc(2024, 5, 1),
      isVideo: false,
    );
    final p2 = SwipifyPhoto(
      id: 's2',
      creationTime: DateTime.utc(2024, 5, 2),
      isVideo: false,
    );
    return PhotoBatch(
      id: 'May 2024',
      title: 'May 2024',
      assets: [p1, p2],
      allAssetIds: ['s1', 's2'],
      totalCount: 2,
      reviewedCount: 0,
      isFullyReviewed: false,
    );
  }

  group('SwipeScreen gestures', () {
    testWidgets('pan past threshold flies off and records keep decision',
        (tester) async {
      await pumpSwipeScreen(tester, batch: batchTwo());

      await tester.drag(
        find.byType(SwipeDeckStack),
        const Offset(280, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(SwipeScreen));
      final container = ProviderScope.containerOf(ctx);
      final decisions = container.read(swipeSessionNotifierProvider).decisions;
      expect(decisions, hasLength(1));
      expect(decisions.single.id, 's2');
      expect(decisions.single.isDelete, false);
    });

    testWidgets('pan under threshold rebounded without decision',
        (tester) async {
      await pumpSwipeScreen(tester, batch: batchTwo());

      await tester.drag(
        find.byType(SwipeDeckStack),
        const Offset(80, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(SwipeScreen));
      final container = ProviderScope.containerOf(ctx);
      expect(
        container.read(swipeSessionNotifierProvider).decisions,
        isEmpty,
      );
    });
  });

  group('SwipeScreen leave batch', () {
    testWidgets('close with pending work shows leave dialog; Discard pops',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mock = GalleryChannelMock(
        requestPermissionResponse: 'authorized',
        fetchLibraryMetadataResponse: [
          {
            'id': 's1',
            'creationTime':
                DateTime.utc(2024, 5, 1).millisecondsSinceEpoch,
            'isVideo': false,
          },
          {
            'id': 's2',
            'creationTime':
                DateTime.utc(2024, 5, 2).millisecondsSinceEpoch,
            'isVideo': false,
          },
        ],
        fileBytes: kTestPng1x1,
        thumbnailBytes: kTestPng1x1,
      )..register();
      addTearDown(mock.unregister);
      addTearDown(LibraryThumbnailCache.clear);

      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: SwipifyTheme.darkTheme,
            home: const LibraryReviewScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clean').first);
      await tester.pumpAndSettle();
      expect(find.byType(SwipeScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Leave this batch?'), findsOneWidget);

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.byType(SwipeScreen), findsNothing);
      expect(find.text('Swipify Photos & Videos'), findsOneWidget);
    });

    testWidgets('Save & leave commits keeps and pops swipe route',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mock = GalleryChannelMock(
        requestPermissionResponse: 'authorized',
        fetchLibraryMetadataResponse: [
          {
            'id': 's1',
            'creationTime':
                DateTime.utc(2024, 5, 1).millisecondsSinceEpoch,
            'isVideo': false,
          },
          {
            'id': 's2',
            'creationTime':
                DateTime.utc(2024, 5, 2).millisecondsSinceEpoch,
            'isVideo': false,
          },
        ],
        fileBytes: kTestPng1x1,
        thumbnailBytes: kTestPng1x1,
      )..register();
      addTearDown(mock.unregister);
      addTearDown(LibraryThumbnailCache.clear);

      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: SwipifyTheme.darkTheme,
            home: const LibraryReviewScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final appCtx = tester.element(find.byType(MaterialApp));
      final container = ProviderScope.containerOf(appCtx);

      await tester.tap(find.text('Clean').first);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save & leave'));
      await tester.pumpAndSettle();

      expect(find.byType(SwipeScreen), findsNothing);
      expect(find.text('Swipify Photos & Videos'), findsOneWidget);
      expect(container.read(reviewedIdsProvider), contains('s2'));
    });

    testWidgets('Navigator.maybePop blocked opens leave dialog', (tester) async {
      await pumpSwipeScreen(tester, batch: batchTwo());

      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final swipeCtx = tester.element(find.byType(SwipeScreen));
      final popped = await Navigator.of(swipeCtx).maybePop();
      expect(popped, isFalse);
      await tester.pumpAndSettle();

      expect(find.text('Leave this batch?'), findsOneWidget);
    });
  });
}
