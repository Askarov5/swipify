import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swipify/core/native_gallery_helper.dart';
import 'package:swipify/core/providers/impact_stats_provider.dart';
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

  final metadata = await NativeGalleryHelper.fetchLibraryMetadata();
  final filter = ref.watch(mediaFilterProvider);
  
  if (filter == MediaTypeFilter.photos) {
    return metadata.where((e) => !e.isVideo).toList();
  } else if (filter == MediaTypeFilter.videos) {
    return metadata.where((e) => e.isVideo).toList();
  }
  return metadata;
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

  /// Batch key from [PhotoBatch.id] while this session is active.
  final String? activeBatchId;

  /// True once [SwipeSessionNotifier.commitSession] has written keep IDs to [reviewedIdsProvider]
  /// (may be true while deletes are still pending or failed).
  final bool keepsPersistedToLibrary;

  SwipeSessionState({
    required this.remainingAssets,
    this.keepQueue = const [],
    this.deleteQueue = const [],
    this.isCommitted = false,
    this.activeBatchId,
    this.keepsPersistedToLibrary = false,
  });

  SwipeSessionState copyWith({
    List<SwipifyPhoto>? remainingAssets,
    List<SwipifyPhoto>? keepQueue,
    List<SwipifyPhoto>? deleteQueue,
    bool? isCommitted,
    String? activeBatchId,
    bool clearActiveBatchId = false,
    bool? keepsPersistedToLibrary,
  }) {
    return SwipeSessionState(
      remainingAssets: remainingAssets ?? this.remainingAssets,
      keepQueue: keepQueue ?? this.keepQueue,
      deleteQueue: deleteQueue ?? this.deleteQueue,
      isCommitted: isCommitted ?? this.isCommitted,
      activeBatchId:
          clearActiveBatchId ? null : (activeBatchId ?? this.activeBatchId),
      keepsPersistedToLibrary:
          keepsPersistedToLibrary ?? this.keepsPersistedToLibrary,
    );
  }
}

class SwipeSessionNotifier extends Notifier<SwipeSessionState> {
  static String _draftPrefsKey(String batchId) =>
      'swipify_swipe_draft_v1_${batchId.hashCode}';

  @override
  SwipeSessionState build() {
    return SwipeSessionState(remainingAssets: []);
  }

  void init(List<SwipifyPhoto> assets, String batchId) {
    state = SwipeSessionState(
      remainingAssets: List.from(assets),
      activeBatchId: batchId,
    );
  }

  /// Restore persisted draft for this batch if valid (call after [init]).
  void tryRestoreDraft(PhotoBatch batch, List<SwipifyPhoto> library) {
    if (state.activeBatchId != batch.id) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(_draftPrefsKey(batch.id));
    if (raw == null) return;

    Map<String, dynamic> map;
    try {
      map = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      prefs.remove(_draftPrefsKey(batch.id));
      return;
    }

    final rIds = List<String>.from(map['r'] as List? ?? const []);
    final kIds = List<String>.from(map['k'] as List? ?? const []);
    final dIds = List<String>.from(map['d'] as List? ?? const []);
    final kp = map['kp'] as bool? ?? false;

    final batchSet = batch.allAssetIds.toSet();
    final allDraftIds = <String>{...rIds, ...kIds, ...dIds};
    if (allDraftIds.isEmpty) return;
    if (!allDraftIds.every(batchSet.contains)) {
      prefs.remove(_draftPrefsKey(batch.id));
      return;
    }

    final lookup = {for (final p in library) p.id: p};
    List<SwipifyPhoto>? resolve(List<String> ids) {
      final out = <SwipifyPhoto>[];
      for (final id in ids) {
        final p = lookup[id];
        if (p == null) {
          prefs.remove(_draftPrefsKey(batch.id));
          return null;
        }
        out.add(p);
      }
      return out;
    }

    final remaining = resolve(rIds);
    if (remaining == null) return;
    final keep = resolve(kIds);
    if (keep == null) return;
    final del = resolve(dIds);
    if (del == null) return;

    state = state.copyWith(
      remainingAssets: remaining,
      keepQueue: keep,
      deleteQueue: del,
      keepsPersistedToLibrary: kp,
      isCommitted: false,
    );
    _persistDraft();
  }

