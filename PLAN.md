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

Earlier §5.1–§5.7, §5.11–§5.21, §5.23, and most of §5.8 are
shipped — see [HISTORY.md](HISTORY.md) for full per-section
write-ups. What follows is only the work that's still pending.

### 5.1 Competitor-gap features

Audited against MacWhisper, Buzz, Aiko, Whisper Transcription
(local GUI peers) plus Otter.ai / Fireflies.ai / Descript (cloud)
in May 2026. CrisperWeaver already does most of what they do AND
several things they don't (engine breadth, cross-platform, free /
OSS, multilingual UI, text translation, OpenAI-compatible HTTP
server, parallel batch pool with OOM pre-flight). The list below
is what's missing — ranked by impact ÷ effort.

#### Tier A — high impact, moderate cost

* **5.1.1 System audio capture** — "Transcribe what's playing
  in Zoom / YouTube / any app." Cross-platform Dart interface +
  per-platform native implementations.
  - ✅ **macOS 13+** (May 2026) — ScreenCaptureKit-based,
    `SystemAudioCapture.swift` registered from
    `MainFlutterWindow.swift`. AVAudioConverter resamples to
    16 kHz mono Float32 inside the isolate; EventChannel
    delivers PCM frames to Dart. UI: new "screen-share" icon
    button in the audio recorder, greyed out on unsupported
    platforms. First use prompts for Screen Recording
    permission (TCC); `permission_denied` / `os_too_old` /
    `start_failed` rcs come back as typed exceptions
    (`SystemAudioPermissionException`,
    `SystemAudioUnsupportedException`) with localised
    snackbar messages in en + de.
  - ✅ **Linux** (May 2026) — `parec` subprocess against
    `@DEFAULT_SINK@.monitor`, asking PulseAudio for 16 kHz mono
    float32-le PCM directly so no Dart-side resampling. `parec`
    ships with `pulseaudio-utils` (Ubuntu/Debian/Fedora default
    install) or `pipewire-pulse` (Pipewire-based distros).
    Service does a one-shot `which parec` probe in `isSupported`
    and caches the answer; missing-tool case surfaces a typed
    `SystemAudioUnsupportedException` with an install hint.
  - ✅ **Windows** (May 2026) — `ffmpeg` subprocess using the
    `-f wasapi -i default` loopback (FFmpeg 5+). Requires the
    user to have ffmpeg on PATH; `where ffmpeg` probe caches
    the answer in `isSupported`. Missing-tool case surfaces a
    typed exception with `winget` / `choco` install hints.
    Native WASAPI plugin (~2 days) would remove the install
    dependency but isn't blocking — deferred follow-up.
  - ❌ **iOS** — Apple sandbox forbids system audio capture
    entirely. Throws `SystemAudioUnsupportedException`
    permanently.
  - ⏳ **Android** — MediaProjection API. Surfaces a
    system-visible "recording" indicator; the UX cost is real
    but the feature works. ~2–3 days.

