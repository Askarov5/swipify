import 'dart:ui';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme.dart';
import '../../core/native_gallery_helper.dart';
import '../../core/providers/photo_provider.dart';

class SwipeScreen extends ConsumerStatefulWidget {
  final PhotoBatch batch;

  const SwipeScreen({super.key, required this.batch});

  static Future<T?> open<T>(BuildContext context, PhotoBatch batch) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (_) => SwipeScreen(batch: batch)),
    );
  }

  @override
  ConsumerState<SwipeScreen> createState() => _SwipeScreenState();
}

enum _DeckMotion { idle, rebounding, flyingOff }

class _SwipeScreenState extends ConsumerState<SwipeScreen>
    with SingleTickerProviderStateMixin {
  static const double _parallaxDistanceFactor = 0.35;

  late AnimationController _deckController;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  _DeckMotion _motion = _DeckMotion.idle;

  Offset _reboundStartDrag = Offset.zero;
  double _reboundStartParallax = 0;

  Offset _flyStartDrag = Offset.zero;
  Offset _flyEndDrag = Offset.zero;
  double _flyStartParallax = 0;
  double _animParallax = 0;

  SwipifyPhoto? _pendingFlyOffCard;
  bool _pendingFlyOffIsKeep = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final library = await ref.read(allMediaProvider.future);
        if (!mounted) return;
        final notifier = ref.read(swipeSessionNotifierProvider.notifier);
        notifier.init(widget.batch.assets, widget.batch.id);
        notifier.tryRestoreDraft(widget.batch, library);
      } catch (_) {
        if (!mounted) return;
        ref.read(swipeSessionNotifierProvider.notifier).init(
              widget.batch.assets,
              widget.batch.id,
            );
      }
    });
    _deckController = AnimationController(vsync: this)
      ..addListener(_onDeckAnimationTick);
  }

  @override
  void dispose() {
    _deckController.dispose();
    super.dispose();
  }

  void _onDeckAnimationTick() {
    if (!mounted || _motion == _DeckMotion.idle) return;
    final t = _deckController.value;
    setState(() {
      switch (_motion) {
        case _DeckMotion.idle:
          break;
        case _DeckMotion.rebounding:
          final c = Curves.easeOutCubic.transform(t);
          _dragOffset = Offset.lerp(_reboundStartDrag, Offset.zero, c)!;
          _animParallax = lerpDouble(_reboundStartParallax, 0, c)!;
          break;
        case _DeckMotion.flyingOff:
          final c = Curves.easeInCubic.transform(t);
          _dragOffset = Offset.lerp(_flyStartDrag, _flyEndDrag, c)!;
          _animParallax = lerpDouble(_flyStartParallax, 1, c)!;
          break;
      }
    });
  }

  double _parallaxFromDrag(double screenWidth) {
    final denom = screenWidth * _parallaxDistanceFactor;
    if (denom <= 0) return 0;
    return (_dragOffset.distance / denom).clamp(0.0, 1.0);
  }

  double _effectiveParallax(double screenWidth) {
    switch (_motion) {
      case _DeckMotion.idle:
        return _parallaxFromDrag(screenWidth);
      case _DeckMotion.rebounding:
      case _DeckMotion.flyingOff:
        return _animParallax;
    }
  }

  void _completeFlyOff(SwipeSessionNotifier session) {
    final card = _pendingFlyOffCard;
    if (card == null || !mounted) return;
    final keep = _pendingFlyOffIsKeep;
    _pendingFlyOffCard = null;
    if (keep) {
      session.keepItem(card);
    } else {
      session.deleteItem(card);
    }
    setState(() {
      _motion = _DeckMotion.idle;
      _dragOffset = Offset.zero;
      _animParallax = 0;
    });
    _deckController.reset();
  }

  void _startFlyOff({
    required BuildContext context,
    required SwipeSessionNotifier session,
    required SwipifyPhoto card,
    required bool keep,
  }) {
    if (_motion != _DeckMotion.idle) return;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sign = keep ? 1.0 : -1.0;
    _deckController.stop();
    final startParallax = _parallaxFromDrag(screenWidth);
    setState(() {
      _isDragging = false;
      _flyStartDrag = _dragOffset;
      _flyEndDrag = Offset(
        sign * screenWidth * 1.5 + _dragOffset.dx * 0.15,
        _dragOffset.dy,
      );
      _flyStartParallax = startParallax;
      _animParallax = startParallax;
      _pendingFlyOffCard = card;
      _pendingFlyOffIsKeep = keep;
      _motion = _DeckMotion.flyingOff;
    });
    _deckController.duration = const Duration(milliseconds: 280);
    _deckController.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      _completeFlyOff(session);
    });
  }

  void _onPanStart(DragStartDetails details) {
    if (_motion != _DeckMotion.idle) return;
    _deckController.stop();
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_motion != _DeckMotion.idle) return;
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details, SwipeSessionNotifier session,
      SwipifyPhoto frontCard) {
    if (_motion != _DeckMotion.idle) return;
    setState(() => _isDragging = false);

    final screenWidth = MediaQuery.sizeOf(context).width;

    if (_dragOffset.dx.abs() > screenWidth * 0.3) {
      final swipedRight = _dragOffset.dx > 0;
      _startFlyOff(
        context: context,
        session: session,
        card: frontCard,
        keep: swipedRight,
      );
    } else {
      final start = _dragOffset;
      final startP = _parallaxFromDrag(screenWidth);
      setState(() {
        _motion = _DeckMotion.rebounding;
        _reboundStartDrag = start;
        _reboundStartParallax = startP;
        _animParallax = startP;
      });
      _deckController.duration = const Duration(milliseconds: 320);
      _deckController.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        setState(() {
          _motion = _DeckMotion.idle;
          _dragOffset = Offset.zero;
          _animParallax = 0;
        });
        _deckController.reset();
      });
    }
  }

  bool _needsExitGuard(SwipeSessionState session) {
    if (session.isCommitted) return false;
    return session.keepQueue.isNotEmpty || session.deleteQueue.isNotEmpty;
  }

  void _onClosePressed(bool needsExitGuard) {
    if (!needsExitGuard) {
      Navigator.pop(context);
      return;
    }
    _showLeaveBatchDialog();
  }

  Future<void> _showLeaveBatchDialog() async {
    final session = ref.read(swipeSessionNotifierProvider);
    final keepCount = session.keepQueue.length;
    final deleteCount = session.deleteQueue.length;

    if (!mounted) return;

    await showDialog<void>(
      context: context,
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
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(dialogContext),
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
                          if (mounted) Navigator.pop(context);
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
                            if (!context.mounted) return;
                            if (ok) {
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            } else {
                              if (dialogContext.mounted) {
                                setDialogState(() => saving = false);
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
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

  @override
  Widget build(BuildContext context) {
    final initialAssets = widget.batch.assets;
    final sessionState = ref.watch(swipeSessionNotifierProvider);
    final needsExitGuard = _needsExitGuard(sessionState);

    return PopScope(
      canPop: !needsExitGuard,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showLeaveBatchDialog();
      },
      child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: SwipifyTheme.onSurfaceVariant),
          onPressed: () => _onClosePressed(needsExitGuard),
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
                final showDeleteRetry = !isCommitted &&
                    sessionState.keepsPersistedToLibrary &&
                    hasDeletes;

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
                        if (showDeleteRetry) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Your keeps are saved. Some items could not be deleted from the library.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: SwipifyTheme.secondary,
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
                            label: Text(
                                'Retry delete (${sessionState.deleteQueue.length})'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SwipifyTheme.secondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
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
                                ? 'Confirm & Delete ${sessionState.deleteQueue.length} Items'
                                : 'Finish Batch'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasDeletes
                                  ? SwipifyTheme.secondary
                                  : SwipifyTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                          ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(swipeSessionNotifierProvider.notifier)
                                .discardSession();
                            Navigator.pop(context);
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
              final screenWidth = MediaQuery.sizeOf(context).width;
              final deckParallax = _effectiveParallax(screenWidth);
              final deckBusy = _motion != _DeckMotion.idle;

              return Stack(
                fit: StackFit.expand,
                children: [
                  // Full-screen card stack
                  Stack(
                    alignment: Alignment.center,
                    children: cards.asMap().entries.map((entry) {
                      int index = entry.key;
                      SwipifyPhoto asset = entry.value;
                      bool isFrontCard = index == cards.length - 1;
                      final swipeKeepTint = !isFrontCard
                          ? false
                          : (_motion == _DeckMotion.flyingOff
                              ? _pendingFlyOffIsKeep
                              : _dragOffset.dx > 0);

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
                                  key: ValueKey(asset.id),
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
                                          'Photo ${asset.id.split('/').last}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.white),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          asset.creationTime.toLocal().toString().split('.')[0],
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white.withValues(alpha: 0.7)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isFrontCard &&
                                    (_isDragging || _motion == _DeckMotion.flyingOff))
                                  Container(
                                    color: swipeKeepTint
                                        ? SwipifyTheme.primary.withValues(
                                            alpha: (_dragOffset.dx.abs() / 300)
                                                .clamp(0.0, 0.4))
                                        : SwipifyTheme.secondary.withValues(
                                            alpha: (_dragOffset.dx.abs() / 300)
                                                .clamp(0.0, 0.4)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );

                      if (isFrontCard) {
                        final rotationAngle =
                            screenWidth > 0 ? (_dragOffset.dx / screenWidth) * 0.3 : 0.0;
                        return IgnorePointer(
                          ignoring: deckBusy,
                          child: GestureDetector(
                            onPanStart: _onPanStart,
                            onPanUpdate: _onPanUpdate,
                            onPanEnd: (details) =>
                                _onPanEnd(details, sessionNotifier, asset),
                            child: Transform.translate(
                              offset: _dragOffset,
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
                                    onPressed: deckBusy
                                        ? null
                                        : () => _startFlyOff(
                                              context: context,
                                              session: sessionNotifier,
                                              card: cards.last,
                                              keep: false,
                                            ),
                                    icon: const Icon(Icons.delete, color: SwipifyTheme.secondary, size: 32),
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
                                    onPressed: deckBusy
                                        ? null
                                        : () => _startFlyOff(
                                              context: context,
                                              session: sessionNotifier,
                                              card: cards.last,
                                              keep: true,
                                            ),
                                    icon: const Icon(Icons.skip_next, color: SwipifyTheme.primary, size: 32),
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
      ),
    );
  }
}

class SwipifyMediaWidget extends StatefulWidget {
  final SwipifyPhoto asset;
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
  /// Max edge length for deck thumbnails (back cards and video posters).
  static const double _deckThumbExtent = 720;

  /// Avoid repeat native export / path resolution when revisiting the same clip in one session.
  static final Map<String, String> _sessionVideoPathCache = <String, String>{};

  VideoPlayerController? _videoController;
  bool _isMuted = true;
  bool _initialized = false;
  String? _videoError;

  Future<Uint8List?>? _imageFuture;
  Future<Uint8List?>? _videoPosterFuture;

  Future<Uint8List?> _photoLoadFuture() {
    if (widget.isFrontCard) {
      return widget.asset.fileData;
    }
    return NativeGalleryHelper.fetchThumbnail(
      widget.asset.id,
      width: _deckThumbExtent,
      height: _deckThumbExtent,
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.asset.isVideo) {
      _videoPosterFuture = NativeGalleryHelper.fetchThumbnail(
        widget.asset.id,
        width: _deckThumbExtent,
        height: _deckThumbExtent,
      );
      if (widget.isFrontCard) {
        _initVideo();
      }
    } else {
      _imageFuture = _photoLoadFuture();
    }
  }

  void _disposeVideoController() {
    _videoController?.removeListener(_onVideoPlayerTick);
    final c = _videoController;
    _videoController = null;
    c?.dispose();
    _initialized = false;
  }

  void _onVideoPlayerTick() {
    final c = _videoController;
    if (c == null || !mounted) return;
    if (!c.value.isInitialized) return;
    if (c.value.hasError) {
      c.removeListener(_onVideoPlayerTick);
      final msg = c.value.errorDescription;
      c.dispose();
      _videoController = null;
      setState(() {
        _initialized = false;
        _videoError = msg ?? 'Playback error';
      });
    }
  }

  Future<void> _initVideo() async {
    if (!mounted || !widget.isFrontCard) return;

    /// Swipes schedule overlapping async work; only the latest [loadId] may update state.
    final String loadId = widget.asset.id;

    setState(() {
      _videoError = null;
    });

    String? path;
    try {
      path = _sessionVideoPathCache[loadId];
      if (path == null) {
        path = await NativeGalleryHelper.fetchFilePath(loadId);
        if (path != null) {
          _sessionVideoPathCache[loadId] = path;
        }
      }
    } catch (_) {
      if (!mounted || widget.asset.id != loadId) return;
      setState(() {
        _videoError = 'Could not access video.';
      });
      return;
    }

    if (!mounted || widget.asset.id != loadId) return;
    if (path == null) {
      setState(() {
        _videoError = 'Could not access video.';
      });
      return;
    }

    _disposeVideoController();
    if (!mounted || widget.asset.id != loadId) return;

    final controller = VideoPlayerController.file(File(path));
    _videoController = controller;
    controller.addListener(_onVideoPlayerTick);

    try {
      await controller.initialize();
      if (!mounted || widget.asset.id != loadId) {
        controller.removeListener(_onVideoPlayerTick);
        await controller.dispose();
        if (_videoController == controller) {
          _videoController = null;
        }
        return;
      }
      await controller.setVolume(0.0);
      await controller.setLooping(true);
      setState(() {
        _initialized = true;
        _videoError = null;
      });
      controller.play();
    } catch (_) {
      controller.removeListener(_onVideoPlayerTick);
      await controller.dispose();
      if (_videoController == controller) {
        _videoController = null;
      }
      if (!mounted || widget.asset.id != loadId) return;
      _sessionVideoPathCache.remove(loadId);
      setState(() {
        _initialized = false;
        _videoError = 'Video failed to load.';
      });
    }
  }

  void _retryVideo() {
    _disposeVideoController();
    _initVideo();
  }

  @override
  void didUpdateWidget(SwipifyMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Safely refresh completely if a completely different asset was injected into this exact positional widget state
    if (widget.asset.id != oldWidget.asset.id) {
      if (widget.asset.isVideo) {
        _videoController?.removeListener(_onVideoPlayerTick);
        _videoController?.dispose();
        _videoController = null;
        _initialized = false;
        _videoError = null;
        _videoPosterFuture = NativeGalleryHelper.fetchThumbnail(
          widget.asset.id,
          width: _deckThumbExtent,
          height: _deckThumbExtent,
        );
        if (widget.isFrontCard) {
          _initVideo();
        }
      } else {
        _videoController?.removeListener(_onVideoPlayerTick);
        _videoController?.dispose();
        _videoController = null;
        _videoError = null;
        setState(() {
          _imageFuture = _photoLoadFuture();
        });
      }
      return;
    }

    if (!widget.asset.isVideo &&
        widget.isFrontCard != oldWidget.isFrontCard) {
      setState(() {
        _imageFuture = _photoLoadFuture();
      });
      return;
    }

    if (widget.asset.isVideo) {
      if (widget.isFrontCard && !oldWidget.isFrontCard) {
        if (!_initialized) {
          _initVideo();
        } else {
          _videoController?.play();
        }
      } else if (!widget.isFrontCard && oldWidget.isFrontCard) {
        _videoController?.removeListener(_onVideoPlayerTick);
        _videoController?.dispose();
        _videoController = null;
        _initialized = false;
        _videoError = null;
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onVideoPlayerTick);
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
    if (widget.asset.isVideo) {
      if (!_initialized || _videoController == null) {
        return Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<Uint8List?>(
              future: _videoPosterFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    snapshot.data == null) {
                  if (widget.isFrontCard) {
                    return const SizedBox.shrink();
                  }
                  return const Center(child: CircularProgressIndicator());
                }
                final bytes = snapshot.data;
                if (bytes != null && bytes.isNotEmpty) {
                  return Center(
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  );
                }
                return const Center(
                  child: Icon(Icons.videocam, size: 64, color: Colors.grey),
                );
              },
            ),
            if (widget.isFrontCard && _videoError == null)
              Positioned(
                top: 12,
                right: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
            if (widget.isFrontCard && _videoError != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _videoError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _retryVideo,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: _videoController!.value.size.width,
                height: _videoController!.value.size.height,
                child: VideoPlayer(_videoController!),
              ),
            ),
          ),
          if (widget.isFrontCard)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 80, right: 16),
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
    }
    
    // Fallback Image Handle
    return FutureBuilder<Uint8List?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const Center(child: Icon(Icons.broken_image, size: 64, color: Colors.grey));
        }

        return Center(
          child: Image.memory(
            snapshot.data!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        );
      },
    );
  }
}
