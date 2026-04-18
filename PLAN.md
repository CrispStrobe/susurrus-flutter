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

Two engines behind the `TranscriptionEngine` interface (`lib/engines/transcription_engine.dart`):

| Engine            | State                                                                      |
| ----------------- | -------------------------------------------------------------------------- |
| `CrispASREngine`  | ✅ Primary. Dart FFI to `libcrispasr` / `libwhisper`. Dispatches across all 10 backends via `CrispasrSession`. |
| `MockEngine`      | ✅ Deterministic fake responses — used for UI work and CI.                 |

Earlier prototypes had separate `WhisperCppEngine` and `CoreMLEngine` values (method-channel wrappers). Dropped: whisper.cpp ships inside CrispASR, and CoreML acceleration will land as an opt-in inside libwhisper (`WHISPER_USE_COREML`) rather than a separate engine. `EngineType.sherpaOnnx` was dropped earlier for being a placeholder.

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
| Windows  | ⚠️    | Flutter runner scaffold + CI job + `scripts/bundle_windows_dlls.ps1` all in place. Job is `continue-on-error` in `release.yml` until CrispASR's shared-DLL build is verified end-to-end (upstream CI only tests static libs). |
| Android  | ⚠️    | KTS gradle only (Groovy + legacy CMakeLists removed). APK builds with Mock engine out of the box; real ASR needs `libwhisper.so` cross-built via `CrispASR/build-android.sh` and dropped into `android/app/src/main/jniLibs/<abi>/`. That wiring isn't automated in CI. |
| iOS      | ⚠️    | Podfile rewritten to a clean minimal Flutter template. `pod install` should now succeed, but hasn't been CI-verified; the Xcode project still contains a Runner-Bridging-Header.h reference that's now a no-op. |

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

### 5.2 iOS build verification

**What:** the Podfile's been rewritten to a clean minimal Flutter template; `pod install` should now succeed. Still unverified:

- `cd ios && pod install` on a Mac with CocoaPods installed.
- `flutter build ios --debug --no-codesign` to confirm the Runner target still links.
- Drop the orphan `Runner-Bridging-Header.h` reference in `ios/Runner.xcodeproj/project.pbxproj` — the header is a 1-liner now and nothing Swift-side imports it. Keeping it wired is a no-op but cleaner to remove.

**Risk:** low.

### 5.3 Android native-lib CI wiring

**What:** Gradle is pure KTS; APK builds with the Mock engine. To ship real ASR on Android, CI needs to:

1. Checkout CrispASR (already done by the other CI jobs).
2. Run `CrispASR/build-android.sh --vulkan` inside the runner to cross-build `libwhisper.so` + sibling backend `.so`'s for `arm64-v8a` (and optionally `x86_64` for emulator testing).
3. Copy the `.so`'s to `android/app/src/main/jniLibs/arm64-v8a/`.
4. `flutter build apk --release`.

Where: add a new `build-android-native` job to `.github/workflows/release.yml` (or extend the existing one in `ci.yml`). The KTS already packages whatever's in `jniLibs/`.

**Risk:** medium. Android NDK cross-builds are slow (~15-30 min); may want to cache the `.so`'s keyed on `CRISPASR_REF`.

### 5.4 Windows CI end-to-end validation

**What:** CI job, bundler script, Flutter scaffold — all in place. Release workflow runs CMake shared-DLL build of CrispASR on a Windows runner, drops DLLs next to `runner.exe` via `scripts/bundle_windows_dlls.ps1`, zips. Marked `continue-on-error` because CrispASR's upstream CI only exercises the STATIC lib path (`-DBUILD_SHARED_LIBS=OFF`) — our `-ON` build may hit symbol-export issues we haven't yet seen.

**Remaining:** watch the first green run, verify `whisper.dll` contains all needed exports (`whisper_init_from_file_with_params`, `crispasr_session_open_explicit`, `crispasr_audio_load`, …), install on a real Windows box, transcribe. If export-mismatch: add explicit `__declspec(dllexport)` to the whisper.h decls.

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
