import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
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
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.celebration,
                          color: SwipifyTheme.primary, size: 64),
                      const SizedBox(height: 16),
                      const Text('Batch Finished!',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Kept: ${sessionState.keepQueue.length}'),
                      Text('Deleted: ${sessionState.deleteQueue.length}'),
                      const SizedBox(height: 24),
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
                    ],
                  ),
                );
              }

              final sessionNotifier = ref.read(swipeSessionNotifierProvider.notifier);

              final total = initialAssets.length;
              final progress = 1.0 - (cards.length / total);

              return SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: SwipifyTheme.surfaceContainerHighest,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              SwipifyTheme.primary),
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
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: SwipifyTheme.secondary,
                                      fontWeight: FontWeight.bold)),
                          Text('KEEP',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: SwipifyTheme.primary,
                                      fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Stack(
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
                                  height:
                                      MediaQuery.of(context).size.height * 0.6,
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
                                        AssetEntityImage(
                                          asset,
                                          isOriginal: false,
                                          thumbnailSize:
                                              const ThumbnailSize.square(800),
                                          fit: BoxFit.cover,
                                        ),
                                        Align(
                                          alignment: Alignment.bottomCenter,
                                          child: Container(
                                            height: 100,
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: [
                                                  Colors.black
                                                      .withValues(alpha: 0.8),
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  asset.title ??
                                                      'Image ${asset.id}',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Colors.white),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  '${asset.width}x${asset.height} • ${asset.createDateTime.toString().split(' ')[0]}',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.7)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (isFrontCard && _isDragging)
                                          Container(
                                            color: _dragOffset.dx > 0
                                                ? SwipifyTheme.primary
                                                    .withValues(
                                                        alpha: (_dragOffset.dx /
                                                                300)
                                                            .clamp(0.0, 0.4))
                                                : SwipifyTheme.secondary
                                                    .withValues(
                                                        alpha: (_dragOffset.dx
                                                                    .abs() /
                                                                300)
                                                            .clamp(0.0, 0.4)),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );

                              if (isFrontCard) {
                                final rotationAngle = (_dragOffset.dx /
                                        MediaQuery.of(context).size.width) *
                                    0.3;
                                return GestureDetector(
                                  onPanStart: _onPanStart,
                                  onPanUpdate: _onPanUpdate,
                                  onPanEnd: (details) => _onPanEnd(
                                      details, sessionNotifier, asset),
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
                                scale: 1.0 -
                                    ((cards.length - 1 - index) * 0.05)
                                        .clamp(0.0, 1.0),
                                child: Transform.translate(
                                  offset: Offset(
                                      0,
                                      ((cards.length - 1 - index) * 20.0)
                                          .clamp(0.0, 100.0)),
                                  child: card,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 24.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            color: SwipifyTheme.surfaceContainerHigh
                                .withValues(alpha: 0.6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    sessionNotifier.deleteItem(cards.last);
                                  },
                                  icon: const Icon(Icons.close,
                                      color: SwipifyTheme.secondary, size: 32),
                                  style: IconButton.styleFrom(
                                    backgroundColor: SwipifyTheme
                                        .secondaryContainer
                                        .withValues(alpha: 0.3),
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {},
                                  icon: const Icon(Icons.info_outline,
                                      color: SwipifyTheme.onSurfaceVariant),
                                ),
                                IconButton(
                                  onPressed: () {
                                    sessionNotifier.keepItem(cards.last);
                                  },
                                  icon: const Icon(Icons.favorite,
                                      color: SwipifyTheme.primary, size: 32),
                                  style: IconButton.styleFrom(
                                    backgroundColor: SwipifyTheme
                                        .primaryContainer
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
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
