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

---

## 5.22 iOS feature parity — static audit + xcframework bundling (shipped, on-device pass pending)

Static-audit fixes applied without an iPhone in hand:

* CoreML companion `.mlmodelc` download was gated `Platform.isMacOS`
  only; every modern iPhone has the Apple Neural Engine, so the
  ANE-targeted companion is just as load-bearing on iOS. Fixed in
  `lib/services/model_service.dart` near `_maybeFetchCoreMLCompanion`.
* `ios/Runner/Info.plist` had two booby-traps that would have made
  iOS launch noisy / unstable on first run, both removed:
  - `NSExtension { NSExtensionPointIdentifier =
    com.apple.widgetkit-extension }` at the host-app level — that
    key only belongs in an extension target's Info.plist; in the
    main app it tells iOS to treat the host bundle as an extension.
  - `UIApplicationSceneManifest` referencing
    `$(PRODUCT_MODULE_NAME).SceneDelegate`, but no
    `SceneDelegate.swift` exists in the target. iOS 13+ would log
    a scene-connection failure on every launch and fall back to
    AppDelegate. Re-introducing the manifest needs a real
    SceneDelegate.swift to land first.
* Custom-models-dir picker hidden on iOS
  (`lib/screens/settings_screen.dart`). The iOS sandbox makes
  arbitrary host paths meaningless without security-scoped
  bookmarks; the default `<app-docs>/models/whisper_cpp/` is the
  only sane location until that flow is built.

**Native library bundling — DONE end-to-end.** Two new scripts wire
the xcframework into the Flutter iOS build:

* `scripts/build_ios_xcframework.sh` — slim iOS-only build (device
  + simulator arm64 slices). The full upstream `build-xcframework.sh`
  builds 7 Apple platform slices in 30–60 min and 7–20 GB of disk;
  this slim variant produces just the two iOS slices in ~1.5 min
  once the cmake configure has run. Cmake flags discovered by trial:
  - `-DCRISPASR_WITH_ESPEAK_NG=OFF` — kokoro otherwise links
    against homebrew's macOS libespeak-ng which doesn't satisfy
    iOS arm64 at link time. Kokoro on iOS therefore can't
    phonemize (one of 30+ backends affected; the rest work).
  - Default `-DCRISPASR_COREML=OFF` when `IOS_MIN_OS_VERSION < 14`
    (CoreML needs iOS 14+). Bump the env var to enable.
  - Glob `src/${release_dir}/lib*.a` to pull in all 30 per-backend
    static archives plus `libcrisp_audio.a` from its sibling build
    dir; without those we get linker errors for
    `_voxtral_init_from_file`, `_kokoro_init_from_file`, etc.
  - Dedup `.o` files by basename across archives: `moonshine`
    and `moonshine_streaming` both ship `moonshine-tokenizer.o`,
    which would cause duplicate-symbol errors at the `clang++
    -dynamiclib -force_load combined.a` step. First lib wins
    (alphabetical order on the per-lib subdirs).
* `scripts/wire_ios_xcframework.rb` — uses the xcodeproj Ruby gem
  (already on disk via CocoaPods) to add the xcframework as a
  linked + embedded framework on the Runner target, with
  `CodeSignOnCopy` so Xcode signs it during build, and adds
  `$(PROJECT_DIR)/Frameworks` to `FRAMEWORK_SEARCH_PATHS`.
  Idempotent.

`flutter build ios --debug --no-codesign` produces
`Runner.app/Frameworks/crispasr.framework` (~4.8 MB stripped, dSYM
separate) with `install_name = @rpath/crispasr.framework/crispasr`,
matching the third candidate in `package:crispasr`'s
`_libCandidates()`. `xcrun dyld_info -exports` confirms 322+
exported symbols including `_crispasr_session_open`,
`_kokoro_init_from_file`, `_voxtral_init_from_file`,
`_whisper_init_from_file`. The xcframework itself is gitignored
(regenerate via the build script); CI wires it via release.yml.

`just_audio` playback configured — `_configureAudioSession()` in
`lib/main.dart` calls
`AudioSession.instance.configure(AudioSessionConfiguration.speech())`
at startup (iOS/Android only). `speech()` is just_audio's
recommended preset for transcription apps: `playAndRecord` +
speaker override + bluetooth allow.

