import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    // Start with a large-enough window that the dual-pane transcription
    // screen doesn't clip. Users can still resize smaller; scroll views
    // inside the app handle narrow widths.
    let defaultSize = NSSize(width: 1200, height: 800)
    let screen = NSScreen.main?.visibleFrame
      ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
    let origin = NSPoint(
      x: screen.midX - defaultSize.width / 2,
      y: screen.midY - defaultSize.height / 2
    )
    let windowFrame = NSRect(origin: origin, size: defaultSize)

    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 600, height: 480)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
