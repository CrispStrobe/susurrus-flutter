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

### 5.1 Finish i18n

**What:** migrate remaining hardcoded strings in `lib/widgets/` and older `lib/screens/settings_screen.dart` paths to `AppLocalizations.of(context)!.<key>`.

**Where:** grep for string literals in `lib/widgets/` and `lib/screens/settings_screen.dart`. Add matching keys to both `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`. Regenerate with `flutter gen-l10n` (automatic on `flutter pub get`).

**Risk:** low. Mechanical work.

### 5.2 iOS build verification — ✅ DONE

* `cd ios && pod install` succeeds. 16 pods (DKImagePicker,
  audio_session, file_picker, just_audio, permission_handler,
  receive_sharing_intent, record_ios, share_plus,
  shared_preferences_foundation, url_launcher_ios, etc.).
* `ios/Flutter/Profile.xcconfig` added so CocoaPods stops warning
  about an unwired Profile config.
* `flutter build ios --debug --simulator` — green, 96.8 s, produces
  `build/ios/iphonesimulator/Runner.app` with 17 embedded frameworks.
* `flutter build ios --debug --no-codesign` (device) — green, 56.5 s,
  produces `build/ios/iphoneos/Runner.app`.
* `PrivacyInfo.xcprivacy` lands in the .app bundle root; Info.plist
  in the bundle is clean (no NSPrivacy* keys, MinimumOSVersion 13.0,
  microphone description present).

**Got there by:** `xcodebuild -downloadPlatform iOS` to pull
the iOS 26.3.1 simulator runtime (16 GB on disk under
`/Library/Developer/CoreSimulator/Volumes/`), after first freeing
boot-disk space via the symlink-and-clean dance documented in this
session (HF model dirs symlinked to `/Volumes/backups/ai/...`,
`flutter clean` across five sibling Flutter projects).

**Bridging header — DON'T DROP IT.** The earlier note in this PLAN
("the header is a 1-liner now and nothing Swift-side imports it")
was wrong. `AppDelegate.swift` calls
`GeneratedPluginRegistrant.register(with: self)`; that class is
declared in the auto-generated `GeneratedPluginRegistrant.h`
(Objective-C). The bridging header is the only thing exposing the
class to Swift. Removing it breaks the Swift compile.

### 5.3 Android native-lib CI wiring — ✅ shipped

