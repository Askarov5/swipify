import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipify/core/library_thumbnail_cache.dart';
import 'package:swipify/core/providers/preferences_provider.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/features/library/library_review_screen.dart';
import 'package:swipify/features/swipe_deck/swipe_screen.dart';

import 'support/gallery_channel_mock.dart';
import 'support/test_image_bytes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Library batch Clean opens SwipeScreen for batch', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final creation = DateTime.utc(2024, 5, 12);
    const assetId = 'lib-open-1';

    final mock = GalleryChannelMock(
      requestPermissionResponse: 'authorized',
      fetchLibraryMetadataResponse: [
        {
          'id': assetId,
          'creationTime': creation.millisecondsSinceEpoch,
          'isVideo': false,
        },
      ],
      thumbnailBytes: kTestPng1x1,
      fileBytes: kTestPng1x1,
    )..register();
    addTearDown(mock.unregister);
    addTearDown(LibraryThumbnailCache.clear);

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

    expect(find.text('May 2024'), findsWidgets);
    expect(find.text('Clean'), findsOneWidget);

    await tester.tap(find.text('Clean'));
    await tester.pumpAndSettle();

    expect(find.byType(SwipeScreen), findsOneWidget);
    expect(find.text('May 2024'), findsWidgets);
  });
}
