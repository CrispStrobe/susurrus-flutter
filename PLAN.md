# CrisperWeaver — Implementation plan & current status

What's done, what's partial, and what's next — with enough file paths and context that a fresh session can pick up any item.

---

## Table of contents

1. [Engine status](#1-engine-status)
2. [Model-family status](#2-model-family-status)
3. [Platform status](#3-platform-status)
4. [Feature status](#4-feature-status)
5. [Open roadmap items](#5-open-roadmap-items)
6. [Adding a new backend](#6-adding-a-new-backend)
7. [Server alternative (not used)](#7-server-alternative-not-used)

---

## 1. Engine status

Four engines behind the `TranscriptionEngine` interface (`lib/engines/transcription_engine.dart`):

| Engine                  | State                                                                      |
| ----------------------- | -------------------------------------------------------------------------- |
| `CrispASREngine`        | ✅ Primary. Dart FFI to `libcrispasr` / `libwhisper`. Dispatches across all 10 backends via `CrispasrSession`. |
| `MockEngine`            | ✅ Deterministic fake responses — used for UI work and CI.                 |
| `WhisperCppEngine`      | ⚠️ Method-channel wrapper. Redundant with CrispASR; retained for plugin-only builds. |
| `CoreMLEngine`          | ⚠️ Same pattern, iOS-only target.                                          |

`EngineType.sherpaOnnx` was dropped (placeholder only).

## 2. Model-family status

All 10 CrispASR backends are runtime-ready through `CrispasrSession`. The bundled `libcrispasr` must be linked with each backend's shared library; `CrispasrSession.availableBackends()` reports live at startup which ones this build has.

| Family               | Download | Runtime FFI                      | Notes                                    |
| -------------------- | :------: | :------------------------------: | ---------------------------------------- |
| Whisper              | ✅       | ✅ (default path)                 | Full features (word-ts, lang-detect, streaming, VAD) |
| Parakeet             | ✅       | ✅ via `CrispasrSession`          | Fast English ASR, native word timestamps  |
| Canary               | ✅       | ✅ via `CrispasrSession`          | Speech translation X ↔ en                 |
| Qwen3-ASR            | ✅       | ✅ via `CrispasrSession`          | 30+ langs incl. Chinese dialects          |
| Cohere               | ✅       | ✅ via `CrispasrSession`          | High-accuracy Conformer decoder           |
| Granite Speech       | ✅       | ✅ via `CrispasrSession`          | Instruction-tuned                         |
| FastConformer-CTC    | ✅       | ✅ via `CrispasrSession`          | Low-latency CTC                           |
| Canary-CTC           | ✅       | ✅ via `CrispasrSession`          | Shared canary_ctc_* pipeline              |
| Voxtral Mini 3B      | ✅       | ✅ via `CrispasrSession`          | Shared VoxtralFamilyOps loop              |
| Voxtral Mini 4B      | ✅       | ✅ via `CrispasrSession`          | Realtime variant, same loop               |
| Wav2Vec2             | ✅       | ✅ via `CrispasrSession`          | Self-supervised, public C++ API sufficed  |

The same unified dispatcher is shared with the Python (`crispasr.Session`) and Rust (`crispasr::Session`) wrappers — one C-ABI, three languages.

## 3. Platform status

| Platform | State | Blocker                                                                                      |
| -------- | ----- | -------------------------------------------------------------------------------------------- |
| macOS    | ✅    | None. `flutter build macos` + `scripts/bundle_macos_dylibs.sh` produces a runnable `.app`.   |
| Linux    | ✅    | None. CI `build-linux` job bundles all `.so`'s; local build needs a Linux host.              |
| Windows  | ⚠️    | CMake targets exist; no CI job yet.                                                          |
| Android  | ⚠️    | APK builds with Mock engine. Gradle is mixed Groovy (`app/build.gradle`) + KTS (`settings.gradle.kts`). Pick one and port the plugin registrations. Separately, `libwhisper.so` is built by `CrispASR/build-android.sh` and bundled under `android/app/src/main/jniLibs/<abi>/` — but this wiring isn't automated in CI. |
| iOS      | ⚠️    | Xcode project regenerated; `pod install` is blocked by stale `TensorFlowLiteSwift '~> 2.13.0'` pin in `ios/Podfile`. Drop the pin or refresh the pod spec. |

## 4. Feature status

| Feature                                    | State                                                                 |
| ------------------------------------------ | --------------------------------------------------------------------- |
| Model download + resume + cancel + delete  | ✅                                                                    |
| Quantised variants (q4_0 / q5_0 / q8_0)    | ✅ from `cstr/whisper-ggml-quants`                                    |
| Checksum skip toggle                       | ✅ in *Settings → Debugging*                                           |
| History (persisted)                        | ✅ `<app-docs>/history/*.json`                                         |
| Exports (TXT / SRT / VTT / JSON)           | ✅ via share sheet                                                    |
| Performance readout (RTF, WPS)             | ✅                                                                    |
| Logging + log viewer                       | ✅ ring buffer + optional file sink                                   |
| Inbound share (audio → app)                | ✅ Android intent filters, iOS doc types, macOS UTI open-in           |
| Desktop drag-and-drop                      | ✅ `desktop_drop` on transcription screen                             |
| Audio decoding (WAV / MP3 / FLAC)          | ✅ `crispasr_audio_load` FFI via miniaudio — no ffmpeg dep            |
| Word-level timestamps (Whisper)            | ✅ via CrispASR 0.2.0                                                 |
| Language auto-detect (Whisper)             | ✅ via CrispASR 0.2.0 `crispasr_detect_language`                      |
| VAD (Silero) Dart binding                  | ✅ via CrispASR 0.2.0 `crispasr_vad_segments` (needs VAD GGML model)  |
| Streaming transcription (Whisper)          | ✅ via CrispASR 0.3.0 `crispasr_stream_*` — 10s window / 3s step       |
| i18n (en + de)                             | ⚠️ Scaffold via `flutter_localizations` + `lib/l10n/*.arb`; main screens migrated, widgets + older Settings strings still hardcoded |
| Real speaker diarization                   | ❌ Blocked on upstream CrispASR diarization API — current MFCC/k-means is a stopgap |

---

## 5. Open roadmap items

### 5.1 Finish i18n

**What:** migrate remaining hardcoded strings in `lib/widgets/` and older `lib/screens/settings_screen.dart` paths to `AppLocalizations.of(context)!.<key>`.

**Where:** grep for string literals in `lib/widgets/` and `lib/screens/settings_screen.dart`. Add matching keys to both `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`. Regenerate with `flutter gen-l10n` (automatic on `flutter pub get`).

**Risk:** low. Mechanical work.

### 5.2 iOS Podfile unblock

**What:** `ios/Podfile` pins `TensorFlowLiteSwift '~> 2.13.0'` from an earlier engine placeholder. The current engine matrix doesn't use TFLite. Drop the `pod 'TensorFlowLiteSwift', '~> 2.13.0'` line and run `pod install` inside `ios/`.

**Risk:** the line may belong to a plugin (record? sherpa_onnx leftover?) — grep first.

**Verification:** `cd ios && pod install && xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug -destination 'generic/platform=iOS' build`.

### 5.3 Android Gradle cleanup

**What:** unify on Groovy *or* KTS. Current state has `app/build.gradle.kts` (from `flutter create`) *and* legacy `app/build.gradle`. Pick KTS (matches Flutter's 2024+ scaffolding), delete the Groovy files, port any plugin registrations (e.g. `AudioProcessingPlugin`, `WhisperCppPlugin`) into the Kotlin activity's `configureFlutterEngine`.

**Risk:** medium. Plugin registration via `MethodChannel` needs to survive the port.

**Verification:** `flutter build apk --debug` locally; then test on an emulator.

### 5.4 Windows CI job

**What:** add a `build-windows` job to `.github/workflows/ci.yml`. Needs: Windows runner (already in GH Actions matrix), MSVC 2022, CMake, Flutter Windows toolchain enabled. Build libwhisper + all sibling `.dll`'s; run `flutter build windows --debug`; bundle `.dll`'s into `build/windows/x64/runner/Debug/`.

**Risk:** medium. MSVC + ggml's SIMD headers can be fiddly; CrispASR CI already validates Windows builds, so cross-reference its config.

### 5.5 Real speaker diarization

**What:** upstream CrispASR needs a diarization API (pyannote-compatible embeddings + clustering) before we can drop the current MFCC/k-means fallback in `lib/services/diarization_service.dart`. When that lands, rewire via `CrispasrSession.diarize()` (TBD symbol).

**Risk:** high; blocked on upstream. Track via `CrispASR/TODO.md`.

### 5.6 Backend-specific UX

- **Canary / Voxtral:** source/target language pickers (currently the UI assumes Whisper's single `lang` field).
- **Voxtral / Granite:** `--ask` audio Q&A mode — a prompt field below the transcribe button, feed user text into the session's generation prompt.
- **Parakeet / FastConformer-CTC:** expose beam-search / best-of-N toggles where the backend supports them.

**Where:** `lib/screens/transcription_screen.dart` + `lib/engines/crispasr_engine.dart` (pass through to `CrispasrSession`).

### 5.7 Dependency refresh

37 packages have newer versions blocked by constraint overrides (`intl`, `material_color_utilities`, `record_linux`). Revisit after Flutter 3.39 lands: many of the overrides are there to paper over SDK transitions.

### 5.8 Release polish

- Tag-based code signing for macOS + notarization (currently ad-hoc sign only).
- Signed Android APK.
- Windows MSI / EXE installer.

---

## 6. Adding a new backend

Three-step recipe:

1. In `CrispASR/src/CMakeLists.txt`, in the *Dart FFI multi-backend linkage* section, add:
   ```cmake
   if (TARGET canary) target_link_libraries(whisper PUBLIC canary) endif()
   ```
2. Add a `#if __has_include("canary.h")` block to `CrispASR/src/crispasr_dart_helpers.cpp`, plus a `case "canary":` arm in `crispasr_session_open_explicit` and `crispasr_session_transcribe`.
3. `cmake --build build --target whisper` and copy both `libwhisper.dylib` + `libcanary.dylib` into the app bundle's `Contents/Frameworks/`.

CrisperWeaver picks up new backends automatically through `CrispasrSession.availableBackends()` — no Dart changes needed. If the user picks a backend the bundled libwhisper wasn't linked with, the load error names exactly which backends ARE available.

## 7. Server alternative (not used)

CrispASR also ships an HTTP server (`examples/cli/crispasr_server.cpp`) with `POST /inference`, `POST /v1/audio/transcriptions` (OpenAI-compatible), `POST /load`, `GET /backends`. Desktop builds *could* bundle the `crispasr` binary and spawn it in server mode. We don't — iOS can't spawn subprocesses, and FFI is the parity path for mobile. Leaving the note here in case a future desktop-only variant wants fewer dylibs and more process isolation.
