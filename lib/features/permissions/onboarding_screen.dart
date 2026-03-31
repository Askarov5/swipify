import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../library/library_review_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          // Ambient Background Glows
          Positioned(
            bottom: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SwipifyTheme.primary.withValues(alpha: 0.05),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                child: const SizedBox(),
              ),
            ),
          ),
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8AD3D7).withValues(alpha: 0.05),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: const SizedBox(),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Anchor Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.security,
                          color: SwipifyTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'DIGITAL CURATOR',
                        style:
                            Theme.of(context).textTheme.displayLarge?.copyWith(
                                  fontSize: 12,
                                  color: SwipifyTheme.primary,
                                  letterSpacing: 2.0,
                                ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Hero Illustration Proxy
                        Container(
                          width: double.infinity,
                          height: 180,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: SwipifyTheme.surfaceContainerLow,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.photo_library,
                              size: 48,
                              color: SwipifyTheme.primary,
                            ),
                          ),
                        ),

                        // Headline & Content
                        Column(
                          children: [
                            Text(
                              'Ready to Declutter Your Gallery?',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontSize: 28,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'To start swiping through your photos and videos, we need full access to your library.\n100% on-device processing.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),

                        // Key Benefits Bento-ish
                        Column(
                          children: [
                            _buildBenefitRow(
                              Icons.lock,
                              'Privacy First',
                              'On-device scanning.',
                            ),
                            const SizedBox(height: 8),
                            _buildBenefitRow(
                              Icons.cloud_off,
                              'Zero Uploads',
                              'No cloud needed.',
                            ),
                            const SizedBox(height: 8),
                            _buildBenefitRow(
                              Icons.bolt,
                              'Faster Review',
                              'AI-powered sorting.',
                            ),
                          ],
                        ),

                        // Actions
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: SwipifyTheme.primary,
                                  foregroundColor: SwipifyTheme.onPrimary,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(32),
                                  ),
                                  elevation: 8,
                                ),
                                onPressed: () async {
                                  // Request permissions
                                  await PhotoManager.requestPermissionExtend();
                                  if (context.mounted) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const LibraryReviewScreen()),
                                    );
                                  }
                                },
                                child: Text(
                                  'Give Full Access',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: SwipifyTheme.onPrimary,
                                        fontSize: 16,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const LibraryReviewScreen()),
                                );
                              },
                              child: Text(
                                'Not Now',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SwipifyTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: SwipifyTheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: SwipifyTheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                    color: SwipifyTheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
