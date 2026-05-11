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

Audited against the common feature set of comparable local
GUI tools (whisper-based desktop apps for macOS / Linux /
Windows) plus the cloud meeting-transcription category, in
May 2026. CrisperWeaver already does most of what they do AND
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
  - ✅ **Android 10+** (May 2026) — `MediaProjection` +
    `AudioPlaybackCaptureConfiguration` via a foreground
    service (`SystemAudioCaptureForegroundService.kt`). On
    `start()` the activity launches the system
    "screen + audio capture" permission dialog; on grant the
    foreground service spins up with a persistent
    `mediaProjection`-type notification (required by Android 14)
    and an `AudioRecord` configured at 16 kHz mono Float32 (the
    framework resamples internally). PCM frames flow back to
    Dart via a static frame-listener callback (same-process, no
    AIDL) → EventChannel sink. Captures `USAGE_MEDIA`,
    `USAGE_GAME`, `USAGE_UNKNOWN` (covers music, video, games,
    most apps) but deliberately excludes
    `USAGE_VOICE_COMMUNICATION` so Zoom/phone-call audio gets
    captured via system speaker output rather than the more
    invasive direct path. New permission:
    `FOREGROUND_SERVICE_MEDIA_PROJECTION` in manifest.

* ✅ **5.1.2 Custom vocabulary / dictionary boost** (May 2026)
  — Persistent chip list in Advanced Options. The biasing
  mechanism is per-backend-class:

  | Class | Mechanism | Models |
  |---|---|---|
  | Whisper-style | `initial_prompt` prefill | whisper, moonshine |
  | LLM-backend | `setAsk(prompt)` prefix | voxtral, voxtral4b, qwen3, granite, granite-4.1{,-plus}, glm-asr, kyutai-stt, gemma4-e2b, omniasr-llm{,-unlimited}, mimo-asr |
  | CTC-style | Not supported (no token-prefill point) | parakeet, canary, cohere, fastconformer-ctc, wav2vec2, firered-asr, omniasr-CTC |

  How it works: new `AdvancedOptions.vocabulary: List<String>`
  field with copyWith roundtrip; new
  `AdvancedOptions.vocabularyViaInitialPromptBackends` and
  `vocabularyViaAskPromptBackends` capability sets; new
  static `mergeVocabularyIntoPrompt(backend, vocab, existing)`
  helper that prepends `"Vocabulary: term1, term2, …. "` to
  the existing prompt iff the backend supports it (else
  returns existing unchanged — defense-in-depth against the
  caller forgetting to gate on the capability set).

  The drain loop's three call sites (single-file, batch
  serial, batch pool) all resolve the active backend via a
  new `_resolveBackend(modelId)` helper and call the merge
  separately for `initial_prompt` vs `askPrompt` per the
  capability set. CTC-class backends silently get the user's
  original prompts unchanged.

  UI: `_buildVocabularyRow` adds a TextField + add-button +
  Wrap of InputChips. Helper text changes between three
  variants per backend class:
    - "Biases the decoder via Whisper's initial_prompt …" for
      whisper / moonshine
    - "Biases the LLM by prepending … Combined with Q&A — your
      question still runs." for LLM backends
    - "The active backend is CTC-style and can't bias
      vocabulary at the decoder. Switch to …" for CTC, with the
      input + chip-delete disabled.

  11 new tests pin the capability-set membership, the
  CTC exclusion, copyWith roundtrip, and the merge formatter's
  6 edge cases (empty vocab, CTC backend, whisper+existing,
  whisper-alone, LLM, whitespace-filter, all-whitespace).

* ✅ **5.1.3 Inline transcript editing** (May 2026) — long-press
  on a segment in `transcription_output_widget.dart` opens a
  bottom-sheet → "Edit segment" → dialog with a multiline
  TextField pre-filled with the current text. On save:
  `AppStateNotifier.editSegment(index, newText)` updates the
  in-memory state with `metadata['edited'] = true` (rendered as
  a tiny pencil icon next to the segment), and if the
  transcription has a saved history id we also fire
  `historyService.update(entry)` so the edit survives a reload.
  New `HistoryService.update(HistoryEntry)` method; new
  `AppState.historyEntryId` field stashed by the transcription
  screen after the first save; `startTranscription()` rebuilds
  AppState from scratch so a fresh run can't overwrite the
  previous entry. 2 new HistoryService tests pin the update /
  missing-id-noop contract.