  void _persistDraft() {
    final batchId = state.activeBatchId;
    if (batchId == null) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final key = _draftPrefsKey(batchId);
    if (state.isCommitted) {
      prefs.remove(key);
      return;
    }
    final payload = jsonEncode({
      'r': state.remainingAssets.map((e) => e.id).toList(),
      'k': state.keepQueue.map((e) => e.id).toList(),
      'd': state.deleteQueue.map((e) => e.id).toList(),
      'kp': state.keepsPersistedToLibrary,
    });
    prefs.setString(key, payload);
  }

  /// Clears in-memory swipe queues (e.g. user left without saving).
  void discardSession() {
    final batchId = state.activeBatchId;
    if (batchId != null) {
      ref.read(sharedPreferencesProvider).remove(_draftPrefsKey(batchId));
    }
    state = SwipeSessionState(remainingAssets: []);
  }

  void keepItem(SwipifyPhoto item) {
    if (!state.remainingAssets.contains(item)) return;

    final nextRemaining = List<SwipifyPhoto>.from(state.remainingAssets)
      ..remove(item);
    final nextKeep = List<SwipifyPhoto>.from(state.keepQueue)..add(item);
    state = state.copyWith(remainingAssets: nextRemaining, keepQueue: nextKeep);
    _persistDraft();
  }

  void deleteItem(SwipifyPhoto item) {
    if (!state.remainingAssets.contains(item)) return;

    final nextRemaining = List<SwipifyPhoto>.from(state.remainingAssets)
      ..remove(item);
    final nextDelete = List<SwipifyPhoto>.from(state.deleteQueue)..add(item);
    state = state.copyWith(remainingAssets: nextRemaining, deleteQueue: nextDelete);
    _persistDraft();
  }

  /// Persists keeps, then deletes (if any). Returns `true` when fully done.
  /// On delete failure, keeps stay saved; [keepsPersistedToLibrary] is true;
  /// [isCommitted] stays false so the user can call again to retry deletes.
  Future<bool> commitSession() async {
    if (state.isCommitted) return true;

    final keepIds = state.keepQueue.map((e) => e.id).toList();
    final deleteIds = state.deleteQueue.map((e) => e.id).toList();

    if (!state.keepsPersistedToLibrary) {
      if (keepIds.isNotEmpty) {
        ref.read(reviewedIdsProvider.notifier).addIds(keepIds);
      }
      state = state.copyWith(keepsPersistedToLibrary: true);
      _persistDraft();
    }

    if (deleteIds.isEmpty) {
      state = state.copyWith(isCommitted: true);
      _persistDraft();
      ref.read(impactStatsProvider.notifier).recordCommitCompleted();
      return true;
    }

    final deleteQueueSnapshot = List<SwipifyPhoto>.from(state.deleteQueue);

    var deleteOk = false;
    try {
      deleteOk = await NativeGalleryHelper.deletePhotos(deleteIds);
    } catch (e) {
      debugPrint("Error deleting items: $e");
    }

    if (deleteOk) {
      final photoCount =
          deleteQueueSnapshot.where((e) => !e.isVideo).length;
      final videoCount = deleteQueueSnapshot.where((e) => e.isVideo).length;
      ref
          .read(impactStatsProvider.notifier)
          .recordSuccessfulDeletes(photos: photoCount, videos: videoCount);
      ref.read(reviewedIdsProvider.notifier).addIds(deleteIds);
      ref.invalidate(allMediaProvider);
      state = state.copyWith(isCommitted: true);
      _persistDraft();
      ref.read(impactStatsProvider.notifier).recordCommitCompleted();
      return true;
    }

    _persistDraft();
    return false;
  }
}

final swipeSessionNotifierProvider = NotifierProvider<SwipeSessionNotifier, SwipeSessionState>(
  SwipeSessionNotifier.new,
);
