import Cocoa
import FlutterMacOS
import Photos
import AVFoundation

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
    case "fetchFilePath":
      fetchFilePath(call: call, result: result)
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
      fetchOptions.predicate = NSPredicate(format: "mediaType == %d OR mediaType == %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
      let assets = PHAsset.fetchAssets(with: fetchOptions)
      
      var metadataList: [[String: Any]] = []
      metadataList.reserveCapacity(assets.count)
      
      assets.enumerateObjects { (asset, index, stop) in
        if let creationDate = asset.creationDate {
          metadataList.append([
            "id": asset.localIdentifier,
            "creationTime": Int(creationDate.timeIntervalSince1970 * 1000),
            "isVideo": asset.mediaType == .video
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
      
      PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 1080, height: 1080), contentMode: .aspectFit, options: options) { image, _ in
        if let image = image, let tiffData = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiffData), let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
          DispatchQueue.main.async { result(FlutterStandardTypedData(bytes: jpegData)) }
        } else {
          DispatchQueue.main.async { result(nil) }
        }
      }
    }
  }

  private func fetchFilePath(call: FlutterMethodCall, result: @escaping FlutterResult) {
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
      
      let options = PHVideoRequestOptions()
      options.isNetworkAccessAllowed = true
      /// `.current` matches the edited/rendered clip Photos shows; `.original` can yield assets that export or decode poorly.
      options.version = .current

      PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
        guard let avAsset = avAsset else {
          DispatchQueue.main.async { result(nil) }
          return
        }

        self.materializePlayableVideoPath(avAsset: avAsset, phAsset: asset, assetId: id) { path in
          DispatchQueue.main.async { result(path) }
        }
      }
    }
  }

  /// Copies URL-backed library video into app temp when possible; otherwise export / resource copy.
  /// Returning raw Photos sandbox paths to Flutter is unreliable for [VideoPlayerController].
  private func materializePlayableVideoPath(avAsset: AVAsset, phAsset: PHAsset, assetId: String, completion: @escaping (String?) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
      if let urlAsset = avAsset as? AVURLAsset, urlAsset.url.isFileURL,
         FileManager.default.fileExists(atPath: urlAsset.url.path) {
        if let copied = self.copyLibraryVideoToTemp(from: urlAsset.url, assetId: assetId) {
          completion(copied)
          return
        }
      }
      self.exportVideoToTempFile(avAsset: avAsset, phAsset: phAsset, assetId: assetId, completion: completion)
    }
  }

  private func copyLibraryVideoToTemp(from srcURL: URL, assetId: String) -> String? {
    let safeBase = assetId.replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: ":", with: "_")
    let ext = srcURL.pathExtension.isEmpty ? "mov" : srcURL.pathExtension
    let dest = FileManager.default.temporaryDirectory
      .appendingPathComponent("swipify_mat_\(safeBase)_\(UUID().uuidString).\(ext)")
    do {
      if FileManager.default.fileExists(atPath: dest.path) {
        try FileManager.default.removeItem(at: dest)
      }
      try FileManager.default.copyItem(at: srcURL, to: dest)
      var isDir: ObjCBool = false
      guard FileManager.default.fileExists(atPath: dest.path, isDirectory: &isDir), !isDir.boolValue else {
        return nil
      }
      if let attrs = try? FileManager.default.attributesOfItem(atPath: dest.path),
         let size = attrs[.size] as? NSNumber,
         size.int64Value > 0 {
        return dest.path
      }
    } catch {
      NSLog("[SwipifyGallery] copyLibraryVideoToTemp: %@", error.localizedDescription)
    }
    return nil
  }

  /// Writes a playable file under NSTemporaryDirectory when the asset is not a direct file URL (e.g. compositions).
  /// Uses a unique filename per export to avoid clobbering concurrent [fetchFilePath] calls; falls back to PHAssetResourceManager.
  private func exportVideoToTempFile(avAsset: AVAsset, phAsset: PHAsset, assetId: String, completion: @escaping (String?) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
      let safeBase = assetId.replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: ":", with: "_")
      let tmp = FileManager.default.temporaryDirectory

      struct Attempt {
        let preset: String
        let ext: String
        let fileType: AVFileType
      }
      let attempts: [Attempt] = [
        Attempt(preset: AVAssetExportPresetHighestQuality, ext: "mp4", fileType: .mp4),
        Attempt(preset: AVAssetExportPresetHighestQuality, ext: "mov", fileType: .mov),
        Attempt(preset: AVAssetExportPresetMediumQuality, ext: "mp4", fileType: .mp4),
        Attempt(preset: AVAssetExportPresetMediumQuality, ext: "mov", fileType: .mov),
        Attempt(preset: AVAssetExportPresetPassthrough, ext: "mov", fileType: .mov),
      ]

      for attempt in attempts {
        let unique = UUID().uuidString
        let outURL = tmp.appendingPathComponent("swipify_vid_\(safeBase)_\(unique).\(attempt.ext)")

        guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: attempt.preset) else {
          continue
        }
        guard exportSession.supportedFileTypes.contains(attempt.fileType) else {
          continue
        }
        exportSession.outputURL = outURL
        exportSession.outputFileType = attempt.fileType
        exportSession.shouldOptimizeForNetworkUse = false

        let sem = DispatchSemaphore(value: 0)
        exportSession.exportAsynchronously {
          sem.signal()
        }
        sem.wait()
        if exportSession.status == .completed {
          completion(outURL.path)
          return
        }
        let errDesc = exportSession.error?.localizedDescription ?? "nil"
        NSLog("[SwipifyGallery] export failed preset=%@ ext=%@ status=%ld err=%@", attempt.preset, attempt.ext, exportSession.status.rawValue, errDesc)
      }

      if let path = self.copyVideoResourceToTempSync(phAsset: phAsset, assetId: assetId) {
        completion(path)
      } else {
        completion(nil)
      }
    }
  }

  private func copyVideoResourceToTempSync(phAsset: PHAsset, assetId: String) -> String? {
    let resources = PHAssetResource.assetResources(for: phAsset)
    let preferredTypes: [PHAssetResourceType] = [.video, .fullSizeVideo, .pairedVideo, .fullSizePairedVideo]
    guard let videoResource = resources.first(where: { preferredTypes.contains($0.type) }) else {
      NSLog("[SwipifyGallery] copyResource: no video resource for %@", assetId)
      return nil
    }

    let safeBase = assetId.replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: ":", with: "_")
    let tmp = FileManager.default.temporaryDirectory
    let outURL = tmp.appendingPathComponent("swipify_res_\(safeBase)_\(UUID().uuidString).mov")

    let opts = PHAssetResourceRequestOptions()
    opts.isNetworkAccessAllowed = true

    let sem = DispatchSemaphore(value: 0)
    var resultPath: String?
    PHAssetResourceManager.default().writeData(for: videoResource, toFile: outURL, options: opts) { error in
      defer { sem.signal() }
      if let error = error {
        NSLog("[SwipifyGallery] copyResource error: %@", error.localizedDescription)
        return
      }
      var isDir: ObjCBool = false
      guard FileManager.default.fileExists(atPath: outURL.path, isDirectory: &isDir), !isDir.boolValue else {
        NSLog("[SwipifyGallery] copyResource: missing file %@", outURL.path)
        return
      }
      if let attrs = try? FileManager.default.attributesOfItem(atPath: outURL.path),
         let size = attrs[.size] as? NSNumber,
         size.int64Value > 0 {
        resultPath = outURL.path
      } else {
        NSLog("[SwipifyGallery] copyResource: empty file %@", outURL.path)
      }
    }
    sem.wait()
    return resultPath
  }

  private func makeTempVideoURL(assetId: String) -> URL {
    let safe = assetId.replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: ":", with: "_")
    return FileManager.default.temporaryDirectory
      .appendingPathComponent("swipify_vid_\(safe).mp4")
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