Local rebuild after a CrispASR change:
`bash scripts/build_ios_xcframework.sh && flutter build ios`
(rerun `wire_ios_xcframework.rb` only if the pbxproj was wiped).

**Still pending — needs a real device** (tracked in PLAN.md):
mic permission prompt flow, streaming mic chunk cadence, recording-
→-playback transitions, screen-lock survival, share intake from
Files/Mail, FilePicker → openable path, CoreML mlmodelc loading
log line, `PrivacyInfo.xcprivacy` for App Store Connect (needed
before first TestFlight upload — NSPrivacy* keys in Info.plist
are ignored from May 2024 onwards).

---

## 5.8 Advanced Options completeness — May 2026

All toggles the CrispASR CLI exposes that map cleanly to a Flutter
widget are now in *Advanced Options* on the transcription screen.

* **Temperature** — slider 0.0–1.0, hidden on backends that don't
  honour `crispasr_session_set_temperature` (whisper / mimo-asr /
  wav2vec2 / …); shown for canary, cohere, parakeet, moonshine,
  voxtral, voxtral4b, qwen3, granite, glm-asr, gemma4-e2b,
  omniasr-llm. Threaded through TranscriptionService →
  TranscriptionEngine → CrispASREngine → `_session.setTemperature(t)`
  per-call so a previous non-zero value doesn't stick after the
  user drags back to 0.
* **Best-of-N** — slider 1–10, always visible. Whisper consumes
  via `wparams.greedy.best_of`; other backends loop externally and
  pick the highest-mean-confidence transcript (C-side
  implementation in `crispasr_session_transcribe_lang`).
* **Source-language picker** — paired with the existing target-
  language dropdown. New `AdvancedOptions.sourceLanguageCapableBackends`
  set (strict superset of `translationCapableBackends`) adds
  parakeet / mimo-asr / firered-asr / kyutai-stt / glm-asr /
  gemma4-e2b / omniasr-llm{,-unlimited} / moonshine. Hidden on
  English-only / non-ASR backends (wav2vec2, fastconformer-ctc,
  kokoro, orpheus, chatterbox, indextts, vibevoice-tts, pyannote,
  firered-punc, fullstop-punc). Flows through CrispASREngine →
  both the per-call `language:` arg AND
  `session.setSourceLanguage(lang)` for defense-in-depth.
* **Audio Q&A (`--ask`)** — multiline prompt field, gated on
  `askCapableBackends` (voxtral / voxtral4b / qwen3 / granite /
  glm-asr).
* **Beam search via session API** —
  `crispasr_session_set_beam_size` shipped (CrispASR commit
  `958e6bd7`). Whisper consumes it natively (switches sampling
  strategy to BEAM_SEARCH with the supplied width). Kyutai-STT /
  moonshine / omniasr-LLM wired via existing per-backend setters;
  glm-asr / firered wired via new per-backend
  `<backend>_set_beam_size` setters (commits `66c27c45` +
  `d6ecd1e0`). Six of eleven beam-capable session backends now
  parallel-pool-eligible with beam search ON. Granite / voxtral
  / qwen3 deferred — their beam decode lives in CLI wrappers
  using `core_beam_decode::run_with_probs`, not in the backend
  library; exposing it through the public C API needs per-backend
  refactor work tracked as CrispASR PLAN §90.

---

## 5.23 Batch transcription — scale-out, parallelism, save/resume (shipped May 2026)

What `BatchQueueService` did before this slice: held a
`List<TranscriptionJob>` in a Riverpod `StateNotifier`, serial
drain, no persistence. Worked for 5–20 files; collapsed at scale.
This slice rebuilt the whole batch tier — six commits across four
weeks of bench-side iteration — and turned it into a genuinely
overnight-batch-ready system.

### Q1 foundation — per-job JSON persistence

* Migrated storage to `<app-docs>/batch/default/job-<id>.json`.
  One small file per job; one rename per state mutation. Scales
  to 1000s of jobs without rewriting any per-progress-tick.
* New `BatchPersistenceService` (cross-platform `dart:io` +
  path_provider, same shape as `HistoryService`).
