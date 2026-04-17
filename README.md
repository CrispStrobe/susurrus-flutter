# CrisperWeaver

**On-device speech recognition. No cloud. Ten model families, one app.**

CrisperWeaver is a cross-platform Flutter app for fully-offline audio transcription. Drop in a file, paste a URL, or record with the mic — audio never leaves the device. Ten open-weight ASR families are supported through a single unified engine ([CrispASR][crispasr]): Whisper, Parakeet, Canary, Voxtral, Qwen3-ASR, Cohere, Granite, FastConformer-CTC, Canary-CTC, and Wav2Vec2.

[crispasr]: https://github.com/CrispStrobe/CrispASR

![AGPL-3.0](https://img.shields.io/badge/license-AGPL--3.0-blue) ![Flutter 3.38](https://img.shields.io/badge/flutter-3.38-blue) ![macOS · Linux · Windows · iOS · Android](https://img.shields.io/badge/platforms-macOS%20·%20Linux%20·%20Windows%20·%20iOS%20·%20Android-lightgrey)

---

## What you can do

- **Transcribe any audio file** — WAV / MP3 / FLAC decoded on-device, no ffmpeg required.
- **Record from the mic** and transcribe live.
- **Paste a URL** to a remote file; CrisperWeaver downloads and processes it.
- **Drag and drop** files onto the transcription screen (desktop).
- **Receive shared audio** from the OS share sheet (Android / iOS / macOS).
- **Choose your model family and quantisation** — q4_0 / q5_0 / q8_0 variants, plus f16 originals.
- **Download and manage models** from a built-in browser — parallel queue, resume, SHA-1 verify, cancel, delete.
- **See live performance numbers** — real-time factor, words per second, wall-clock.
- **Get word-level timestamps** and language auto-detection (via Whisper).
- **Stream transcription** from long-running mic or file input (10 s sliding window / 3 s step).
- **Export** to `.txt`, `.srt`, `.vtt`, or `.json` through the system share sheet.
- **Review history** — every run is persisted as JSON and browseable / re-exportable.
- **Diagnose with logs** — in-app viewer with filter / search / copy / export, optional file sink.
- **Use CrisperWeaver in English or German** — full i18n scaffold via `flutter_localizations`.

## Supported models

One dispatcher (`CrispasrSession`) handles all 10 backends; bundled `libcrispasr` reports at startup which are linked in the current build.

| Family                | Sizes                               | Languages                   | Notes                                |
| --------------------- | ----------------------------------- | --------------------------- | ------------------------------------ |
| **Whisper**           | tiny → large-v3 + q4_0/q5_0/q8_0    | 99                          | Word-level ts, lang-detect, streaming |
| **Parakeet** (NVIDIA) | tdt-0.6b-v3                         | 25 EU (auto-detect)         | Fast, native word timestamps          |
| **Canary** (NVIDIA)   | 1b-v2                               | 25 EU (explicit src/tgt)    | Speech translation X ↔ en             |
| **Qwen3-ASR**         | 0.6b                                | 30 + 22 Chinese dialects    | Multilingual                          |
| **Cohere**            | 03-2026                             | 13                          | High-accuracy Conformer decoder       |
| **Granite Speech**    | 3.2-8b, 3.3-2b/8b, 4.0-1b           | en fr de es pt ja           | Instruction-tuned                     |
| **FastConformer-CTC** | small → xxlarge                     | en                          | Low-latency CTC                       |
| **Canary-CTC**        | 1b                                  | 25 EU                       | CTC variant of canary                 |
| **Voxtral Mini**      | 3B (2507), 4B realtime (2602)       | 8 / 13                      | Speech translation; realtime 4B       |
| **Wav2Vec2**          | large-xlsr-53-english + variants    | per-model (en, de, multi)   | Self-supervised CTC                   |

Downloads pull f16 from `ggerganov/whisper.cpp` and quantised variants from [`cstr/whisper-ggml-quants`][cstr] and other `cstr/*-GGUF` repos. Skip-checksum toggle in Settings for custom or mirrored GGUFs.

[cstr]: https://huggingface.co/cstr

## Platforms

| Platform | State                                                                 |
| -------- | --------------------------------------------------------------------- |
| macOS    | ✅ Verified — CI builds Metal-enabled `.app`, local build green        |
| Linux    | ✅ CI-built desktop bundle with DT_NEEDED dylibs                       |
| Windows  | ⚠️ CMake targets exist; no CI yet                                     |
| Android  | ⚠️ APK builds with Mock engine; `libwhisper.so` wiring is manual      |
| iOS      | ⚠️ Xcode project ready; pinned TensorFlowLiteSwift blocks `pod install` |

Roadmap and blockers: see [`PLAN.md`](PLAN.md).

---

## Building

### Prerequisites

- Flutter 3.38.x (`stable`)
- Xcode + CocoaPods for iOS / macOS
- JDK 17 + Android SDK for Android
- CMake + a C++ toolchain to build `libwhisper` from CrispASR
- Optional: Metal (macOS), CUDA / Vulkan (Linux/Windows), Core ML (iOS), NNAPI (Android)

### Clone the two repos side-by-side

```bash
mkdir crisperweaver && cd crisperweaver
git clone https://github.com/CrispStrobe/CrispASR.git
git clone https://github.com/CrispStrobe/CrisperWeaver.git
```

`pubspec.yaml` refers to the Dart FFI package via `path: ../CrispASR/flutter/crispasr`.

### Build libwhisper / libcrispasr (macOS / Linux)

```bash
cd CrispASR
cmake -B build -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_SHARED_LIBS=ON -DWHISPER_METAL=ON
cmake --build build --parallel --target whisper
```

Produces `build/src/libwhisper.*.dylib` (macOS) or `.so` (Linux) plus a `libcrispasr` alias.

### Run

```bash
cd ../CrisperWeaver
flutter pub get
flutter run -d macos        # or: linux, windows, android, ios
```

### Package a macOS `.app` with all dylibs bundled

```bash
flutter build macos --release
CRISPASR_DIR="$(pwd)/../CrispASR" \
  APP=build/macos/Build/Products/Release/crisper_weaver.app \
  ./scripts/bundle_macos_dylibs.sh
```

The script copies every sibling ASR dylib into `Contents/Frameworks/`, creates the `libcrispasr.dylib` alias, and ad-hoc codesigns the bundle. At runtime, `CrispASREngine` auto-detects the library from the bundle first, then `$HOME/code/CrispASR/build/src/`, then `/usr/local/lib/`, then an optional user-supplied path.

---

## Using it

1. **First run**: open *Settings → Manage models* and download the model you want. Default pick is Whisper base (~140 MB, covers 99 languages).
2. **Transcribe a file**: back to the main screen, drop a file or click the picker. Language auto-detects by default.
3. **Record from the mic**: use the recorder card. Stop → transcribe.
4. **Stream from mic** (Whisper): toggle *Stream* in the recorder. Partial text arrives as you speak.
5. **Export the result**: share-sheet button → pick TXT / SRT / VTT / JSON.
6. **Browse past runs**: *History* in the drawer — everything is persisted as JSON under `<app-docs>/history/`.

Useful Settings:
- **Preferred engine** — CrispASR is the default.
- **Default model / language** — pre-select across new transcriptions.
- **Skip checksum verification** — custom / mirrored GGUFs.
- **Log level + file sink** — `<app-docs>/logs/session.log` for bug reports.

---

## CI & releases

- **`ci.yml`** — on push / PR: `flutter analyze` + `flutter test` on Ubuntu and macOS, plus debug `.app` and Linux bundle uploaded as workflow artifacts. Checks out sibling `CrispStrobe/CrispASR` automatically.
- **`release.yml`** — on a `vX.Y.Z` tag (or manual dispatch): Release `.app` with Metal-enabled `libwhisper` + all ten backend dylibs bundled, ad-hoc codesigned, zipped, and attached to the matching GitHub Release. Also uploads an unsigned Android APK.

Both workflows honour `CRISPASR_REPO` / `CRISPASR_REF` env vars at the top of each file, in case you maintain a fork of CrispASR.

---

## Roadmap

The short version:

- Real speaker diarization (blocked on upstream CrispASR diarization API — MFCC/k-means stopgap currently in place).
- Windows CI job.
- iOS `pod install` unblock: drop the stale `TensorFlowLiteSwift '~> 2.13.0'` pin.
- Android Gradle cleanup: pick Groovy *or* KTS, port plugin registrations.
- Finish i18n migration for widgets + older Settings strings.
- Backend-specific UX (source/target language UI for Canary, Voxtral audio Q&A mode, Granite `--ask` flag, etc.).

Full per-item breakdown with file paths, risks, and verification steps: **[`PLAN.md`](PLAN.md)**.

Technical learnings collected during development (FFI quirks, dylib bundling, macOS chrome, CI patterns): **[`LEARNINGS.md`](LEARNINGS.md)**.

---

## License & author

CrisperWeaver is **GNU AGPL-3.0-or-later**. See [`LICENSE`](LICENSE) for full text and the in-app *About* screen for the auto-aggregated third-party license list (`showLicensePage`).

Copyright © Christian Ströbele · Stuttgart, Germany.
