import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/photo_provider.dart';
/// Shown when the user tries to leave a batch with unsaved decisions.
Future<void> showSwipeLeaveBatchDialog(
  BuildContext pageContext,
  WidgetRef ref,
) async {
  if (!pageContext.mounted) return;

  await showDialog<void>(
    context: pageContext,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (dialogContext) {
      bool saving = false;
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Consumer(
            builder: (context, ref, _) {
              final session = ref.watch(swipeSessionNotifierProvider);
              final keepCount = session.keepCount;
              final deleteCount = session.deleteCount;
              final remaining = session.remainingAssets;

              final String primaryLabel;
              if (deleteCount > 0) {
                primaryLabel = 'Delete & leave';
              } else {
                primaryLabel = 'Save & leave';
              }

              final String secondaryHint;
              if (deleteCount > 0) {
                secondaryHint =
                    'Discard loses your choices. Delete & leave removes everything in your delete list from the library now and saves your sort progress—you can finish this batch anytime.';
              } else {
                secondaryHint =
                    'Discard loses your choices. Save & leave records your keeps and saves draft progress only (nothing is deleted from the library until you delete from the deck).';
              }

              Future<void> onPrimaryPressed() async {
                setDialogState(() => saving = true);
                try {
                  final notifier =
                      ref.read(swipeSessionNotifierProvider.notifier);
                  bool ok;
                  if (deleteCount > 0) {
                    if (remaining.isNotEmpty) {
                      ok = await notifier.applyPendingDeletesSaveAndCompact();
                    } else {
                      ok = await notifier.commitSession();
                    }
                  } else {
                    if (remaining.isNotEmpty) {
                      ok = await notifier.saveKeepsAndPersistDraft();
                    } else {
                      ok = await notifier.commitSession();
                    }
                  }
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
              }

              return AlertDialog(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(
                  'Leave this batch?',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
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
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        secondaryHint,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                      style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                    ),
                  ),
                  FilledButton(
                    onPressed: saving ? null : () => onPrimaryPressed(),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: saving
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : Text(primaryLabel),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}
