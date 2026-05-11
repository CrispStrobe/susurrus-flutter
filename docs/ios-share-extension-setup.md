# iOS Share Extension setup

The Share Extension makes CrisperWeaver appear in iOS's system
Share Sheet — the half-sheet that pops up when you tap **Share…**
on a recording in Voice Memos, an attachment in Mail, a file in
Files, or any other app that vends a Share action.

The Swift / Info.plist / entitlements **source files are checked
in** at `ios/ShareExtension/` and `ios/Runner/Runner.entitlements`.
What's not checked in is the one-time Xcode target wiring — that
needs to happen interactively in Xcode (or via a `xcodeproj`
Ruby script). This doc lists the steps.

## What's already done

- `ios/ShareExtension/ShareViewController.swift` — extension
  entry point, sub-classes `RSIShareViewController` from
  `receive_sharing_intent`. Auto-redirects to the main app
  after writing inbound files into the shared container.
- `ios/ShareExtension/Info.plist` — declares the extension's
  `NSExtensionActivationRule` (file attachments up to 10 items;
  text, image, movie disabled).
- `ios/ShareExtension/ShareExtension.entitlements` — App Group
  identifier `group.com.crispstrobe.crisperweaver`.
- `ios/Runner/Runner.entitlements` — same App Group on the main
  app side so it can read what the extension wrote.
- `ios/Runner/Info.plist` — `CFBundleDocumentTypes` already
  declares the audio + subtitle types; `UTExportedTypeDeclarations`
  declares `com.crispstrobe.crisperweaver.srt` and
  `com.crispstrobe.crisperweaver.vtt`.

## One-time Xcode steps

Open `ios/Runner.xcworkspace` (the *workspace*, not the project,
so CocoaPods is picked up).

### 1. Add the Share Extension target

1. **File → New → Target…**
2. Pick **iOS → Application Extension → Share Extension**, click *Next*.
3. **Product Name:** `ShareExtension`. **Language:** Swift. Tap
   *Finish*. When Xcode asks to "Activate the scheme", say *Cancel*
   (we'll manage schemes manually).
4. Xcode generates a `ShareExtension` group with default files.
   **Delete the generated `ShareViewController.swift` and
   `MainInterface.storyboard`** — the templates create them in
   the wrong place and Storyboard isn't needed; we use the
   checked-in `ios/ShareExtension/ShareViewController.swift`.
5. Right-click the `ShareExtension` group → **Add Files to
   "Runner"…** and select:
   - `ios/ShareExtension/ShareViewController.swift`
   - `ios/ShareExtension/Info.plist`
   - `ios/ShareExtension/ShareExtension.entitlements`
   Make sure the target membership is **ShareExtension only**, not
   Runner.

### 2. Replace the generated Info.plist

In the target's **Build Settings → Packaging → Info.plist File**,
set the path to `ShareExtension/Info.plist` so Xcode uses the
checked-in file instead of the auto-generated one.

### 3. Add the App Group capability

For **both** the Runner target and the ShareExtension target:

1. Open the target in the project editor.
2. **Signing & Capabilities → + Capability → App Groups**.
3. Click the `+` under the group list and add
   `group.com.crispstrobe.crisperweaver`.
4. Confirm the *App Groups* checkbox is ticked.

If Xcode complains about "no provisioning profile that includes
App Groups", let it auto-generate one — for a personal team this
works without further App Store Connect work.

### 4. Wire the entitlements files

For each target, point at the checked-in entitlements:

- **Runner target → Build Settings → Code Signing → Code Signing
  Entitlements:** `Runner/Runner.entitlements`
- **ShareExtension target → Build Settings → Code Signing → Code
  Signing Entitlements:** `ShareExtension/ShareExtension.entitlements`

### 5. Embed the extension in the main app

Runner target → **General → Frameworks, Libraries, and Embedded
Content**. The ShareExtension should already appear (Xcode adds
it automatically); confirm **Embed & Sign** is set so the
extension ships inside `Runner.app/PlugIns/ShareExtension.appex`.

### 6. Add `receive_sharing_intent` to the extension's Podfile

Open `ios/Podfile` and add a new target block that mirrors what
the package's README shows (it's the same `flutter_install_*`
boilerplate the main `Runner` target has). After saving:

```bash
cd ios && pod install
```

### 7. Build + smoke test

1. Build the Runner scheme to the device or simulator.
2. Open Voice Memos, tap a recording → Share → CrisperWeaver
   should now appear in the half-sheet.
3. After tapping CrisperWeaver, the share extension flashes
   briefly then the main app comes to the foreground with the
   audio loaded into Selected Source.

Multi-file shares also work — drop multiple files in Files,
share to CrisperWeaver, and `ShareIntakeService` enqueues the
extras into the batch queue automatically (see
`lib/services/share_intake_service.dart` for the triage).

## Troubleshooting

- **CrisperWeaver doesn't appear in the Share Sheet** — the
  most common cause is the `NSExtensionActivationRule` not
  matching. The default config in `Info.plist` accepts files
  and attachments; if the source app vends something else
  (image, URL, text), iOS hides CrisperWeaver. Switch the
  rule to a `NSExtensionActivationSupportsFileWithMaxCount =
  10` if you need broader coverage.
- **The extension launches but the main app doesn't open** —
  check that the App Group identifier is *identical* in both
  targets' entitlements. A typo there silently breaks the
  hand-off.
- **`pod install` complains about a missing target** — close
  Xcode before running `pod install`, then reopen the
  workspace.
