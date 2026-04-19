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
| Windows  | ✅    | Released via `release.yml`; `.zip` with `whisper.dll` + sibling backend DLLs produced on every tag. Still `continue-on-error` until a user confirms the runtime works on a real Windows machine. |
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
| VAD (Silero) — end to end                  | ✅ shipped in v0.1.7 via CrispASR 0.4.4 `crispasr_session_transcribe_vad`; single Advanced Options toggle, Silero GGUF bundled as asset, whisper + session paths both wired |
| Streaming transcription (Whisper)          | ✅ via CrispASR 0.3.0 `crispasr_stream_*` — 10s window / 3s step       |
| i18n (en + de)                             | ⚠️ Scaffold via `flutter_localizations` + `lib/l10n/*.arb`; main screens migrated, widgets + older Settings strings still hardcoded |
| Real speaker diarization (library API)     | ⚠️ Unblocked by CrispASR 0.4.5 `crispasr_diarize_segments_abi` (energy / xcorr / vad-turns / pyannote). Current in-app MFCC/k-means stopgap still in `lib/services/diarization_service.dart` — swap to the lib call is pending wiring work |
| Language auto-detect for non-Whisper backends | ⚠️ Unblocked by CrispASR 0.4.6 `crispasr_detect_language_pcm` (whisper-tiny + silero-native). Not wired in UI yet |
| Word timestamps for LLM backends           | ⚠️ Unblocked by CrispASR 0.4.7 `crispasr_align_words_abi` (canary-CTC / qwen3-fa). Not wired for qwen3 / voxtral / granite yet |

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

### 5.5 Real speaker diarization — unblocked

**What:** CrispASR 0.4.5 shipped `crispasr_diarize_segments_abi` with four methods (energy, xcorr, vad-turns, native pyannote GGUF). The Dart binding in `package:crispasr` 0.4.5 exposes it as a top-level `diarizeSegments({...})` helper returning `List<DiarizeSegment>`.

**Remaining work:**
1. Wire `diarizeSegments` in `lib/services/diarization_service.dart` — call it after `CrispASREngine.transcribe()` returns. Pass the original PCM + segment timings, receive per-segment speaker indices back.
2. Default method: `pyannote` when we have a GGUF on disk (bundle the 5 MB `pyannote-v3-seg.gguf` as an asset the same way we bundle `silero-v6.2.0-ggml.bin` for VAD), falling back to `vadTurns` otherwise. On stereo input, use `energy` or `xcorr`.
3. Delete `_mfccFeatures()` / `_kMeansCluster()` from `diarization_service.dart`; these were the stopgap that's no longer needed.
4. Add a method picker in Advanced Options (matching the VAD pattern from v0.1.7).

**Where:** `lib/services/diarization_service.dart`, `lib/widgets/advanced_options_widget.dart`, `assets/diarize/` + `pubspec.yaml`.

**Risk:** medium. The library call is fast (energy / vad-turns are µs; pyannote is ~50 ms per segment on CPU) but our current output format needs to be preserved — the UI's speaker coloring keys on zero-based ints, which is already what the lib returns.

### 5.6 Backend-specific UX

