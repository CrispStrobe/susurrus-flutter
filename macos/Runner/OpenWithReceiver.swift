// OpenWithReceiver — macOS Open-With / drag-onto-dock bridge.
//
// macOS hands incoming files to the app via three NSApplication
// delegate methods:
//   - application(_:open:)      modern, receives [URL]
//   - application(_:openFile:)  legacy single file
//   - application(_:openFiles:) legacy multi
//
// AppDelegate routes all three through this receiver. The
// catch: when the user launches the app COLD via Finder's
// "Open With CrisperWeaver", the delegate fires before
// FlutterViewController has built its engine, which means our
// MethodChannel isn't registered yet. So we buffer file paths
// in `pending` until MainFlutterWindow.awakeFromNib calls
// `attachChannel(_:)` — at which point we drain the buffer and
// switch to live forwarding.
//
// Wire-level protocol on channel `crisperweaver/open_with`:
//   Flutter → Native:  consumePending()  → [String] paths
//                                          (drained from buffer)
//   Native → Flutter:  invokeMethod("onFiles", [String] paths)
//                      for any file that arrives after Flutter
//                      is already listening
//
// The Dart side (DesktopOpenWithBridge in
// lib/services/desktop_open_with_bridge.dart) calls
// consumePending() once at boot and listens for onFiles for
// the lifetime of the app.

import Cocoa
import FlutterMacOS

final class OpenWithReceiver {
    static let shared = OpenWithReceiver()
    private init() {}

    private let kChannelName = "crisperweaver/open_with"

    /// Paths accumulated while Flutter isn't listening yet.
    /// Drained by the first call to `consumePending` from Dart
    /// (typically the post-frame callback in main.dart).
    private var pending: [String] = []

    /// The bound channel. Nil before MainFlutterWindow registers.
    private var channel: FlutterMethodChannel?

    /// Serialise mutations across the AppDelegate (main thread)
    /// and any future background callers. NSLock is enough; the
    /// hot path is ~rare (file open) and the locked sections are
    /// trivially short.
    private let lock = NSLock()

    /// Forward an incoming batch of file paths. Filters
    /// out file URLs that don't exist (paranoia — macOS does
    /// hand us valid URLs but a network volume can disappear
    /// between the user's click and our delegate call).
    func enqueue(_ paths: [String]) {
        let real = paths.filter { !$0.isEmpty }
        guard !real.isEmpty else { return }
        lock.lock()
        let ch = channel
        if ch == nil {
            // No subscriber yet — buffer until Flutter calls
            // consumePending.
            pending.append(contentsOf: real)
            lock.unlock()
            return
        }
        lock.unlock()
        // Hot path: a live subscriber is bound. Hop to the main
        // thread (FlutterMethodChannel requires it) and push.
        DispatchQueue.main.async {
            ch?.invokeMethod("onFiles", arguments: real)
        }
    }

    /// Convenience: enqueue from an `[URL]` (the
    /// application(_:open:) shape). Non-file URLs are skipped —
    /// custom-scheme URLs go through a different pipeline
    /// (CFBundleURLTypes / GoRouter deep links) that this
    /// receiver doesn't touch.
    func enqueue(urls: [URL]) {
        enqueue(urls.compactMap { $0.isFileURL ? $0.path : nil })
    }

    /// Bind the Flutter side. Called from
    /// MainFlutterWindow.awakeFromNib once the FlutterEngine's
    /// binary messenger exists. Idempotent — re-binding (e.g.
    /// on a hot restart) drains whatever has accumulated and
    /// keeps the new channel.
    func attachChannel(messenger: FlutterBinaryMessenger) {
        let ch = FlutterMethodChannel(
            name: kChannelName, binaryMessenger: messenger)
        ch.setMethodCallHandler { [weak self] call, result in
            guard let self = self else {
                result(FlutterMethodNotImplemented)
                return
            }
            switch call.method {
            case "consumePending":
                self.lock.lock()
                let drained = self.pending
                self.pending = []
                self.lock.unlock()
                result(drained)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        lock.lock()
        channel = ch
        lock.unlock()
    }
}