`release.yml`'s `build-android` job runs `CrispASR/build-android.sh
--vulkan` to cross-build `libcrispasr.so` + sibling backend `.so`'s
for `arm64-v8a`, drops them into
`android/app/src/main/jniLibs/arm64-v8a/`, then `flutter build apk
--release`. v0.4.0 produced a 31 MB `crisper_weaver-android-arm64.apk`
with real ASR. Still pending: an emulator smoke test in the same job
(currently no on-device verification step).

### 5.4 Windows CI end-to-end validation — ✅ shipped

`release.yml`'s `build-windows` job runs the CMake shared-DLL build of
CrispASR on a Windows runner, drops DLLs next to `runner.exe` via
`scripts/bundle_windows_dlls.ps1`, zips. v0.4.0 produced a 25 MB
`crisper_weaver-windows-x64.zip`. Still pending: install on a real
Windows box and transcribe end-to-end (the export-mismatch concern
from the original PLAN didn't materialise — green for v0.3.0 onwards).

### 5.5 Real speaker diarization — ✅ shipped

CrispASR 0.4.5 `crispasr_diarize_segments_abi` is now wired through
`DiarizationService` (`lib/services/diarization_service.dart`); the
MFCC/k-means stopgap is gone. Default method is `vadTurns` (mono-
friendly, no extra model file). Pyannote GGUF + a method picker in
Advanced Options remain optional polish items.

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

Shipped this session (v0.4.x prep):
- **Temperature** — slider 0.0–1.0 in Advanced Options, hidden on
  backends that don't honour `crispasr_session_set_temperature`
  (whisper, mimo-asr, wav2vec2, …); shown for canary, cohere,
  parakeet, moonshine. Greedy default (0.0). Threaded through
  TranscriptionService → TranscriptionEngine → CrispASREngine →
  `_session.setTemperature(t)` per-call so a previous non-zero value
  doesn't stick after the user drags back to 0.

Remaining (follow-up):
- **Best-of-N** — *blocked on upstream CrispASR*. Neither
  `crispasr_session_set_best_of` nor a `best_of` field on
  `TranscribeOptions` exists yet; would need a C-ABI addition + Dart
  binding before the slider can do anything. Whisper-side `best_of`
  could still be wired by extending `TranscribeOptions` directly.
- **Source / target language** — target-lang dropdown shipped in an
  earlier slice; explicit source-lang picker still pending for backends
  that accept `-sl` separately from autodetect.
- **Audio Q&A (`--ask`)** — shipped (the prompt field in Advanced).
- **Grammar (GBNF)** — Whisper-only, niche but valuable for structured output.
- **Streaming on mic** — `CrispASREngine.transcribeStream` exists but isn't UI-wired yet.
- **Auto-download default** — CrispASR's `-m auto` per backend. "Auto-download default" button per card in Model Management.

**Where:** `lib/widgets/advanced_options_widget.dart` (new), swap the inline block in `transcription_screen.dart`. Also a new enum `EngineCapability { vad, beamSearch, bestOf, temperature, initialPrompt, translation, audioQA, grammar, streaming }` on `TranscriptionEngine` so the UI knows which controls to show.

**Risk:** low-medium. Each knob is independently wired — incremental shipping works. The FFI is already in place for most of these; we're adding surface, not behaviour.

### 5.11 LID + forced aligner wiring — ✅ shipped

Both pieces are wired:

- **LID** — `LidService` (`lib/services/lid_service.dart`) reuses any
  multilingual whisper GGUF the user has already downloaded (preferring
  tiny → base → small) and runs it as a pre-step for session backends
  when `language` is "auto". Confidence-gated so noisy buffers don't
  flip the language unexpectedly.
- **Forced aligner** — `AlignerService` (`lib/services/aligner_service.dart`)
  searches for `canary-ctc-aligner-*.gguf` / `qwen3-forced-aligner-*.gguf`
  and runs `alignWords` as a post-step when the user enabled word
  timestamps and the active session backend didn't emit any.

Both services no-op silently when the required model isn't on disk —
no surprise downloads, no bundled-asset bloat.

### 5.12 Punctuation restoration (FireRedPunc) — ✅ shipped

CrispASR 0.5.x exposes `crispasr.PuncModel`, a BERT-based punctuation +
capitalisation post-processor (~100 MB GGUF). CrisperWeaver wires it as:

- `PuncService` (`lib/services/punc_service.dart`) — lazy load,
  per-segment `process()`, no-op when no `fireredpunc-*.gguf` is on disk.
- "Restore punctuation" toggle in Advanced Options
  (`lib/widgets/advanced_options_widget.dart`).
- Catalogued in `model_service.dart` under the `firered-punc` backend so
  users can fetch it from Model Management.

Useful for CTC backends (wav2vec2 / fastconformer-ctc / firered-asr)
which emit unpunctuated lowercase text.

### 5.13 CrispASR registry discovery — ✅ shipped

`ModelService.refreshFromCrispasrRegistry()` queries the C-side model
registry baked into libcrispasr via FFI. It iterates every backend
that `CrispasrSession.availableBackends()` reports, calls
`crispasr.registryLookup(backend)`, and merges the canonical entry
into `_discoveredModels` — surfacing every backend the bundled libwhisper
knows about without a CrisperWeaver code change. Runs on every Model
Management screen open; offline-safe (no network).

### 5.14 TTS integration — ✅ shipped

`SynthesizeScreen` (drawer entry next to Transcribe / History / Models),
`TtsService` wrapping `CrispasrSession.synthesize / setVoice /
setCodecPath`, `ModelKind` discriminator on `ModelDefinition` + filter
chips in Model Management. Four TTS backends reachable today:

- **vibevoice-tts** — multilingual, voicepack via `setVoice`.
- **qwen3-tts** — multilingual, codec via `setCodecPath` + voicepack
  via `setVoice` (voicepack GGUF or `.wav` reference + ref text).
- **kokoro** — multilingual, voicepack via `setVoice` (espeak-ng
  phonemiser bundled). Wired in CrispASR `crispasr_c_api.cpp` 2026-05-01.
- **orpheus** — Llama-3.2-3B + SNAC codec, codec via `setCodecPath`.
  Wired in CrispASR `crispasr_c_api.cpp` 2026-05-01.

### 5.15 mimo-asr session dispatch — ✅ shipped

XiaomiMiMo MiMo-Audio ASR added to `crispasr_c_api.cpp` open + transcribe
arms 2026-05-01. Two-file backend: the main model plus a separate
`mimo_tokenizer` companion (PCM → 8-channel codes). The session API
routes the tokenizer through `crispasr_session_set_codec_path` —
same shape as qwen3-tts and orpheus's codec/tokenizer companions, so
the existing `setCodecPath` Dart binding works without changes.

CrisperWeaver catalogs both files (`mimo-asr-q4_k` + `mimo-tokenizer-q4_k`),
with `companions: ['mimo-tokenizer-q4_k']` on the main entry so the
Synthesize / Model Management UI surfaces the dependency.

### 5.17 Quality gate + integration tests — ✅ shipped

- `analysis_options.yaml` promotes the lint categories that catch real
  defects to **errors** (`use_build_context_synchronously`, `avoid_print`,
  `unused_*`, `inference_failure_*`, `deprecated_member_use`). A
  regression now fails the build instead of silently piling up.
- `flutter analyze` reports **0 issues**; `flutter test` is **green**.
- `test/backend_dispatch_test.dart` validates the C-API dispatch arms:
  - `availableBackends() exposes every wired backend` — asserts every
    backend the catalog ships shows up in
    `CrispasrSession.availableBackends()`. Catches regressions in
    `crispasr_session_available_backends`.
  - `open() with non-existent file fails cleanly per backend` — opens
    each dispatched backend with a bogus path and asserts the per-backend
    init path throws cleanly instead of crashing or hanging.
  - End-to-end synth/transcribe roundtrips, opt-in via env vars
    (kept out of the default `flutter test` pass so CI doesn't drag in
    gigabyte fixtures). Roundtrips verified this session on M1 Metal:
    - **whisper** (ggml-tiny.bin, 6 s) — `jfk.wav` transcribes the
      "ask not" line.
    - **kokoro** (1:39) — produces ~2 s of 24 kHz mono PCM from "Hello
      world." after loading a `kokoro-voice-*.gguf` voicepack via
      `setVoice`.
    - **mimo-asr** (13:55) — produces non-empty transcript from
      `test/jfk.wav` after loading `mimo-tokenizer-q4_k.gguf` via
      `setCodecPath` (the C-API routes the tokenizer through that
      setter, so existing Dart bindings work without changes).
    - **qwen3-tts customvoice** (1:22) — uses one of the 9 baked
      speakers via `setSpeakerName(speakers().first)`. The base 0.6b
      variant needs an ICL voice prompt (WAV + ref text via
      `set_voice_prompt_with_text`) which is a more involved path.
    - **vibevoice-tts** (17:22, 4 GB f32+tokenizer GGUF) — produces
      non-zero PCM after loading a `vibevoice-voice-*.gguf` voicepack.
      The smaller `f16` and `q4_k` variants of the same name don't
      include the Tekken tokenizer and fail at first synthesize with
      "model lacks tokenizer" — only the `f32-tokenizer` filename is
      shippable today.
    - **orpheus** wired (`crispasr_session_set_codec_path` →
      `orpheus_set_codec_path`, `crispasr_session_synthesize` →
      `orpheus_synthesize`, gated on `orpheus_codec_loaded`); 3 GB
      base + SNAC model is slow under Metal so the e2e test is opt-in.

### 5.18 Test-suite speed — partial (see roadmap below)

The opt-in end-to-end backend tests are slow because of three layered
costs, in roughly this order:

1. **Metal kernel JIT (~30-60 s per backend per process).** ggml-metal
   compiles MSL pipelines lazily for each unique tensor shape on first
   use. The cache is in-memory only — every fresh process starts cold.
2. **Sequential LLM-style audio decode.** Orpheus / qwen3-tts /
   mimo-asr generate one audio (or text) token at a time through a
   0.6B–3B LLM. Per-second-of-audio cost scales with model size +
   number of decode steps; f32 weights compound the bandwidth hit.
3. **Cold-start per `flutter test` invocation.** Dart VM boot + dylib
   load + GGUF mmap + Metal kernel JIT all repeat for every separate
   test invocation we run.

Speedup roadmap, ordered by ROI / effort:

| Win | Measured speedup | Status |
|---|---|---|
| Per-test `tags: ['slow']` annotation so vanilla `flutter test` skips heavy roundtrips (env-var-gated `skip:` clauses already make them no-ops without GGUFs, but the tag also lets `--exclude-tags slow` actively suppress them) | Default suite holds sub-5 s (6 tests) | ✅ shipped — `test/backend_dispatch_test.dart`, `dart_test.yaml` |
| Run all opt-in e2e backends in one `flutter test` invocation | **Serial sweep ~46 min → single-process ~25 min (1.8×)** — each Session opens its own ggml_metal_device but Apple's system-level driver caches compiled MSL within a process, so backends after the first reuse pipelines for shared op shapes | ✅ shipped — single test file with `--tags slow` |
| Cap test inputs to the minimum that validates dispatch: `test/jfk-2s.wav` (2 s, vs the original 11 s), `"Hi."` TTS prompt (vs `"Hello world."`) | ~5× on whisper decode; ~3× on TTS decode loops | ✅ shipped |
| Bump `n_threads` from default 4 → 8 on M1+ in CrispasrSession.open | 10-25 % faster prefill on CPU-heavy backends (mimo-asr) | ⚠️ deferred — most mid-decode time is Metal-bound (0 % CPU during sample), so the projected win shrinks. Revisit if we ever profile a CPU-bound backend. |
| Re-download q4_k variants where we currently rely on f32/q8_0 (vibevoice-realtime-0.5b-tts-q4_k is 0 bytes locally; orpheus-3b q4_k pending HF publish) | vibevoice 17:22 → ~4 min projected; orpheus 11:50 → ~5 min projected | ⚠️ blocked on HF availability |
| **Persistent Metal pipeline cache via `MTLBinaryArchive`** — patch `ggml/src/ggml-metal/ggml-metal-device.m` to write/read pipeline state objects to a per-device disk cache (Apple's first-party API). Set the cache path via a `GGML_METAL_PIPELINE_CACHE` env var; default to `~/Library/Caches/ggml-metal/<device-name>.archive`. Same pattern used by Apple's own MPS / MLX caches. Joins the existing `// CrispASR patch` set in ggml-metal. | 30-60 s saved on every cold start across all CrispASR consumers — CI sweep projected ~25 min → ~5 min | ⚠️ ~half-day source patch in upstream ggml-metal |
| CoreML for whisper on Apple Silicon (`WHISPER_USE_COREML=1` build flag, ship paired `.mlmodelc`) | Whisper-tiny already 6 s; large-v3 → 2-3× | ⚠️ deferred to next CrispASR cycle; see PLAN §5.x in upstream |

