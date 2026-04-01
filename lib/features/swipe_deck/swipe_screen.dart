import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../../core/theme.dart';
import '../../core/providers/photo_provider.dart';

class SwipeScreen extends ConsumerStatefulWidget {
  final PhotoBatch batch;

  const SwipeScreen({super.key, required this.batch});

  @override
  ConsumerState<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends ConsumerState<SwipeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _swipeController;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(swipeSessionNotifierProvider.notifier).init(widget.batch.assets);
    });
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        setState(() {
          _dragOffset = Offset(_dragOffset.dx * (1 - _swipeController.value),
              _dragOffset.dy * (1 - _swipeController.value));
        });
      });
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _swipeController.stop();
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details, SwipeSessionNotifier session,
      AssetEntity frontCard) {
    setState(() => _isDragging = false);

    final screenWidth = MediaQuery.of(context).size.width;

    if (_dragOffset.dx.abs() > screenWidth * 0.3) {
      bool swipedRight = _dragOffset.dx > 0;
      if (swipedRight) {
        session.keepItem(frontCard);
      } else {
        session.deleteItem(frontCard);
      }
      setState(() {
        _dragOffset = Offset.zero;
      });
    } else {
      _swipeController.forward(from: 0).whenComplete(() {
        setState(() => _dragOffset = Offset.zero);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialAssets = widget.batch.assets;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: SwipifyTheme.onSurfaceVariant),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.batch.title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(color: SwipifyTheme.surface),
          Builder(
            builder: (context) {
              if (initialAssets.isEmpty) {
                return const Center(child: Text('Batch is empty'));
              }

              final sessionState = ref.watch(swipeSessionNotifierProvider);
              final cards = sessionState.remainingAssets;

              if (cards.isEmpty && sessionState.keepQueue.isEmpty && sessionState.deleteQueue.isEmpty) {
                // Not yet initialized
                return const Center(child: CircularProgressIndicator());
              }

              if (cards.isEmpty) {
                final isCommitted = sessionState.isCommitted;
                final bool hasDeletes = sessionState.deleteQueue.isNotEmpty;

                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isCommitted ? Icons.check_circle : Icons.celebration,
                          color: SwipifyTheme.primary, size: 64),
                      const SizedBox(height: 16),
                      Text(isCommitted ? 'Saved!' : 'Batch Finished!',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Kept: ${sessionState.keepQueue.length}'),
                      Text('To Delete: ${sessionState.deleteQueue.length}'),
                      const SizedBox(height: 24),
                      if (!isCommitted) ...[
                        ElevatedButton.icon(
                          onPressed: () async {
                            final notifier = ref.read(swipeSessionNotifierProvider.notifier);
                            await notifier.commitSession();
                            if (context.mounted) {
                              Navigator.pop(context); // Return to library after commit
                            }
                          },
                          icon: hasDeletes ? const Icon(Icons.delete_forever) : const Icon(Icons.check),
                          label: Text(hasDeletes ? 'Confirm & Delete ${sessionState.deleteQueue.length} Items' : 'Finish Batch'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasDeletes ? SwipifyTheme.secondary : SwipifyTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context); // Discards session changes
                          },
                          child: const Text('Cancel / Discard', style: TextStyle(color: SwipifyTheme.onSurfaceVariant)),
                        )
                      ] else ...[
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SwipifyTheme.primaryContainer,
                            foregroundColor: SwipifyTheme.onSurface,
                          ),
                          child: const Text('Back to Library'),
                        )
                      ]
                    ],
                  ),
                );
              }

              final sessionNotifier = ref.read(swipeSessionNotifierProvider.notifier);

              final total = initialAssets.length;
              final progress = 1.0 - (cards.length / total);

              return Stack(
                fit: StackFit.expand,
                children: [
                  // Full-screen card stack
                  Stack(
                    alignment: Alignment.center,
                    children: cards.asMap().entries.map((entry) {
                      int index = entry.key;
                      AssetEntity asset = entry.value;
                      bool isFrontCard = index == cards.length - 1;

                      Widget card = Hero(
                        tag: isFrontCard
                            ? 'hero_collage_${widget.batch.title}'
                            : 'card_$index',
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
                                  asset: asset,
                                  isFrontCard: isFrontCard,
                                ),
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    height: 180, // Made taller for gradient fading behind buttons
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
                                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 120),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          asset.title ?? 'Media ${asset.id}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.white),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${asset.width}x${asset.height} • ${asset.createDateTime.toString().split(' ')[0]}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white.withValues(alpha: 0.7)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isFrontCard && _isDragging)
                                  Container(
                                    color: _dragOffset.dx > 0
                                        ? SwipifyTheme.primary.withValues(
                                            alpha: (_dragOffset.dx / 300).clamp(0.0, 0.4))
                                        : SwipifyTheme.secondary.withValues(
                                            alpha: (_dragOffset.dx.abs() / 300).clamp(0.0, 0.4)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );

                      if (isFrontCard) {
                        final rotationAngle = (_dragOffset.dx / MediaQuery.of(context).size.width) * 0.3;
                        return GestureDetector(
                          onPanStart: _onPanStart,
                          onPanUpdate: _onPanUpdate,
                          onPanEnd: (details) => _onPanEnd(details, sessionNotifier, asset),
                          child: Transform.translate(
                            offset: _dragOffset,
                            child: Transform.rotate(
                              angle: rotationAngle,
                              child: card,
                            ),
                          ),
                        );
                      }

                      return Transform.scale(
                        scale: 1.0 - ((cards.length - 1 - index) * 0.05).clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, ((cards.length - 1 - index) * 20.0).clamp(0.0, 100.0)),
                          child: card,
                        ),
                      );
                    }).toList(),
                  ),

                  // Top Overlay (Progress bar + Labels)
                  SafeArea(
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
                                valueColor: const AlwaysStoppedAnimation<Color>(SwipifyTheme.primary),
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
                                        shadows: [const Shadow(color: Colors.black, blurRadius: 4)],
                                        fontWeight: FontWeight.bold)),
                                Text('KEEP',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: SwipifyTheme.primary,
                                        shadows: [const Shadow(color: Colors.black, blurRadius: 4)],
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Overlay (Buttons)
                  Align(
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
                                    onPressed: () {
                                      sessionNotifier.deleteItem(cards.last);
                                    },
                                    icon: const Icon(Icons.close, color: SwipifyTheme.secondary, size: 32),
                                    style: IconButton.styleFrom(
                                      backgroundColor: SwipifyTheme.secondaryContainer.withValues(alpha: 0.3),
                                      padding: const EdgeInsets.all(16),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {},
                                    icon: const Icon(Icons.info_outline, color: SwipifyTheme.onSurfaceVariant),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      sessionNotifier.keepItem(cards.last);
                                    },
                                    icon: const Icon(Icons.favorite, color: SwipifyTheme.primary, size: 32),
                                    style: IconButton.styleFrom(
                                      backgroundColor: SwipifyTheme.primaryContainer.withValues(alpha: 0.3),
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
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class SwipifyMediaWidget extends StatefulWidget {
  final AssetEntity asset;
  final bool isFrontCard;

  const SwipifyMediaWidget({
    super.key,
    required this.asset,
    required this.isFrontCard,
  });

  @override
  State<SwipifyMediaWidget> createState() => _SwipifyMediaWidgetState();
}

class _SwipifyMediaWidgetState extends State<SwipifyMediaWidget> {
  VideoPlayerController? _videoController;
  bool _isMuted = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initMedia();
  }

  Future<void> _initMedia() async {
    if (widget.asset.type == AssetType.video) {
      final file = await widget.asset.file;
      if (file != null) {
        _videoController = VideoPlayerController.file(file);
        await _videoController!.initialize();
        await _videoController!.setVolume(0.0);
        await _videoController!.setLooping(true);
        if (mounted) {
          setState(() {
            _initialized = true;
          });
          if (widget.isFrontCard) {
            _videoController!.play();
          }
        }
      }
    }
  }

  @override
  void didUpdateWidget(SwipifyMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.asset.type == AssetType.video && _videoController != null) {
      if (widget.isFrontCard && !oldWidget.isFrontCard) {
        _videoController!.play();
      } else if (!widget.isFrontCard && oldWidget.isFrontCard) {
        _videoController!.pause();
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _toggleMute() {
    if (_videoController == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _videoController!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asset.type == AssetType.image) {
      return AssetEntityImage(
        widget.asset,
        isOriginal: false,
        thumbnailSize: const ThumbnailSize.square(800),
        fit: BoxFit.cover,
      );
    } else if (widget.asset.type == AssetType.video) {
      if (!_initialized || _videoController == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _videoController!.value.size.width,
              height: _videoController!.value.size.height,
              child: VideoPlayer(_videoController!),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 80, right: 16), // Below Appbar
                child: IconButton(
                  icon: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                  ),
                  onPressed: _toggleMute,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return const Center(child: Icon(Icons.error));
    }
  }
}
