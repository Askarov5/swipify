import Cocoa
import FlutterMacOS
import Photos

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

/// A lightweight native plugin to handle photo library permissions directly
/// via PHPhotoLibrary, bypassing photo_manager's method channel which has
/// compatibility issues on macOS 26 + Flutter 3.41.
class PhotoPermissionPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.swipify/photo_permission",
      binaryMessenger: registrar.messenger
    )
    let instance = PhotoPermissionPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestPermission":
      requestPhotoPermission(result: result)
    case "checkPermission":
      checkPhotoPermission(result: result)
    case "openSettings":
      openSettings(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestPhotoPermission(result: @escaping FlutterResult) {
    if #available(macOS 11, *) {
      PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
        DispatchQueue.main.async {
          result(self.statusToString(status))
        }
      }
    } else {
      // macOS 10.15 fallback — uses the older API without access level
      PHPhotoLibrary.requestAuthorization { status in
        DispatchQueue.main.async {
          result(self.statusToString(status))
        }
      }
    }
  }

  private func openSettings(result: @escaping FlutterResult) {
    // Open System Settings > Privacy & Security > Photos
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
      NSWorkspace.shared.open(url)
      result(true)
    } else {
      result(false)
    }
  }

  private func checkPhotoPermission(result: @escaping FlutterResult) {
    if #available(macOS 11, *) {
      let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
      result(statusToString(status))
    } else {
      let status = PHPhotoLibrary.authorizationStatus()
      result(statusToString(status))
    }
  }

  private func statusToString(_ status: PHAuthorizationStatus) -> String {
    switch status {
    case .authorized:
      return "authorized"
    case .limited:
      return "limited"
    case .denied:
      return "denied"
    case .restricted:
      return "restricted"
    case .notDetermined:
      return "notDetermined"
    @unknown default:
      return "notDetermined"
    }
  }
}
