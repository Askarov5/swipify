import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A bulletproof permission helper that uses a custom native MethodChannel
/// on both iOS and macOS to request photo library permissions. This bypasses
/// photo_manager's broken method channel (incompatible with Flutter 3.41's
/// FlutterImplicitEngineDelegate on iOS and merged-thread mode on macOS 26).
class PhotoPermissionHelper {
  static const _channel = MethodChannel('com.swipify/photo_permission');

  /// Request photo library permission.
  /// Returns: authorized, limited, denied, restricted, notDetermined
  static Future<String> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<String>('requestPermission');
      return result ?? 'notDetermined';
    } catch (e) {
      debugPrint('Permission request error: $e');
      return 'notDetermined';
    }
  }

  /// Check current permission status without prompting.
  static Future<String> checkPermission() async {
    try {
      final result = await _channel.invokeMethod<String>('checkPermission');
      return result ?? 'notDetermined';
    } catch (e) {
      debugPrint('Check permission error: $e');
      return 'notDetermined';
    }
  }

  /// Open the system Settings app to the photo privacy page.
  /// On iOS: opens Settings > Privacy > Photos for this app
  /// On macOS: opens System Settings > Privacy & Security > Photos
  static Future<bool> openSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openSettings');
      return result ?? false;
    } catch (e) {
      debugPrint('Open settings error: $e');
      return false;
    }
  }

  /// Returns true if the user has granted full or limited access.
  static bool isGranted(String status) {
    return status == 'authorized' || status == 'limited';
  }

  /// Returns true if the user has explicitly denied access.
  static bool isDenied(String status) {
    return status == 'denied' || status == 'restricted';
  }
}
