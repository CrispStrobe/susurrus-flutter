# CrisperWeaver — History

Archive of completed roadmap items. Live work is in [PLAN.md](PLAN.md);
technical learnings sit in [LEARNINGS.md](LEARNINGS.md).

Cross-references to git commits and CrispASR's
[HISTORY.md](https://github.com/CrispStrobe/CrispASR/blob/main/HISTORY.md)
are linked inline where relevant. Each entry below was once an open
PLAN section; collapsing them here keeps PLAN.md focused on what's
pending.

---

## Releases

| Tag | Date | Highlights |
|---|---|---|
| [v0.4.1](https://github.com/CrispStrobe/CrisperWeaver/releases/tag/v0.4.1) | 2026-05-10 | CrispASR-0.6.2 parity sweep (rounds 1–6) — see §"May 2026 parity sweep" below. Pairs with [CrispASR v0.6.2](https://github.com/CrispStrobe/CrispASR/releases/tag/v0.6.2). |
| v0.4.0 | 2026-05-03 | First iOS IPA. Real ASR everywhere (macOS / Linux / Windows / Android / iOS). xcframework wiring shipped. |
| v0.3.0 | 2026-05-02 | Windows release; mic-streaming live transcript; per-backend Storage tab. |
| v0.2.x — v0.1.x | 2026-04 → 2026-05 | Initial macOS / Linux / Android releases; batch transcription; VAD; Advanced Options block. |

---

## May 2026 parity sweep — six rounds, lands in v0.4.1

Brought CrisperWeaver's catalog, advanced-options surface, and post-
processor wiring up to CrispASR 0.6.0 → 0.6.2 parity. Net effect:
3 new screens, 8 new backends in the catalog, runtime tunable
flash-attn / GPU layers / TTS sampling, and 3 new export formats —
all without breaking the v0.4.0 app surface (every new toggle
defaults to "behaves like before").

### Round 1 — initial parity (catalog + dispatcher)

* New ASR backends: **gemma4-e2b** (USM Conformer + Gemma-4 35L,
  140+ languages), **omniasr-llm-unlimited** (streaming, 15 s
  protocol, unlimited audio), **granite-speech-4.1** (2B, 4.1+,
  4.1-nar variants).
* New TTS backends: **chatterbox / kartoffelbox** (T3 AR + S3Gen
  flow-matching), **indextts** (GPT-2 AR + BigVGAN, ZH+EN),
  **qwen3-tts-voicedesign** (1.7B, natural-language voice instruct),
  **vibevoice-1.5b** (runtime WAV cloning via
  `setVoice(wav, refText:)`).
* New post-processors: **fullstop-punc multilang** (EN/DE/FR/IT)
  alongside FireRedPunc (ZH+EN). Picker in Advanced Options.
* Diarisation method picker — vadTurns (default) / pyannote
  (downloadable GGUF) / energy / xcorr. `DiarizationService`
  auto-locates the pyannote GGUF and falls back to vad-turns when
  missing.
* LID method picker — whisper / silero. `LidService` honours the
  picked method, resolves the file, and falls back when mismatched.
* VAD picker — silero (bundled) / firered / marblenet /
  whisper-vad-encdec. Threshold, min-speech-ms, min-silence-ms,
  speech-pad-ms exposed as sliders, plumbed through
  `TranscribeOptions` / `SessionVadOptions`.
* Whisper-only knobs: tdrz (tinydiarize), token-level timestamps.
* Three new export formats: **CSV** (RFC-4180 quoting), **LRC**
  (lyrics, mm:ss.cs), **WTS** (Whisper Text Segments debug).
* TTS knobs in Synthesize screen: trim-silence, speed slider
  (0.25× – 4×, nearest-neighbour resample), reference-transcript
  field, voice-design instruct field.
* New `AdvancedTranscribeOptions` value class bundles the parity
  knobs so `transcribeFile`/`transcribeUrl` keep stable signatures.

Companion CrispASR commits: `5591ecfe` (translateText FFI),
`1518f477` (CrispasrSession.openStream), `95e2fdf7` (chatterbox
sampling knobs).

### Round 2 — text translation + LID accelerator

* ✅ **Text translation screen** — `TextTranslationService` +
  `TranslateScreen` shipped. Catalogue covers M2M-100 (418M, 1.2B),
  WMT21 Dense (en→X **and** X→en — both checkpoints), MADLAD-400 3B.
  New `translateText` method on `CrispasrSession`. Source/target
  dropdowns with one-click swap, max-tokens slider,
  copy-to-clipboard.
* ✅ **LID accelerator knobs** — `lidUseGpu` / `lidFlashAttn` /
  `nThreads` exposed in `AdvancedTranscribeOptions` and the
  Advanced Options "Performance" section, threaded through
  `crispasr_detect_language_pcm`.
* ✅ **`ModelKind.translate`** filter — Model Manager can now
  group text-translation models separately from speech-translation
  ASR backends.

### Round 3 — custom voice + non-Whisper streaming + voice baking

* ✅ **Custom voice WAV picker** on the Synthesize screen —
  surfaces the existing `voiceWavPath` parameter that
  `TtsService` already accepted. Pick a WAV, optionally pair with a
  Reference transcript for runtime cloning.
* ✅ **Streaming for non-Whisper backends** — new
  `CrispasrSession.openStream()` Dart helper wrapping
  `crispasr_session_stream_open`. Engine's `transcribeStream`
  routes through it whenever a session is loaded. Live mic
  transcription works on whisper / kyutai-stt / moonshine-streaming
  / voxtral4b end-to-end.
* ✅ **Voice baking flow** — `VoiceBakingService` spawns CrispASR's
  `bake-chatterbox-voice-from-wav.py` script via `Process.start`,
  streams stdout/stderr live, drops the resulting GGUF into the
  models directory. Bake screen launched from the cake icon in the
  Synthesize app-bar. Desktop-only (mobile has no Python runtime).

### Round 4 — ASR GPU toggle + chatterbox sampling

* ✅ **ASR-side GPU + perf toggles** — extended the C-ABI with
  `crispasr_session_open_with_params(path, backend, params_v1*)`.
  Threads `use_gpu` / `verbosity` / `n_threads` through every
  backend's `*_context_params` at session-open time. Surfaced in
  Advanced Options "Performance" as the *ASR on GPU* toggle.
  Takes effect on the next model load.
* ✅ **TTS sampling knobs** — chatterbox runtime setters for
  diffusion steps, top-p, min-p, repetition penalty, CFG weight,
  exaggeration, max speech tokens. Orpheus temperature too. New
  `crispasr_session_set_*` exports + Dart binding methods
  (`setTtsSteps`, `setTopP`, …). Synthesize screen surfaces five
  sliders in its Advanced section; setters silently no-op on
  backends that don't honour each field.

### Round 5 — flash-attn + n_gpu_layers plumbing + OpenAI server + qwen3-tts temp

* ✅ **Flash-attention + n_gpu_layers plumbing** — open-params
  struct bumped to v2 (additive — v1 callers keep working). Wired
  through the Dart binding's `CrispasrSession.openWithParams()` and
  into CrisperWeaver's Advanced Options Performance section.
  Whisper honours flash_attn at the kernel level today; per-backend
  kernel wiring tracked as
  [CrispASR PLAN #86](https://github.com/CrispStrobe/CrispASR/blob/main/PLAN.md#86-per-backend-flash-attention-wiring-crisperweaver-driven).
* ✅ **Qwen3-TTS sampling temperature** — was a hardcoded
  `temperature=0.9f` in the code-predictor's top-k sampler; now
  reads `c->params.temperature` so the existing Synthesize-screen
  temperature slider works on it. New `qwen3_tts_set_temperature`
  runtime setter routed via `crispasr_session_set_temperature`.
* ✅ **Local HTTP server (OpenAI-compatible)** — `shelf`-based,
  bound to 127.0.0.1 only. Endpoints:
  `POST /v1/audio/transcriptions`, `POST /v1/audio/speech`,
  `POST /v1/translations`, `GET /health`. Toggle in
  *Settings → Local HTTP server*. Lets external scripts drive
  CrisperWeaver locally without re-authoring against a different
  API.

### Round 6 — close CrispASR PLAN #88 and #89

* ✅ **CrispASR #89 — flash_attn fields on every backend** — 12
  of 12 backends (parakeet, canary, qwen3, cohere, granite_speech,
  voxtral, voxtral4b, vibevoice, qwen3_tts, orpheus, kokoro,
  chatterbox) now have `flash_attn` (or pre-existing `use_flash`)
  in their `*_context_params`. `crispasr_session_open_explicit`
  threads `g_open_flash_attn_tls` through. → CrispASR HISTORY §84.
* ✅ **CrispASR #88 — kokoro length-scale + vibevoice
  diffusion-step runtime knobs.** Kokoro: new `length_scale` field
  + `kokoro_set_length_scale` setter, applied before banker's-
  rounding in the duration predictor. VibeVoice: new
  `vibevoice_set_tts_steps` setter mutates the pre-existing
  `tts_steps` cparams field. Both routed through unified session
  setters. CrisperWeaver: TtsService's `synthesize` now drives
  `setLengthScale(1/speed)` so the speed slider stretches/squeezes
  via the duration model on kokoro (clean) AND the client-side
  resampler on backends without one (fallback). →
  CrispASR HISTORY §85.

---

## Pre-sweep §5.x roadmap items — shipped

These were the original CrisperWeaver §5 items in PLAN.md; full
write-ups now live below. Each section was at one point an open
roadmap item; collapsing them here keeps PLAN.md focused on the
remaining work.

### 5.1 Finish i18n

Two sweeps moved 40+ hardcoded strings from `lib/widgets/` and
`lib/screens/` behind `AppLocalizations`: transcription share/save
menu (TXT/SRT/VTT/JSON), snackbars (load/save/playback/synthesize/
copy failures + success toasts), settings dialogs (Select Engine,
HF Token + label), download-model prompt body, audio-recorder /
diariser / log-viewer tooltips, log popup menu items, streaming
error dialogs. Only the brand string "CrisperWeaver" on the about
screen is intentionally left as a literal. EN+DE entries in
lockstep, guarded by `test/arb_consistency_test.dart`.

### 5.2 iOS build verification

* `cd ios && pod install` succeeds (16 pods).
* `ios/Flutter/Profile.xcconfig` added so CocoaPods stops warning
  about an unwired Profile config.
* `flutter build ios --debug --simulator` — green, 96.8 s.
* `flutter build ios --debug --no-codesign` (device) — green, 56.5 s.
* `PrivacyInfo.xcprivacy` lands in the .app bundle root; Info.plist
  is clean (MinimumOSVersion 13.0, microphone description present).
* Bridging header DON'T DROP IT — `AppDelegate.swift` calls
  `GeneratedPluginRegistrant.register(with: self)`; that class is
  declared in the auto-generated `GeneratedPluginRegistrant.h`
  (Objective-C). The bridging header is the only thing exposing
  the class to Swift.

### 5.3 Android native-lib CI wiring

`release.yml`'s `build-android` job runs
`CrispASR/build-android.sh --vulkan` to cross-build
`libcrispasr.so` + sibling backend `.so`'s for `arm64-v8a`,
drops them into `android/app/src/main/jniLibs/arm64-v8a/`,
then `flutter build apk --release`. v0.4.0 produced a 31 MB
real-ASR APK. Pending: an emulator smoke test.

### 5.4 Windows CI end-to-end validation

`release.yml`'s `build-windows` job runs the CMake shared-DLL
build of CrispASR on a Windows runner, drops DLLs next to
`runner.exe` via `scripts/bundle_windows_dlls.ps1`, zips. v0.4.0
produced a 25 MB `crisper_weaver-windows-x64.zip`. Green for
v0.3.0+. Pending: install on a real Windows box and transcribe
end-to-end.

### 5.5 Real speaker diarization

CrispASR 0.4.5 `crispasr_diarize_segments_abi` wired through
`DiarizationService` (`lib/services/diarization_service.dart`);
the MFCC/k-means stopgap is gone. Default method `vadTurns`
(mono-friendly, no extra model file). Pyannote GGUF + method
picker in Advanced Options shipped as part of round 1.

### 5.6 Backend-specific UX

All four sub-items landed:

- **Voxtral / Granite `--ask` Q&A** — Advanced Options → "Ask the
  audio" prompt field, gated on `askCapableBackends`.
- **Canary / Voxtral source + target language pickers** — paired
  Source/Target dropdowns in Advanced Options, both gated on
  `translationCapableBackends`. Source override falls back to the
  main language picker / autodetect when empty.
- **Beam search toggle** — for every backend that honours it.
- **Parakeet / FastConformer-CTC best-of-N** — slider 1–10 in
  Advanced Options, always visible.

### 5.7 Batch transcription (v0.1.4)

Multi-file drop / pick + serial queue + `BatchQueueCard`.
`TranscriptionJob` (filePath, status, progress, result) lives in
a Riverpod `StateNotifier`. Persistence via SharedPreferences so
a user can close the app mid-batch and resume.

Files: `lib/services/batch_queue_service.dart`,
`lib/widgets/batch_queue_card.dart`, mods to
`lib/screens/transcription_screen.dart`.

### 5.11 LID + forced aligner wiring

- **LID** — `LidService` (`lib/services/lid_service.dart`) reuses
  any multilingual whisper GGUF the user has already downloaded
  (preferring tiny → base → small) and runs it as a pre-step for
  session backends when `language` is "auto". Confidence-gated.
- **Forced aligner** — `AlignerService`
  (`lib/services/aligner_service.dart`) searches for
  `canary-ctc-aligner-*.gguf` / `qwen3-forced-aligner-*.gguf` and
  runs `alignWords` as a post-step when word timestamps are
  requested but the active session backend didn't emit any.

Both no-op silently when the model isn't on disk.

### 5.12 Punctuation restoration (FireRedPunc)

`PuncService` (`lib/services/punc_service.dart`) lazy-loads
CrispASR's `crispasr.PuncModel`, runs per-segment `process()`,
no-ops when no `fireredpunc-*.gguf` is on disk. "Restore
punctuation" toggle in Advanced Options. Catalogued under the
`firered-punc` backend so users can fetch from Model Management.
Round 1 added the `fullstop-punc` multilang variant alongside.

### 5.13 CrispASR registry discovery

`ModelService.refreshFromCrispasrRegistry()` queries the C-side
model registry baked into libcrispasr via FFI. Iterates every
backend `availableBackends()` reports, calls
`crispasr.registryLookup(backend)`, merges canonical entries into
`_discoveredModels`. Runs on every Model Management screen open;
offline-safe (no network).

### 5.14 TTS integration

`SynthesizeScreen`, `TtsService` wrapping
`CrispasrSession.synthesize / setVoice / setCodecPath`,
`ModelKind` discriminator + filter chips in Model Management.
Four TTS backends pre-sweep: vibevoice-tts, qwen3-tts, kokoro,
orpheus. Round 1 added chatterbox / kartoffelbox / indextts /
qwen3-tts-voicedesign / vibevoice-1.5b on top.

### 5.15 mimo-asr session dispatch

XiaomiMiMo MiMo-Audio ASR (two-file backend: main model +
`mimo_tokenizer` companion). Routes the tokenizer through
`crispasr_session_set_codec_path` — same shape as qwen3-tts and
orpheus's codec/tokenizer companions. Catalog ships both files
with `companions: ['mimo-tokenizer-q4_k']` on the main entry.

### 5.16 Build automation

`scripts/build_macos.sh` is the one-shot end-to-end macOS build:
configure cmake into `build-flutter-bundle/`, build all backend
static archives + relink `libwhisper.dylib`, `flutter pub get` +
`flutter build macos`, then `scripts/bundle_macos_dylibs.sh` to
copy + alias dylibs and rewrite install names. Reports linked
backends parsed from `nm` output.

### 5.17 Quality gate + integration tests

* `analysis_options.yaml` promotes lint categories that catch real
  defects to **errors**: `use_build_context_synchronously`,
  `avoid_print`, `unused_*`, `inference_failure_*`,
  `deprecated_member_use`. A regression fails the build.
* `flutter analyze` reports **0 issues**; `flutter test` is
  **green** at every commit.
* `test/backend_dispatch_test.dart` validates the C-API dispatch
  arms — `availableBackends()` shape, per-backend bogus-path
  open-failure path, plus opt-in env-var-gated end-to-end
  synth/transcribe roundtrips for whisper / kokoro / mimo-asr /
  qwen3-tts / vibevoice / orpheus.

### 5.19 Real-time partial display during file transcribe

The engine's `transcribeFile(..., onSegment: …)` hook now feeds
each finished segment into `AppStateNotifier.addSegment` as it
lands, so a 10-min file paints segments incrementally instead of
holding the screen blank for 30 s then dumping the whole transcript
at once. Final `completeTranscription(segments)` call still runs
for the persisted history entry, but the screen has already
rendered the rolling text.

### 5.20 Speaker name labels

Diariser labels ("Speaker 1", "Speaker 2", …) become editable
chips in `TranscriptionOutputWidget`. Tap → rename dialog →
mapping lives in `AppStateNotifier.speakerNames` for the session
and is persisted into history JSON under
`HistoryEntry.speakerNames: Map<String, String>`. Backward-compat
loader treats absent maps as empty so old history entries still
deserialise.

### 5.21 Background download manager + Storage tab

`lib/screens/storage_screen.dart` (Settings → "Storage breakdown")
shows per-backend disk usage with one-click "delete all of X"
action. `(other)` bucket is read-only — those files come from
manual drops or the per-row delete in Use/Manage Models. Throttled
`_downloadWithResume`'s progress callback from ~10 Hz to ~4 Hz
(250 ms) so multi-GB downloads no longer rebuild the UI hundreds
of times per second. ARB strings under `storage*` and
`settingsStorageBreakdown*` (en + de).

### 5.18 Test-suite speed — in-app side + MTLBinaryArchive

**In-app side**: default `flutter test` holds sub-5 s by tagging
slow e2e tests with `tags: ['slow']` (env-var-gated; vanilla CI
skips them). Single-process `--tags slow` sweep: ~46 min serial →
~25 min in one process (1.8× via Apple's intra-process MSL
pipeline cache). Test fixtures cut to minimum: `test/jfk-2s.wav`
instead of 11 s, `"Hi."` TTS prompt instead of `"Hello world."`.

**Persistent `MTLBinaryArchive` pipeline cache** (CrispASR commit
[`2665b1e5`](https://github.com/CrispStrobe/CrispASR/commit/2665b1e5)):
serialises compiled `MTLComputePipelineState` objects to disk and
reloads them on subsequent process spawns, eliminating the
~30–60 s shader-compile tax visible on every cold start.

Real-machine benchmark (M1 Max, whisper-tiny + samples/jfk.mp3):

| Run | Whisper time | Wall time |
|---|---:|---:|
| Cold start (cache empty) | 5888 ms | 22.5 s |
| Warm start 1 (cache present) | 4349 ms | 4.6 s |
| Warm start 2 (cache complete) | **370 ms** | **0.6 s** |

That's a 38× wall-clock speedup over the cold path. Storage is
~683 KB per device, auto-managed at
`~/Library/Caches/ggml-metal/<device>.archive`. Override path via
`GGML_METAL_PIPELINE_CACHE`; opt out via
`GGML_METAL_PIPELINE_CACHE_DISABLE=1`.

Implementation in `ggml/src/ggml-metal/ggml-metal-device.m`:
- New file-static helpers (`crispasr_metal_pipeline_cache_url /
  _open / _flush`) own the archive lifecycle.
- `ggml_metal_device_init` opens the archive BEFORE any PSO gets
  compiled, so even the tensor-API-probe `dummy_kernel` benefits.
- `ggml_metal_library_compile_pipeline` switches from
  `newComputePipelineStateWithFunction:error:` to the descriptor-
  based form so `binaryArchives:@[archive]` can be attached. Metal
  consults the archive first; cache hits skip the shader compiler.
  Cache misses fall through to JIT and call
  `addComputePipelineFunctionsWithDescriptor` to push the new PSO
  back into the archive.
- `ggml_metal_device_free` serialises the archive to disk via
  `serializeToURL`. No-op when nothing was added since the last
  serialise (typical for warm-only runs).
- Stale cache from a different ggml-metal build auto-recovers by
  deleting the file and starting fresh. `add-to-archive` failures
  are non-fatal — pipeline already compiled successfully.

Every CrispASR consumer benefits: the CLI, CrisperWeaver, the test
sweep, the OpenAI-compatible local server. CI sweep projected
~25 min → ~5 min after the cache warms on the first run of any
runner.

**Still open** (deferred): CoreML for whisper on Apple Silicon
(`WHISPER_USE_COREML=1` build flag + paired `.mlmodelc`) — next
CrispASR cycle. Re-download q4_k variants for vibevoice / orpheus
— blocked on HF availability.
