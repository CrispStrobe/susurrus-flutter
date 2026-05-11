import UIKit
import Flutter
import Foundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // iOS helpers MethodChannel — currently exposes
    // `excludeFromBackup(path)` so the §5.23 batch persistence
    // service can flag the in-flight checkpoint directory
    // `NSURLIsExcludedFromBackupKey = true`, sparing the user's
    // iCloud bandwidth + storage during long batch runs.
    //
    // Other platforms (Android/desktop) don't have an equivalent
    // mechanism; the Dart wrapper is a no-op there, so this handler
    // doesn't need a non-iOS sibling.
    let controller = window?.rootViewController as? FlutterViewController
    if let controller = controller {
      let channel = FlutterMethodChannel(
        name: "crisperweaver/ios_helpers",
        binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { (call, result) in
        switch call.method {
        case "excludeFromBackup":
          guard let args = call.arguments as? [String: Any],
                let path = args["path"] as? String else {
            result(FlutterError(
              code: "BAD_ARGS",
              message: "expected {path: String}",
              details: nil))
            return
          }
          var url = URL(fileURLWithPath: path)
          var values = URLResourceValues()
          values.isExcludedFromBackup = true
          do {
            try url.setResourceValues(values)
            result(true)
          } catch {
            result(FlutterError(
              code: "SET_FAILED",
              message: error.localizedDescription,
              details: nil))
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
