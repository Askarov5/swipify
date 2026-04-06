import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipify/core/native_gallery_helper.dart';
import 'package:swipify/core/providers/photo_provider.dart';
import 'package:swipify/core/providers/preferences_provider.dart';
import 'package:swipify/features/swipe_deck/swipe_deck_stack.dart';

import 'support/gallery_channel_mock.dart';
import 'support/test_image_bytes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SwipeDeckStack', () {
    testWidgets('loads front photo via native fetchFile mock', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mock = GalleryChannelMock(
        fileBytes: kTestPng1x1,
        thumbnailBytes: kTestPng1x1,
      )..register();
      addTearDown(mock.unregister);

      final photo = SwipifyPhoto(
        id: 'deck-1',
        creationTime: DateTime.utc(2024, 3, 15, 12),
        isVideo: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: _SwipeDeckHarness(photos: [photo]),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.byType(RawImage), findsWidgets);
    });

    testWidgets('recordDecision removes card after simulated fly-off callback',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mock = GalleryChannelMock(
        fileBytes: kTestPng1x1,
        thumbnailBytes: kTestPng1x1,
      )..register();
      addTearDown(mock.unregister);

      final p1 = SwipifyPhoto(
        id: 'a',
        creationTime: DateTime.utc(2024, 1, 1),
        isVideo: false,
      );
      final p2 = SwipifyPhoto(
        id: 'b',
        creationTime: DateTime.utc(2024, 1, 2),
        isVideo: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: _SwipeDeckHarness(photos: [p1, p2]),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      final stackFinder = find.byType(SwipeDeckStack);
      final stack = tester.widget<SwipeDeckStack>(stackFinder);
      final session = stack.sessionNotifier;
      session.recordDecision(p2, delete: true);

      await tester.pump();
      expect(session.state.remainingAssets, hasLength(1));
      expect(session.state.remainingAssets.single.id, 'a');
    });
  });
}

class _SwipeDeckHarness extends ConsumerStatefulWidget {
  const _SwipeDeckHarness({required this.photos});

  final List<SwipifyPhoto> photos;

  @override
  ConsumerState<_SwipeDeckHarness> createState() => _SwipeDeckHarnessState();
}

class _SwipeDeckHarnessState extends ConsumerState<_SwipeDeckHarness> {
  Offset _drag = Offset.zero;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(swipeSessionNotifierProvider.notifier).init(
            widget.photos,
            'test-batch',
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(swipeSessionNotifierProvider);
    if (sessionState.sessionBatchOrder.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final cards = sessionState.remainingAssets;
    final sessionNotifier = ref.read(swipeSessionNotifierProvider.notifier);
    final w = MediaQuery.sizeOf(context).width;

    return Scaffold(
      body: SizedBox(
        width: 400,
        height: 700,
        child: SwipeDeckStack(
          cards: cards,
          batchTitle: 'Test',
          motion: SwipeDeckMotion.idle,
          dragOffset: _drag,
          isDragging: _dragging,
          pendingFlyOffIsKeep: false,
          deckParallax: 0,
          screenWidth: w,
          deckBusy: false,
          sessionNotifier: sessionNotifier,
          onPanStart: (_) => setState(() => _dragging = true),
          onPanUpdate: (d) => setState(() => _drag += d.delta),
          onPanEnd: (_, __, ___) => setState(() {
            _dragging = false;
            _drag = Offset.zero;
          }),
        ),
      ),
    );
  }
}
