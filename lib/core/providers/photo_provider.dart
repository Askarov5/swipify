import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swipify/core/native_gallery_helper.dart';
import 'package:swipify/core/providers/preferences_provider.dart';

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
  final List<SwipifyPhoto> assets;
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
  return await NativeGalleryHelper.requestPermission();
});

final allMediaProvider = FutureProvider<List<SwipifyPhoto>>((ref) async {
  final permission = await ref.watch(photoPermissionProvider.future);
  if (!NativeGalleryHelper.isGranted(permission)) {
    return [];
  }

  return await NativeGalleryHelper.fetchLibraryMetadata();
});

final batchedMediaProvider = Provider<AsyncValue<List<PhotoBatch>>>((ref) {
  final allMediaAsync = ref.watch(allMediaProvider);
  final groupingMode = ref.watch(groupingModeProvider);
  final reviewedIds = ref.watch(reviewedIdsProvider);

  return allMediaAsync.whenData((assets) {
    final grouped = <String, List<SwipifyPhoto>>{};
    for (final asset in assets) {
      final date = asset.creationTime;
      final key = groupingMode == GroupingMode.month
          ? _formatMonth(date)
          : _formatDate(date);
      grouped.putIfAbsent(key, () => []).add(asset);
    }

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
  final List<SwipifyPhoto> remainingAssets;
  final List<SwipifyPhoto> keepQueue;
  final List<SwipifyPhoto> deleteQueue;
  final bool isCommitted;

  SwipeSessionState({
    required this.remainingAssets,
    this.keepQueue = const [],
    this.deleteQueue = const [],
    this.isCommitted = false,
  });

  SwipeSessionState copyWith({
    List<SwipifyPhoto>? remainingAssets,
    List<SwipifyPhoto>? keepQueue,
    List<SwipifyPhoto>? deleteQueue,
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

  void init(List<SwipifyPhoto> assets) {
    if (state.remainingAssets.isEmpty && state.keepQueue.isEmpty && state.deleteQueue.isEmpty) {
      state = SwipeSessionState(remainingAssets: List.from(assets));
    }
  }

  void keepItem(SwipifyPhoto item) {
    if (!state.remainingAssets.contains(item)) return;

    final nextRemaining = List<SwipifyPhoto>.from(state.remainingAssets)
      ..remove(item);
    final nextKeep = List<SwipifyPhoto>.from(state.keepQueue)..add(item);
    state = state.copyWith(remainingAssets: nextRemaining, keepQueue: nextKeep);
  }

  void deleteItem(SwipifyPhoto item) {
    if (!state.remainingAssets.contains(item)) return;

    final nextRemaining = List<SwipifyPhoto>.from(state.remainingAssets)
      ..remove(item);
    final nextDelete = List<SwipifyPhoto>.from(state.deleteQueue)..add(item);
    state = state.copyWith(remainingAssets: nextRemaining, deleteQueue: nextDelete);
  }

  Future<void> commitSession() async {
    if (state.isCommitted) return;
    
    final keepIds = state.keepQueue.map((e) => e.id).toList();
    final deleteIds = state.deleteQueue.map((e) => e.id).toList();

    ref.read(reviewedIdsProvider.notifier).addIds(keepIds);

    if (deleteIds.isNotEmpty) {
      try {
        final success = await NativeGalleryHelper.deletePhotos(deleteIds);
        if (success) {
          ref.read(reviewedIdsProvider.notifier).addIds(deleteIds);
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
