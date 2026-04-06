import 'dart:async' show unawaited;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/native_gallery_helper.dart';
import '../../core/providers/photo_provider.dart';
import '../../core/theme.dart';
import 'swipe_batch_finished_view.dart';
import 'swipe_deck_bottom_bar.dart';
import 'swipe_deck_progress_overlay.dart';
import 'swipe_deck_stack.dart';
import 'swipe_leave_batch_dialog.dart';
import 'swipe_physics.dart';

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

class _SwipeScreenState extends ConsumerState<SwipeScreen>
    with SingleTickerProviderStateMixin {
  static const double _parallaxDistanceFactor = 0.35;

  late AnimationController _deckController;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  SwipeDeckMotion _motion = SwipeDeckMotion.idle;

  Offset _reboundStartDrag = Offset.zero;
  double _reboundStartParallax = 0;

  Offset _flyStartDrag = Offset.zero;
  Offset _flyEndDrag = Offset.zero;
  double _flyStartParallax = 0;
  double _animParallax = 0;

  SwipifyPhoto? _pendingFlyOffCard;
  bool _pendingFlyOffIsKeep = false;

  /// One haptic when |dx| crosses the distance commit threshold during a drag.
  bool _distanceThresholdHapticSent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final notifier = ref.read(swipeSessionNotifierProvider.notifier);
      notifier.init(widget.batch.assets, widget.batch.id);
      try {
        final library = await ref.read(allMediaProvider.future);
        if (!mounted) return;
        notifier.tryRestoreDraft(widget.batch, library);
      } catch (_) {
        // [init] already applied; deck is usable without draft restore.
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
    if (!mounted || _motion == SwipeDeckMotion.idle) return;
    final t = _deckController.value;
    setState(() {
      switch (_motion) {
        case SwipeDeckMotion.idle:
          break;
        case SwipeDeckMotion.rebounding:
          final c = Curves.easeOutCubic.transform(t);
          _dragOffset = Offset.lerp(_reboundStartDrag, Offset.zero, c)!;
          _animParallax = lerpDouble(_reboundStartParallax, 0, c)!;
          break;
        case SwipeDeckMotion.flyingOff:
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
      case SwipeDeckMotion.idle:
        return _parallaxFromDrag(screenWidth);
      case SwipeDeckMotion.rebounding:
      case SwipeDeckMotion.flyingOff:
        return _animParallax;
    }
  }

  void _completeFlyOff(SwipeSessionNotifier session) {
    final card = _pendingFlyOffCard;
    if (card == null || !mounted) return;
    final keep = _pendingFlyOffIsKeep;
    _pendingFlyOffCard = null;
    session.recordDecision(card, delete: !keep);
    setState(() {
      _motion = SwipeDeckMotion.idle;
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
    if (_motion != SwipeDeckMotion.idle) return;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sign = keep ? 1.0 : -1.0;
    _deckController.stop();
    final startParallax = _parallaxFromDrag(screenWidth);
    HapticFeedback.lightImpact();
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
      _motion = SwipeDeckMotion.flyingOff;
    });
    _deckController.duration = const Duration(milliseconds: 280);
    _deckController.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      _completeFlyOff(session);
    });
  }

  void _onPanStart(DragStartDetails details) {
    if (_motion != SwipeDeckMotion.idle) return;
    _deckController.stop();
    _distanceThresholdHapticSent = false;
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_motion != SwipeDeckMotion.idle) return;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final distanceThreshold =
        screenWidth * SwipeDeckGesturePolicy.commitWidthFraction;
    setState(() {
      final next = _dragOffset + details.delta;
      if (!_distanceThresholdHapticSent &&
          next.dx.abs() > distanceThreshold &&
          _dragOffset.dx.abs() <= distanceThreshold) {
        HapticFeedback.selectionClick();
        _distanceThresholdHapticSent = true;
      }
      _dragOffset = next;
    });
  }

  void _onPanEnd(DragEndDetails details, SwipeSessionNotifier session,
      SwipifyPhoto frontCard) {
    if (_motion != SwipeDeckMotion.idle) return;
    setState(() => _isDragging = false);

    final screenWidth = MediaQuery.sizeOf(context).width;

    if (SwipeDeckGesturePolicy.shouldCompleteSwipe(
          screenWidth: screenWidth,
          dragDx: _dragOffset.dx,
          velocityPixelsPerSecond: details.velocity.pixelsPerSecond,
        )) {
      final keep = SwipeDeckGesturePolicy.keepIfCompleting(
        dragDx: _dragOffset.dx,
      );
      _startFlyOff(
        context: context,
        session: session,
        card: frontCard,
        keep: keep,
      );
    } else {
      final start = _dragOffset;
      final startP = _parallaxFromDrag(screenWidth);
      setState(() {
        _motion = SwipeDeckMotion.rebounding;
        _reboundStartDrag = start;
        _reboundStartParallax = startP;
        _animParallax = startP;
      });
      _deckController.duration = const Duration(milliseconds: 320);
      _deckController.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        setState(() {
          _motion = SwipeDeckMotion.idle;
          _dragOffset = Offset.zero;
          _animParallax = 0;
        });
        _deckController.reset();
      });
    }
  }

  bool _needsExitGuard(SwipeSessionState session) {
    if (session.isCommitted) return false;
    return session.decisions.isNotEmpty;
  }

  void _onClosePressed(bool needsExitGuard) {
    if (!needsExitGuard) {
      Navigator.pop(context);
      return;
    }
    showSwipeLeaveBatchDialog(context, ref);
  }

  Future<void> _onApplyDeletesPressed() async {
    final messenger = ScaffoldMessenger.of(context);
    final removedCount = ref.read(swipeSessionNotifierProvider).deleteCount;
    final notifier = ref.read(swipeSessionNotifierProvider.notifier);
    final ok = await notifier.applyPendingDeletesSaveAndCompact();
    if (!mounted) return;
    if (ok) {
      if (removedCount > 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              removedCount == 1
                  ? 'Removed 1 item from your library. Progress saved.'
                  : 'Removed $removedCount items from your library. Progress saved.',
            ),
          ),
        );
      }
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Keeps were saved, but delete failed. Try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialAssets = widget.batch.assets;
    final sessionState = ref.watch(swipeSessionNotifierProvider);
    final needsExitGuard = _needsExitGuard(sessionState);
    final deckBusy = _motion != SwipeDeckMotion.idle;
    final canUndo = sessionState.decisions.isNotEmpty &&
        !sessionState.isCommitted &&
        !deckBusy;

    return PopScope(
      canPop: !needsExitGuard,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        showSwipeLeaveBatchDialog(context, ref);
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
          actions: [
            if (!sessionState.isCommitted)
              IconButton(
                tooltip:
                    canUndo ? 'Undo last swipe' : 'Nothing to undo yet',
                icon: const Icon(Icons.settings_backup_restore,
                    color: SwipifyTheme.onSurfaceVariant),
                onPressed: canUndo
                    ? () {
                        ref
                            .read(swipeSessionNotifierProvider.notifier)
                            .undoLastDecision();
                      }
                    : null,
              ),
          ],
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
                final deckBusy = _motion != SwipeDeckMotion.idle;

                if (initialAssets.isNotEmpty &&
                    sessionState.sessionBatchOrder.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (cards.isEmpty) {
                  return SwipeBatchFinishedView(deckBusy: deckBusy);
                }

                final sessionNotifier =
                    ref.read(swipeSessionNotifierProvider.notifier);

                final total = sessionState.sessionBatchOrder.length;
                final progress =
                    total > 0 ? 1.0 - (cards.length / total) : 0.0;
                final screenWidth = MediaQuery.sizeOf(context).width;
                final deckParallax = _effectiveParallax(screenWidth);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    SwipeDeckStack(
                      cards: cards,
                      batchTitle: widget.batch.title,
                      motion: _motion,
                      dragOffset: _dragOffset,
                      isDragging: _isDragging,
                      pendingFlyOffIsKeep: _pendingFlyOffIsKeep,
                      deckParallax: deckParallax,
                      screenWidth: screenWidth,
                      deckBusy: deckBusy,
                      sessionNotifier: sessionNotifier,
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                    ),
                    SwipeDeckProgressOverlay(progress: progress),
                    SwipeDeckBottomBar(
                      deckBusy: deckBusy,
                      canApplyDeletes: sessionState.deleteCount > 0 &&
                          !sessionState.isCommitted,
                      pendingDeleteCount: sessionState.deleteCount,
                      onDelete: () => _startFlyOff(
                            context: context,
                            session: sessionNotifier,
                            card: cards.last,
                            keep: false,
                          ),
                      onKeep: () => _startFlyOff(
                            context: context,
                            session: sessionNotifier,
                            card: cards.last,
                            keep: true,
                          ),
                      onApplyDeletes: () =>
                          unawaited(_onApplyDeletesPressed()),
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