* `BatchQueueNotifier` mirrors every mutation to disk via
  unawaited futures.
* `main.dart`'s post-frame callback hydrates via `load()`.
  Running-when-killed jobs demoted back to `queued` so the next
  drain pass picks them up.
* Per-job filesystem-op serializer (`_serial` lock) keeps
  concurrent unawaited writes from racing each other's rename
  (real bug, caught by the load-test suite — fix: chain ops on
  the same job ID through a per-id future).
* 25 new tests.

### Q1 sub-bullet — backend grouping + duration probe

* Opt-in `Settings.groupBatchByBackend`. Drain loop calls
  `BatchQueueNotifier.reorderByGrouping()` at start, stable-sorting
  only queued jobs by `(backend, modelId, language, createdAt)`.
  Done / error / running rows stay put.
* `AudioService.probeDuration(File)` — header-only `just_audio`
  read via a throwaway player so we don't stomp the shared
  playback session. Sub-second on every supported codec.
* `BatchQueueNotifier` accepts an injectable `durationProbe`
  callback (production wiring fires the audio service; unit
  tests inject a closure for hermetic timing). Stamps
  `durationSec` on each job at enqueue.
* Queue card shows pending-audio sum as a `12m` / `1h12m` chip —
  prefixed `~` when some probes haven't returned yet.
* 12 new tests.

### Q3 — resume from checkpoint after crash

* Per-job append-only `<id>.ckpt.jsonl` written by the drain
  loop on every `onSegment`.
* `BatchQueueNotifier.load()` finds resumable jobs and stamps
  `resumeOffsetSec = lastCheckpointSegment.endTime` on each.
* `transcribeFile` / `engine.transcribe` gained an optional
  `startOffsetSec` parameter. Whisper: `_runChunkedWhisper` skips
  the first `floor(offset / chunkSec)` chunks and reports progress
  relative to the remaining work (no jump-to-30% on tick 1 after
  resume). Whisper non-chunked path + session path: trim leading
  samples + shift emitted segments via new
  `shiftSegmentForResume`.
* Drain loop replays the checkpoint segments into AppState before
  dispatch so the user sees the recovered prefix without a flash.
* `setDone` clears the `.ckpt` — successful runs leave no stale
  files behind.
* 9 new tests.

### Q3 deferred polish

* Mid-batch backend swap awareness — drain loop checks
  `next.modelId` against the engine's `currentModelId` before
  each job and reloads on mismatch. Falls back to the current
  session on load failure (logged warning) so a stale modelId
  from a deleted GGUF doesn't kill the queue.
* iCloud-backup exclusion — new `crisperweaver/ios_helpers`
  MethodChannel in `ios/Runner/AppDelegate.swift` exposes
  `excludeFromBackup(path)` which calls
  `URL.setResourceValues({isExcludedFromBackup: true})`. The Dart
  wrapper in `lib/services/ios_helpers.dart` is a no-op on every
  non-iOS platform, so `BatchPersistenceService._ensureDir`
  fires it unconditionally at first directory create.
* Localised resume snackbar — `BatchQueueNotifier` tracks
  `lastLoadResumedCount` from the most recent `load()`;
  `transcription_screen`'s post-frame callback reads it once and
  shows a `SnackBar` saying "Recovered N interrupted
  transcription(s) — hit Start to resume". Plural-aware ARBs in
  en + de.

### Q2 v1 — pipeline parallelism via audio prefetch

* `SettingsService.maxConcurrentTranscriptions` slider (1–4
  desktop/Android, 1–2 iOS, persisted+clamped).
* When > 1, drain loop kicks off
  `AudioPrefetchService.prefetch(nextFilePath)` — an
  `Isolate.run` worker decodes the audio in parallel with the
  current file's GPU transcription. `AudioService.loadAudioFile`
  consumes the cached PCM or falls through to a synchronous
  decode on cache miss. One session, one model copy in RAM,
  real-world 5–15% wall-time savings on batches of compressed
  audio.
* 9 new tests.

### Q2 v2 — N-way session pool with OOM pre-flight

