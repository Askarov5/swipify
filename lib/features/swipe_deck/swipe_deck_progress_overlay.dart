import 'package:flutter/material.dart';

class SwipeDeckProgressOverlay extends StatelessWidget {
  final double progress;

  const SwipeDeckProgressOverlay({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                  backgroundColor:
                      scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(scheme.primary),
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
                            color: scheme.secondary,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 4)
                            ],
                            fontWeight: FontWeight.bold)),
                  Text('KEEP',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 4)
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
