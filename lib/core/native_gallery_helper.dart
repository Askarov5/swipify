import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void _logGalleryDebug(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

/// Lightweight representation of a photo provided natively.
class SwipifyPhoto {
  final String id;
  final DateTime creationTime;
  final bool isVideo;

  SwipifyPhoto({
    required this.id, 
    required this.creationTime,
    required this.isVideo,
  });

  /// Dynamically gets the thumbnail by calling the native channel
  Future<Uint8List?> get thumbnailData async {
    return await NativeGalleryHelper.fetchThumbnail(id, width: 300, height: 300);
  }

  /// Dynamically gets the high resolution file bytes
  Future<Uint8List?> get fileData async {
    return await NativeGalleryHelper.fetchFile(id);
  }
}

/// A bulletproof custom service replacing photo_manager.
/// Manages permissions, metadata extraction, and deletions directly via iOS/macOS PHPhotoLibrary.
class NativeGalleryHelper {
  static const _channel = MethodChannel('com.swipify/gallery');

  /// Coalesces concurrent [fetchFilePath] calls for the same asset so native export temp files are not clobbered.
  static final Map<String, Future<String?>> _filePathInflight = {};

  /// Fetches lightweight metadata shell for all images natively
  static Future<List<SwipifyPhoto>> fetchLibraryMetadata() async {
    try {
      final List<dynamic>? results = await _channel.invokeMethod('fetchLibraryMetadata');
      if (results == null) return [];
      
      return results.map((e) {
        final map = e as Map<dynamic, dynamic>;
        return SwipifyPhoto(
          id: map['id'] as String,
          creationTime: DateTime.fromMillisecondsSinceEpoch(map['creationTime'] as int),
          isVideo: map['isVideo'] as bool? ?? false,
        );
      }).toList();
    } catch (e) {
      _logGalleryDebug('Metadata fetch error: $e');
      return [];
    }
  }

  /// Fetch compressed thumbnail byte data specifically for Grid rendering
  static Future<Uint8List?> fetchThumbnail(String id, {double width = 300, double height = 300}) async {
    try {
      return await _channel.invokeMethod<Uint8List>('fetchThumbnail', {
        'id': id,
        'width': width,
        'height': height,
      });
    } catch (e) {
      _logGalleryDebug('Thumbnail fetch error: $e');
      return null;
    }
  }

  /// Fetch high quality byte data for Swipe Screen (typically meant for photos)
  static Future<Uint8List?> fetchFile(String id) async {
    try {
      return await _channel.invokeMethod<Uint8List>('fetchFile', {'id': id});
    } catch (e) {
      _logGalleryDebug('File fetch error: $e');
      return null;
    }
  }

  /// Returns a path under app temp suitable for [VideoPlayerController.file].
  /// Use [forceRefresh] on user retry so native always materializes a new file (avoids stale paths).
  static Future<String?> fetchFilePath(String id, {bool forceRefresh = false}) {
    if (forceRefresh) {
      return _fetchFilePathOnce(id);
    }
    return _filePathInflight.putIfAbsent(id, () {
      return _fetchFilePathOnce(id).whenComplete(() {
        _filePathInflight.remove(id);
      });
    });
  }

  static Future<String?> _fetchFilePathOnce(String id) async {
    try {
      final Object? raw = await _channel.invokeMethod('fetchFilePath', {'id': id});
      if (raw is String && raw.isNotEmpty) return raw;
      return null;
    } catch (e) {
      _logGalleryDebug('File Path fetch error: $e');
      return null;
    }
  }

  /// Deletes a list of photos using native prompt APIs
  static Future<bool> deletePhotos(List<String> ids) async {
    try {
      final result = await _channel.invokeMethod<bool>('deletePhotos', {'ids': ids});
      return result ?? false;
    } catch (e) {
      _logGalleryDebug('Delete error: $e');
      return false;
    }
  }

  // --- PERMISSIONS ENDPOINT ---

  static Future<String> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<String>('requestPermission');
      return result ?? 'notDetermined';
    } catch (e) {
      _logGalleryDebug('Permission request error: $e');
      return 'notDetermined';
    }
  }

  static Future<String> checkPermission() async {
    try {
      final result = await _channel.invokeMethod<String>('checkPermission');
      return result ?? 'notDetermined';
    } catch (e) {
      _logGalleryDebug('Check permission error: $e');
      return 'notDetermined';
    }
  }

  static Future<bool> openSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openSettings');
      return result ?? false;
    } catch (e) {
      _logGalleryDebug('Open settings error: $e');
      return false;
    }
  }

  static bool isGranted(String status) => status == 'authorized' || status == 'limited';
  static bool isDenied(String status) => status == 'denied' || status == 'restricted';
}
