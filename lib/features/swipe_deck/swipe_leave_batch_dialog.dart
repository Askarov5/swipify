import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/photo_provider.dart';
import '../../core/theme.dart';

/// Shown when the user tries to leave a batch with unsaved decisions.
Future<void> showSwipeLeaveBatchDialog(
  BuildContext pageContext,
  WidgetRef ref,
) async {
  final session = ref.read(swipeSessionNotifierProvider);
  final keepCount = session.keepCount;
  final deleteCount = session.deleteCount;

  if (!pageContext.mounted) return;

  await showDialog<void>(
    context: pageContext,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (dialogContext) {
      bool saving = false;
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: SwipifyTheme.surfaceContainerHigh,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Leave this batch?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: SwipifyTheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You sorted $keepCount kept and $deleteCount to delete so far.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: SwipifyTheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Discard loses those choices. Save & leave applies them now; you can finish the rest of this batch later.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: SwipifyTheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            actionsAlignment: MainAxisAlignment.end,
            actionsOverflowAlignment: OverflowBarAlignment.end,
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Continue swiping'),
              ),
              TextButton(
                onPressed: saving
                    ? null
                    : () {
                        ref
                            .read(swipeSessionNotifierProvider.notifier)
                            .discardSession();
                        Navigator.pop(dialogContext);
                        if (pageContext.mounted) Navigator.pop(pageContext);
                      },
                child: Text(
                  'Discard',
                  style: TextStyle(color: SwipifyTheme.secondary),
                ),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        try {
                          final ok = await ref
                              .read(swipeSessionNotifierProvider.notifier)
                              .commitSession();
                          if (!pageContext.mounted) return;
                          if (ok) {
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            if (pageContext.mounted) {
                              Navigator.pop(pageContext);
                            }
                          } else {
                            if (dialogContext.mounted) {
                              setDialogState(() => saving = false);
                            }
                            if (pageContext.mounted) {
                              ScaffoldMessenger.of(pageContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Keeps were saved, but delete failed. Finish this batch to retry.',
                                  ),
                                ),
                              );
                            }
                          }
                        } catch (_) {
                          if (dialogContext.mounted) {
                            setDialogState(() => saving = false);
                          }
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: SwipifyTheme.primary,
                  foregroundColor: SwipifyTheme.onPrimary,
                ),
                child: saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: SwipifyTheme.onPrimary,
                        ),
                      )
                    : const Text('Save & leave'),
              ),
            ],
          );
        },
      );
    },
  );
}
