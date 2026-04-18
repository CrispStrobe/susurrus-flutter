# CrisperWeaver — Technical learnings

Things we spent hours figuring out while porting CrispASR's 10-backend FFI surface into a cross-platform Flutter app. Nothing here is news to someone who's shipped a native-code Flutter app before — everything here is something we'd have saved a day by knowing up front.

If a learning is still live (affects current work), it's linked from [`PLAN.md`](PLAN.md). If it's purely historical (a bug we fixed), it lives here.

---

## Dart FFI

### Generic helpers over `NativeFunction<T>` fail under `flutter test`, not `dart test`

**Symptom:** a helper like

```dart
R _tryLookup<T extends Function, R extends Function>(String sym) {
  return lib.lookupFunction<NativeFunction<T>, R>(sym);
}
```

compiles and runs under `dart test` but fails in `flutter test` with

> Expected type 'NativeFunction<T>' to be a valid and instantiated subtype of 'NativeType'

**Reason:** the Flutter test runner rewraps `NativeFunction<T>` generics differently from the standalone VM; `T` isn't visible as an instantiated type at the FFI lookup site.

**Fix:** drop the generic. Per-symbol `providesSymbol` probe + concrete `lookupFunction<Concrete, Concrete>`:

```dart
if (!lib.providesSymbol('crispasr_audio_load')) return null;
final fn = lib.lookupFunction<
    Int32 Function(Pointer<Utf8>, Pointer<Pointer<Float>>, Pointer<Int32>, Pointer<Int32>),
    int Function(Pointer<Utf8>, Pointer<Pointer<Float>>, Pointer<Int32>, Pointer<Int32>)
>('crispasr_audio_load');
```

More boilerplate, but it works everywhere.

### `calloc<Utf8>(n)` fails: Utf8 is not a `SizedNativeType`

**Symptom:** allocation lines like `calloc<Utf8>(16)` fail compilation on newer Dart FFI:

> 'Utf8' is not a 'SizedNativeType'

**Fix:** allocate as bytes, then cast:

```dart
final buf = calloc<Uint8>(16).cast<Utf8>();
```

### Optional FFI symbols: probe before bind

If your library may or may not expose a symbol (e.g. new helpers added in CrispASR 0.4.x), always `providesSymbol('foo')` before `lookupFunction`. Otherwise any older copy of the dylib crashes the app on startup.

## Dylib bundling

### `libcrispasr` is a compatibility alias, not a separate library

CrispASR's core dylib is still called `libwhisper.dylib` (historical — the project is a whisper.cpp fork). `libcrispasr.dylib` is a symlink (Unix) or copy (Windows) created by CMake post-build. Both point to the same file and export the same symbols; the Dart loader tries `libcrispasr` first, falls back to `libwhisper`.

**Don't** expect them to be independently versionable — they're the same code.

### On macOS, DT_NEEDED sibling dylibs must live in `Contents/Frameworks/`

The app bundles ten dylibs: `libwhisper.dylib` plus `libparakeet`, `libcanary`, `libcohere`, `libqwen3_asr`, `libgranite_speech`, `libcanary_ctc`, `libvoxtral`, `libvoxtral4b`, `libwav2vec2-ggml` — all linked as DT_NEEDED from libwhisper itself. `dyld` finds them via `@rpath/@loader_path` (CMake sets this correctly at build time), but they must physically sit next to `libwhisper.dylib` inside `Contents/Frameworks/`.

`scripts/bundle_macos_dylibs.sh` does the copy + ad-hoc codesign. Skipping the codesign causes Gatekeeper to refuse to load the auxiliary dylibs with a permissions error that looks like "library not found" — very misleading.

### On Linux, DT_NEEDED siblings go into `bundle/lib/` — plus version symlinks

Unlike macOS, Linux's `libwhisper.so` has a SONAME with a version number (e.g. `libwhisper.so.1`). The CMake build produces three files:

```
libwhisper.so -> libwhisper.so.1
libwhisper.so.1 -> libwhisper.so.1.8.4
libwhisper.so.1.8.4
```

The CI bundle script picks the real file (`.so.1.8.4`), copies it as `libwhisper.so`, then symlinks `libcrispasr.so → libwhisper.so`. Both open paths work. Missing sibling `.so`'s (parakeet/canary/...) are skipped with a warning — a slim build stays valid.

