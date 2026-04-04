import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme.dart';

class SwipeDeckBottomBar extends StatelessWidget {
  final bool deckBusy;
  final bool canUndo;
  final VoidCallback? onDelete;
  final VoidCallback? onKeep;
  final VoidCallback? onUndo;

  const SwipeDeckBottomBar({
    super.key,
    required this.deckBusy,
    required this.canUndo,
    required this.onDelete,
    required this.onKeep,
    required this.onUndo,
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
                color: SwipifyTheme.surfaceContainerHigh.withValues(alpha: 0.6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: deckBusy ? null : onDelete,
                      icon: const Icon(Icons.delete,
                          color: SwipifyTheme.secondary, size: 32),
                      style: IconButton.styleFrom(
                        backgroundColor: SwipifyTheme.secondaryContainer
                            .withValues(alpha: 0.3),
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Undo last swipe',
                      onPressed: (!deckBusy && canUndo) ? onUndo : null,
                      icon: const Icon(
                        Icons.settings_backup_restore,
                        color: SwipifyTheme.onSurfaceVariant,
                        size: 32,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: SwipifyTheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    IconButton(
                      onPressed: deckBusy ? null : onKeep,
                      icon: const Icon(Icons.skip_next,
                          color: SwipifyTheme.primary, size: 32),
                      style: IconButton.styleFrom(
                        backgroundColor: SwipifyTheme.primaryContainer
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
