import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Register our custom photo permission plugin that directly uses
    // PHPhotoLibrary - this bypasses photo_manager's broken channel
    SwipifyGalleryService.register(
      with: flutterViewController.registrar(forPlugin: "SwipifyGalleryService")
    )

    super.awakeFromNib()
  }
}