### Static libs linked into shared libs need `-fPIC`

**Symptom:** linking `libwav2vec2-ggml.a` (a CMake `STATIC` library) into `libwhisper.so` fails on Linux with

> relocation R_X86_64_32 against `.rodata' can not be used when making a shared object; recompile with -fPIC

**Fix:** `set_target_properties(wav2vec2-ggml PROPERTIES POSITION_INDEPENDENT_CODE ON)` in the CMakeLists for that target. macOS is lenient (always PIC); Linux enforces it.

## Flutter + macOS

### CardTheme / DialogTheme / TabBarTheme were renamed in 3.38

If you pinned Flutter ≤ 3.35 and bumped to 3.38.5, any custom theming like

```dart
cardTheme: CardTheme(elevation: 2)
```

stops compiling. The replacements are `CardThemeData`, `DialogThemeData`, `TabBarThemeData`. Same constructor args, just the `*Data` suffix.

### Abstract exception classes can't be thrown

`EngineException` was declared abstract (`abstract class EngineException implements Exception`). Calling `throw EngineException('...')` fails compilation. Either declare it concrete, or add a `GenericEngineException(this.message)` concrete subclass for the "no specific reason" cases. We did the latter.

### `RenderFlex overflowed by N pixels` on macOS initial window

On macOS the default NSWindow opens at a smaller-than-you-think size. If your top `Scaffold` has an AppBar + tabs + search field + status chip all in one row, you will overflow at 1024-wide. Iterative fixes we ended up with:

- `LayoutBuilder` with `constraints.maxWidth < 720` → wrap wide-form widgets in a narrow variant.
- Remove tab icons (just labels).
- `isDense: true` on the search field.
- Use `titleMedium` instead of `headlineSmall` in AppBar.
- Set `minSize` on the NSWindow in `MainFlutterWindow.swift`.
- Default window to 1200 × 800.

The Flutter inspector's "overflow by X pixels" message counts from the *outside in* — start with the top-level row and work inward. Don't bother with `Expanded` on the first pass; it usually isn't what you want.

### Xcode "Run Script" phase warning is noise

> Run script build phase 'Run Script' will be run during every build because it does not specify any outputs.

Flutter's own generated script phase. Cosmetic. Ignore.

## Flutter dependency pinning

### `material_color_utilities` is a constant moving target

Flutter SDK pins an exact version; ecosystem packages pin a broader range; the two occasionally disagree. Our override:

```yaml
dependency_overrides:
  material_color_utilities: ">=0.8.0 <0.12.0"
```

Revisit after every Flutter minor bump.

### `intl` version collision with `flutter_localizations`

Same issue. `flutter_localizations` pins `intl` tightly; packages like `share_plus` pin a range that doesn't overlap. Override:

```yaml
dependency_overrides:
  intl: ">=0.19.0 <0.21.0"
```

### `record_linux` 0.7.x breaks `record` 5.x's platform interface

`record 5.1.2` wants `record_linux ^1.3.0`, but pub's resolver picks `0.7.2` without an override. Symptom: Linux build fails because the mic-record plugin can't find `LinuxRecorder.registerWith()`. Override:

```yaml
dependency_overrides:
  record_linux: ^1.3.0
```

## CI patterns

### Sibling-repo checkout

CrisperWeaver's `pubspec.yaml` has `crispasr: { path: ../CrispASR/flutter/crispasr }`. CI's `checkout` actions therefore both live under `$GITHUB_WORKSPACE`:

```yaml
- uses: actions/checkout@v4
  with:
    path: repos/CrisperWeaver
- uses: actions/checkout@v4
  with:
    repository: CrispStrobe/CrispASR
    path: repos/CrispASR
```

`working-directory: repos/CrisperWeaver` on every subsequent step. The `../CrispASR/...` path resolves naturally.

Lesson: don't try to use a git submodule for this. Submodules pin a SHA; we want `main` both places. Sibling checkout is messier but gives you the "develop both repos in lockstep" workflow you actually wanted.

### `cancel-in-progress` is what you want

```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
```

When you push three commits in quick succession, only the last one runs to completion — the first two get cancelled mid-stream. Saves runner minutes and keeps CI status readable.

### `flutter analyze` infos/warnings ≠ errors

By default, `flutter analyze` exits non-zero on infos and warnings too. We only want to fail on errors:

```yaml
- run: |
    set +e
    flutter analyze --no-fatal-infos --no-fatal-warnings
    status=$?
    if [ $status -ne 0 ]; then
      echo "::error::flutter analyze reported errors"
      exit $status
    fi
