import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// When [embedded] is true, returns only the centered content for a parent tab shell (no [Scaffold], no back button).
class EmailComingSoonScreen extends StatelessWidget {
  const EmailComingSoonScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mark_email_unread_outlined,
              size: 100,
              color: SwipifyTheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 32),
            Text(
              'Coming Soon!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: SwipifyTheme.primary,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'You will soon be able to connect your inbox and quickly swipe away junk mail to reach inbox zero.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: SwipifyTheme.onSurfaceVariant,
                  ),
            ),
            if (!embedded) ...[
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SwipifyTheme.primaryContainer,
                  foregroundColor: SwipifyTheme.onSurface,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                child: const Text('Back to Gallery'),
              ),
            ],
          ],
        ),
      ),
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Cleanup'),
        backgroundColor: SwipifyTheme.surface,
        elevation: 0,
      ),
      body: content,
    );
  }
}
