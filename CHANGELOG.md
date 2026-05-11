# Changelog

Notable user-facing changes per release. Full diff per version on
the [GitHub releases page](https://github.com/CrispStrobe/CrisperWeaver/releases).

## Unreleased

### §5.1 competitor-gap features — Tier A + B + most of C closed (May 2026)

The post-v0.4.1 sweep. Audited against the common feature set of
comparable local GUI tools (whisper-based desktop apps for macOS /
Linux / Windows) plus the cloud meeting-transcription category.
Twelve features land in this batch; full write-ups in
[HISTORY.md](HISTORY.md#post-v041-51-competitor-gap-sweep--may-2026).

- **System audio capture** (§5.1.1) — "Transcribe what's playing
  in Zoom / YouTube / any app." Per-platform native paths:
  ScreenCaptureKit on macOS 13+, `parec` on Linux, ffmpeg-WASAPI
  loopback on Windows, MediaProjection on Android 10+. iOS is
  permanently unsupported by Apple's sandbox.
- **Custom vocabulary / dictionary boost** (§5.1.2) — Persistent
  chip list in Advanced Options. Routed per-backend-class via
  `initial_prompt` (whisper / moonshine), `setAsk` prefix (audio-
  LLM backends), or no-op (CTC-style, with explanatory helper
  text).
- **Inline transcript editing + history persistence** (§5.1.3) —
  Long-press a segment → edit dialog. Edits update AppState AND
  the on-disk history JSON so they survive a reload.
- **History search** (§5.1.4) — Substring filter on title +
  transcript with yellow-highlighted matches and auto-expand of
  matching entries.
- **Audio waveform editor + bidirectional transcript sync**
  (§5.1.5) — Dedicated `EditAudioScreen` with trim / cut middle
  / split into chapters + an optional collapsible transcript pane
  on the same screen. Tap segment → seek; long-press segment →
  Select / Trim to / Mark for split; tap waveform → matching
  segment highlights. Entry points on the transcript output's
  segment long-press menu. Pure-Dart, no FFmpeg.
- **"Tidy transcript" deterministic pass** (§5.1.6 v1) — Pure-
  Dart cleanup: remove fillers (per-language + custom), collapse
  repeats, fix punctuation, capitalise sentence starts, optional
  annotation-tag strip. Before/after preview of the first three
  segments in the dialog.
- **BYOK cloud LLM cleanup pass** (§5.1.6 v2) — Optional opt-in
  LLM pass against any OpenAI-compatible endpoint (OpenAI,
  Anthropic via proxy, OpenRouter, Groq, Cerebras, Together,
  local llama-server). Key stays on device.
- **Local on-device LLM cleanup + summarisation** (§5.1.6 v3) —
  Point at a GGUF chat model on disk and every Tidy / Summarize
  pass routes through it via libcrispasr's chat ABI. No network,
  no API key, no per-token billing. Metal / CUDA acceleration
  used when available; one-time model-load amortised across
  every pass in the session via a dedicated worker isolate. A
  three-mode selector (Off / Cloud / Local) replaces the
  cloud-only LLM-pass checkbox; defaults respect the
  user's persisted preference and configured paths.
- **Templates / presets** (§5.1.7) — Save current `(backend,
  modelId, language, AdvancedOptions)` tuple as a named preset.
  One-tap Apply restores all four atomically.
- **Meeting-style summarisation** (§5.1.8) — Action Items / Key
  Topics / Decisions sections via structured Markdown over the
  same cloud-LLM endpoint as the cleanup pass.
- **Global hotkey for push-to-transcribe** (§5.1.11) — Desktop-
  only system shortcut. Push-to-talk OR toggle modes. Combo
  parser handles modifier aliases (cmd / command / win / super
  → meta; ctrl → control; option → alt).
- **Voice clone wizard** (§5.1.12) — 3-step guided flow on top of
  the existing chatterbox / indextts / qwen3-tts-base / vibevoice
  runtime cloning. Capture (10s mic OR file pick) → reference
  text → hand-off to Synthesize with both pre-populated.
- **Whisper subtitle formatting** (§5.8) — Two new Advanced
  Options rows: tokens-per-segment cap + split-on-word-boundary.
  Yields SRT-friendly short subtitle lines.

### Responsive UI — phone / narrow-window fit (May 2026)

The app was designed-for-desktop primary and had no first-class
phone story. This pass adds four layers of mobile-fit polish
without rewriting the existing layouts:

- **Responsive dialog widths** — every `showDialog` call clamps
  to `min(designedWidth, screenWidth - 32)` via a new
  `responsiveDialogWidth(context)` helper. Same for height where
  bounded. Dialogs no longer overflow on 360-wide phones; the
  Tidy / Summarize / Local LLM / Cloud LLM / Hotkey / Presets /
  inline-edit / rename-speaker dialogs all now adapt. Bonus:
  optional fullscreen-on-phone `showResponsiveDialog` helper for
  future dialogs that want to feel native on mobile.
- **AppBar tightening** — home screen drops the tagline subtitle
  below 600 px width; below 480 px it keeps only Settings as a
  visible action and folds History / Models / Synthesize /
  Translate / Presets into a `PopupMenuButton` overflow.
- **`AdaptiveSegmentedButton<T>`** — drop-in replacement for
  `SegmentedButton` that falls back to `DropdownButtonFormField`
  on compact widths. Applied to the new Tidy + Summarize
  three-mode selectors so localised long labels don't overflow.
- **Tabs in the main screen on phones** — below 600 px the
  transcription screen renders a 3-tab `TabBar` (Input / Run /
  Output) instead of the stacked-column layout, so each pane
  gets the full viewport one at a time. Tabs default to Output
  when the transcript already has segments, Input otherwise; the
  existing wide / extra-wide reflows (≥700, ≥1300) are
  untouched.
- **Bottom `NavigationBar` on phones** — Home / History /
  Settings get a Material 3 NavigationBar at the bottom when
  width < 480. Uses `context.go()` so bouncing between primary
  destinations doesn't pile up the back stack. Secondary
  destinations (Models / Synthesize / Translate / Logs / About)
  stay reachable via the AppBar overflow menu.

### Responsive UI — Settings sub-screens on mobile (May 2026)

Follow-up to the responsive-UI pass above: the Cloud LLM /
Local LLM / Hotkey *dialogs* now convert to pushable sub-screens
on phone-width viewports, matching iOS / Android Settings
conventions. Wide layouts still see the original dialogs.

- Three new form widgets — `CloudLlmSettingsForm`,
  `LocalLlmSettingsForm`, `HotkeySettingsForm` — own the
  TextEditingControllers + slider state and expose `save()` /
  `clear()` via a GlobalKey<…FormState>. Both the wide-layout
  AlertDialog and the new phone-form Scaffold consume the same
  form widget, so behaviour stays identical across surfaces.
- Three new sub-screen routes: `/settings/cloud-llm`,
  `/settings/local-llm`, `/settings/hotkey`. Save/Clear actions
  live in the AppBar; the leading back button discards in-flight
  edits (matches the dialogs' Cancel).
- Each Settings ListTile branches on `isPhoneWidth(context)` —
  push the route on phones, show the dialog on wide. The branch
  is the only call-site change; the rest of the refactor is
  pure widget-extraction.
- The Hotkey form keeps its commit-time validation: an invalid
  combo while enabled returns a `HotkeySaveResult.invalidCombo`
  instead of silently committing. Both containers surface the
  rejection as a SnackBar.

8 new widget tests cover the form-widget contracts
(value rendering, save-time trimming, clear-and-fire, hotkey
validation gating). Full test suite: 333 pass (was 325, +8).

### Platform-native share / receive (May 2026)

Filled out the OS-level send/receive surfaces so CrisperWeaver
talks to neighbouring apps on every platform.

**Outbound — share transcripts to other apps:**

- New **Share as Markdown** entry in the transcript Share menu
  — bullet-list with `HH:MM:SS → HH:MM:SS` timestamps and bold
  speaker labels, ready to paste into Slack / Discord / Notion /
  GitHub. Adds `TranscriptFormat.md` to the export enum.
- New **Share audio + transcript** entry — sends the source
  audio AND an SRT transcript as a two-file bundle in a single
  share. Wraps both files with `SharePlus.share(files: [...])`.
- Pre-existing **Save as SRT / VTT / TXT / JSON / CSV / LRC / WTS**
  entries already auto-open the share sheet after saving — no
  change to those paths.

**Inbound — receive shares into CrisperWeaver:**

- **Multi-file share intake** — `ShareIntakeService` no longer
  drops everything past the first file. First usable audio goes
  to the selected-source slot, subsequent audio files enqueue
  into the batch queue. Closes a silent data-loss bug for
  Android `SEND_MULTIPLE` and macOS multi-file drag-drop.
- **Transcript-file intake** — sharing a `.srt` or `.vtt` (or
  opening one with CrisperWeaver) parses it into segments and
  loads "review mode". New `TranscriptParsers` module handles
  SubRip + WebVTT grammars (CRLF tolerant, optional cue
  identifiers, NOTE/STYLE/REGION skipping, speaker-prefix
  extraction). 13 unit tests pin the grammar handling.
- **Android intent-filters** for `application/x-subrip` and
  `text/vtt` on both VIEW (Open With) and SEND (Share Sheet)
  intents. `.txt` is intentionally left off the VIEW filter to
  avoid CrisperWeaver appearing for every random plaintext file.
- **iOS / macOS UTI declarations** — proper exported UTIs for
  `com.crispstrobe.crisperweaver.srt` (conforms to
  public.plain-text, extension `srt`, MIME
  `application/x-subrip` + `text/srt`) and `…vtt` (extension
  `vtt`, MIME `text/vtt`). A new "Subtitle Files" entry in
  `CFBundleDocumentTypes` references those UTIs so Finder /
  Files Open With surfaces CrisperWeaver for them.

**Desktop integration:**

- **Linux `.desktop` file** — `linux/com.crispstrobe.crisperweaver.desktop`
  with audio + subtitle MimeTypes, `Exec=crisper_weaver %F` so
  `Open With CrisperWeaver` passes files as positional argv.
- **Argv-based intake on desktop** — `main()` now takes
  `List<String> args` and forwards them to
  `ShareIntakeService.acceptPaths` after the provider graph is
  up. Audio + transcript triage happens in the same code path
  as Android / iOS shares.

**iOS Share Extension (template files only, target wiring is
the tracked follow-up):**

- Swift / Info.plist / entitlements template under
  `ios/ShareExtension/` plus the matching
  `ios/Runner/Runner.entitlements` with the
  `group.com.crispstrobe.crisperweaver` App Group identifier.
- Step-by-step Xcode target-creation guide in
  `docs/ios-share-extension-setup.md`. Once the target is wired
  in `Runner.xcodeproj`, CrisperWeaver appears in iOS's system
  Share Sheet from Voice Memos / Mail / Files etc. with no
  further code changes.

Tracked PLAN.md follow-ups: macOS NSServices / Open-With wiring
(needs an NSPasteboard → MethodChannel bridge in
`AppDelegate.swift`), Windows file association (installer /
MSIX work), and the iOS Share Extension Xcode target setup
itself.

Tests: +13 transcript-parser tests. Full suite: 346 pass (was
333, +13).

### macOS Open-With bridge (May 2026)

Finishing the macOS half of the share/receive story:

- New `macos/Runner/OpenWithReceiver.swift` — singleton that
  buffers incoming file paths until the Flutter side binds the
  MethodChannel, then live-forwards subsequent opens.
- `AppDelegate.swift` overrides `application(_:open:)` plus the
  legacy `openFile:` / `openFiles:` hooks so every macOS
  delegate-method entry point funnels into the receiver.
  Finder "Open With", `open foo.wav` from the terminal, and
  drag-onto-dock-icon all land here.
- `MainFlutterWindow.awakeFromNib` binds the channel
  (`crisperweaver/open_with`) alongside the existing system-
  audio-capture channel.
- New `DesktopOpenWithBridge` Dart service drains the Swift
  buffer (`consumePending`) at boot and listens for live
  `onFiles` calls afterwards; both flows feed
  `ShareIntakeService.acceptPaths` so the existing audio /
  transcript triage runs unchanged.
- `OpenWithReceiver.swift` wired into `Runner.xcodeproj`'s
  Sources build phase via four `project.pbxproj` edits
  (PBXBuildFile + PBXFileReference + Runner group + Sources
  phase), matching the existing `SystemAudioCapture.swift`
  pattern.

Pre-flight: 3 hermetic channel-contract tests via
`TestDefaultBinaryMessengerBinding`. Total: 349 tests pass (was
346, +3).

### Performance — Metal cold start (CrispASR upstream)

* **38× faster ASR / TTS cold starts** via the persistent
  `MTLBinaryArchive` pipeline cache (CrispASR commit
  [`2665b1e5`](https://github.com/CrispStrobe/CrispASR/commit/2665b1e5)).
  Compiled Metal compute pipeline state objects (PSOs) now serialise
  to `~/Library/Caches/ggml-metal/<device>.archive` (~683 KB per
  device) on shutdown and reload on the next launch. Real-machine
  benchmark (M1 Max, whisper-tiny + jfk.mp3): cold 22.5 s → second
  warm run 0.6 s. Every CrispASR consumer benefits: CLI,
  CrisperWeaver, test sweep, OpenAI server. Override path via
  `GGML_METAL_PIPELINE_CACHE`; opt out via
  `GGML_METAL_PIPELINE_CACHE_DISABLE=1`.

## v0.4.1 — 2026-05-10

Conservative patch over v0.4.0 covering six rounds of CrispASR-0.6.2
parity work. Pairs with [`CrispASR v0.6.2`][crispasr-062]. No
breaking app-side changes; new screens are additive, every new
toggle defaults to "behaves like v0.4.0".

[crispasr-062]: https://github.com/CrispStrobe/CrispASR/releases/tag/v0.6.2

### Highlights

* **3 new screens** — Translate (text-to-text via M2M-100 / WMT21 /
  MADLAD-400), Voice Bake (Chatterbox WAV-to-GGUF via the
  bake-chatterbox-voice-from-wav.py script), Local HTTP server
  (OpenAI-compatible on 127.0.0.1:8765).
* **4 new ASR backends + 4 new TTS backends in the model catalog**:
  gemma4-e2b (140 langs), omniasr-llm-unlimited (streaming),
  granite-speech 4.1 family, chatterbox / kartoffelbox / indextts /
  qwen3-tts-voicedesign / vibevoice-1.5b. Plus pyannote-v3-seg,
  silero-LID, FireRed/MarbleNet/Whisper-VAD GGUFs, fullstop-punc,
  m2m100-418m / 1.2b, WMT21 (both directions), MADLAD-400.
* **Streaming for non-Whisper backends** — kyutai-stt,
  moonshine-streaming, voxtral4b live mic transcription via the
  new session-level openStream binding.
* **Custom-WAV picker on Synthesize** with reference-transcript
  field for runtime cloning (qwen3-tts Base, vibevoice-1.5b,
  indextts, chatterbox without a baked GGUF).
* **Advanced Options blossomed**: VAD picker (silero / firered /
  marblenet / whisper-vad-encdec) + threshold + min-speech +
  min-silence + speech-pad sliders, diarisation method picker
  (vad-turns / pyannote / energy / xcorr), LID method picker
  (whisper / silero), tdrz toggle, token-timestamps toggle,
  punctuation-family picker, Performance section (ASR-on-GPU,
  flash-attn, n_gpu_layers, n_threads, LID-on-GPU).
* **Synthesize advanced section**: ref-text / instruct fields,
  trim-silence toggle, speed slider (0.25× – 4.00×, drives both
  client-side resample AND the new kokoro length_scale), 5
  sampling sliders (temperature, diffusion-steps, CFG weight,
  exaggeration, top-p).
* **3 new export formats**: CSV (RFC-4180), LRC (lyrics, mm:ss.cs),
  WTS (Whisper Text Segments debug).

### CrispASR 0.6 parity sweep — round 6 (May 2026)
- **PLAN #89 — flash_attn fields on every backend's
  `*_context_params`** — mechanical struct-field plumbing across
  the 12 backends with `use_gpu`. The runtime toggle now reaches
  per-backend init code; per-backend kernel wiring (PLAN #86) lands
  incrementally.
- **PLAN #88 — kokoro length-scale + vibevoice diffusion-step
  runtime knobs.** Kokoro has a new `length_scale` field on
  `kokoro_context_params` that multiplies the duration-predictor
  output before banker's-rounding; CrisperWeaver's existing TTS
  *speed* slider now drives BOTH the C-side scalar (clean stretch
  via the duration model) AND the client-side resample (fallback
  on every other TTS backend). VibeVoice's pre-existing `tts_steps`
  field gets a runtime setter, routed through the unified
  `crispasr_session_set_tts_steps` so the existing
  *Diffusion steps* slider works on it as well as chatterbox.

### CrispASR 0.6 parity sweep — round 5 (May 2026)
- **Flash-attention + n_gpu_layers** — bumped the open-params struct
  to v2 with `flash_attn` (bool, default true) and `n_gpu_layers`
  (int, default -1 = max). Whisper now honours flash-attn natively;
  other backends accept the toggle and will branch on it as the
  per-backend kernel work lands. Surfaced as the *ASR flash-attention*
  toggle and *GPU layers (LLM)* slider in the Performance section.
- **Qwen3-TTS sampling temperature is now runtime-tunable** — was
  hardcoded `temperature=0.9f` inside the code-predictor's top-k
  sampler; now reads `c->params.temperature` (still defaulting to
  0.9 when unset). New `qwen3_tts_set_temperature` runtime setter,
  routed through `crispasr_session_set_temperature` so the existing
  Synthesize-screen Temperature slider Just Works on qwen3-tts now
  too.
- **Local OpenAI-compatible HTTP server** — toggle in Settings →
  *Local HTTP server* spins up a `shelf` HTTP server on
  `127.0.0.1:8765` exposing `POST /v1/audio/transcriptions`
  (multipart, OpenAI-shaped JSON / text / SRT / VTT response),
  `POST /v1/audio/speech` (JSON body → 24 kHz mono WAV bytes),
  `POST /v1/translations` (JSON body → translated text), and `GET
  /health`. External scripts that previously hit
  `https://api.openai.com/v1/audio/...` now work unchanged when
  pointed at the local URL. No auth — bound to loopback only.

### CrispASR 0.6 parity sweep — round 4 (May 2026)
- **ASR-side GPU toggle is now a runtime knob.** New
  `crispasr_session_open_with_params` C-ABI on the CrispASR side
  takes a versioned struct (`abi_version`, `n_threads`, `use_gpu`,
  `verbosity`) and threads `use_gpu` into every backend whose
  context_params accepts it (parakeet, canary, qwen3, cohere,
  granite, voxtral, vibevoice, qwen3-tts, orpheus, kokoro,
  chatterbox). Surfaced as the *ASR on GPU* toggle in the
  Performance section of Advanced Options. Takes effect on the
  next model load (not retroactive to the currently-open session).
* **Chatterbox sampling knobs** — diffusion-step count, top-p,
  min-p, repetition penalty, CFG weight, exaggeration, max speech
  tokens. New runtime setters in `chatterbox.cpp` mutate the
  context's `params` struct between synth calls. Exposed via new
  per-knob session setters (`crispasr_session_set_tts_steps`,
  `_set_top_p`, `_set_min_p`, `_set_repetition_penalty`,
  `_set_cfg_weight`, `_set_exaggeration`,
  `_set_max_speech_tokens`) on the C-ABI, mapped through the Dart
  binding (`setTtsSteps`, `setTopP`, …) and surfaced on the
  Synthesize screen as labelled sliders.
* **Orpheus runtime temperature** — new `orpheus_set_temperature`
  C export; `crispasr_session_set_temperature` now routes to
  orpheus and chatterbox in addition to canary / cohere /
  parakeet / moonshine, so the existing temperature slider works
  on those TTS backends too without UI changes.

### CrispASR 0.6 parity sweep — round 3 (May 2026)
- **Custom voice (WAV reference)** card on the *Synthesize* screen.
  Pick a WAV from disk for runtime cloning on backends that take a
  reference (qwen3-tts Base, vibevoice-1.5b, indextts, chatterbox).
  Pairs with the Reference transcript field; overrides the catalog
  voicepack dropdown when set.
- **Streaming for non-Whisper backends.** New `openStream()` on
  `CrispasrSession` in the Dart binding wraps
  `crispasr_session_stream_open`; the engine's `transcribeStream`
  now picks the right path automatically. Live mic transcription
  works end-to-end on whisper / kyutai-stt / moonshine-streaming /
  voxtral4b. The "Stream" toggle on the recorder surfaces a
  backend-specific error when the active model has no streaming
  arm.
- **Voice baking flow.** New *Bake voice (WAV → GGUF)* screen
  (launched from the cake icon in the *Synthesize* app-bar) drives
  CrispASR's `models/bake-chatterbox-voice-from-wav.py` via
  `Process.start`. Pick a WAV, set output filename, optional
  Python interpreter / script-path overrides, run. Stdout + stderr
  stream into a live tail panel + the in-app log viewer; the
  resulting GGUF is dropped into the user's models dir so it
  shows up in the voicepack picker on the next open.
- Desktop-only — mobile sandboxes have no Python runtime, so the
  Bake button hides itself on iOS / Android.

### CrispASR 0.6 parity sweep — round 2 (May 2026)
- New **Translate** screen — text-to-text translation via M2M-100,
  WMT21 Dense (en→X **and** X→en, both checkpoints catalogued), and
  MADLAD-400 (419 languages). Source/target dropdowns with a swap
  button, max-tokens slider, copy-to-clipboard. New
  `TextTranslationService` + `translateText()` exposed on
  `CrispasrSession` in the Dart binding.
- LID accelerator knobs in Advanced Options — toggle GPU offload,
  flash-attention, and CPU thread count for the
  `crispasr_detect_language_pcm` call. Threaded through
  `LidService` + `AdvancedTranscribeOptions`.
- New `ModelKind.translate` filter so the Model Manager can group
  text translation models away from the speech-translation backends
  (canary, voxtral, …).
- CrispASR README + cli docs corrected — WMT21 ships **two** Dense
  24-wide checkpoints (`en-x` and `x-en`), not one en→X-only.

### CrispASR 0.6 parity sweep — round 1 (May 2026)
- 4 new ASR backends in the catalog: **gemma4-e2b** (USM Conformer +
  Gemma-4, 140+ languages), **omniasr-llm-unlimited** (streaming, 15 s
  protocol), **granite-speech-4.1** (2B, 4.1+, 4.1-nar variants),
  rounding out the Granite Speech family.
- 4 new TTS backends: **chatterbox** (T3 AR + S3Gen flow-matching),
  **kartoffelbox** (Chatterbox German finetune), **indextts** (GPT-2 AR
  + BigVGAN, zero-shot WAV cloning), **qwen3-tts-voicedesign** (natural-
  language voice description via the new `synthInstruct` field),
  **vibevoice-1.5b** (runtime WAV cloning via `setVoice(wav, refText:)`).
- New diarisation method picker — pick between vad-turns (mono,
  bundled), pyannote (ML, downloadable GGUF), stereo energy, stereo
  cross-correlation. Pyannote v3 segmentation GGUF added to the model
  catalog.
- New LID method picker — Silero 95-langs joins the Whisper-encoder
  default. The new `silero-lang95-v1-f16.gguf` GGUF is downloadable
  through Model Management.
- VAD picker + tuning sliders — choose between Silero (bundled),
  FireRedVAD (F1 97.57%), MarbleNet, Whisper-VAD-EncDec. Threshold,
  min-speech-ms, min-silence-ms, speech-pad-ms exposed as sliders
  when VAD is enabled.
- Multilingual punctuation: new fullstop-punc post-processor
  (EN/DE/FR/IT) alongside the existing FireRedPunc (ZH+EN). Toggle
  in Advanced Options chooses which family runs.
- Whisper-only: tinydiarize speaker-turn markers (`tdrz`) and token-
  level DTW timestamps now available in Advanced Options.
- Three new export formats — **CSV** (segment-level, RFC-4180 quoted),
  **LRC** (lyrics, mm:ss.cs), **WTS** (Whisper Text Segments debug
  format).
- TTS knobs: trim-silence (post-process under -72 dBFS), speed slider
  (0.25×–4.00×, nearest-neighbour resample), reference-transcript
  field for runtime voice cloning, natural-language voice-design
  prompt for qwen3-tts VoiceDesign.
- Capability sets in `AdvancedOptions` extended — Granite 4.1 family,
  GLM-ASR, Gemma4, OmniASR LLM all now eligible for source/target
  language hints, audio Q&A, and the temperature slider.

**Decoder controls**
- Best-of-N slider in Advanced Options (1–10, always visible).
  Whisper consumes via `wparams.greedy.best_of`; other backends
  loop N decodes externally and pick the highest-mean-confidence
  transcript. Cost is N× per-call decode time.
- Decoder temperature slider for sampling-capable backends
  (canary, cohere, parakeet, moonshine). 0.0 = greedy / reproducible
  (default); >0.0 = stochastic sampling, useful when greedy
  hallucinates a repetition.
- Source-language override paired with the existing target-language
  picker; lets you pin the source for translation when whisper's
  autodetect is unreliable on noisy audio.

**Quality of life**
- Storage breakdown screen (Settings → Storage breakdown) — per-
  backend disk usage with one-click "delete all of X" action.
- Mic-streaming live transcript on the recorder (Whisper-only) —
  toggle the "Stream" switch and partial transcripts appear in the
  output card while you talk.
- Real-time partial display during long file transcribe — Whisper
  files >60 s are split into 30 s chunks; each chunk's segments
  stream into the UI as they finish instead of all arriving at the
  end.
- Speaker rename — tap a speaker chip in the output to override the
  diariser's auto-assigned label. The mapping persists into history
  JSON and survives restarts.

**iOS**
- v0.4.0 was the first release to ship a real iOS IPA. The unsigned
  IPA (15 MB) bundles `crispasr.framework` with all 30 backends
  statically linked into a single dynamic library; the previous
  v0.3.0 IPA was an empty Flutter shell with no native backend.
- `audio_session` configured at startup with the `speech()` preset
  so playback / recording / silent-mode interact correctly.
- `PrivacyInfo.xcprivacy` covering NSUserDefaults, FileTimestamp,
  DiskSpace, SystemBootTime — the four required-reason API
  categories the app touches via shared_preferences, path_provider,
  dart:io, and DateTime.now(). Required for App Store submission
  since May 2024.
- CoreML companion download (`.mlmodelc` next to whisper GGUFs)
  now also fires on iOS — every modern iPhone has the Apple
  Neural Engine, so the .mlmodelc is just as load-bearing on iOS
  as it has been on macOS.

**i18n**
- 40+ user-facing strings moved from hardcoded English to
  `AppLocalizations`. EN+DE entries in lockstep, guarded by a new
  `arb_consistency_test` that fails CI if a key is added to one
  locale and not the other or if ICU placeholders ({count}, {size},
  …) drift between translations.

**Tests**
- Default suite: 6 → 87 tests. Coverage for HistoryEntry round-
  trip + back-compat, AppStateNotifier full lifecycle, AdvancedOptions
  copyWith + capability sets, storage formatters + grouping +
  deletion, subtitle export (SRT/VTT/JSON formatters + content),
  chunked-whisper segment offset shifter, HistoryService persistence,
  SettingsService SharedPreferences round-trip, ARB consistency.
- Default `flutter test` runs in ~5 s; opt-in heavy e2e backend
  roundtrips stay env-var-gated.

**CI**
- macOS + Linux CI jobs aligned to the same build scripts devs run
  locally (`scripts/build_macos.sh`, `scripts/build_linux.sh`).
  Earlier hand-rolled `cmake … --target crispasr` invocations
  diverged from the local scripts in two load-bearing ways:
  (a) skipped `-DCRISPASR_BUILD_TESTS=OFF` so cmake configure pulled
  in unrelated source trees and tripped on the OBJCXX language
  requirement that comes in via the CoreML wrappers; (b) only built
  the `crispasr` target without first building the 30 per-backend
  STATIC archives, so the resulting libwhisper.dylib was missing
  every backend except whisper at runtime.
- iOS release job updated to call `scripts/build_ios_xcframework.sh`
  + `scripts/wire_ios_xcframework.rb` before `flutter build ios`,
  so the released IPA contains the native backends.

## v0.4.0 — 2026-05-03

- iOS xcframework wiring (the launch blocker) — Runner.app now
  embeds `crispasr.framework` (4.8 MB stripped, 322+ exported
  symbols), `install_name = @rpath/crispasr.framework/crispasr`
  matches the Dart loader's third candidate exactly. Both iOS
  device + simulator builds green.
- Storage breakdown screen + per-backend "delete all" action.
- Speaker rename + persistence across history loads.
- Chunked Whisper for incremental segment display on long files.
- Audio Q&A `--ask` field for instruct-tuned LLM backends.
- Segment editing + karaoke-style segment playback.

## v0.3.0 and earlier

See the [GitHub releases page](https://github.com/CrispStrobe/CrisperWeaver/releases)
for v0.3.0 (streaming mic + translation UI + 33-voice gallery +
CoreML for Whisper), v0.2.x (TTS scaffold + 3 new ASR backends +
build automation), and the v0.1.x series (initial Flutter shell,
batch transcription, model auto-download, diarization, history).
