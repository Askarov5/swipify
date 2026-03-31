import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'core/providers/preferences_provider.dart';
import 'features/permissions/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const SwipifyApp(),
    ),
  );
}

class SwipifyApp extends StatelessWidget {
  const SwipifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Curator',
      theme: SwipifyTheme.darkTheme,
      home: const OnboardingScreen(),
    );
  }
}