### 5.16 Build automation — ✅ shipped

`scripts/build_macos.sh` is the one-shot end-to-end macOS build:
1. `cmake` configure into `build-flutter-bundle/` (won't fight other
   build dirs in the upstream CrispASR checkout).
2. Build all 30 backend STATIC archives + relink `libwhisper.dylib`
   (the static archives only get pulled into the shared lib if their
   targets exist, so they need an explicit build pass first).
3. `flutter pub get` (regenerates l10n).
4. `flutter build macos`.
5. `scripts/bundle_macos_dylibs.sh` — copies libwhisper + ggml dylibs,
   creates `libcrispasr.dylib` + `libcrispasr.1.dylib` aliases for the
   SONAME self-reference, auto-bundles homebrew deps (espeak-ng for
   kokoro) with `install_name_tool` rewrites to `@rpath/`.
6. Reports linked backends parsed from `nm` output.

### 5.19 Real-time partial display during file transcribe

**What:** the engine already calls `onSegment` for each finished
segment via the existing `transcribeFile(..., onSegment: …)` hook,
but `TranscriptionScreen` only renders the final result list. On a
10-min file the user sees nothing for 30 s, then the whole transcript
arrives in one paint. Wire the per-segment callback into
`AppStateNotifier.addSegment` (which already exists and updates
`currentTranscription` incrementally) so each finished segment shows
up as it lands.