- **Canary / Voxtral:** source/target language pickers (currently the UI assumes Whisper's single `lang` field).
- **Voxtral / Granite:** `--ask` audio Q&A mode — a prompt field below the transcribe button, feed user text into the session's generation prompt.
- **Parakeet / FastConformer-CTC:** expose beam-search / best-of-N toggles where the backend supports them.

**Where:** `lib/screens/transcription_screen.dart` + `lib/engines/crispasr_engine.dart` (pass through to `CrispasrSession`).

### 5.7 Batch transcription ✅ shipped in v0.1.4

Let the user drop/pick multiple files at once and process them in a queue. Results become separate history entries; overall progress + per-item progress both visible.

**Design:**
- File picker and `desktop_drop` already support multi-select / multi-drop. Change `_selectedFilePath` in `transcription_screen.dart` to a `List<String>` plus an active-index pointer.
- Introduce `TranscriptionJob` (filePath, status = queued|running|done|error, progress, result). Queue lives in a Riverpod `StateNotifier` so the UI can watch and the engine worker can advance it.
- Serialize: one transcription at a time to share the loaded model's context — concurrent FFI calls into the same whisper_context are unsafe. If we want parallelism, it'd be one isolate per file each holding its own context (memory-expensive for Whisper-large).
- UI: a new `BatchQueueCard` above the current transcription output, showing a list with `[filename · progress · status · delete]` rows. Individual completion streams into the existing TranscriptionOutput widget; "Export all" emits one ZIP of SRT/TXT files.
- Persistence: save `BatchJobState` to SharedPreferences so a user can close the app mid-batch and resume.

**Where:** new `lib/services/batch_queue_service.dart`, new `lib/widgets/batch_queue_card.dart`, mods to `lib/screens/transcription_screen.dart`.

**Risk:** medium. Handling large queues (100s of files at hours each) means we need to stream history writes, not buffer in RAM, plus clean error recovery (OOM on one file shouldn't kill the whole queue).

### 5.8 Expose more CrispASR capabilities in Advanced Options

Shipped in v0.1.4 (first slice): **translate-to-English**, **beam search** toggle, **initial prompt** text field. Live in the Advanced Options → Advanced decoding block; applies to both single-file and batch runs.

Shipped in v0.1.7: **Skip silence (VAD)** toggle. Drives `CrispasrSession.transcribeVad` (session backends) and `TranscribeOptions.vad = true` (whisper) via the new v0.4.4 library C-ABI. Silero v6.2.0 GGUF is bundled as `assets/vad/silero-v6.2.0-ggml.bin` (~885 KB).

Remaining (follow-up):
- **Best-of-N** — LLM backends (Voxtral/Qwen3/Granite) support it; Whisper has `best_of`. One slider.
- **Temperature** — `crispasr_params_set_temperature`. Greedy default; 0.2–1.0 useful for noisy audio where greedy hallucinates.
- **Source / target language** — Canary, Voxtral, Qwen3 support translation via `-sl / -tl`. UI switches from one `language` dropdown to two when the selected backend advertises translation capability.
- **Audio Q&A (`--ask`)** — Voxtral and Qwen3 answer free-form questions about audio. Prompt box below Transcribe, active only when the backend supports it.
- **Grammar (GBNF)** — Whisper-only, niche but valuable for structured output.
- **Streaming on mic** — `CrispASREngine.transcribeStream` exists but isn't UI-wired yet.
- **Auto-download default** — CrispASR's `-m auto` per backend. "Auto-download default" button per card in Model Management.

**Where:** `lib/widgets/advanced_options_widget.dart` (new), swap the inline block in `transcription_screen.dart`. Also a new enum `EngineCapability { vad, beamSearch, bestOf, temperature, initialPrompt, translation, audioQA, grammar, streaming }` on `TranscriptionEngine` so the UI knows which controls to show.

**Risk:** low-medium. Each knob is independently wired — incremental shipping works. The FFI is already in place for most of these; we're adding surface, not behaviour.

### 5.11 LID + forced aligner wiring — newly unblocked

CrispASR 0.4.6 (`crispasr_detect_language_pcm`) and 0.4.7
(`crispasr_align_words_abi`) shipped the same week as 0.4.5's
diarization API. Both are exposed as top-level Dart functions in
`package:crispasr` 0.4.8. Two separate pieces of work:

**LID (v0.4.6):** when the user selects a non-Whisper backend and leaves `language` on "auto", we currently fall through to whatever the backend does (some — cohere, granite — force English; others — voxtral — default to English too). Instead, run `detectLanguagePcm(pcm, method: LidMethod.whisper, modelPath: ggmlTinyPath)` as a pre-step to fill `language` before dispatching to the session transcribe. Needs `ggml-tiny.bin` (75 MB) bundled as an asset or auto-downloaded at first use.

**Forced aligner (v0.4.7):** qwen3, voxtral, voxtral4b, granite don't emit word-level timestamps natively. Use `alignWords(alignerModel: canaryCtcPath, transcript: fullText, pcm: pcmBuffer)` as a post-step when the user has "word timestamps" enabled and the active backend doesn't produce them. Canary-CTC-aligner GGUF (~60 MB) bundled or downloaded on demand.

**Where:** `lib/engines/crispasr_engine.dart` gets a new pre-step hook + a new post-step hook. `lib/services/vad_service.dart` pattern of "extract-GGUF-asset-on-first-use" is the template; mirror it in a new `LidService` and `AlignerService`.

**Risk:** low. Both are optional — if the asset isn't present we skip the step gracefully. Biggest cost is disk (75 MB whisper-tiny + 60 MB canary-ctc = ~135 MB app bundle bump), so we'd likely leave these as opt-in downloads rather than bundled assets.

### 5.9 Dependency refresh

37 packages have newer versions blocked by constraint overrides (`intl`, `material_color_utilities`, `record_linux`). Revisit after Flutter 3.39 lands: many of the overrides are there to paper over SDK transitions.

### 5.10 Release polish

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
