# Susurrus — on-device speech recognition

A Flutter app for fully-offline audio transcription. Bring an audio file, paste a URL, or record with the mic; Susurrus runs Whisper (and, via [CrispASR][crispasr], a growing family of other open-weight ASR models) locally with GGML/ggml quantization — no audio leaves the device.

[crispasr]: https://github.com/CrispStrobe/CrispASR

## Status

| Area                              | State                                   |
| --------------------------------- | --------------------------------------- |
| CrispASR FFI engine (Whisper GGML)| ✅ Works                                 |
| Mock engine (tests / demo)        | ✅ Works                                 |
| Whisper.cpp method-channel engine | ⚠️ Redundant with CrispASR; left in matrix for plugin-only builds |
| CoreML method-channel engine      | ⚠️ Same                                  |
| Sherpa ONNX                       | ✅ Retired from enum (was placeholder only) |
| macOS build                       | ✅ Verified via `flutter build macos`; dylib auto-detected from `Contents/Frameworks/` |
| Linux build                       | ✅ CI job (`build-linux` on `ubuntu-latest`); local build blocked by host (macOS dev machine) |
| Windows build                     | ⚠️ CMake targets present but no CI job yet |
| iOS build                         | ⚠️ Xcode project regenerated; `pod install` blocked by stale `TensorFlowLiteSwift '~> 2.13.0'` pin in `ios/Podfile` — drop pin or refresh pod spec |
| Android build                     | ⚠️ `libwhisper.so` is built + bundled under `android/app/src/main/jniLibs/arm64-v8a/`; Gradle now mixes legacy Groovy (`app/build.gradle`) with regenerated KTS (`settings.gradle.kts` / `app/build.gradle.kts`). Pick one and port the plugin registrations. |
| i18n (en + de)                    | ✅ Scaffold via `flutter_localizations` + `lib/l10n/*.arb`; main screens migrated, widgets + older settings strings still hardcoded |
| Model download + resume           | ✅                                       |
| Quantized variants (q4_0/q5_0/q8_0)| ✅ from `cstr/whisper-ggml-quants`      |
| Checksum skip toggle              | ✅ in Settings → Debugging               |
| History (persisted)               | ✅                                       |
| Exports (TXT/SRT/VTT/JSON)        | ✅                                       |
| Performance readout (RTF, WPS)    | ✅                                       |
| Logging + log viewer              | ✅                                       |
| Inbound share (audio → app)       | ✅ Android intent filters + iOS doc types; macOS UTI open-in |
| Streaming transcription           | ❌ Blocked on upstream CrispASR Dart pkg — see `docs/crispasr-dart-gaps.md` |
| Real speaker diarization          | ❌ Blocked on upstream CrispASR Dart pkg — current MFCC/k-means fallback is a stopgap |
| Non-Whisper backends (Parakeet, Canary, Qwen3-ASR, Voxtral, …) | ❌ Blocked on upstream CrispASR Dart pkg backend dispatch |

## What's inside

- **Four engines** behind a common `TranscriptionEngine` interface:
  - `CrispASREngine` — direct Dart FFI to `libwhisper.{dylib,so,dll}` / `whisper.framework`. Works on macOS / Linux / Windows today; mobile needs the per-platform libwhisper cross-build.
  - `MockEngine` — deterministic fake responses, used for UI work and CI.
  - `WhisperCppEngine`, `CoreMLEngine` — method-channel wrappers that expect platform plugins that are currently only stubbed.
- **Model manager** with parallel download queue, resume, SHA-1 verify, cancel, and delete. Pulls F16 Whisper GGMLs from `ggerganov/whisper.cpp` and q4_0 / q5_0 / q8_0 variants from `cstr/whisper-ggml-quants` on HuggingFace. A "Skip checksum verification" toggle in Settings bypasses SHA mismatch on mirrored or custom builds.
- **Transcription screen**: file picker, URL input, live mic recorder, language / model dropdowns, language auto-detect, diarization toggle, progress bar, live perf readout (RTF × audio-length / wall-clock, words/s), and an engine-status chip.
- **History**: every transcription saved as JSON in `<app-documents>/history/`, browseable and re-exportable.
- **Exports**: `.txt`, `.srt`, `.vtt`, `.json` via share sheet.
- **Logs**: in-memory ring buffer, optional file sink to `<app-documents>/logs/session.log`, dedicated viewer screen with level filter / search / copy / export / clear. Captures `FlutterError.onError`.
- **About screen**: service provider, contact, privacy summary, disclaimer, and the Flutter-generated open-source license list.

## Repo layout

