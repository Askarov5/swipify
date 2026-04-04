import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preferences_provider.dart';

/// Persisted aggregates for the stats / impacts screen.
class ImpactStats {
  const ImpactStats({
    required this.photosDeletedTotal,
    required this.videosDeletedTotal,
    required this.commitsCompletedTotal,
  });

  final int photosDeletedTotal;
  final int videosDeletedTotal;
  final int commitsCompletedTotal;

  int get itemsRemovedTotal => photosDeletedTotal + videosDeletedTotal;
}

class ImpactStatsNotifier extends Notifier<ImpactStats> {
  static const _kPhotos = 'impact_stats_photos_deleted_v1';
  static const _kVideos = 'impact_stats_videos_deleted_v1';
  static const _kCommits = 'impact_stats_commits_completed_v1';

  @override
  ImpactStats build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return ImpactStats(
      photosDeletedTotal: prefs.getInt(_kPhotos) ?? 0,
      videosDeletedTotal: prefs.getInt(_kVideos) ?? 0,
      commitsCompletedTotal: prefs.getInt(_kCommits) ?? 0,
    );
  }

  void recordSuccessfulDeletes({required int photos, required int videos}) {
    if (photos == 0 && videos == 0) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final nextP = state.photosDeletedTotal + photos;
    final nextV = state.videosDeletedTotal + videos;
    prefs.setInt(_kPhotos, nextP);
    prefs.setInt(_kVideos, nextV);
    state = ImpactStats(
      photosDeletedTotal: nextP,
      videosDeletedTotal: nextV,
      commitsCompletedTotal: state.commitsCompletedTotal,
    );
  }

  void recordCommitCompleted() {
    final prefs = ref.read(sharedPreferencesProvider);
    final next = state.commitsCompletedTotal + 1;
    prefs.setInt(_kCommits, next);
    state = ImpactStats(
      photosDeletedTotal: state.photosDeletedTotal,
      videosDeletedTotal: state.videosDeletedTotal,
      commitsCompletedTotal: next,
    );
  }
}

final impactStatsProvider =
    NotifierProvider<ImpactStatsNotifier, ImpactStats>(ImpactStatsNotifier.new);
