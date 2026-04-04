import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipify/core/native_gallery_helper.dart';
import 'package:swipify/core/providers/photo_provider.dart';
import 'package:swipify/core/providers/preferences_provider.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/features/swipe_deck/swipe_screen.dart';

import 'support/gallery_channel_mock.dart';
import 'support/test_image_bytes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SwipeScreen shows deck chrome after session and library load',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final creation = DateTime.utc(2024, 5, 10);
    const assetId = 'swipe-screen-asset';

    final mock = GalleryChannelMock(
      requestPermissionResponse: 'authorized',
      fetchLibraryMetadataResponse: [
        {
          'id': assetId,
          'creationTime': creation.millisecondsSinceEpoch,
          'isVideo': false,
        },
      ],
      fileBytes: kTestPng1x1,
      thumbnailBytes: kTestPng1x1,
    )..register();
    addTearDown(mock.unregister);

    final photo = SwipifyPhoto(
      id: assetId,
      creationTime: creation,
      isVideo: false,
    );

    final batch = PhotoBatch(
      id: 'May 2024',
      title: 'May 2024',
      assets: [photo],
      allAssetIds: [assetId],
      totalCount: 1,
      reviewedCount: 0,
      isFullyReviewed: false,
    );

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
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('May 2024'), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);
    expect(find.byIcon(Icons.skip_next), findsOneWidget);
    expect(find.text('DELETE'), findsOneWidget);
    expect(find.text('KEEP'), findsOneWidget);
  });
}
