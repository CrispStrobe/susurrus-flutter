// ShareViewController — iOS Share Extension entry point.
//
// This is what makes CrisperWeaver appear in the system Share
// Sheet when the user taps "Share…" on a recording in Voice
// Memos, an attachment in Mail, a file in Files, or any other
// app that vends a Share action.
//
// The heavy lifting (parsing the NSExtensionContext, writing
// the inbound files into the App Group's shared container,
// hopping to the main app via the registered URL scheme) lives
// in `receive_sharing_intent`'s `RSIShareViewController`. We
// just sub-class it and let the main-app side
// (`ShareIntakeService` in lib/services/share_intake_service.dart)
// pick the files up on the other side of the boundary.
//
// Wiring (one-time, done manually in Xcode — see
// docs/ios-share-extension-setup.md):
//
//   1. Add this folder as a Share Extension target in
//      ios/Runner.xcodeproj. The target's "Embedded Content"
//      must be marked for the main Runner app target so the
//      extension ships inside the .app bundle.
//   2. Enable the "App Groups" capability on BOTH the Runner
//      target and this extension target, using the same group
//      identifier (group.com.crispstrobe.crisperweaver). This
//      is the shared container both sides read/write from.
//   3. Add Info.plist (next to this file) declaring the
//      extension's NSExtensionAttributes — the NSPredicate
//      activation rule decides which share types CrisperWeaver
//      appears for.
//   4. Add ShareExtension.entitlements with the App Group
//      identifier under com.apple.security.application-groups.
//
// Once the target is wired, no further code changes are needed
// for ordinary inbound flows.

import UIKit
import Social
import MobileCoreServices
import receive_sharing_intent

class ShareViewController: RSIShareViewController {
    // RSIShareViewController auto-redirects to the host app
    // after writing the shared files into the App Group
    // container. We keep the default — overriding to return
    // false would force the extension to render its own
    // settings UI before redirecting, which we don't need.
    override func shouldAutoRedirect() -> Bool {
        return true
    }
}
