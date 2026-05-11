import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  // Self-foreground on launch. `flutter run` calls `open <bundle>`
  // post-attach to bring us forward (see flutter_tools'
  // macos_device.dart#onAttached), but on macOS 26 Tahoe that
  // secondary `open` against an already-running app returns 1 and
  // surfaces as the noisy "Failed to foreground app; open returned 1"
  // line. Activating ourselves here makes that step redundant — the
  // window reliably comes forward on `flutter run` regardless of
  // whether the upstream `open` succeeds.
  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    if #available(macOS 14.0, *) {
      NSApp.activate()
    } else {
      NSApp.activate(ignoringOtherApps: true)
    }
  }
}