* `MemoryEstimator` — cross-platform RAM probe (`sysctl
  hw.memsize` on macOS, `/proc/meminfo` on Linux, `wmic` on
  Windows; conservative platform-default constants on iOS /
  Android where shelling out isn't allowed). Computes projected
  RSS = `baseRss + N × on-disk-size × 1.6 overhead` and clamps
  N down to whatever fits in `physicalMemory × 50% − 400 MB`.
  9 hermetic tests.
* `TranscriptionWorker` — top-level isolate entry. Opens its
  own `CrispasrSession.openWithParams` (falls back to plain
  `open` for older builds), bidirectional SendPort protocol for
  `transcribe` / `shutdown` commands + segment streaming. Carries
  every sticky session-state setter (translate / targetLanguage /
  askPrompt / temperature / bestOf / beamSize) and supports
  `transcribeVad` when a VAD model path is supplied. Word
  timestamps round-trip across the SendPort wire. Float32List
  samples pass by transfer (no copy).
* `TranscriptionWorkerPool` — async `spawn(N, modelPath, ...)`
  brings N workers up in parallel, free-list dispatcher with
  completer-based waiters, per-worker `dead` flag for graceful
  degradation when a session crashes, idempotent `shutdown()`.
* `SettingsService.maxConcurrentSessions` slider (1–4 / 1–2 iOS),
  separate from the v1 prefetch knob. Settings UI shows live
  RAM projection ("Projected RAM: 2.4 GB of 16.0 GB (per-worker:
  320 MB)") against the currently-selected default model, with
  an orange "Clamped to N of M workers — model too big" hint
  when the estimator would refuse the slider value.
* Drain loop wiring (option (a) — aggregate batch view):
    1. fires `appStateNotifier.startTranscription()` ONCE at
       batch open (instead of per-job),
    2. dispatches pool-eligible jobs to the pool with the
       in-flight set capped at `pool.size`,
    3. handles pool-ineligible jobs (resume offset / beamSearch
       on non-whisper / tdrz) serially within the same loop
       (pool keeps running between them),
    4. drops the live `addSegment` → AppState path for pool
       jobs (segments still hit `.ckpt.jsonl`); the queue card
       is the source of truth in aggregate mode,
    5. on batch finish, fires one `completeTranscription` to
       settle the screen,
    6. tears the pool down in `finally` even on uncaught errors.
* Spawn failures gracefully degrade to the serial+prefetch path.
  Per-job pool dispatch failures mark the job's row as error and
  the drain loop continues; one bad worker doesn't kill the
  batch.
* `poolEligible(job, adv, enableDiarization)` top-level pure
  function — three genuine blockers left (resume offset / beam
  search on non-whisper / tdrz); everything else (VAD,
  diarization, punctuation, translate, target-lang, Q&A,
  temperature, bestOf, word timestamps) is handled inside or
  alongside the pool dispatch.
* 18 new tests (12 eligibility + 6 wire-format).

### Beam search via session API — six backends parallel-pool-eligible

Worker pool's beamSearch eligibility used to fall through to
serial. The fix was a CrispASR-side new C-ABI
`crispasr_session_set_beam_size` (commit `958e6bd7`) plus
per-backend wiring (commits `66c27c45` + `d6ecd1e0`):

* whisper — native consumption (switches `wparams.strategy =
  BEAM_SEARCH` with the supplied width).
* kyutai-stt, moonshine, omniasr-LLM — wired via existing
  per-backend `<backend>_set_beam_size` setters; just needed
  dispatch calls from `transcribe_single` in
  `crispasr_c_api.cpp`.
* glm-asr, firered — wired via NEW per-backend setters added
  in the same commit batch.

Granite / voxtral / qwen3 remain pending: their beam decode
lives in CLI wrappers using `core_beam_decode::run_with_probs`,
not in the backend library. Exposing it through the public C
API needs per-backend refactor work tracked as CrispASR PLAN
§90.

### Net result

A 100-file overnight batch with VAD + diarization + punctuation
restore + speech translation + temperature sampling now runs
N-way parallel on the pool, with crash-recovery via per-job
checkpoints and progress restoration via the resume snackbar.
The same batch would previously have run serially because each
of those features individually disqualified the job from the
pool. ~190 tests pass on every commit during the slice; stable
across 5 consecutive full-suite runs.
