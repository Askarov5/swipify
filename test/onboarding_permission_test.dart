import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipify/core/providers/preferences_provider.dart';
import 'package:swipify/features/permissions/onboarding_screen.dart';

import 'support/gallery_channel_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// [LibraryReviewScreen] mounts stats/email tabs in an [IndexedStack], so
  /// [sharedPreferencesProvider] must be overridden for any navigation test.
  Future<void> pumpOnboarding(
    WidgetTester tester, {
    GalleryChannelMock? galleryMock,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    galleryMock?.register();
    if (galleryMock != null) {
      addTearDown(galleryMock.unregister);
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          home: OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('OnboardingScreen permission flows', () {
    testWidgets('Give Full Access + grant navigates to library', (tester) async {
      await pumpOnboarding(
        tester,
        galleryMock: GalleryChannelMock(
          checkPermissionResponse: 'notDetermined',
          requestPermissionResponse: 'authorized',
        ),
      );

      await tester.tap(find.text('Give Full Access'));
      await tester.pumpAndSettle();

      expect(find.text('Swipify Photos & Videos'), findsOneWidget);
    });

    testWidgets('Give Full Access when already granted skips request dialog',
        (tester) async {
      await pumpOnboarding(
        tester,
        galleryMock: GalleryChannelMock(
          checkPermissionResponse: 'authorized',
        ),
      );

      await tester.tap(find.text('Give Full Access'));
      await tester.pumpAndSettle();

      expect(find.text('Swipify Photos & Videos'), findsOneWidget);
    });

    testWidgets('Give Full Access when denied shows settings dialog',
        (tester) async {
      await pumpOnboarding(
        tester,
        galleryMock: GalleryChannelMock(
          checkPermissionResponse: 'denied',
        ),
      );

      await tester.tap(find.text('Give Full Access'));
      await tester.pumpAndSettle();

      expect(find.text('Photo Access Required'), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);
    });

    testWidgets('Not Now skips permission and opens library', (tester) async {
      await pumpOnboarding(tester, galleryMock: GalleryChannelMock());

      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      expect(find.text('Swipify Photos & Videos'), findsOneWidget);
    });
  });
}
