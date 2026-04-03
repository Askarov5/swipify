import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../swipe_deck/swipe_screen.dart';
import '../dashboard/stats_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/photo_provider.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/native_gallery_helper.dart';

class LibraryReviewScreen extends ConsumerWidget {
  const LibraryReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: SwipifyTheme.surface.withValues(alpha: 0.8),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            const Icon(Icons.menu, color: SwipifyTheme.primary),
            const SizedBox(width: 16),
            Text(
              'DIGITAL CURATOR',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 14,
                    color: SwipifyTheme.primary,
                    letterSpacing: 2.0,
                  ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: CircleAvatar(
              backgroundColor: SwipifyTheme.surfaceContainerHighest,
              radius: 16,
              child: Icon(Icons.person,
                  size: 16, color: SwipifyTheme.onSurfaceVariant),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: ref.watch(photoPermissionProvider).when(
              data: (permission) {
                if (!NativeGalleryHelper.isGranted(permission)) {
                  return _buildPermissionRequired(context);
                }
                return _buildLibraryContent(context, ref);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) =>
                  Center(child: Text('Error checking permissions: $e')),
            ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildPermissionRequired(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: SwipifyTheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.no_photography,
                  size: 64, color: SwipifyTheme.primary),
            ),
            const SizedBox(height: 32),
            Text(
              'No Access to Photos',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: SwipifyTheme.onSurface,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Swipify is completely private and runs 100% on your device. We need access to your photo library to help you declutter.\n\nWithout access, this app cannot function.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SwipifyTheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SwipifyTheme.primary,
                  foregroundColor: SwipifyTheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  elevation: 8,
                ),
                onPressed: () => NativeGalleryHelper.openSettings(),
                icon: const Icon(Icons.settings),
                label: const Text(
                  'Open Settings',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryContent(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Review Library',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontSize: 28),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select a batch to begin your curation session.',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(fontSize: 12),
                  ),
                ],
              ),
              _buildSegmentedControl(context, ref),
            ],
          ),
          const SizedBox(height: 24),

          // Filter Tabs
          _buildFilterTabs(context, ref),
          const SizedBox(height: 24),

          // List Items
          ref.watch(batchedMediaProvider).when(
                data: (batches) {
                  if (batches.isEmpty) {
                    return const Center(
                        child: Padding(
                      padding: EdgeInsets.only(top: 48.0),
                      child: Text("No photos found or all are reviewed."),
                    ));
                  }
                  return Column(
                    children: batches
                        .map((batch) => _buildBatchCard(context, ref, batch))
                        .toList(),
                  );
                },
                loading: () => const Center(
                    child: Padding(
                  padding: EdgeInsets.only(top: 48.0),
                  child: CircularProgressIndicator(),
                )),
                error: (e, st) =>
                    Center(child: Text('Error loading batches: $e')),
              ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(groupingModeProvider);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SwipifyTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => ref.read(groupingModeProvider.notifier).updateMode(GroupingMode.month),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: mode == GroupingMode.month
                    ? SwipifyTheme.surfaceContainerHighest
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Month',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: mode == GroupingMode.month
                          ? SwipifyTheme.primary
                          : SwipifyTheme.onSurfaceVariant,
                      fontWeight: mode == GroupingMode.month
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => ref.read(groupingModeProvider.notifier).updateMode(GroupingMode.date),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: mode == GroupingMode.date
                    ? SwipifyTheme.surfaceContainerHighest
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Date',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: mode == GroupingMode.date
                          ? SwipifyTheme.primary
                          : SwipifyTheme.onSurfaceVariant,
                      fontWeight: mode == GroupingMode.date
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(BuildContext context, WidgetRef ref) {
    final currentFilter = ref.watch(mediaFilterProvider);

    Widget buildTab(String label, MediaTypeFilter filter) {
      final isActive = currentFilter == filter;
      return Expanded(
        child: GestureDetector(
          onTap: () => ref.read(mediaFilterProvider.notifier).updateFilter(filter),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? SwipifyTheme.surfaceContainerHigh
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isActive
                        ? SwipifyTheme.primary
                        : SwipifyTheme.onSurfaceVariant,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SwipifyTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          buildTab('All', MediaTypeFilter.all),
          buildTab('Photos', MediaTypeFilter.photos),
          buildTab('Videos', MediaTypeFilter.videos),
        ],
      ),
    );
  }

  Widget _buildBatchCard(
      BuildContext context, WidgetRef ref, PhotoBatch batch) {
    final actionable = !batch.isFullyReviewed;
    final title = batch.title;
    final subtitle = '${batch.reviewedCount} / ${batch.totalCount} Reviewed';
    final progress =
        batch.totalCount == 0 ? 0.0 : batch.reviewedCount / batch.totalCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: actionable
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => SwipeScreen(batch: batch)),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SwipifyTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.transparent),
          ),
          child: Row(
            children: [
              Hero(
                tag: 'hero_collage_$title',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 64,
                    height: 64,
                    color: SwipifyTheme.surfaceContainerHighest,
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      children: List.generate(
                        4,
                        (index) => Container(
                          color: actionable
                              ? SwipifyTheme.primaryContainer
                                  .withValues(alpha: 0.5)
                              : Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: SwipifyTheme.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (!actionable)
                          const Padding(
                            padding: EdgeInsets.only(right: 4.0),
                            child: Icon(Icons.check_circle,
                                size: 14, color: SwipifyTheme.primary),
                          ),
                        Text(
                          actionable ? subtitle : 'Cleaned',
                          style: TextStyle(
                            fontSize: 12,
                            color: actionable
                                ? SwipifyTheme.onSurfaceVariant
                                : SwipifyTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    if (actionable && batch.reviewedCount > 0) ...[
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: SwipifyTheme.surfaceContainerHighest,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            SwipifyTheme.primary),
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  ],
                ),
              ),
              actionable
                  ? ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SwipifyTheme.surfaceContainerHighest,
                        foregroundColor: SwipifyTheme.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => SwipeScreen(batch: batch)),
                        );
                      },
                      icon: const Text('Clean',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      label: const Icon(Icons.auto_awesome, size: 16),
                    )
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SwipifyTheme.surfaceContainerHighest,
                        foregroundColor: SwipifyTheme.onSurfaceVariant,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                      onPressed: () {
                        ref
                            .read(reviewedIdsProvider.notifier)
                            .removeIds(batch.allAssetIds);
                      },
                      icon: const Text('Re-scan',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      label: const Icon(Icons.refresh, size: 16),
                    ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right,
                  color: SwipifyTheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: SwipifyTheme.surface,
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.only(bottom: 24, top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(Icons.image, 'Photos', true, null),
          _buildNavItem(Icons.mail, 'Email', false, null),
          _buildNavItem(Icons.insert_chart, 'Stats', false, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const StatsScreen()),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      IconData icon, String label, bool isActive, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color:
              isActive ? SwipifyTheme.surfaceContainerHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isActive
                    ? SwipifyTheme.primary
                    : SwipifyTheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isActive
                    ? SwipifyTheme.primary
                    : SwipifyTheme.primary.withValues(alpha: 0.4),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