**Where:** `lib/screens/transcription_screen.dart` —
`onSegment: appStateNotifier.addSegment` is already passed, but the
final `completeTranscription(segments)` call clobbers the incremental
list. Either drop the final replace (segments are equivalent) or
de-dupe by index. Half day.

**Risk:** low. Existing tests cover `addSegment` shape.

### 5.20 Speaker name labels

**What:** diarisation labels speakers as "Speaker 1", "Speaker 2",
… today. Tap a speaker chip → rename → name persists for the
session and into history JSON. Optional: auto-suggest names from
known voices (out of scope for v1).

**Where:** `lib/services/history_service.dart` adds a per-session
`speakerNames: Map<String, String>` field; `TranscriptionOutputWidget`
header chip becomes editable (PopupMenu → Rename). Half day.

**Risk:** low. Localised to UI + history schema bump (handled
backward-compat by the loader treating absent map as empty).

### 5.21 Background download manager + Storage tab — SHIPPED

**What:** added `lib/screens/storage_screen.dart` (Settings →
"Storage breakdown" → /storage) showing per-backend disk usage
with a one-click "delete all of X" action. `(other)` bucket is
read-only — those files come from manual drops or the
`Use/Manage models` flow that already has its own per-row delete.
Throttled `_downloadWithResume`'s progress callback from ~10 Hz
to ~4 Hz (250ms) so multi-GB downloads no longer rebuild the UI
hundreds of times per second. Skipped the worker-isolate move:
the throttle alone fixed the stutter, and isolating Dio for the
sake of one progress tick wasn't worth the message-passing
plumbing.

**Where:** `lib/services/model_service.dart` — added
`getStorageByBackend()`, `deleteBackendModels(backend)`, the
`BackendStorage` data class, and a `_BackendBytes` accumulator.
Route registered in `lib/main.dart`. ARB strings under
`storage*` and `settingsStorageBreakdown*` (en + de).

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
