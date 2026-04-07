import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:swipify/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Force dark so ThemeMode.system matches prior smoke-test appearance.
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(platformBrightness: Brightness.dark),
        child: ProviderScope(child: SwipifyApp(initialRouteIsLibrary: false)),
      ),
    );

    // Verify that the app builds without crashing.
    expect(find.byType(SwipifyApp), findsOneWidget);
  });
}
