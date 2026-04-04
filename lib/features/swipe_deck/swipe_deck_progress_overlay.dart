import 'package:flutter/material.dart';

import '../../core/theme.dart';

class SwipeDeckProgressOverlay extends StatelessWidget {
  final double progress;

  const SwipeDeckProgressOverlay({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(SwipifyTheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('DELETE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: SwipifyTheme.secondary,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 4)
                            ],
                            fontWeight: FontWeight.bold)),
                  Text('KEEP',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: SwipifyTheme.primary,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 4)
                            ],
                            fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
