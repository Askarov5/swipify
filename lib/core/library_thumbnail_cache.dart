import 'dart:typed_data';

import 'package:swipify/core/native_gallery_helper.dart';

/// In-memory thumbnail bytes for library batch previews, keyed by asset id.
///
/// Shares one [Future] per id so parallel requests (e.g. 2×2 grid) dedupe.
/// Callers typically request only the first four [SwipifyPhoto.id]s per batch
/// (`batch.assets.take(4)`), which updates as items are reviewed/removed.
final class LibraryThumbnailCache {
  LibraryThumbnailCache._();

  static final Map<String, Uint8List> _bytes = {};
  static final Map<String, Future<Uint8List?>> _futures = {};

  static Future<Uint8List?> getOrFetch(
    String id, {
    double width = 128,
    double height = 128,
  }) {
    return _futures.putIfAbsent(id, () async {
      final cached = _bytes[id];
      if (cached != null) {
        return cached;
      }
      final data =
          await NativeGalleryHelper.fetchThumbnail(id, width: width, height: height);
      if (data != null) {
        _bytes[id] = data;
      }
      return data;
    });
  }

  /// Optional: release memory (e.g. on logout); next load will refetch.
  static void clear() {
    _bytes.clear();
    _futures.clear();
  }
}