* **5.1.2 Custom vocabulary / dictionary boost** — Persistent
  list of "always-recognize-these" terms (brand names, acronyms,
  technical jargon, people's names). Already plumbed through
  whisper's `initial_prompt` field; just needs a UI for managing
  the list + an `AdvancedOptions.vocabulary` array that gets
  joined into the prompt on every dispatch. MacWhisper Pro sells
  this as a paid feature. ~1 day.

* **5.1.3 Inline transcript editing** — Click a segment → edit
  text → re-save. The data model has it (segments are mutable),
  but no robust click-to-edit UI yet. Polished version with
  undo + auto-save: ~2 days. Every competitor has this.

* **5.1.4 History search** — Full-text search across past
  transcriptions. The JSON files are already there, just need a
  search index (fts5 via sqflite, or naive grep for small
  libraries). ~1 day.

#### Tier B — high impact, higher cost

* **5.1.5 Audio waveform visualization with segment sync** —
  Click a segment, waveform highlights; click waveform, scrubs.
  `waveform_flutter` exists but isn't great; might need a custom
  CustomPainter on top of `just_audio`'s PositionStream. ~3 days.
  Standard in Descript / MacWhisper.

* **5.1.6 LLM post-editing pass** — "Clean up this transcript"
  button that runs segments through a local LLM (capitalize,
  remove "um"s, fix obvious mishearings) OR via
  Anthropic/OpenAI API for cloud users. CrisperWeaver has audio-
  LLMs (voxtral, granite) but they're audio-instruction-tuned;
  a small text LLM (Qwen2.5-1.5B-Instruct, ~1 GB) added to the
  engine pool would be the right tool. ~3–4 days inc. UI.

* **5.1.7 Templates / presets** — Save current `(model,
  AdvancedOptions, export formats)` as named preset. "Podcast
  prep", "Voice memos", "Multilingual interview". ~1 day.
  Low-glamor, high power-user love.

#### Tier C — niche but cool

* **5.1.8 Meeting-style summarization** (action items / topics /
  decisions) — Same machinery as 5.1.6 with structured-output
  prompt templates. Requires 5.1.6 first.
* **5.1.9 Subtitle burning into video** — User selects a video
  file + transcript, gets a video with hardcoded subs. FFmpeg
  subprocess. ~1 day desktop-only.
* **5.1.10 Audio enhancement before transcribe** — Noise
  reduction (RNNoise FFI), dereverberation. Useful for bad
  recordings. ~2–3 days of FFI integration.
* **5.1.11 Hotkey / global shortcut** — "Push-to-transcribe from
  anywhere" via a system-level hotkey. `hotkey_manager` package
  exists. ~1 day desktop, no-op on mobile.
* **5.1.12 Voice cloning workflow** — Wizard "record 10s →
  clone" on top of existing chatterbox / indextts / qwen3-tts.
  ~2 days UX work; the engines are there.

#### Tier D — skip / wait for demand

* Cloud sync (high effort, splits the privacy story)
* Web UI on top of the HTTP server (desktop app covers this
  audience already)
* Final Cut / Premiere XML export (real niche)
* Voice commands during recording (low value vs. UX complexity)

### 5.8 Advanced-Options leftovers

Most of §5.8 is shipped — see [HISTORY.md → "Advanced Options
completeness — May 2026"](HISTORY.md). What's still pending:

* **GBNF (grammar-constrained sampling)** — Whisper-only, niche
  but valuable for structured output (force JSON / SKUs / phone-
  number shape). **Deferred**: needs new CrispASR work, not just
  CrisperWeaver UI. Six concrete steps:
  1. Promote `CrispASR/examples/grammar-parser.{h,cpp}` → `src/`
     so libcrispasr links it (currently CLI-only).
  2. New C-ABI `crispasr_session_set_grammar_text(s, gbnf,
     rule_name, penalty)` that calls `grammar_parser::parse` and
     stores the parsed `whisper_grammar_element` graph in the
     session.
  3. Thread the parsed rules into `wparams.grammar_rules` /
     `n_grammar_rules` / `grammar_rule` / `grammar_penalty` on
     every whisper transcribe dispatch.
  4. Dart binding `CrispasrSession.setGrammar(text, rule,
     penalty)` with the usual `providesSymbol` guard.
  5. CrisperWeaver UI: `grammarText` + `grammarRule` +
     `grammarPenalty` in `AdvancedOptions`, multiline TextField
     gated on `_activeBackend() == 'whisper'`, plumbed through
     `CrispASREngine.transcribe`.
  6. Tests on both repos.
  Estimated 2–3 days. Track here until prioritised; matching
  entry in CrispASR PLAN.

* **CrispASR CLI features missing from CrisperWeaver** — found
  during the §5.23 beam-search audit, listed here so the next
  parity pass doesn't have to rediscover them:
  - `--offset-t` / `--duration` — process only a [t0, t0+d)
    audio window. Useful for "transcribe minute 5–10 of this
    podcast." Needs engine-side slice + timestamp shift (same
    machinery as resume-offset, bilateral). ~1 day.
  - `--alt N` / `--alt-n` — alternative token candidates with
    probabilities. Power-user feature; needs C-ABI plumbing for
    alt-decoder output + UI. ~2 days.
  - Whisper decoder fallback thresholds (`--word-thold`,
    `--entropy-thold`, `--logprob-thold`, `--no-speech-thold`,
    `--no-fallback`, `--temperature-inc`) — already in the Dart
    binding, just not in the UI. ~half day to surface as
    Advanced Options rows + localised strings.
  - Subtitle line formatting (`--max-len`, `--split-on-word`,
    `--split-on-punct`) — already in whisper context-params;
    CrisperWeaver post-formats instead. ~1 day to wire through.
  - Token suppression (`--suppress-nst`, `--suppress-regex`),
    `--carry-initial-prompt`, `--print-confidence` — niche edge
    cases. ~1 hour each.

* **Auto-download default** — CrispASR's `-m auto` per backend.
  *Needs a design pass before becoming a dev task:* model catalog
  has no `isDefault` flag, Model Management is per-quant not
  per-backend, and "smallest functional default" varies wildly
  (whisper-tiny standalone; parakeet has one variant; kokoro
  needs a voicepack; voxtral-q4_k is gigabytes). Three plausible
  shapes — (a) `recommendedDefault: true` flag + "Recommended"
  badge, (b) "Quick start" AppBar bottom-sheet with curated
  combo, (c) per-backend collapsible sections each with a
  "Download default" header button. Pick one before implementing.

### 5.18 Test-suite speed — CoreML for whisper still pending

MTLBinaryArchive pipeline cache shipped (38× cold-start speedup)
— see [HISTORY.md](HISTORY.md).

**Still pending**:

| Win | Projected speedup | Status |
|---|---|---|
| CoreML for whisper on Apple Silicon (`WHISPER_USE_COREML=1` + paired `.mlmodelc`) | Whisper-tiny already 6 s; large-v3 → 2–3× | Deferred to a future CrispASR cycle |
| Re-download q4_k variants for vibevoice / orpheus | vibevoice 17:22 → ~4 min projected; orpheus 11:50 → ~5 min | Blocked on HF availability |

### 5.22 iOS on-device verification — pending

Static audit + xcframework bundling + plist cleanup all shipped
— see [HISTORY.md](HISTORY.md). What's left needs an iPhone:

1. **Mic permission prompt** — First `record.hasPermission()` must
   show the system mic prompt (`NSMicrophoneUsageDescription`
   already set). Verify initial-grant + "denied → Settings →
   toggle on" recovery.
2. **Streaming mic** — `AudioRecorder.startStream` with PCM16 @
   16 kHz is documented as iOS-supported but only the macOS path
   has been exercised. Confirm sub-second chunk cadence + live
   heartbeat.
3. **Recording → playback transitions** — `just_audio` configured
   with `AudioSessionConfiguration.speech()`; needs on-device
   confirmation that switching mic → file → mic is smooth.
4. **Background audio continuation** — `UIBackgroundModes =
   [audio]` declared; verify streaming mic survives screen-lock.
5. **Share intake** — "Open in CrisperWeaver" from Files / Mail
   delivers a path through `receive_sharing_intent`; verify the
   path is readable (security-scoped) and picked up correctly.
6. **`FilePicker.pickFiles`** — UIDocumentPicker copies to temp;
   verify the returned path is openable by `just_audio`.
7. **CoreML companion `.mlmodelc`** — verify
   `getApplicationDocumentsDirectory()` is writable for the
   unzip target and that the companion actually loads ("Loading
   Core ML model" in libwhisper logs).
8. **`PrivacyInfo.xcprivacy`** — required for App Store Connect
   uploads from May 2024. NSUserDefaults + FileTimestamp APIs
   used; add the manifest before first TestFlight upload.

**Risk:** medium-high. Item 1 (xcframework bundling) was the
only launch-blocker and is done. The rest are quality issues
that surface in use.

**Pre-existing detail on the xcframework bundling +
auto-fix audit:** [HISTORY.md → "iOS feature parity"](HISTORY.md).
### 5.23 Batch transcription — scale-out, parallelism, save/resume

✅ **Shipped May 2026.** All four sub-questions (Q1 foundation,
Q1 grouping + duration probe, Q2 v1 pipeline prefetch, Q2 v2
N-way session pool with OOM pre-flight + worker-protocol
expansion + drain-loop integration, Q3 resume-from-checkpoint,
Q3 polish) shipped end-to-end. Full per-step write-up in
[HISTORY.md → §5.23](HISTORY.md).

**Still pending — small CrispASR-side follow-up:**

* Beam search via session API for granite / voxtral / qwen3 —
  six of eleven beam-capable backends are wired (whisper +
  kyutai-stt / moonshine / omniasr-LLM / glm-asr / firered);
  the remaining three need their per-backend high-level
  transcribe APIs to expose beam_size before
  `crispasr_session_set_beam_size` can plumb through. Their
  beam decode currently lives in CLI wrappers using
  `core_beam_decode::run_with_probs`. ~1–1.5 days total
  across the three families. Tracked as
  [CrispASR PLAN §90](https://github.com/CrispStrobe/CrispASR/blob/main/PLAN.md).

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
