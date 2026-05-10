# Changelog

Notable user-facing changes per release. Full diff per version on
the [GitHub releases page](https://github.com/CrispStrobe/CrisperWeaver/releases).

## Unreleased

(Nothing yet — round 7 will land here as it ships.)

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
