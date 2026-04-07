import 'dart:ui';

import 'package:flutter/material.dart';


/// Trash + check: apply pending deletes and leave (see [SwipeDeckBottomBar.onApplyDeletes]).
class _TrashCheckIcon extends StatelessWidget {
  const _TrashCheckIcon();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.delete_outline,
            color: scheme.onSurfaceVariant,
            size: 32,
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Icon(
              Icons.check_circle,
              color: scheme.primary,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class SwipeDeckBottomBar extends StatelessWidget {
  final bool deckBusy;
  final bool canApplyDeletes;
  /// Shown as small "Delete(n)" under the apply icon when > 0.
  final int pendingDeleteCount;
  final VoidCallback? onDelete;
  final VoidCallback? onKeep;
  final VoidCallback? onApplyDeletes;

  const SwipeDeckBottomBar({
    super.key,
    required this.deckBusy,
    required this.canApplyDeletes,
    required this.pendingDeleteCount,
    required this.onDelete,
    required this.onKeep,
    required this.onApplyDeletes,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                color: Theme.of(context).colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      tooltip: 'Mark for delete',
                      onPressed: deckBusy ? null : onDelete,
                      icon: Icon(Icons.close,
                          color: Theme.of(context).colorScheme.secondary, size: 32),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondaryContainer
                            .withValues(alpha: 0.3),
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    IconButton(
                      tooltip:
                          'Remove delete list from library and leave. You can resume this batch later.',
                      onPressed: (!deckBusy && canApplyDeletes)
                          ? onApplyDeletes
                          : null,
                      icon: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _TrashCheckIcon(),
                          if (pendingDeleteCount > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Delete($pendingDeleteCount)',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                            ),
                          ],
                        ],
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    IconButton(
                      onPressed: deckBusy ? null : onKeep,
                      icon: Icon(Icons.skip_next,
                          color: Theme.of(context).colorScheme.primary, size: 32),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer
                            .withValues(alpha: 0.3),
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
