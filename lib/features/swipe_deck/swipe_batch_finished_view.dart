import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/photo_provider.dart';
/// Shown when the deck has no remaining cards (batch complete or awaiting commit).
class SwipeBatchFinishedView extends ConsumerWidget {
  final bool deckBusy;

  const SwipeBatchFinishedView({
    super.key,
    required this.deckBusy,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final sessionState = ref.watch(swipeSessionNotifierProvider);
    final isCommitted = sessionState.isCommitted;
    final hasDeletes = sessionState.deleteCount > 0;
    final showDeleteRetry = !isCommitted &&
        sessionState.keepsPersistedToLibrary &&
        hasDeletes;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isCommitted ? Icons.check_circle : Icons.celebration,
              color: scheme.primary, size: 64),
          const SizedBox(height: 16),
          Text(isCommitted ? 'Saved!' : 'Batch Finished!',
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Kept: ${sessionState.keepCount}'),
          Text('To Delete: ${sessionState.deleteCount}'),
          const SizedBox(height: 24),
          if (!isCommitted) ...[
            if (sessionState.decisions.isNotEmpty && !deckBusy) ...[
              TextButton.icon(
                onPressed: () {
                  ref
                      .read(swipeSessionNotifierProvider.notifier)
                      .undoLastDecision();
                },
                icon: const Icon(Icons.undo, size: 20),
                label: const Text('Undo last'),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (showDeleteRetry) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Your keeps are saved. Some items could not be deleted from the library.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.secondary,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  final notifier =
                      ref.read(swipeSessionNotifierProvider.notifier);
                  final ok = await notifier.commitSession();
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Delete still failed. Try again later.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.delete_forever),
                label: Text('Retry delete (${sessionState.deleteCount})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.secondary,
                  foregroundColor: scheme.onSecondary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (!showDeleteRetry)
              ElevatedButton.icon(
                onPressed: () async {
                  final notifier =
                      ref.read(swipeSessionNotifierProvider.notifier);
                  final ok = await notifier.commitSession();
                  if (!context.mounted) return;
                  if (ok) {
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not complete. If you chose deletes, use Retry when it appears.',
                        ),
                      ),
                    );
                  }
                },
                icon: hasDeletes
                    ? const Icon(Icons.delete_forever)
                    : const Icon(Icons.check),
                label: Text(hasDeletes
                    ? 'Confirm & Delete ${sessionState.deleteCount} Items'
                    : 'Finish Batch'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      hasDeletes ? scheme.secondary : scheme.primary,
                  foregroundColor:
                      hasDeletes ? scheme.onSecondary : scheme.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                ref.read(swipeSessionNotifierProvider.notifier).discardSession();
                Navigator.pop(context);
              },
              child: Text('Cancel / Discard',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            )
          ] else ...[
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onSurface,
              ),
              child: const Text('Back to Library'),
            )
          ]
        ],
      ),
    );
  }
}
