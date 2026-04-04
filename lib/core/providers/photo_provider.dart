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

/// One swipe decision in chronological order (LIFO undo).
class SwipeDecision {
  final String id;
  final bool isDelete;

  const SwipeDecision({required this.id, required this.isDelete});

  Map<String, dynamic> toJson() => {'id': id, 'del': isDelete};

  factory SwipeDecision.fromJson(Map<String, dynamic> m) {
    return SwipeDecision(
      id: m['id'] as String,
      isDelete: m['del'] as bool,
    );
  }
}

class SwipeSessionState {
  /// Immutable snapshot order for this session; front card is [remainingAssets.last].
  final List<SwipifyPhoto> sessionBatchOrder;

  /// Chronological decisions; length is resume depth (prefix model).
  final List<SwipeDecision> decisions;

  final bool isCommitted;

  /// Batch key from [PhotoBatch.id] while this session is active.
  final String? activeBatchId;

  /// True once [SwipeSessionNotifier.commitSession] has written keep IDs to [reviewedIdsProvider]
  /// (may be true while deletes are still pending or failed).
  final bool keepsPersistedToLibrary;

  SwipeSessionState({
    this.sessionBatchOrder = const [],
    this.decisions = const [],
    this.isCommitted = false,
    this.activeBatchId,
    this.keepsPersistedToLibrary = false,
  });

  /// Not-yet-reviewed slice: prefix of [sessionBatchOrder] of length `L - decisions.length`.
  List<SwipifyPhoto> get remainingAssets {
    final L = sessionBatchOrder.length;
    final n = decisions.length;
    if (n >= L) return [];
    return sessionBatchOrder.sublist(0, L - n);
  }

  int get keepCount => decisions.where((d) => !d.isDelete).length;

  int get deleteCount => decisions.where((d) => d.isDelete).length;

  SwipeSessionState copyWith({
    List<SwipifyPhoto>? sessionBatchOrder,
    List<SwipeDecision>? decisions,
    bool? isCommitted,
    String? activeBatchId,
    bool clearActiveBatchId = false,
    bool? keepsPersistedToLibrary,
  }) {
    return SwipeSessionState(
      sessionBatchOrder: sessionBatchOrder ?? this.sessionBatchOrder,
      decisions: decisions ?? this.decisions,
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
      'swipify_swipe_draft_${batchId.hashCode}';

  @override
  SwipeSessionState build() {
    return SwipeSessionState();
  }

  void init(List<SwipifyPhoto> assets, String batchId) {
    state = SwipeSessionState(
      sessionBatchOrder: List.from(assets),
      activeBatchId: batchId,
    );
  }

  /// Restore persisted draft for this batch if valid (call after [init]).
  void tryRestoreDraft(PhotoBatch batch, List<SwipifyPhoto> library) {
    if (state.activeBatchId != batch.id) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final key = _draftPrefsKey(batch.id);

    final raw = prefs.getString(key);
    if (raw == null) return;

    Map<String, dynamic> map;
    try {
      map = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      prefs.remove(key);
      return;
    }

    final oIds = List<String>.from(map['o'] as List? ?? const []);
    final decRaw = map['dec'] as List? ?? const [];
    final kp = map['kp'] as bool? ?? false;

    final batchSet = batch.allAssetIds.toSet();
    if (oIds.isEmpty) return;
    if (!oIds.every(batchSet.contains)) {
      prefs.remove(key);
      return;
    }

    final lookup = {for (final p in library) p.id: p};
    List<SwipifyPhoto>? resolveOrder(List<String> ids) {
      final out = <SwipifyPhoto>[];
      for (final id in ids) {
        final p = lookup[id];
        if (p == null) {
          prefs.remove(key);
          return null;
        }
        out.add(p);
      }
      return out;
    }

    final order = resolveOrder(oIds);
    if (order == null) return;

    final decisions = <SwipeDecision>[];
    for (final e in decRaw) {
      if (e is! Map) {
        prefs.remove(key);
        return;
      }
      try {
        decisions.add(
          SwipeDecision.fromJson(Map<String, dynamic>.from(e)),
        );
      } catch (_) {
        prefs.remove(key);
        return;
      }
    }

    final orderIds = oIds.toSet();
    for (final d in decisions) {
      if (!orderIds.contains(d.id)) {
        prefs.remove(key);
        return;
      }
    }

    if (decisions.length > order.length) {
      prefs.remove(key);
      return;
    }

    for (var i = 0; i < decisions.length; i++) {
      final expectedId = order[order.length - 1 - i].id;
      if (decisions[i].id != expectedId) {
        prefs.remove(key);
        return;
      }
    }

    state = state.copyWith(
      sessionBatchOrder: order,
      decisions: decisions,
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
      'o': state.sessionBatchOrder.map((e) => e.id).toList(),
      'dec': state.decisions.map((e) => e.toJson()).toList(),
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
    state = SwipeSessionState();
  }

  /// Records a swipe on the current front card ([remainingAssets.last]).
  void recordDecision(SwipifyPhoto item, {required bool delete}) {
    final remaining = state.remainingAssets;
    if (remaining.isEmpty) return;
    if (remaining.last.id != item.id) return;

    state = state.copyWith(
      decisions: [...state.decisions, SwipeDecision(id: item.id, isDelete: delete)],
    );
    _persistDraft();
  }

  void undoLastDecision() {
    if (state.isCommitted || state.decisions.isEmpty) return;
    state = state.copyWith(
      decisions: state.decisions.sublist(0, state.decisions.length - 1),
    );
    _persistDraft();
  }

  /// Persists keeps, then deletes (if any). Returns `true` when fully done.
  /// On delete failure, keeps stay saved; [keepsPersistedToLibrary] is true;
  /// [isCommitted] stays false so the user can call again to retry deletes.
  Future<bool> commitSession() async {
    if (state.isCommitted) return true;

    final keepIds = <String>[];
    final deleteIds = <String>[];
    for (final d in state.decisions) {
      if (d.isDelete) {
        deleteIds.add(d.id);
      } else {
        keepIds.add(d.id);
      }
    }

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

    final photoById = {for (final p in state.sessionBatchOrder) p.id: p};
    final deleteQueueSnapshot = deleteIds
        .map((id) => photoById[id])
        .whereType<SwipifyPhoto>()
        .toList();

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
