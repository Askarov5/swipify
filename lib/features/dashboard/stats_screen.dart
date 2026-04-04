import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/impact_stats_provider.dart';
import '../../core/providers/photo_provider.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/theme.dart';

/// When [embedded] is true, only scrollable content is returned (for use inside a parent shell with its own [Scaffold]/[AppBar]).
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key, this.embedded = false});

  final bool embedded;

  static const String _title = 'Swipify Impacts';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final impact = ref.watch(impactStatsProvider);
    final reviewedIds = ref.watch(reviewedIdsProvider);
    final allMediaAsync = ref.watch(allMediaProvider);
    final batchesAsync = ref.watch(batchedMediaProvider);

    final libraryProgress = allMediaAsync.maybeWhen(
      data: (list) {
        final total = list.length;
        if (total == 0) return 0.0;
        final r = reviewedIds.length;
        return (r / total).clamp(0.0, 1.0);
      },
      orElse: () => 0.0,
    );

    final batchesCleaned = batchesAsync.maybeWhen(
      data: (batches) => batches.where((b) => b.isFullyReviewed).length,
      orElse: () => 0,
    );

    final removed = impact.itemsRemovedTotal;
    final scrollable = SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: CircularProgressIndicator(
                    value: libraryProgress,
                    strokeWidth: 8,
                    backgroundColor: SwipifyTheme.surfaceContainerHighest,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      SwipifyTheme.primary,
                    ),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$removed',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontSize: 64,
                            color: SwipifyTheme.primary,
                          ),
                    ),
                    Text(
                      'ITEMS REMOVED',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard(
                context,
                'Photos Deleted',
                '${impact.photosDeletedTotal}',
                SwipifyTheme.secondary,
              ),
              _buildStatCard(
                context,
                'Videos Deleted',
                '${impact.videosDeletedTotal}',
                SwipifyTheme.secondary,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard(
                context,
                'Batches Cleaned',
                '$batchesCleaned',
                SwipifyTheme.primary,
              ),
              _buildStatCard(
                context,
                'Commits Done',
                '${impact.commitsCompletedTotal}',
                SwipifyTheme.primary,
              ),
            ],
          ),
        ],
      ),
    );

    if (embedded) {
      return scrollable;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _title,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(child: scrollable),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SwipifyTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontSize: 32, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style:
                Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
