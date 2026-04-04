import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mocks the `com.swipify/gallery` [MethodChannel] so tests run without native code.
///
/// Configure responses, call [register] before invoking [NativeGalleryHelper], and
/// [unregister] in tearDown to avoid leaking handlers across tests.
class GalleryChannelMock {
  GalleryChannelMock({
    this.checkPermissionResponse = 'authorized',
    this.requestPermissionResponse = 'authorized',
    this.openSettingsResponse = true,
    this.deletePhotosResponse = true,
    this.fetchLibraryMetadataResponse = const <Map<String, Object>>[],
    this.thumbnailBytes,
    this.fileBytes,
    this.filePath,
  });

  /// Values match the strings produced by native code for [NativeGalleryHelper].
  String checkPermissionResponse;
  String requestPermissionResponse;
  bool openSettingsResponse;
  bool deletePhotosResponse;

  /// Each map: `id` (String), `creationTime` (int ms epoch), `isVideo` (bool).
  List<Map<String, Object>> fetchLibraryMetadataResponse;

  Uint8List? thumbnailBytes;
  Uint8List? fileBytes;
  String? filePath;

  static const MethodChannel _channel = MethodChannel('com.swipify/gallery');

  void register() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, _handle);
  }

  void unregister() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }

  Future<Object?>? _handle(MethodCall call) async {
    switch (call.method) {
      case 'checkPermission':
        return checkPermissionResponse;
      case 'requestPermission':
        return requestPermissionResponse;
      case 'openSettings':
        return openSettingsResponse;
      case 'deletePhotos':
        return deletePhotosResponse;
      case 'fetchLibraryMetadata':
        return fetchLibraryMetadataResponse;
      case 'fetchThumbnail':
        return thumbnailBytes;
      case 'fetchFile':
        return fileBytes;
      case 'fetchFilePath':
        return filePath;
      default:
        return null;
    }
  }
}
