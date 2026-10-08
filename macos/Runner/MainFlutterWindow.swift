import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var windowChannel: FlutterMethodChannel?
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    windowChannel = FlutterMethodChannel(
      name: "pronhub/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    windowChannel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setFullscreen" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let enabled = call.arguments as? Bool, let window = self else {
        result(FlutterError(code: "invalid_argument", message: "Expected a boolean", details: nil))
        return
      }
      if window.styleMask.contains(.fullScreen) != enabled {
        window.toggleFullScreen(nil)
      }
      result(nil)
    }

    super.awakeFromNib()
  }
}
