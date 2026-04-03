import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:swipify/core/providers/preferences_provider.dart';
import 'package:swipify/core/photo_permission_helper.dart';

enum GroupingMode { month, date }

class GroupingModeNotifier extends Notifier<GroupingMode> {
  @override
  GroupingMode build() => GroupingMode.month;
  
  void updateMode(GroupingMode mode) {
    state = mode;
  }
}

final groupingModeProvider =
    NotifierProvider<GroupingModeNotifier, GroupingMode>(GroupingModeNotifier.new);

enum MediaTypeFilter { all, photos, videos }

class MediaFilterNotifier extends Notifier<MediaTypeFilter> {
  @override
  MediaTypeFilter build() => MediaTypeFilter.all;

  void updateFilter(MediaTypeFilter filter) {
    state = filter;
  }
}

final mediaFilterProvider =
    NotifierProvider<MediaFilterNotifier, MediaTypeFilter>(MediaFilterNotifier.new);

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

final photoPermissionProvider = FutureProvider<String>((ref) async {
  return await PhotoPermissionHelper.requestPermission();
});

final allMediaProvider = FutureProvider<List<AssetEntity>>((ref) async {
  final permission = await ref.watch(photoPermissionProvider.future);
  if (!PhotoPermissionHelper.isGranted(permission)) {
    return [];
  }

  final filter = ref.watch(mediaFilterProvider);
  RequestType requestType = RequestType.image | RequestType.video;
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

  // Fetch ALL metadata shells (AssetEntity).
  // Native PhotoManager executes this seamlessly for 15,000+ items typically under 200ms
  // because it strictly defers heavy image bytes/thumbnails until the SwipeScreen explicitly requests them.
  return await recentAlbum.getAssetListRange(start: 0, end: count);
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
  final bool isCommitted;

  SwipeSessionState({
    required this.remainingAssets,
    this.keepQueue = const [],
    this.deleteQueue = const [],
    this.isCommitted = false,
  });

  SwipeSessionState copyWith({
    List<AssetEntity>? remainingAssets,
    List<AssetEntity>? keepQueue,
    List<AssetEntity>? deleteQueue,
    bool? isCommitted,
  }) {
    return SwipeSessionState(
      remainingAssets: remainingAssets ?? this.remainingAssets,
      keepQueue: keepQueue ?? this.keepQueue,
      deleteQueue: deleteQueue ?? this.deleteQueue,
      isCommitted: isCommitted ?? this.isCommitted,
    );
  }
}

class SwipeSessionNotifier extends Notifier<SwipeSessionState> {
  @override
  SwipeSessionState build() {
    return SwipeSessionState(remainingAssets: []);
  }

  void init(List<AssetEntity> assets) {
    if (state.remainingAssets.isEmpty && state.keepQueue.isEmpty && state.deleteQueue.isEmpty) {
      state = SwipeSessionState(remainingAssets: List.from(assets));
    }
  }

  void keepItem(AssetEntity item) {
    if (!state.remainingAssets.contains(item)) return;

    final nextRemaining = List<AssetEntity>.from(state.remainingAssets)
      ..remove(item);
    final nextKeep = List<AssetEntity>.from(state.keepQueue)..add(item);
    state = state.copyWith(remainingAssets: nextRemaining, keepQueue: nextKeep);
  }

  void deleteItem(AssetEntity item) {
    if (!state.remainingAssets.contains(item)) return;

    final nextRemaining = List<AssetEntity>.from(state.remainingAssets)
      ..remove(item);
    final nextDelete = List<AssetEntity>.from(state.deleteQueue)..add(item);
    state = state.copyWith(remainingAssets: nextRemaining, deleteQueue: nextDelete);
  }

  Future<void> commitSession() async {
    if (state.isCommitted) return;
    
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
    
    state = state.copyWith(isCommitted: true);
  }
}

final swipeSessionNotifierProvider = NotifierProvider<SwipeSessionNotifier, SwipeSessionState>(
  SwipeSessionNotifier.new,
);