```

### `cppcheck` hates third-party single-header libraries

`miniaudio.h` is 95K lines. cppcheck spends minutes on it and generates hundreds of warnings for code that isn't ours. Suppress by filename:

```yaml
--suppress="*:src/miniaudio.h" --suppress="*:*stb_vorbis.c"
```

## WAV parsing

### Signed 16-bit PCM: use `getInt16`, not `getUint16` then subtract

Classic off-by-one-bit mistake. Reading the sample as unsigned and subtracting 32768 to "re-center" gives you an output amplitude that's *almost* right but off by 1 LSB. Just use `byteData.getInt16(pos, Endian.little)` and divide by 32768 — floats handle the range directly.

### Chunk iteration: pad to 2 bytes

WAV chunks are padded to 2-byte boundaries. After reading a chunk, `if (chunkSize % 2 != 0) offset++;` — otherwise a fmt chunk with odd size (rare but legal) misaligns every subsequent chunk and you get "No data chunk found".

## macOS lifecycle + ggml teardown race

### Dispose heavy native state on `AppLifecycleListener.onExitRequested`

On the red-X close of a Flutter macOS app, the runtime calls `exit()` → `__cxa_finalize_ranges()`. Any global `std::vector<ggml_metal_device>` destructor that runs at that moment tries to free residency sets, but ggml-metal's background 500 ms keep-alive dispatch queue (`__ggml_metal_rsets_init_block_invoke`) is still alive → `ggml_metal_rsets_free` asserts → `abort` → macOS shows a "closed unexpectedly" dialog.

**Fix:** wire `AppLifecycleListener(onExitRequested: ...)` in the root Stateful widget. Inside it: dispose the engine (which tears down the whisper context, which cancels ggml-metal's dispatch queue), flush your log sink, *then* return `AppExitResponse.exit`. By the time `exit()` runs the global destructors, the Metal state is gone.

```dart
_lifecycle = AppLifecycleListener(onExitRequested: () async {
  ref.read(transcriptionServiceProvider).dispose();
  await Log.instance.enableFileSink(false);  // flush + close
  return AppExitResponse.exit;
});
```

`AppExitResponse` is in `dart:ui`, not `package:flutter/services.dart` as the name suggests — `import 'dart:ui' show AppExitResponse;`.

### Heavyweight Swift code in `MainFlutterWindow.swift` lingers forever

The standard Flutter-for-macOS template has a 26-line `MainFlutterWindow.swift`. Ours had 387 lines of dead `AudioProcessingPlugin` Swift (AVFoundation + Accelerate FFT via `DSPSplitComplex`). It was legacy from the method-channel audio path — replaced by CrispASR's FFI `crispasr_audio_load` long ago — but the Swift was still compiled, still registered the plugin, and still held `AVAudioEngine` references that contributed to the "closed unexpectedly" crash.

**Lesson:** when you rip out a method-channel-based feature on one platform, search for its *other* platform counterparts. I missed this on macOS after cleaning it from iOS. Grep for the plugin name across `ios/` AND `macos/`.

## Remote catalog naming drift

### Don't hardcode third-party file names — probe and build the catalog at runtime

We shipped a hardcoded catalog of `ModelDefinition` entries pointing at `huggingface.co/cstr/*-GGUF/resolve/main/*.gguf` URLs. Each entry was a guess based on the backend's HF-Space naming. Four of them were wrong — e.g. `cohere-transcribe-03-2026-q5_0.gguf` (our guess) vs `cohere-transcribe-q5_0.gguf` (actual). Users got `HTTP 404 "Entry not found"` with no way to recover.

**Fix:** add a `BackendRepo` struct with just `repoId` + `baseName`, and call `GET huggingface.co/api/models/<repo>?blobs=true` at runtime. Parse every `.gguf` sibling into a `ModelDefinition` with the **real** filename and **real** byte-size. Merge live-probed entries over the hardcoded defaults. Auto-probe on first model-manager open so users never have to know about a "refresh" button.

**Corollary:** at most, hardcode repo-level info (repo ID, display prefix), never file-level (filename, URL, size). HF file names drift when model authors republish.

## Logging infrastructure

### Disable Dio's `LogInterceptor` in apps that have their own log view

`package:dio`'s `LogInterceptor(requestHeader:true, responseHeader:true, responseBody:true)` emits ~50 trace lines per HTTP request (every header, every response body byte). We gated it on `kDebugMode` — which is true under `flutter run`, which is where users actually read in-app logs. Our own `download start` / `download done` + DioException summary in the catch already capture the signal. The interceptor was pure noise.

**Lesson:** log only at application-event granularity (download started, download failed with HTTP 404), not at network-protocol granularity. If you need network-protocol logs, gate them behind a separate "HTTP verbose" toggle, not a debug-mode flag.

## Theming and dark mode

### Don't hardcode text colors — use `Theme.of(context).colorScheme.onSurface`

The Logs screen hardcoded `Colors.black87` as the default text colour for every log row. Black-on-dark-surface in dark mode → invisible text. Same mistake lurks wherever `Colors.black*` / `Colors.white*` is used without a theme-aware fallback. The fix is always `Theme.of(context).colorScheme.onSurface` (or `onPrimary` etc. for tinted backgrounds).

Legitimate uses of `Colors.white` still exist — specifically `foregroundColor: Colors.white` paired with `backgroundColor: Colors.red` on destructive-action buttons. Those are OK because both colors are explicit.

## Architecture decisions

### CoreML as an opt-in inside whisper.cpp, not a separate engine

Early scaffolding had a separate `EngineType.coreML` + iOS `CoreMLWhisperPlugin` that talked to a method channel. That's the wrong shape — whisper.cpp ships its own CoreML integration (`WHISPER_USE_COREML`) which loads a `.mlmodelc` for the encoder forward pass, uses the Apple Neural Engine, and falls back to the GGML encoder on error — all through the existing `whisper_full_*` API. Net effect: CoreML acceleration rides through the *same* `CrispASREngine` path with no engine-level fork.

Lesson: resist the urge to model every hardware accelerator as a separate engine. If the underlying library already has a "try accelerator X, fall back to CPU" path, expose it as a build-time flag, not a user-visible engine switch. You save the duplicated tokenizer / audio-loader / context-management code that each engine would otherwise need.

### Model format ≠ engine

`ModelType.whisperCpp` is a *file-format marker* (GGML / GGUF binary loadable by whisper/CrispASR context). It's NOT coupled to a hypothetical `WhisperCppEngine`. Same file lands in `CrispASREngine.loadModel()`. When renaming or culling engine types, grep carefully — the `whisperCpp` token has two unrelated meanings.

## Process / project hygiene

### Don't narrate a rename halfway

Renaming `susurrus-flutter` → `CrisperWeaver` across a Flutter project touches bundle IDs (macOS / iOS / Android), Kotlin package directories, Dart `package:` imports in tests, CI workflow paths, README prose, and a dozen `pubspec.yaml`-referenced identifiers. Mid-rename build attempts created empty shell directories at the intermediate path (`crisperweaver-flutter/`) that Xcode picked up as "stale file" warnings for weeks. Fix: rename atomically via a Python script, run `flutter clean`, then build. Don't `flutter build macos` between step 3 and 4 of the rename.

Corollary: grep the whole tree for the old name *before* declaring the rename done. It catches README references, doc URLs, and assert-messages you'd otherwise miss.

### AGPL-3.0 attribution via LicenseRegistry

Flutter's `showLicensePage` aggregates every pub dep's license. For *native* code bundled via dylib (CrispASR, whisper.cpp, ggml, miniaudio), pub doesn't know about them — register them manually at startup:

```dart
// lib/services/native_licenses.dart
LicenseRegistry.addLicense(() async* {
  yield LicenseEntryWithLineBreaks(
    ['CrispASR'],
    await rootBundle.loadString('assets/licenses/CrispASR.txt'),
  );
});
```

Keep the raw license text in `assets/licenses/` and declare the asset in `pubspec.yaml`. The *About* screen then shows the full list, satisfying AGPL's "provide the license with the conveyed work" requirement.

### Don't commit build artefacts

We accidentally committed `crispasr/target/` (Cargo build dir) and `Cargo.lock` from CrispASR during a CI fix. `.gitignore` additions + `git rm --cached` fixed it. Lesson: when fixing CI across a multi-repo tree, run `git status` frequently.
