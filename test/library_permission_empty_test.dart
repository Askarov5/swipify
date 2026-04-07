import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipify/core/providers/preferences_provider.dart';
import 'package:swipify/core/theme.dart';
import 'package:swipify/features/library/library_review_screen.dart';

import 'support/gallery_channel_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Library shows Open Settings when permission denied', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final mock = GalleryChannelMock(
      checkPermissionResponse: 'denied',
      requestPermissionResponse: 'denied',
    )..register();
    addTearDown(mock.unregister);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: SwipifyTheme.lightTheme,
          darkTheme: SwipifyTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const LibraryReviewScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Open Settings'), findsOneWidget);
    expect(find.text('Check access'), findsOneWidget);
    expect(find.text('Review Library'), findsNothing);
  });

  testWidgets('Library shows Allow access when permission not determined', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final mock = GalleryChannelMock(
      checkPermissionResponse: 'notDetermined',
      requestPermissionResponse: 'authorized',
    )..register();
    addTearDown(mock.unregister);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: SwipifyTheme.lightTheme,
          darkTheme: SwipifyTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const LibraryReviewScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Allow access to photos'), findsOneWidget);
    expect(find.text('Review Library'), findsNothing);
  });

  testWidgets('Library shows empty state when granted but no assets', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final mock = GalleryChannelMock(
      checkPermissionResponse: 'authorized',
      fetchLibraryMetadataResponse: const [],
    )..register();
    addTearDown(mock.unregister);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: SwipifyTheme.lightTheme,
          darkTheme: SwipifyTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const LibraryReviewScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No photos or videos'), findsOneWidget);
    expect(find.text('Review Library'), findsOneWidget);
  });
}
