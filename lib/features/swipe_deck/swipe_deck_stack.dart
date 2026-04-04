import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../core/native_gallery_helper.dart';
import '../../core/providers/photo_provider.dart';
import '../../core/theme.dart';
import 'swipify_media_widget.dart';

enum SwipeDeckMotion { idle, rebounding, flyingOff }

class SwipeDeckStack extends StatelessWidget {
  final List<SwipifyPhoto> cards;
  final String batchTitle;
  final SwipeDeckMotion motion;
  final Offset dragOffset;
  final bool isDragging;
  final bool pendingFlyOffIsKeep;
  final double deckParallax;
  final double screenWidth;
  final bool deckBusy;
  final SwipeSessionNotifier sessionNotifier;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final void Function(
    DragEndDetails details,
    SwipeSessionNotifier session,
    SwipifyPhoto front,
  ) onPanEnd;

  const SwipeDeckStack({
    super.key,
    required this.cards,
    required this.batchTitle,
    required this.motion,
    required this.dragOffset,
    required this.isDragging,
    required this.pendingFlyOffIsKeep,
    required this.deckParallax,
    required this.screenWidth,
    required this.deckBusy,
    required this.sessionNotifier,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: cards.asMap().entries.map((entry) {
        final index = entry.key;
        final asset = entry.value;
        final isFrontCard = index == cards.length - 1;
        final swipeKeepTint = !isFrontCard
            ? false
            : (motion == SwipeDeckMotion.flyingOff
                ? pendingFlyOffIsKeep
                : dragOffset.dx > 0);

        final card = Hero(
          tag: isFrontCard ? 'hero_collage_$batchTitle' : 'card_$index',
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: SwipifyTheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                if (isFrontCard)
                  const BoxShadow(
                    color: Colors.black45,
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SwipifyMediaWidget(
                    key: ValueKey(asset.id),
                    asset: asset,
                    isFrontCard: isFrontCard,
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.8),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, bottom: 120),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            asset.creationTime
                                .toLocal()
                                .toString()
                                .split('.')[0],
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isFrontCard &&
                      (isDragging || motion == SwipeDeckMotion.flyingOff))
                    Container(
                      color: swipeKeepTint
                          ? SwipifyTheme.primary.withValues(
                              alpha: (dragOffset.dx.abs() / 300).clamp(0.0, 0.4))
                          : SwipifyTheme.secondary.withValues(
                              alpha: (dragOffset.dx.abs() / 300).clamp(0.0, 0.4)),
                    ),
                ],
              ),
            ),
          ),
        );

        if (isFrontCard) {
          final rotationAngle =
              screenWidth > 0 ? (dragOffset.dx / screenWidth) * 0.3 : 0.0;
          return IgnorePointer(
            ignoring: deckBusy,
            child: GestureDetector(
              onPanStart: onPanStart,
              onPanUpdate: onPanUpdate,
              onPanEnd: (details) =>
                  onPanEnd(details, sessionNotifier, asset),
              child: Transform.translate(
                offset: dragOffset,
                child: Transform.rotate(
                  angle: rotationAngle,
                  child: card,
                ),
              ),
            ),
          );
        }

        final depth = cards.length - 1 - index;
        final double scale;
        final double translateY;
        if (cards.length >= 2 && index == cards.length - 2) {
          scale = lerpDouble(0.95, 1.0, deckParallax)!;
          translateY = lerpDouble(20.0, 0.0, deckParallax)!;
        } else {
          scale = 1.0 - (depth * 0.05).clamp(0.0, 1.0);
          translateY = (depth * 20.0).clamp(0.0, 100.0);
        }

        return Transform.scale(
          scale: scale,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: card,
          ),
        );
      }).toList(),
    );
  }
}