```
susurrus-flutter/             ← this repo
  lib/
    engines/                  ← TranscriptionEngine + impls (CrispASR, Mock, ...)
    screens/                  ← transcription, history, models, logs, about, settings
    services/                 ← audio, model downloads, history, share intake, logs
    widgets/                  ← recorder, output, download manager, diarization UI
  assets/models/              ← (empty; models are downloaded at runtime)
  android/  ios/  macos/      ← per-platform Flutter scaffolding
  .github/workflows/          ← CI + release

CrispASR/                     ← sibling checkout required at build time
  flutter/crispasr/           ← pubspec path dep target
  build/src/libwhisper.*.dylib← produced by `cmake --build` there
```

`pubspec.yaml` refers to the Dart FFI package via `path: ../CrispASR/flutter/crispasr`, so CrispASR must be cloned in the parent directory before running `flutter pub get`.

## Building

### Prerequisites

- Flutter 3.38.x (`stable`). Older SDKs may need a `material_color_utilities` override.
- Xcode + CocoaPods for iOS / macOS builds.
- JDK 17 + Android SDK for Android builds.
- CMake + a C++ toolchain to build `libwhisper` from CrispASR.

### Clone both repos side-by-side

```bash
mkdir susurrus && cd susurrus
git clone https://github.com/CrispStrobe/CrispASR.git
git clone https://github.com/<you>/susurrus-flutter.git
```

### Build libwhisper (macOS / Linux)

```bash
cd CrispASR
cmake -B build -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=ON -DWHISPER_METAL=ON
cmake --build build --parallel --target whisper
# Produces CrispASR/build/src/libwhisper.*.dylib (macOS) or .so (Linux)
```

### Run the Flutter app

```bash
cd ../susurrus-flutter
flutter pub get
flutter run -d macos          # or: flutter run -d linux, flutter run -d android, ...
```

### Package a macOS `.app` with the dylib bundled

```bash
flutter build macos --release
APP=build/macos/Build/Products/Release/susurrus_flutter.app
cp ../CrispASR/build/src/libwhisper.*.dylib "$APP/Contents/Frameworks/libwhisper.dylib"
codesign --force --deep --sign - "$APP"
```

At runtime `CrispASREngine` auto-detects `libwhisper.dylib` from the bundle's `Contents/Frameworks/`, or (as a dev fallback) from `$HOME/code/CrispASR/build/src/`, `/usr/local/lib/`, or a user-supplied `libPath` in engine config.

### Android / iOS

The mobile targets currently bundle the Mock engine out-of-the-box. Shipping CrispASR on mobile needs the per-platform libwhisper cross-build — use `CrispASR/build-android.sh` / `build-ios.sh` — and then copying the resulting binary into `android/app/src/main/jniLibs/<abi>/` or the iOS app's `Frameworks/`. That wiring is tracked as future work.

## Settings you'll probably want

- **Preferred engine** — defaults to CrispASR. Switch instantly.
- **Default model / language** — pre-select for every new transcription.
- **Skip checksum verification** — use with custom / mirrored GGUFs that don't match the hardcoded SHA-1s.
- **Log level & "Mirror logs to file"** — essential when reporting issues.

## Troubleshooting

- **"Failed to load model"** on launch: you haven't built / bundled `libwhisper`. Check `Settings → Debugging → Open log viewer`; the `crispasr` tag tells you which paths it probed.
- **Model downloads fail verification**: flip on "Skip checksum verification" and retry. Quantized variants ship without SHAs by design.
- **Antivirus flags something in `~/.pub-cache`**: that directory is pub's archive extraction cache — add it to your AV exclusions. The files are plain-text CHANGELOGs / Dart sources being scanned during download.
- **Build warnings about `file_picker`** referencing itself as default impl on linux/macos/windows: noisy but non-fatal, known upstream issue.

## CI / Release

Two workflows ship in `.github/workflows/`:

- `ci.yml` — on every push / PR: `flutter analyze` + `flutter test` on Ubuntu & macOS, plus a macOS `.app` debug build uploaded as a workflow artifact. Checks out the sibling `CrispASR` repo automatically.
- `release.yml` — on a `vX.Y.Z` tag (or manual dispatch): builds a Release `.app` with Metal-enabled `libwhisper.dylib` bundled, ad-hoc codesigns, zips it, and uploads to the matching GitHub Release. Also builds an unsigned Android APK.

Both assume `CrispStrobe/CrispASR` on `main` as the sibling repo — override via the `CRISPASR_REPO` / `CRISPASR_REF` env vars at the top of each workflow.

## License & author

Susurrus is licensed under the **GNU Affero General Public License v3.0 or later** (AGPL-3.0). Full text in [`LICENSE`](LICENSE); see the `About` screen inside the app for an in-product summary plus the auto-aggregated third-party license list (via `showLicensePage`).

Copyright © Christian Ströbele · Stuttgart, Germany.
