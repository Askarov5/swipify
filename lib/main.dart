import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'core/native_gallery_helper.dart';
import 'core/providers/preferences_provider.dart';
import 'features/permissions/onboarding_screen.dart';
import 'features/library/library_review_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Check permission state synchronously at boot
  final permissionStatus = await NativeGalleryHelper.checkPermission();
  final isGranted = NativeGalleryHelper.isGranted(permissionStatus);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: SwipifyApp(initialRouteIsLibrary: isGranted),
    ),
  );
}

class SwipifyApp extends StatelessWidget {
  final bool initialRouteIsLibrary;

  const SwipifyApp({
    super.key,
    required this.initialRouteIsLibrary,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swipify',
      theme: SwipifyTheme.darkTheme,
      home: initialRouteIsLibrary
          ? const LibraryReviewScreen()
          : const OnboardingScreen(),
    );
  }
}
