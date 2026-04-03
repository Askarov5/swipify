import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'core/providers/preferences_provider.dart';
import 'features/permissions/onboarding_screen.dart';
import 'features/library/library_review_screen.dart';
import 'core/photo_permission_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Check permission state synchronously at boot
  final permissionStatus = await PhotoPermissionHelper.checkPermission();
  final isGranted = PhotoPermissionHelper.isGranted(permissionStatus);

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
      title: 'Digital Curator',
      theme: SwipifyTheme.darkTheme,
      home: initialRouteIsLibrary
          ? const LibraryReviewScreen()
          : const OnboardingScreen(),
    );
  }
}
