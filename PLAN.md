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

### 5.21 Background download manager + Storage tab

**What:** model downloads currently block on the main isolate (the
Dio Future runs on the platform thread, but `_dio.download` rebuilds
the UI per progress tick). On big models the UI stutters. Move
downloads to a worker isolate; the main thread just listens to a
progress stream. Plus add a "Storage" tab in Settings (or Models
header) that lists `[backend, size, count]` rows with per-backend
delete buttons.

**Where:** `lib/services/model_service.dart::downloadWhisperCppModel`
becomes the entry point that spawns an isolate; the existing
`_activeDownloads` map tracks the cancel tokens. Storage tab is a
new screen / dialog. ~1 day.

**Risk:** medium. Isolate ↔ main-thread message passing for download
progress; need to drop the Dio instance into the isolate (dio works
inside isolates per their docs).

### 5.22 iOS feature parity verification

**What:** most of what we built (streaming mic via `record`,
`FilePicker.getDirectoryPath`, `just_audio` playback, the .mlmodelc
bundle path) hasn't been verified on a real iOS device since the
v0.2.0 → v0.3.0 cycle. Spin up a sideload IPA, walk through every
screen, log the breakage, fix.

**Likely sore spots:**
* `record` package's `startStream` API differs across iOS ↔ macOS.
* `FilePicker.getDirectoryPath` is desktop-only on file_picker 11
  per their docs — needs a substitute on iOS (write to app sandbox
  + share via UIDocumentPickerViewController).
* CoreML `.mlmodelc` files need to be writable by the app sandbox
  on iOS; macOS's `<app-docs>/models/whisper_cpp/...` works but the
  iOS path resolution probably needs `getApplicationSupportDirectory`
  variants.
* The custom-models-dir setting probably should be hidden on iOS
  (sandbox doesn't allow arbitrary host paths).

**Where:** every service file that touches paths or platform APIs.
~1 day to test + fix.

**Risk:** medium-high. iOS surface always surprises.

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
