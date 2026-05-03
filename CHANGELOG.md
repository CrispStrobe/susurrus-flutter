# Changelog

Notable user-facing changes per release. Full diff per version on
the [GitHub releases page](https://github.com/CrispStrobe/CrisperWeaver/releases).

## Unreleased

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