* ✅ **5.1.4 History search** (May 2026) — text field in the
  HistoryScreen AppBar. Filters entries client-side by
  case-insensitive substring match against the entry's title
  (source filename or URL) AND its full transcript. Matching
  entries auto-expand so the user sees the hit without an extra
  tap; matched substrings show a yellow highlight in both the
  title row and the transcript body via `TextSpan.rich` +
  `SelectableText.rich`. Per-search count strip ("N of M
  matched") above the list when a query is active. ARB strings
  for hint / no-results / match-count in en + de.

#### Tier B — high impact, higher cost

* **5.1.5 Audio waveform + editor with bidirectional transcript
  sync** — A dedicated `EditAudioScreen` with a waveform
  painter, transport (play/pause/scrub), three editing
  operations (trim / cut middle / split into chapters), AND an
  optional collapsible transcript pane on the same screen so
  bidirectional sync stays visible without overlay-stacking.

  Output is 16 kHz mono PCM WAV (matches the transcription
  input format so "crop then transcribe" is a single
  hand-off). Reached from the transcription screen's "more
  actions" menu.

  **Layout:**

  ```
  +-------------------------------------------------------+
  |  Edit audio              [Save as] [Show transcript ▾] |
  +-------------------------------------------------------+
  |  [waveform — playhead + markers + selection band]     |
  |  |xx.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx| |
  |  ▶ ⏸ ⏹        00:12 / 04:32                           |
  |  [Trim] [Cut middle] [Split] [Selection: 12s – 48s]  |
  +-------------------------------------------------------+
  | ▼ Transcript (collapsible — toggle in AppBar)         |
  |   [00:00] Speaker 1: foo bar baz                      |
  |   [00:12] Speaker 2: hello world ← currently playing  |
  |   [00:24] Speaker 1: another segment                  |
  +-------------------------------------------------------+
  ```

  **Cross-sync (bidirectional):**
    - Click a segment in the transcript pane → seek the
      waveform playhead to that timecode.
    - Drag-select multi-segment passage in the transcript →
      that range becomes the active selection in the waveform
      editor (drives trim / cut-to-this-region / export).
    - Mark segments for cutting in the transcript → cut markers
      populate with the corresponding audio timecodes.
    - Click on the waveform → scroll the transcript to + highlight
      the segment whose `[start, end]` contains that time;
      the currently-playing segment is always highlighted as
      the playhead moves.

  Why one screen instead of separate-views-with-nav-args: the
  bidirectional click-sync workflow is too noisy if the user
  has to navigate back-and-forth to see the other side. The
  collapsible transcript pane keeps the editor uncluttered for
  pure-audio editing (collapse the pane) and stays useful when
  the user wants both views (expand). Pane state persists
  across navigation via Settings.

  Implementation phases:
    A. ✅ `AudioEditService` + WAV encoder + tests (Dart-only,
       no UI) — May 2026.
    B. ✅ Waveform `CustomPainter` + `EditAudioScreen` shell
       with transport + the three ops (no transcript pane
       yet) — May 2026.
    C. ✅ Collapsible transcript pane on the same screen +
       both directions of click-sync. Pane visibility persists
       via `Settings.editAudioShowTranscript` — May 2026.
    D. ✅ Transcript-screen entry points: "Edit this segment in
       audio editor" + "Mark for split in audio editor" actions
       in the segment long-press menu. Push the
       `/edit-audio?path=…&start=…&end=…` or `…&mark=…` route;
       the editor seeds the waveform selection / cut marker
       from the query params, force-opens the transcript pane,
       and parks the playhead at the seeded start so the user
       can play-preview immediately — May 2026.

  Phase A is shipped — pure-Dart service supporting trim() /
  cut() / split() with sample-accurate slicing of the source
  audio via the existing `crispasr.decodeAudioFile` FFI
  decoder. WAV output is bit-perfect at the boundary: Float32
  PCM clipped to ±1.0, encoded as Int16 little-endian, standard
  RIFF/WAVE/fmt/data header. 5 tests pin header bytes +
  clipping + DecodedSource.secondsToSample math.

  **No FFmpeg dependency anywhere in the editor flow.** Decoding
  is via miniaudio (bundled inside libcrispasr — handles WAV /
  MP3 / FLAC / Ogg / Opus natively across every supported
  platform); editing is pure Dart on Float32 buffers; encoding
  is the hand-rolled WAV encoder above; rendering is a Flutter
  `CustomPainter`. All five platforms (macOS / Linux / Windows /
  Android / iOS) run the identical code path. The one place
  CrisperWeaver shells out to FFmpeg is Windows-only system
  audio capture (§5.1.1), which is a separate feature and
  tracked for replacement with a native WASAPI plugin.

* **5.1.6 "Tidy transcript" deterministic pass — shipped May
  2026.** Pure-Dart `TranscriptCleanupService` runs over every
  segment in AppState:
    - removeFillers — strip um/uh/ah/etc. (per-language default
      set + custom additions, case-insensitive, word-boundary
      matching so "Hummingbird" survives).
    - collapseRepeats — "the the cat" → "the cat", repeat-
      replace until stable for runs.
    - normalizeWhitespace — multi-space → one, trim,
      strip-space-before-punctuation.
    - fixPunctuation — `..` → `.` (preserves three-dot
      ellipsis), `,,` → `,`, `,.` → `.`.
    - sentenceCase — capitalise after `.`/`?`/`!`, unicode-
      aware (über → Über), skips content inside `[]`/`()`/`<>`.
    - stripAnnotations — off by default (accessibility), strips
      `[laughter]`/`(applause)`/`<noise>` on opt-in.
  Reached from the transcript more-actions menu → "Tidy
  transcript…" → dialog with toggles + custom-fillers field +
  before/after preview of the first three segments → "Apply to
  all". Applied edits persist via the existing
  `AppState.editSegment` + HistoryService.update path so the
  edits survive a reload. 33 hermetic tests pin each transform
  individually plus the composed pipeline.

  **§5.1.6 v2 cloud path — shipped May 2026.** Optional BYOK
  OpenAI-compatible cleanup pass that runs *after* the
  deterministic v1 on the same Tidy dialog. Pure-Dart
  `CloudLlmCleanupService` POSTs each segment to a user-
  configured `/v1/chat/completions` endpoint with a
  conservative "transcript editor" system prompt; per-segment
  failures are swallowed so one rate-limited call doesn't
  abort the batch. Cancellable via a snackbar action. Works
  against OpenAI, Anthropic via proxy, OpenRouter, Groq,
  Cerebras, Together, a local llama-server, etc.

  Settings → Cloud LLM cleanup stores URL / key / model
  separately; cleanupBatch reads them lazily so a settings
  edit takes effect on the next pass without a restart. Key
  is stored in SharedPreferences (platform-default; encrypted
  by the OS keychain on iOS, plain JSON in app-support
  elsewhere — opt-in feature so the trade-off is acceptable
  for v1).

  Tests: 13 hermetic tests via http's MockClient pin the
  request shape (URL, Bearer auth, OpenAI envelope), response
  parsing, error surfaces, batch behaviour, cancellation, and
  per-segment-failure swallowing. Plus 3 live-network tests
  gated behind `RUN_LIVE_TESTS=1` + a key in
  `GROQ_API_KEY` / `CRISPER_WEAVER_DOTENV` that verify
  end-to-end against Groq's real API in ~5 s. Default
  `flutter test` stays offline.

  **§5.1.6 v3 local LLM — deferred to upstream CrispASR
  work.** Requires promoting llama.cpp from CrispASR's
  `examples/talk-llama/` example to a real public library
  with a clean C ABI (`crispasr_chat_open` / `_generate` /
  `_close` + sampler config + KV cache lifecycle). Tracked in
  a CrisperWeaver-side prompt MD (see top-level
  `docs/prompts/`) that drives the upstream session. Once
  shipped upstream, the v3 swap-in is a one-day wiring job
  here: the same `runLlmPass` toggle would route to a local
  endpoint instead of (or in addition to) the cloud path.

* **5.1.7 Templates / presets — shipped May 2026.** Saves the
  current `(backend, modelId, language, AdvancedOptions)`
  tuple as a named preset; apply later to restore all four
  atomically. Persisted as a JSON-encoded list in
  SharedPreferences with per-row schema-versioning so future
  field additions migrate cleanly.

  PresetService surface: `all()` (oldest-first by createdAt),
  `add()` (auto-disambiguates duplicate names with " (2)"
  suffix), `update()` (overwrites in place by id; falls back
  to add() when the id is unknown — defensive against stale
  UI state), `remove()`, `clear()`. AdvancedOptions ↔ JSON
  helpers are pure (27 fields, three enums, defensive
  fromJson with unknown-key skip + missing-key fallthrough +
  unknown-enum-value default).

  UI: bookmarks icon in the transcription screen AppBar opens
  a dialog with "Save current as preset", per-row Apply /
  Rename / Delete actions, and a one-line summary
  (modelId · language · key option flags). Tapping Apply
  pops the preset back; the screen applies it via the same
  `_selectModel` reload path so the engine swap is identical
  to a manual model change.

  15 new hermetic tests cover round-trip of all 27
  AdvancedOptions fields (defaults + non-defaults), defensive
  fromJson (missing keys, unknown enum names, integer-typed
  doubles, unknown extra keys), and PresetService end-to-end
  (add / collision-suffix / update / remove / clear / cross-
  instance persistence / rapid-fire id uniqueness). 262 tests
  total pass; analyze clean. ARB strings in EN + DE.

#### Tier C — niche but cool

* **5.1.8 Meeting-style summarisation — shipped May 2026.**
  Reuses the same BYOK cloud-LLM endpoint configured for
  §5.1.6 v2. Pure-Dart `TranscriptSummarizeService` sends the
  full transcript to the configured model with a structured-
  output system prompt asking for exactly three optional H2
  sections: `## Action Items`, `## Key Topics`,
  `## Decisions`. The response Markdown is parsed back into
  per-section bullet lists by splitting on H2 headers + bullet
  prefixes (`- `, `* `, `1.`).

  UI: "Summarize…" entry in the transcript more-actions popup
  opens a dialog with three section checkboxes, a Run button
  gated on the cloud-LLM config, and a result pane that
  renders both the structured per-section view and a Copy-all
  Markdown action. Same disabled-state explanation when the
  cloud config is empty as the Tidy dialog.

  Tests: 13 hermetic tests pin the Markdown parser (3 sections
  / "None" placeholders / case-insensitive headers / asterisk
  + numbered bullets / pre-header noise dropped / missing
  sections empty / SummaryResult.isEmpty / raw verbatim
  preservation), plus the HTTP path (disabled config, empty
  transcript short-circuit, empty kinds short-circuit, happy-
  path envelope + parse, non-2xx error surface). Plus one
  live test against Groq's llama-3.3-70b-versatile in
  test/transcript_summarize_live_test.dart, opt-in via
  RUN_LIVE_TESTS=1 + GROQ_API_KEY.

  **§5.1.8 v2 deferred:** structured-output via tool-call /
  JSON-schema for providers that support it (OpenAI's
  `response_format: json_schema`, Anthropic's `tools` field).
  Would tighten the parse and let us add custom output shapes
  (Q&A list, "highlights for the changelog", per-speaker
  summary). Markdown was the safer v1 because it works
  identically across every OpenAI-compatible endpoint without
  per-provider schema knobs.
* **5.1.9 Subtitle burning into video** — User selects a video
  file + transcript, gets a video with hardcoded subs. FFmpeg
  subprocess. ~1 day desktop-only.
* **5.1.10 Audio enhancement before transcribe** — Noise
  reduction (RNNoise FFI), dereverberation. Useful for bad
  recordings. ~2–3 days of FFI integration.
* **5.1.11 Global hotkey — shipped May 2026.** System-level
  keyboard shortcut for start / stop recording without bringing
  the app forward. Desktop only (macOS / Linux / Windows);
  mobile is a no-op since iOS / Android don't expose a global-
  shortcut surface. Pure Dart via the `hotkey_manager` package.

  HotkeyService: broadcast-stream of `HotkeyEvent.keyDown` /
  `keyUp`; subscribers (`AudioRecorderWidget`) dispatch on the
  configured action. Two modes:
    - `pushToTalk` — key-down starts, key-up stops. Walkie-
      talkie idiom; pairs with combos that include a modifier.
    - `toggle` — key-down toggles. Simpler; doesn't need
      holding.

  Persistence: combo as a normalised string in SharedPreferences
  (`meta+shift+space`, `control+alt+r`). Parser handles modifier
  aliases (cmd / command / win / super → meta; ctrl → control;
  option → alt) and canonicalises output (control → alt →
  shift → meta → key) so two equivalent inputs round-trip to
  the same canonical form. F1–F12, letters A–Z, digits 0–9,
  space / enter / tab / escape / backspace / delete supported.

  UI: Settings → Global hotkey opens a dialog with an enable
  switch, a combo text field (validated on save with a helpful
  snackbar on parse failure), and a Radio group for push-to-
  talk vs toggle. Re-registers with the OS on save. Settings
  row hidden entirely on mobile so the affordance only appears
  where it works.

  18 hermetic tests pin the parser (single key, single +
  multi modifiers, case-insensitivity, modifier aliases,
  function keys, digit keys, named keys, empty / unknown
  modifier / unknown key error cases, duplicate-modifier
  dedup) and the serializer (round-trip, canonical modifier
  order, idempotent re-serialisation, case lowering).

  Native plugin registration path can't be unit-tested without
  a host process — but the parser is the only piece with non-
  trivial logic; the plugin call is a single
  `_platform.register` indirection.
* **5.1.12 Voice clone wizard — shipped May 2026.** Linear
  3-step guided flow on top of the existing runtime-cloning
  surfaces in the synthesize screen. Reaches a usable clone
  in three taps instead of "open synthesize, find the custom-
  voice picker, find the ref-text field, know which model to
  pick".

  Steps:
    1. **Capture** — record a 10 s mic clip OR pick an
       existing WAV / FLAC / MP3. Live countdown during
       recording; auto-stop at the limit; playback preview
       before advancing.
    2. **Reference text** — type the verbatim transcript of
       what was said in the clip. Required for backends that
       align against it (indextts, vibevoice-1.5b); empty
       allowed for backends that clone from audio alone
       (chatterbox without baked GGUF, qwen3-tts Base). UI
       explains the distinction so the user knows when
       leaving it empty is correct.
    3. **Hand-off** — summary card + "Open in Synthesize"
       button pushes `/synthesize` with the WAV path + ref
       text pre-populated via GoRouter `extra`. The user picks
       the target text and a clone-capable model in the
       existing screen and runs it.

  Reachable from the Synthesize screen's AppBar via the
  Icons.record_voice_over_outlined chip. Reuses
  `AudioService.startRecording` / `stopRecording` for the
  capture path; FilePicker for the upload path; just_audio
  for the preview. No new native deps.

  **v2 deferred:** auto-fill the reference transcript by
  running the captured clip through the active ASR engine —
  saves one step but bundles the transcription stack into
  the wizard. Today the wizard is pure UX-layer; v2 will
  re-enter the wizard from the transcription side.

  3 widget-smoke tests pin the wizard rendering, the
  stepper labels, and Cancel-on-step-1 popping back. The
  recorder integration is platform-channel-bound and can't
  be unit-tested without a host process; the wizard's pure
  logic (navigation, validation, hand-off payload) is
  trivially correct from inspection.

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
  - Subtitle line formatting (`--max-len`, `--split-on-word`)
    **— shipped May 2026** as two new whisper-only Advanced
    Options rows. `maxLen` is a slider 0..200 (0 = whisper
    default, no cap); `splitOnWord` is a switch that's gated
    on `maxLen > 0` so the user can't fiddle with a no-op.
    Both fields round-trip through PresetService JSON and
    pass through to `crispasr.TranscribeOptions` on the
    whisper file path. `--split-on-punct` would be a third
    knob — needs upstream Dart-binding work first.
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
