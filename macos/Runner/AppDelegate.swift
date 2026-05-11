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

    // Register this AppDelegate as the host for the
    // "Transcribe with CrisperWeaver" Services menu item
    // declared in Info.plist's NSServices array. The matching
    // selector is `transcribeAudio(_:userData:error:)` below.
    // `NSUpdateDynamicServices()` nudges the system to re-scan
    // installed Services so a fresh install / version bump
    // surfaces the entry without a logout.
    NSApp.servicesProvider = self
    NSUpdateDynamicServices()
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

  // -------------------------------------------------------------
  // Services menu handler — fired when the user picks
  // "Transcribe with CrisperWeaver" from a Finder right-click
  // (or any other Services-respecting app). The system hands
  // us the selected files via NSPasteboard; we read the file
  // URLs off it and feed them into the same intake buffer that
  // Open-With / drop-on-dock uses, so the Dart side sees them
  // identically.
  //
  // Selector shape is dictated by Apple's Services contract —
  // the NSMessage in Info.plist's NSServices entry maps to
  // `<message>(_ pboard:userData:error:)`. The error parameter
  // is documented as a pointer-to-NSString the handler writes
  // a user-facing message into on failure; we leave it
  // untouched and just log to our normal sink.
  // -------------------------------------------------------------
  @objc func transcribeAudio(_ pboard: NSPasteboard,
                             userData: String,
                             error: AutoreleasingUnsafeMutablePointer<NSString>) {
    let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil)
      as? [URL] ?? []
    if urls.isEmpty {
      NSLog("[crisperweaver] NSServices invocation had no file URLs")
      return
    }
    OpenWithReceiver.shared.enqueue(urls: urls)
    // Bring the app forward so the user sees the file land in
    // the transcription pane — Services menu invocations don't
    // auto-foreground us the way Finder Open With does.
    if #available(macOS 14.0, *) {
      NSApp.activate()
    } else {
      NSApp.activate(ignoringOtherApps: true)
    }
  }
}
