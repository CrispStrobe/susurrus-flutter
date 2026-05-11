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

  // Open-With / drop-on-dock-icon / `open foo.wav` from the
  // terminal all fire one of these three delegate methods.
  // OpenWithReceiver triages them — buffering on cold launch
  // until MainFlutterWindow binds the MethodChannel, then
  // live-forwarding once Flutter is listening. The
  // CFBundleDocumentTypes in Info.plist already controls WHICH
  // file types macOS will offer CrisperWeaver for in the
  // Finder Open With list; we accept anything the OS hands us
  // here and let the Dart-side triage decide whether it's
  // audio / transcript / drop.

  override func application(_ application: NSApplication, open urls: [URL]) {
    OpenWithReceiver.shared.enqueue(urls: urls)
    super.application(application, open: urls)
  }

  // Legacy hooks — older macOS sometimes still uses these even
  // when `open(_:urls:)` is implemented, depending on how the
  // launching process opened us. FlutterAppDelegate already
  // implements both, so we override.

  override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    OpenWithReceiver.shared.enqueue([filename])
    return true
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    OpenWithReceiver.shared.enqueue(filenames)
    sender.reply(toOpenOrPrint: .success)
  }
}
