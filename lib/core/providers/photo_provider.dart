import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:swipify/core/providers/preferences_provider.dart';

enum GroupingMode { month, date }

final groupingModeProvider =
    StateProvider<GroupingMode>((ref) => GroupingMode.month);

enum MediaTypeFilter { all, photos, videos }

final mediaFilterProvider =
    StateProvider<MediaTypeFilter>((ref) => MediaTypeFilter.all);

class PhotoBatch {
  final String id;
  final String title;
  final List<AssetEntity> assets;
  final List<String> allAssetIds;
  final int totalCount;
  final int reviewedCount;
  final bool isFullyReviewed;

  PhotoBatch({
    required this.id,
    required this.title,
    required this.assets,
    required this.allAssetIds,
    required this.totalCount,
    required this.reviewedCount,
    required this.isFullyReviewed,
  });
}

String _formatMonth(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${months[date.month - 1]} ${date.year}';
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

final photoPermissionProvider = FutureProvider<PermissionState>((ref) async {
  return await PhotoManager.requestPermissionExtend();
});

final allMediaProvider = FutureProvider<List<AssetEntity>>((ref) async {
  final permission = await ref.watch(photoPermissionProvider.future);
  if (!permission.hasAccess) {
    return [];
  }

  final filter = ref.watch(mediaFilterProvider);
  RequestType requestType;
  switch (filter) {
    case MediaTypeFilter.photos:
      requestType = RequestType.image;
      break;
    case MediaTypeFilter.videos:
      requestType = RequestType.video;
      break;
    case MediaTypeFilter.all:
      requestType = RequestType.image | RequestType.video;
      break;
  }

  // Get all paths
  final paths = await PhotoManager.getAssetPathList(
    onlyAll: true,
    type: requestType,
  );

  if (paths.isEmpty) return [];

  final recentAlbum = paths.first;
  final count = await recentAlbum.assetCountAsync;

  // Limiting to the 2000 most recent items for MVP performance (to allow grouping a substantial amount)
  return await recentAlbum.getAssetListRange(
      start: 0, end: count > 2000 ? 2000 : count);
});

final batchedMediaProvider = Provider<AsyncValue<List<PhotoBatch>>>((ref) {
  final allMediaAsync = ref.watch(allMediaProvider);
  final groupingMode = ref.watch(groupingModeProvider);
  final reviewedIds = ref.watch(reviewedIdsProvider);

  return allMediaAsync.whenData((assets) {
    // Group ALL assets sequentially via createDateTime to establish the full batch count
    // PhotoManager returns descending order (latest first)
    final grouped = <String, List<AssetEntity>>{};
    for (final asset in assets) {
      final date = asset.createDateTime;
      final key = groupingMode == GroupingMode.month
          ? _formatMonth(date)
          : _formatDate(date);
      grouped.putIfAbsent(key, () => []).add(asset);
    }

    // Convert to batches list
    final batches = grouped.entries.map((e) {
      final allBatchAssets = e.value;
      final unreviewedAssets = allBatchAssets
          .where((asset) => !reviewedIds.contains(asset.id))
          .toList();

      final totalCount = allBatchAssets.length;
      final reviewedCount = totalCount - unreviewedAssets.length;
      final allAssetIds = allBatchAssets.map((a) => a.id).toList();

      return PhotoBatch(
        id: e.key,
        title: e.key,
        assets: unreviewedAssets,
        allAssetIds: allAssetIds,
        totalCount: totalCount,
        reviewedCount: reviewedCount,
        isFullyReviewed: unreviewedAssets.isEmpty,
      );
    }).toList();

    return batches;
  });
});

class SwipeSessionState {
  final List<AssetEntity> remainingAssets;
  final List<AssetEntity> keepQueue;
  final List<AssetEntity> deleteQueue;

  SwipeSessionState({
    required this.remainingAssets,
    this.keepQueue = const [],
    this.deleteQueue = const [],
  });

  SwipeSessionState copyWith({
    List<AssetEntity>? remainingAssets,
    List<AssetEntity>? keepQueue,
    List<AssetEntity>? deleteQueue,
  }) {
    return SwipeSessionState(
      remainingAssets: remainingAssets ?? this.remainingAssets,
      keepQueue: keepQueue ?? this.keepQueue,
      deleteQueue: deleteQueue ?? this.deleteQueue,
    );
  }
}

class SwipeSessionNotifier
    extends AutoDisposeFamilyNotifier<SwipeSessionState, List<AssetEntity>> {
  @override
  SwipeSessionState build(List<AssetEntity> arg) {
    return SwipeSessionState(remainingAssets: List.from(arg));
  }

  void keepItem(AssetEntity item) {
    if (!state.remainingAssets.contains(item)) return;

    final nextRemaining = List<AssetEntity>.from(state.remainingAssets)
      ..remove(item);
    final nextKeep = List<AssetEntity>.from(state.keepQueue)..add(item);
    state = state.copyWith(remainingAssets: nextRemaining, keepQueue: nextKeep);
    _checkCompletion(nextRemaining);
  }

  void deleteItem(AssetEntity item) {
    if (!state.remainingAssets.contains(item)) return;

    final nextRemaining = List<AssetEntity>.from(state.remainingAssets)
      ..remove(item);
    final nextDelete = List<AssetEntity>.from(state.deleteQueue)..add(item);
    state =
        state.copyWith(remainingAssets: nextRemaining, deleteQueue: nextDelete);
    _checkCompletion(nextRemaining);
  }

  void _checkCompletion(List<AssetEntity> remaining) {
    if (remaining.isEmpty) {
      commitSession();
    }
  }

  Future<void> commitSession() async {
    final keepIds = state.keepQueue.map((e) => e.id).toList();
    final deleteIds = state.deleteQueue.map((e) => e.id).toList();

    // Register keepers immediately
    ref.read(reviewedIdsProvider.notifier).addIds(keepIds);

    if (deleteIds.isNotEmpty) {
      try {
        final deletedIds = await PhotoManager.editor.deleteWithIds(deleteIds);
        if (deletedIds.isNotEmpty) {
          // If the user accepts deletion, we log them as reviewed/deleted
          ref.read(reviewedIdsProvider.notifier).addIds(deletedIds);
        }
      } catch (e) {
        debugPrint("Error deleting items: $e");
      }
    }
  }
}

final swipeSessionNotifierProvider = NotifierProvider.autoDispose
    .family<SwipeSessionNotifier, SwipeSessionState, List<AssetEntity>>(
  SwipeSessionNotifier.new,
);
