import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../swipe_deck/swipe_screen.dart';
import '../dashboard/stats_screen.dart';
import '../email/email_coming_soon_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/photo_provider.dart';
import '../../core/providers/preferences_provider.dart';
import '../../core/library_thumbnail_cache.dart';
import '../../core/native_gallery_helper.dart';

enum _MainNavTab { photos, email, stats }

class LibraryReviewScreen extends ConsumerStatefulWidget {
  const LibraryReviewScreen({super.key});

  @override
  ConsumerState<LibraryReviewScreen> createState() =>
      _LibraryReviewScreenState();
}

class _LibraryReviewScreenState extends ConsumerState<LibraryReviewScreen>
    with WidgetsBindingObserver {
  _MainNavTab _selectedTab = _MainNavTab.photos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      ref.read(photoPermissionProvider.notifier).syncFromSystem();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: SwipifyTheme.surface.withValues(alpha: 0.8),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: _selectedTab == _MainNavTab.photos
            ? Text(
                'Swipify Photos & Videos',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: SwipifyTheme.primary,
                    ),
              )
            : Text(
                _selectedTab == _MainNavTab.email
                    ? 'Email Cleanup'
                    : 'Swipify Impacts',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedTab.index,
          sizing: StackFit.expand,
          children: [
            _buildPhotosTab(context, ref),
            const EmailComingSoonScreen(embedded: true),
            const StatsScreen(embedded: true),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildPhotosTab(BuildContext context, WidgetRef ref) {
    return ref.watch(photoPermissionProvider).when(
          data: (permission) {
            if (!NativeGalleryHelper.isGranted(permission)) {
              return _buildPermissionRequired(context, ref, permission);
            }
            return _buildLibraryContent(context, ref);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) =>
              Center(child: Text('Error checking permissions: $e')),
        );
  }

  Widget _buildPermissionRequired(
      BuildContext context, WidgetRef ref, String permission) {
    final needsSettings = NativeGalleryHelper.isDenied(permission) ||
        permission == 'restricted';
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
              needsSettings
                  ? 'Photo access was denied or restricted. Enable full access to your library in Settings, then tap Check access below.'
                  : 'Swipify is completely private and runs on your device. Allow access to your photo library so you can review and declutter.\n\nWithout access, this screen stays empty.',
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
                onPressed: () => ref
                    .read(photoPermissionProvider.notifier)
                    .requestFullAccess(),
                icon: Icon(needsSettings ? Icons.settings : Icons.photo_library),
                label: Text(
                  needsSettings ? 'Open Settings' : 'Allow access to photos',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            if (needsSettings) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref
                    .read(photoPermissionProvider.notifier)
                    .syncFromSystem(),
                child: const Text(
                  'Check access',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _onSelectTab(_MainNavTab tab) {
    if (_selectedTab == tab) return;
    setState(() => _selectedTab = tab);
  }

  Widget _buildLibraryContent(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(photoPermissionProvider.notifier).syncFromSystem();
        ref.invalidate(allMediaProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                      final filter = ref.watch(mediaFilterProvider);
                      return _buildLibraryEmptyState(context, filter);
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
      ),
    );
  }

  Widget _buildLibraryEmptyState(
      BuildContext context, MediaTypeFilter filter) {
    final (IconData icon, String title, String body) = switch (filter) {
      MediaTypeFilter.all => (
          Icons.photo_library_outlined,
          'No photos or videos',
          'Your library has no images or videos we can show, or we could not load them. Pull down to refresh.',
        ),
      MediaTypeFilter.photos => (
          Icons.image_not_supported_outlined,
          'No photos for this filter',
          'There are no photos in your library. Try the All or Videos tab, or pull down to refresh.',
        ),
      MediaTypeFilter.videos => (
          Icons.videocam_off_outlined,
          'No videos for this filter',
          'There are no videos in your library. Try the All or Photos tab, or pull down to refresh.',
        ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 48.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: SwipifyTheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: SwipifyTheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: SwipifyTheme.onSurface,
                  ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: SwipifyTheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
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
    final prefs = ref.watch(sharedPreferencesProvider);
    final draftRaw = prefs.getString(swipeSessionDraftPrefsKey(batch.id));
    final hasSwipeDraft = draftRaw != null && draftRaw.isNotEmpty;

    final actionable = !batch.isFullyReviewed;
    final showContinue = actionable && hasSwipeDraft;
    final title = batch.title;
    final subtitle = '${batch.reviewedCount} / ${batch.totalCount} Reviewed';
    final progress =
        batch.totalCount == 0 ? 0.0 : batch.reviewedCount / batch.totalCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: actionable
            ? () {
                SwipeScreen.open(context, batch);
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
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: ColoredBox(
                      color: SwipifyTheme.surfaceContainerHighest,
                      child: _BatchThumbnailCollage(
                        candidates: batch.assets.take(4).toList(),
                        actionable: actionable,
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
                    if (showContinue) ...[
                      const SizedBox(height: 4),
                      Text(
                        'In progress',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: SwipifyTheme.primary,
                        ),
                      ),
                    ],
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
                        SwipeScreen.open(context, batch);
                      },
                      icon: Text(
                        showContinue ? 'Continue' : 'Clean',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      label: Icon(
                        showContinue ? Icons.play_arrow : Icons.auto_awesome,
                        size: 16,
                      ),
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
          _buildNavItem(
            Icons.image,
            'Photos',
            _selectedTab == _MainNavTab.photos,
            () => _onSelectTab(_MainNavTab.photos),
          ),
          _buildNavItem(
            Icons.mail,
            'Email',
            _selectedTab == _MainNavTab.email,
            () => _onSelectTab(_MainNavTab.email),
          ),
          _buildNavItem(
            Icons.insert_chart,
            'Stats',
            _selectedTab == _MainNavTab.stats,
            () => _onSelectTab(_MainNavTab.stats),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return Semantics(
      button: true,
      label: label,
      selected: isActive,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? SwipifyTheme.surfaceContainerHigh
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive
                    ? SwipifyTheme.primary
                    : SwipifyTheme.primary.withValues(alpha: 0.4),
              ),
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
      ),
    );
  }
}

/// 2×2 preview grid for a batch row; loads native thumbnails for up to four assets.
class _BatchThumbnailCollage extends StatelessWidget {
  const _BatchThumbnailCollage({
    required this.candidates,
    required this.actionable,
  });

  final List<SwipifyPhoto> candidates;
  final bool actionable;

  Color get _placeholderColor => actionable
      ? SwipifyTheme.primaryContainer.withValues(alpha: 0.5)
      : Colors.grey.withValues(alpha: 0.2);

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      children: List.generate(4, _buildCell),
    );
  }

  Widget _buildCell(int index) {
    if (index >= candidates.length) {
      return ColoredBox(color: _placeholderColor);
    }
    final photo = candidates[index];
    return FutureBuilder<Uint8List?>(
      future: LibraryThumbnailCache.getOrFetch(photo.id, width: 128, height: 128),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ColoredBox(
            color: SwipifyTheme.surfaceContainerHighest,
            child: const Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ),
          );
        }
        final data = snapshot.data;
        if (snapshot.hasError || data == null) {
          return ColoredBox(color: _placeholderColor);
        }
        return Image.memory(
          data,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      },
    );
  }
}
