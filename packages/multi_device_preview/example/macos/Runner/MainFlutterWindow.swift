import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // Open wide enough to show several devices side by side.
    let visible = self.screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1600, height: 1000)
    let size = NSSize(width: min(1600, visible.width), height: min(1000, visible.height))
    let origin = NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2)
    self.setFrame(NSRect(origin: origin, size: size), display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
