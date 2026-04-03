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
class SwipifyGalleryService: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.swipify/gallery",
      binaryMessenger: registrar.messenger
    )
    let instance = SwipifyGalleryService()
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
    case "fetchLibraryMetadata":
      fetchLibraryMetadata(result: result)
    case "fetchThumbnail":
      fetchThumbnail(call: call, result: result)
    case "fetchFile":
      fetchFile(call: call, result: result)
    case "deletePhotos":
      deletePhotos(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func fetchLibraryMetadata(result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      let fetchOptions = PHFetchOptions()
      fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
      let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
      
      var metadataList: [[String: Any]] = []
      metadataList.reserveCapacity(assets.count)
      
      assets.enumerateObjects { (asset, index, stop) in
        if let creationDate = asset.creationDate {
          metadataList.append([
            "id": asset.localIdentifier,
            "creationTime": Int(creationDate.timeIntervalSince1970 * 1000)
          ])
        }
      }
      
      DispatchQueue.main.async { result(metadataList) }
    }
  }

  private func fetchThumbnail(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any], let id = args["id"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "id is required", details: nil))
      return
    }
    
    let width = args["width"] as? CGFloat ?? 300
    let height = args["height"] as? CGFloat ?? 300
    
    DispatchQueue.global(qos: .userInitiated).async {
      let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
      guard let asset = fetchResult.firstObject else {
        DispatchQueue.main.async { result(nil) }
        return
      }
      
      let options = PHImageRequestOptions()
      options.isSynchronous = true
      options.deliveryMode = .fastFormat
      options.isNetworkAccessAllowed = true
      
      PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: width, height: height), contentMode: .aspectFill, options: options) { image, _ in
        if let image = image, let tiffData = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiffData), let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) {
          DispatchQueue.main.async { result(FlutterStandardTypedData(bytes: jpegData)) }
        } else {
          DispatchQueue.main.async { result(nil) }
        }
      }
    }
  }

  private func fetchFile(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any], let id = args["id"] as? String else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "id is required", details: nil))
      return
    }
    
    DispatchQueue.global(qos: .userInitiated).async {
      let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
      guard let asset = fetchResult.firstObject else {
        DispatchQueue.main.async { result(nil) }
        return
      }
      
      let options = PHImageRequestOptions()
      options.isSynchronous = true
      options.deliveryMode = .highQualityFormat
      options.isNetworkAccessAllowed = true
      
      PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, _ in
        if let image = image, let tiffData = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiffData), let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) {
          DispatchQueue.main.async { result(FlutterStandardTypedData(bytes: jpegData)) }
        } else {
          DispatchQueue.main.async { result(nil) }
        }
      }
    }
  }

  private func deletePhotos(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any], let ids = args["ids"] as? [String] else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "ids is required", details: nil))
      return
    }
    
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
    guard fetchResult.count > 0 else {
      result(true)
      return
    }
    
    PHPhotoLibrary.shared().performChanges({
      var assets: [PHAsset] = []
      fetchResult.enumerateObjects { (asset, _, _) in assets.append(asset) }
      PHAssetChangeRequest.deleteAssets(assets as NSArray)
    }) { success, _ in
      DispatchQueue.main.async { result(success) }
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
      PHPhotoLibrary.requestAuthorization { status in
        DispatchQueue.main.async {
          result(self.statusToString(status))
        }
      }
    }
  }

  private func openSettings(result: @escaping FlutterResult) {
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
    case .authorized: return "authorized"
    case .limited: return "limited"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "notDetermined"
    @unknown default: return "notDetermined"
    }
  }
}
