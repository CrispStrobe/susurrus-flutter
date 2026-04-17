#!/usr/bin/env bash
#
# Copy all CrispASR sibling dylibs into a built crisper_weaver.app
# bundle so every backend the library was linked with is resolvable
# at runtime. Runs from either the local dev tree or CI after
# `flutter build macos`.
#
# Expects the sibling CrispASR repo at ../CrispASR (dev) or
# $CRISPASR_DIR (CI). Fails loudly if libwhisper isn't built yet —
# produce it first with:
#   cd ../CrispASR && cmake -B build -DCMAKE_BUILD_TYPE=Release \
#                      -DBUILD_SHARED_LIBS=ON -DWHISPER_METAL=ON && \
#                    cmake --build build --parallel --target whisper
#
# Usage:
#   scripts/bundle_macos_dylibs.sh [path/to/.app]
# Default app path: build/macos/Build/Products/{Debug,Release}/crisper_weaver.app

set -euo pipefail

APP="${1:-}"
if [[ -z "$APP" ]]; then
  for cfg in Debug Release Profile; do
    candidate="build/macos/Build/Products/$cfg/crisper_weaver.app"
    if [[ -d "$candidate" ]]; then APP="$candidate"; break; fi
  done
fi
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "error: app bundle not found. Run flutter build macos first, or pass the path explicitly." >&2
  exit 2
fi

CRISPASR_DIR="${CRISPASR_DIR:-$(cd "$(dirname "$0")/../.." && pwd)/CrispASR}"
if [[ ! -d "$CRISPASR_DIR/build/src" ]]; then
  echo "error: CrispASR build tree not found at $CRISPASR_DIR/build/src" >&2
  echo "       Set CRISPASR_DIR or build CrispASR first." >&2
  exit 3
fi

FRAMEWORKS="$APP/Contents/Frameworks"
mkdir -p "$FRAMEWORKS"

# Core library. CrispASR produces libwhisper.{version}.dylib plus
# symlinks libwhisper.dylib and libcrispasr.dylib; grab whichever
# concrete file exists.
VERSIONED="$(ls "$CRISPASR_DIR"/build/src/libwhisper.[0-9]*.dylib 2>/dev/null | head -1)"
if [[ -z "$VERSIONED" || ! -f "$VERSIONED" ]]; then
  VERSIONED="$CRISPASR_DIR/build/src/libwhisper.dylib"
fi
if [[ ! -f "$VERSIONED" ]]; then
  echo "error: libwhisper dylib not found under $CRISPASR_DIR/build/src" >&2
  exit 4
fi
cp "$VERSIONED" "$FRAMEWORKS/libwhisper.dylib"
# Also create the libcrispasr.dylib alias so the Dart wrapper's
# preferred library name resolves.
ln -sf libwhisper.dylib "$FRAMEWORKS/libcrispasr.dylib"

# Sibling backend dylibs — each one is a DT_NEEDED dependency of
# libwhisper.dylib. Missing ones just get skipped with a warning
# (slim builds are legit; the bundle still works for the backends
# that ARE present).
for name in parakeet canary qwen3_asr cohere granite_speech canary_ctc \
            voxtral voxtral4b; do
  src="$CRISPASR_DIR/build/src/lib${name}.dylib"
  if [[ -f "$src" ]]; then
    cp "$src" "$FRAMEWORKS/lib${name}.dylib"
  else
    echo "warn: $src not found — backend ${name} will be missing at runtime" >&2
  fi
done

# wav2vec2 is built as a static library (see src/CMakeLists.txt), so
# its symbols are already inside libwhisper.dylib — nothing to copy.

# Ad-hoc sign so Gatekeeper / mission control doesn't reject the
# modified bundle during development. Release builds should use a
# real developer ID via codesign separately.
codesign --force --deep --sign - "$APP" >/dev/null

echo "Bundled dylibs:"
ls -l "$FRAMEWORKS" | grep -E "\.dylib" | awk '{print "  " $NF}'
