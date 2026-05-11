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

## 0. CrispASR 0.6.x parity sweep (May 2026) — ✅ shipped in v0.4.1

Six rounds of work between May 2026 brought CrisperWeaver up to
CrispASR 0.6.2 parity: 3 new screens (Translate, Voice Bake, Local
HTTP server), 8 new backends in the catalog, runtime-tunable
flash-attn / GPU layers / TTS sampling sliders, and 3 new export
formats. Released as
[v0.4.1](https://github.com/CrispStrobe/CrisperWeaver/releases/tag/v0.4.1)
paired with
[CrispASR v0.6.2](https://github.com/CrispStrobe/CrispASR/releases/tag/v0.6.2).

Full per-round write-up: **[HISTORY.md → "May 2026 parity sweep"](HISTORY.md)**.

**Still deferred** (each tracked upstream in `../CrispASR/PLAN.md`):

* **Wiring `flash_attn` into every backend's compute graph** — the
  toggle ships in the open-params struct (round 5) and threads
  through to each backend's session via the per-backend `flash_attn`
  field on context_params (round 6, closing CrispASR #89). Only
  whisper consumes it at the kernel level today. Tracked as
  **[CrispASR PLAN.md #86](https://github.com/CrispStrobe/CrispASR/blob/main/PLAN.md#86-per-backend-flash-attention-wiring-crisperweaver-driven)**
  — full per-backend status table, recipe, and recommended order
  (orpheus + chatterbox-T3 first; ~2–3 focused days for the full
  sweep).
* **`gpu_backend` selector** (metal / cuda / vulkan / cpu-only as a
  runtime string) — needs ggml-side multi-backend dispatch first.
  Tracked as
  **[CrispASR PLAN.md #87](https://github.com/CrispStrobe/CrispASR/blob/main/PLAN.md#87-gpu_backend-runtime-selector-multi-backend-ggml-build)**.

The OpenAI-compatible server item that was previously deferred is
SHIPPED as a Dart-side `shelf` server in round 5 (see HISTORY +
the §7 note below). The CrispASR-side `crispasr --server` binary
remains available as the desktop-only alternative.

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
| OmniASR (LLM)        | ✅       | ✅ via `CrispasrSession`          | Multilingual LLM-based ASR (300M)         |
| FireRed ASR2         | ✅       | ✅ via `CrispasrSession`          | AED Mandarin/English                       |
| Kyutai STT 1B        | ✅       | ✅ via `CrispasrSession`          | Streaming-style STT                        |
| GLM-ASR Nano         | ✅       | ✅ via `CrispasrSession`          | GLM-family multilingual                    |
| VibeVoice ASR        | ✅       | ✅ via `CrispasrSession`          | Large multilingual (~4.5 GB)               |
| MiMo ASR             | ✅       | ✅ via `CrispasrSession`          | XiaomiMiMo MiMo-Audio                      |

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
| Real speaker diarization (library API)     | ✅ via CrispASR 0.4.5 `crispasr_diarize_segments_abi` — `lib/services/diarization_service.dart` now calls the shared lib (energy / xcorr / vad-turns / pyannote). MFCC/k-means stopgap removed. |
| Language auto-detect for non-Whisper backends | ✅ via CrispASR 0.4.6 `crispasr_detect_language_pcm` — `LidService` (`lib/services/lid_service.dart`) runs whisper-tiny LID before session backends when the user picks "auto" and any multilingual whisper model is downloaded. |
| Word timestamps for LLM backends           | ✅ via CrispASR 0.4.7 `crispasr_align_words_abi` — `AlignerService` (`lib/services/aligner_service.dart`) runs canary-CTC / qwen3-fa as a post-step for qwen3 / voxtral / granite when the user has word-timestamps enabled and an aligner GGUF is on disk. |
| Punctuation restoration (FireRedPunc)      | ✅ via CrispASR 0.5.x `PuncModel` — `PuncService` (`lib/services/punc_service.dart`) plus an "Restore punctuation" toggle in Advanced Options. Loads `fireredpunc-*.gguf` lazily; silently no-ops when the model isn't downloaded. |
| Dynamic backend discovery from libcrispasr | ✅ `ModelService.refreshFromCrispasrRegistry()` — calls `CrispasrSession.availableBackends()` + `crispasr.registryLookup` per backend, merges every linked backend's canonical GGUF into the model picker without any CrisperWeaver code change. Runs on every Model Management screen open. |

---

## 5. Open roadmap items

### ~~5.1 Finish i18n~~ — **DONE → [HISTORY.md](HISTORY.md)**

### ~~5.2 iOS build verification~~ — **DONE → [HISTORY.md](HISTORY.md)** (audit + xcframework wiring; on-device verification still pending — see 5.22 below)

### ~~5.3 Android native-lib CI wiring~~ — **DONE → [HISTORY.md](HISTORY.md)** (real-ASR APK shipping in releases)

### ~~5.4 Windows CI end-to-end validation~~ — **DONE → [HISTORY.md](HISTORY.md)** (release.yml green; install-on-real-Windows verification still pending)

### ~~5.5 Real speaker diarization~~ — **DONE → [HISTORY.md](HISTORY.md)**

### ~~5.6 Backend-specific UX~~ — **DONE → [HISTORY.md](HISTORY.md)** (Q&A / source+target lang pickers / beam search / best-of-N)

### ~~5.7 Batch transcription~~ — **DONE in v0.1.4 → [HISTORY.md](HISTORY.md)**

### 5.8 Expose more CrispASR capabilities in Advanced Options

Shipped in v0.1.4 (first slice): **translate-to-English**, **beam search** toggle, **initial prompt** text field. Live in the Advanced Options → Advanced decoding block; applies to both single-file and batch runs.

Shipped in v0.1.7: **Skip silence (VAD)** toggle. Drives `CrispasrSession.transcribeVad` (session backends) and `TranscribeOptions.vad = true` (whisper) via the new v0.4.4 library C-ABI. Silero v6.2.0 GGUF is bundled as `assets/vad/silero-v6.2.0-ggml.bin` (~885 KB).

Shipped this session (v0.4.x prep):
- **Temperature** — slider 0.0–1.0 in Advanced Options, hidden on
  backends that don't honour `crispasr_session_set_temperature`
  (whisper, mimo-asr, wav2vec2, …); shown for canary, cohere,
  parakeet, moonshine. Greedy default (0.0). Threaded through
  TranscriptionService → TranscriptionEngine → CrispASREngine →
  `_session.setTemperature(t)` per-call so a previous non-zero value
  doesn't stick after the user drags back to 0.

Shipped after this session's CrispASR best-of-N landed
(`crispasr_session_set_best_of` + `TranscribeOptions.bestOf`):
- **Best-of-N** — slider 1–10 in Advanced Options, always visible.
  Whisper consumes via `wparams.greedy.best_of`; other backends
  loop externally and pick the highest-mean-confidence transcript
  (per CrispASR's C-side implementation). `bestOf=1` default = single
  decode (historical behaviour). Threaded through TranscriptionService
  → TranscriptionEngine → CrispASREngine, with `setBestOf` set on
  every dispatch so a previous non-1 value doesn't stick. The Dart
  wrapper's `setBestOf` method was added in this same change.
- **Source / target language** — target-lang dropdown shipped in an
  earlier slice; **source-lang dropdown now shipped** for every
  multilingual backend via the new
  `AdvancedOptions.sourceLanguageCapableBackends` set (strict superset
  of translation-capable, adds parakeet / mimo-asr / firered-asr /
  kyutai-stt / glm-asr / gemma4-e2b / omniasr-llm{,-unlimited} /
  moonshine). Hidden on English-only / non-ASR backends (wav2vec2,
  fastconformer-ctc, kokoro, orpheus, chatterbox, indextts,
  vibevoice-tts, pyannote, firered-punc, fullstop-punc). The pinned
  value flows through `CrispASREngine.transcribe` → both the per-call
  `language:` arg AND `session.setSourceLanguage(lang)` (defense-in-
  depth — empty value clears, `-2` rc is logged + swallowed for
  backends that don't honour the sticky setter at runtime).
- **Audio Q&A (`--ask`)** — shipped (the prompt field in Advanced).
- **Grammar (GBNF)** — Whisper-only, niche but valuable for
  structured output. **Deferred**: needs new CrispASR work, not just
  CrisperWeaver UI. Specifically:
  1. Promote `examples/grammar-parser.{h,cpp}` → `src/` so libcrispasr
     links it (currently CLI-only).
  2. New C-ABI `crispasr_session_set_grammar_text(s, gbnf, rule_name,
     penalty)` that calls `grammar_parser::parse` and stores the
     parsed `whisper_grammar_element` graph in the session.
  3. Thread the parsed rules into `wparams.grammar_rules` /
     `n_grammar_rules` / `grammar_rule` / `grammar_penalty` on every
     whisper transcribe dispatch.
  4. Dart binding `CrispasrSession.setGrammar(text, rule, penalty)`
     with the usual `providesSymbol` guard.
  5. CrisperWeaver UI: `grammarText` + `grammarRule` + `grammarPenalty`
     in `AdvancedOptions`, a multiline TextField gated on
     `_activeBackend() == 'whisper'`, plumbed through
     `CrispASREngine.transcribe`.
  6. Unit tests on both repos (Catch2 round-trip the parser + Flutter
     widget test on the visibility gate).
  Estimated effort: 2–3 days of careful work + new tests on both
  sides. Track here until prioritised; see also CrispASR PLAN.
- ✅ **Streaming on mic** — already wired. `lib/widgets/audio_recorder_widget.dart` exposes a "Stream" toggle: when on, `audioService.startStreamingRecording()` opens a live PCM stream into `engine.transcribeStream`, and each emitted segment overwrites the rolling text via `AppStateNotifier.replaceLiveStreamingText`. Whisper-only (others don't expose the streaming session API). Error dialogs localised in this session.
- **Auto-download default** — CrispASR's `-m auto` per backend.
  *Needs a design pass before becoming a dev task:* the model catalog
  has no `isDefault` flag, the Model Management list is per-quant not
  per-backend, and "smallest functional default" varies wildly
  (whisper-tiny works standalone; parakeet has one variant; kokoro
  needs a paired voicepack; voxtral-q4_k is gigabytes). Three plausible
  shapes — (a) a `recommendedDefault: true` flag on `ModelDefinition`
  + a "Recommended" badge in the cards, (b) a "Quick start" AppBar
  action with a curated bottom-sheet ("Whisper Tiny + parakeet + a
  kokoro voice"), (c) per-backend collapsible sections each with a
  "Download default" header button. Pick one before implementing.

**Where:** `lib/widgets/advanced_options_widget.dart` (new), swap the inline block in `transcription_screen.dart`. Also a new enum `EngineCapability { vad, beamSearch, bestOf, temperature, initialPrompt, translation, audioQA, grammar, streaming }` on `TranscriptionEngine` so the UI knows which controls to show.

**Risk:** low-medium. Each knob is independently wired — incremental shipping works. The FFI is already in place for most of these; we're adding surface, not behaviour.

### ~~5.11 LID + forced aligner wiring~~ — **DONE → [HISTORY.md](HISTORY.md)**

### ~~5.12 Punctuation restoration (FireRedPunc)~~ — **DONE → [HISTORY.md](HISTORY.md)** (`fullstop-punc` multilang variant added in the May 2026 sweep)

### ~~5.13 CrispASR registry discovery~~ — **DONE → [HISTORY.md](HISTORY.md)**

### ~~5.14 TTS integration~~ — **DONE → [HISTORY.md](HISTORY.md)** (4 backends pre-sweep + 5 more added in May 2026)

### ~~5.15 mimo-asr session dispatch~~ — **DONE → [HISTORY.md](HISTORY.md)**

### ~~5.17 Quality gate + integration tests~~ — **DONE → [HISTORY.md](HISTORY.md)**

### ~~5.18 Test-suite speed~~ — **MTLBinaryArchive done → [HISTORY.md](HISTORY.md)**; CoreML for whisper still open

In-app side and the persistent Metal pipeline cache are both
shipped now. **Persistent `MTLBinaryArchive` pipeline cache** landed
in CrispASR commit `2665b1e5` (PLAN #88 / CrisperWeaver §5.18):

* Cold start: 5888 ms whisper, 22.5 s wall (M1 Max,
  whisper-tiny + jfk.mp3)
* Warm start (cache complete): 370 ms whisper, 0.6 s wall — **38×
  speedup**

Auto-managed at `~/Library/Caches/ggml-metal/<device>.archive`
(~683 KB per device); env vars `GGML_METAL_PIPELINE_CACHE` (path
override) + `GGML_METAL_PIPELINE_CACHE_DISABLE=1` (opt out). Every
CrispASR consumer benefits — CLI, CrisperWeaver, the test sweep,
the OpenAI server. Full pre-sweep + benchmark detail in
[HISTORY.md](HISTORY.md).

**Still open**:

| Win | Projected speedup | Status |
|---|---|---|
| CoreML for whisper on Apple Silicon (`WHISPER_USE_COREML=1` build flag, ship paired `.mlmodelc`) | Whisper-tiny already 6 s; large-v3 → 2–3× | Deferred to a future CrispASR cycle |
| Re-download q4_k variants for vibevoice / orpheus | vibevoice 17:22 → ~4 min projected; orpheus 11:50 → ~5 min | Blocked on HF availability |

### ~~5.16 Build automation~~ — **DONE → [HISTORY.md](HISTORY.md)**

### ~~5.19 Real-time partial display during file transcribe~~ — **DONE → [HISTORY.md](HISTORY.md)** (chunked-whisper `onSegment` streaming wired through `AppStateNotifier.addSegment`)

### ~~5.20 Speaker name labels~~ — **DONE → [HISTORY.md](HISTORY.md)** (tap-to-rename chip + history-schema `speakerNames: Map<String, String>` with backward-compat loader)

### ~~5.21 Background download manager + Storage tab~~ — **DONE → [HISTORY.md](HISTORY.md)**

### 5.22 iOS feature parity verification — AUDIT DONE; ON-DEVICE PASS PENDING

**Static-audit fixes applied (no device needed):**
* CoreML companion download was gated `Platform.isMacOS` only;
  every modern iPhone has the Apple Neural Engine, so the
  `.mlmodelc` is just as load-bearing on iOS. Now fires for both
  (`lib/services/model_service.dart` near `_maybeFetchCoreMLCompanion`).
* `ios/Runner/Info.plist` had two booby-traps that would have made
  iOS launch noisy or unstable:
  - `NSExtension { NSExtensionPointIdentifier =
    com.apple.widgetkit-extension }` at the host-app level — that
    key only belongs in an extension target's Info.plist; in the
    main app it tells iOS to treat the host bundle as an extension.
    Removed.
  - `UIApplicationSceneManifest` referencing
    `$(PRODUCT_MODULE_NAME).SceneDelegate`, but no `SceneDelegate.swift`
    exists in the target. iOS 13+ would log a scene-connection failure
    and fall back to the AppDelegate path on every launch. Removed
    the manifest; a real `SceneDelegate.swift` has to land before we
    re-introduce it.
* The custom-models-dir picker is now hidden on iOS
  (`lib/screens/settings_screen.dart`). On the iOS sandbox an
  arbitrary host path is meaningless without security-scoped
  bookmarks; the default `<app-docs>/models/whisper_cpp/` is the only
  sane location until that flow is built.

**Still needs a real device:**

1. **Native library bundling.** ✅ DONE — verified end-to-end on this
   machine. Two new scripts wire it in:

   - `scripts/build_ios_xcframework.sh` — slim iOS-only build (device +
     simulator arm64 slices). The full upstream
     `CrispASR/build-xcframework.sh` builds 7 Apple platform slices in
     30–60 min and 7–20 GB of disk; this slim variant produces just the
     two iOS slices in ~1.5 min once the cmake configure has run, with
     the right CrispASR cmake flags discovered by trial:
     - `-DCRISPASR_WITH_ESPEAK_NG=OFF` — kokoro otherwise links against
       homebrew's macOS libespeak-ng, which doesn't satisfy iOS arm64
       at link time. Kokoro on iOS therefore can't phonemize (one of
       30+ backends affected; everything else works).
     - Default `-DCRISPASR_COREML=OFF` when `IOS_MIN_OS_VERSION < 14`
       (CoreML needs 14+). Bump the env var to enable.
     - The combine step globs `src/${release_dir}/lib*.a` to pull in
       all 30 per-backend static archives plus `libcrisp_audio.a`
       from its sibling build dir; without those we get linker errors
       for `_voxtral_init_from_file`, `_kokoro_init_from_file`, etc.
     - Dedup `.o` files by basename across archives: `moonshine` and
       `moonshine_streaming` both ship `moonshine-tokenizer.o`,
       which would otherwise cause duplicate-symbol errors at the
       `clang++ -dynamiclib -force_load combined.a` step. First lib
       wins (alphabetical order on the per-lib subdirs).

   - `scripts/wire_ios_xcframework.rb` — uses the xcodeproj Ruby gem
     (already on disk via CocoaPods) to add the xcframework as a
     linked + embedded framework on the Runner target, with
     `CodeSignOnCopy` so Xcode signs it during the build, and adds
     `$(PROJECT_DIR)/Frameworks` to FRAMEWORK_SEARCH_PATHS.
     Idempotent.

   Result: `flutter build ios --debug --no-codesign` produces a
   `Runner.app/Frameworks/crispasr.framework` (~4.8 MB stripped, dSYM
   separate) with `install_name = @rpath/crispasr.framework/crispasr`,
   which already matches the third candidate in `package:crispasr`'s
   `_libCandidates()`. `xcrun dyld_info -exports` confirms 322+
   exported symbols including `_crispasr_session_open`,
   `_kokoro_init_from_file`, `_voxtral_init_from_file`,
   `_whisper_init_from_file`. The xcframework itself is gitignored
   (regenerate via the build script); CI wires it via the new
   release.yml steps.

   Local rebuild after a CrispASR change:
   `bash scripts/build_ios_xcframework.sh && flutter build ios`
   (rerun `wire_ios_xcframework.rb` only if the pbxproj was wiped).
2. **Mic permission prompt.** First `record.hasPermission()` call must
   show the system mic prompt (`NSMicrophoneUsageDescription` is
   already set). Verify both initial-grant and "denied → re-enter
   Settings → toggle on" recovery.
3. **Streaming mic.** `AudioRecorder.startStream` with PCM16 @ 16 kHz
   is documented as iOS-supported but the macOS path is what's been
   exercised. Confirm chunks arrive at sub-second cadence and the
   live transcript heartbeat works.
4. **`just_audio` playback.** ✅ Configured —
   `_configureAudioSession()` in `lib/main.dart` calls
   `AudioSession.instance.configure(AudioSessionConfiguration.speech())`
   at startup (iOS/Android only). `speech()` is just_audio's
   recommended preset for transcription apps: `playAndRecord` +
   speaker override + bluetooth allow. Still needs on-device
   confirmation that recording-→-playback transitions are smooth.
5. **Background audio continuation.** `UIBackgroundModes = [audio]`
   is declared but only takes effect once an audio session is active.
   Verify that streaming mic survives a screen-lock.
6. **Share intake.** "Open in CrisperWeaver" from Files / Mail
   delivers a file path through `receive_sharing_intent`. Verify the
   path is readable (security-scoped) and the transcription screen
   picks it up.
7. **`FilePicker.pickFiles`** for "Open audio file" on the
   transcription screen — file_picker on iOS surfaces this through
   UIDocumentPicker and copies into a temp location; verify the
   returned path is openable by `just_audio`.
8. **CoreML companion .mlmodelc.** After the fix above, verify
   `getApplicationDocumentsDirectory()` returns a writable path on
   iOS for the unzip target, and that the companion actually loads
   (look for "Loading Core ML model" in the libwhisper logs).
9. **`PrivacyInfo.xcprivacy`.** App Store Connect rejects iOS uploads
   from May 2024 onwards that touch certain APIs without a privacy
   manifest *file* (the `NSPrivacy*` keys currently in `Info.plist`
   are ignored — they belong in a separate `PrivacyInfo.xcprivacy`).
   We use NSUserDefaults and FileTimestamp APIs, so add a manifest
   when prepping the first TestFlight build.

**Risk:** medium-high. Item 1 (xcframework bundling) is the only
launch-blocker; the rest are quality issues that surface in use.

### 5.23 Batch transcription — scale-out, parallelism, save / resume

**Status (May 2026):**

* ✅ **Q1 (foundation)** — per-job JSON persistence under
  `<app-docs>/batch/default/job-<id>.json`,
  `BatchPersistenceService` (cross-platform `dart:io` + path_provider,
  same pattern HistoryService ships on every platform),
  `BatchQueueNotifier` mirrors every mutation to disk, app-start
  hydration via `load()` in `main.dart`'s post-frame callback.
  Running-when-killed jobs demoted to queued. Per-job filesystem-op
  serializer keeps concurrent unawaited writes from racing each
  other's rename. 25 new tests.
* ✅ **Q3 (resume from checkpoint)** — append-only
  `<id>.ckpt.jsonl` written by the drain loop on every onSegment;
  `BatchJob.resumeOffsetSec` stamped at app-start from each
  leftover checkpoint's last segment endTime;
  `transcribeFile`/`engine.transcribe` gained an optional
  `startOffsetSec` that routes via `_runChunkedWhisper(firstChunk)`
  for whisper or `_trimLeadingSamples + shiftSegmentForResume` for
  the session path; drain loop replays checkpointed segments into
  AppState before dispatch so the user sees the recovered transcript
  prefix without a flash. setDone deletes the checkpoint. 9 new
  tests on the engine helper + load() hydration round-trip.

**Still open:**

* ✅ **Q1 sub-bullet: backend grouping reorder + duration pre-flight** —
  shipped. Opt-in `Settings.groupBatchByBackend`; the drain loop calls
  `reorderByGrouping()` at start when on, stable-sorting only queued
  jobs by `(backend, modelId, language, createdAt)` so running/done/
  error rows stay put. Duration probe via `AudioService.probeDuration`
  (header-only just_audio read; throwaway player so no playback
  conflict), wired through an injectable `durationProbe` parameter on
  `BatchQueueNotifier` so unit tests stay hermetic. Queue card shows
  the sum as a "~ Xm" badge — "~" prefix when some probes haven't
  returned, exact when all measured. 12 new tests.
* ⏳ **Q2 (parallel workers)** — Settings slider
  `Concurrent transcriptions: 1–4`, per-isolate
  `DynamicLibrary.open` + `CrispasrSession`; iOS clamp to 2 for
  memory budget. ~1–2 days.

**Q3 deferred sub-items:**

* Mid-batch backend swap awareness — when a resumed job's `backend`
  field doesn't match the currently-loaded model, the drain loop
  should silently load the right model rather than reusing the
  current session. Currently it just runs against whatever model is
  loaded.
* iCloud-backup exclusion on iOS for the `batch/` directory
  (`NSURLIsExcludedFromBackupKey`). Non-blocking; worst case today
  is a few KB of brief iCloud noise per in-flight job.
* Localised "recovered N interrupted job(s)" snackbar on app start.
  Currently the user just sees the queue card auto-populated with
  the demoted-to-queued jobs and has to hit Start. The log line
  `hydrated N job(s) from disk resumable=K` is informative for
  debugging but not user-facing.

**Original §5.23 design (for archive):**

The single-file batch queue from §5.7 (shipped v0.1.4) handles a
list of files serially with persisted progress. **The next slice
is about scale: large queues, parallel workers, and reliable
resume across crashes.** Three intertwined design questions; each
needs a decision before code.

#### Q1 — How do we handle *batches of tasks* effectively?

Today's model: `BatchQueueService` holds a `List<TranscriptionJob>`
in a Riverpod `StateNotifier`. Each job is queued → running → done
| error. Serial drain; the loaded model context is shared across
runs. Works fine for 5–20 files; falls over for:

* **100s of files** — UI lag from rebuilding the whole list on
  every progress tick; SharedPreferences blob grows past its
  practical limit (~2 MB per platform); memory pressure if results
  buffer in RAM.
* **Mixed durations** — a 4 h podcast holds up 20 voice memos
  behind it; user can't see "estimated done" without a length
  probe.
* **Heterogeneous backends** — a queue with whisper-en files +
  qwen3-asr Chinese files re-opens the session every job.

**Proposed shape**:
- Migrate `BatchQueueService` storage from SharedPreferences to a
  per-job JSON file under `<app-docs>/batch/<queue-id>/job-<n>.json`
  (mirrors the existing `<app-docs>/history/` layout). One small
  file per job; the index file just lists IDs + statuses + last-
  modified-at.
- Lazy load: keep only the visible window of jobs in memory; page
  in / out as the user scrolls. Riverpod selector keys per job so
  rebuilds are localised.
- Group jobs by `(backend, modelId, language)` so consecutive
  same-backend jobs reuse the loaded session; only swap the
  session when the key changes. Reorder a queue into "backend-
  bundles" on enqueue, opt-in via a Settings toggle (default off
  to preserve user-visible order).
- Pre-flight pass: probe each file's duration via the bundled
  miniaudio decoder (already used by `AudioService`), store on
  the job. Use the sum for a real ETA in the queue card.

#### Q2 — How do we run *parallel workers*?

CrispASR sessions aren't reentrant — concurrent FFI calls into one
`whisper_context` corrupt the decoder state. Two viable paths:

**Option A: one worker per Dart isolate, one session per isolate**.
- Each isolate `loadLibrary` + opens its own `CrispasrSession` for
  the same model. Memory cost: N × model size (whisper-tiny is
  74 MB, large-v3 is 3 GB, voxtral 4B is ~2 GB — 4 isolates × 3 GB
  is real money on a 16 GB Mac).
- Concurrency: 2–4 workers on M1/M2 typically saturate the GPU
  (Metal queue serialises kernels anyway), so the win is mostly
  CPU-side prefill + post-processing overlapping with the next
  file's decode.
- The CrispASR Dart binding's FFI lookups are per-DynamicLibrary so
  cross-isolate sharing of a single dylib reference needs
  `Isolate.run` carrying the `DynamicLibrary` handle, which Dart
  FFI does NOT support — each isolate has to `DynamicLibrary.open`
  its own handle. That's OK but it's a real cost on first spin-up.

**Option B: split work *within* one isolate via VAD chunking**.
- The session API supports VAD-sliced transcription that returns
  segments. For a 4 h file, we already chunk into 30 s windows
  serially. With chunk-level parallelism each window could go
  through a separate session in a separate isolate. Same memory
  cost as Option A but per-FILE, not per-QUEUE.

**Recommendation**: ship Option A (per-job worker) behind a
Settings slider `Concurrent transcriptions: 1–4`. Default 1
(today's behaviour); cap at 4 even on 32 GB hosts — beyond that
Metal queue contention dominates. Option B is a future
optimisation for ultra-long single files.

**Cross-platform**: works on macOS / Linux / Windows / Android (all
support multi-isolate FFI); iOS allows it too but the memory cap
is tighter — clamp to 2 workers on iOS regardless of the slider.

#### Q3 — Save / restore / resume across process restarts

Today: serialised `BatchJobState` per queue lets a closed-and-
reopened app pick up where it left off, but ONLY at file
granularity. Mid-file crashes restart the whole file.

**Proposed shape**:
- Per-job checkpoint file `<app-docs>/batch/<queue-id>/job-<n>.ckpt.json`
  storing `{lastCompletedSegmentEnd: 12.34, segments: [...]}`.
- The engine's `onSegment` callback is already wired; route each
  segment append into both the in-memory list AND an
  append-only `.ckpt.jsonl`-style file. Crash → next start finds
  the .ckpt, restarts the file from `lastCompletedSegmentEnd`
  using chunked-whisper's offset machinery (which already exists
  for >60 s files in `_runChunkedWhisper`).
- On successful job completion, delete the `.ckpt` and finalise
  the result into the history entry.
- New "Resume from crash" snackbar on app start when stale
  `.ckpt` files are detected; offer to resume or discard.

**Risks**:
- The "resume from offset" path only works for backends with
  monotonic time emission (whisper, parakeet, canary, cohere).
  LLM-based backends (voxtral, qwen3-asr, granite) emit one big
  segment — no useful resume granularity. Tier the resume offer
  per backend.
- The `.ckpt` file format needs a version field; bumping it
  requires migration code.

**Test strategy**:
- `batch_queue_service_test.dart` — round-trip a 50-job queue
  through save + load, assert order + status preserved.
- `batch_checkpoint_test.dart` — fake an `onSegment` stream that
  fires N segments then throws; assert the `.ckpt` contains the
  first N − 1, the resume restart begins at `segments.last.end`.
- Integration smoke (opt-in slow): real `transcribeFile` on a
  long WAV, kill the isolate mid-stream, restart, assert
  segment-count + final transcript match the uninterrupted run.

**Estimated effort**: ~3–4 days for Q1+Q3 (per-job JSON storage,
checkpoint file, resume UI, tests); Q2 (parallel workers) is its
own 1–2 days. Total ~1 week if both ship together.

**Risk**: medium. Mostly Dart-side work, no new FFI. The biggest
unknown is iOS memory pressure at 2 workers × voxtral-4B — needs
on-device validation before defaulting to anything > 1.

---

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

## 7. Server modes — built-in vs CrispASR-CLI

**Built-in** (round 5, May 2026): CrisperWeaver ships its own
Dart-side `shelf` HTTP server, toggleable from *Settings → Local
HTTP server*. Bound to `127.0.0.1:8765` by default. Exposes:

- `POST /v1/audio/transcriptions` (multipart upload, OpenAI-shaped
  json/text/srt/vtt response) — routes through the loaded ASR.
- `POST /v1/audio/speech` (JSON in, 24 kHz mono WAV out) — routes
  through `TtsService`.
- `POST /v1/translations` (JSON in, JSON out) — routes through
  `TextTranslationService`.
- `GET /health` (liveness check).

This is the parity path for both desktop and mobile (iOS can't
spawn subprocesses), and avoids loading two copies of every backend
into RAM.

**CLI alternative** (still available for advanced users): CrispASR
ships an HTTP server binary (`examples/cli/crispasr_server.cpp`)
with `POST /inference`, `POST /v1/audio/transcriptions` (OpenAI-
compatible), `POST /load`, `GET /backends`. Desktop builds *could*
bundle the `crispasr` binary and spawn it in server mode for users
who want process isolation or fewer dylibs. We don't bundle it —
the in-app server already covers the use case end-to-end.
