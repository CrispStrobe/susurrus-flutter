#!/usr/bin/env bash
#
# Build crispasr.xcframework with iOS-only slices (device + simulator).
#
# This is the slim, dev-machine alternative to
# CrispASR/build-xcframework.sh, which builds 7 Apple platform slices
# (iOS, macOS, visionOS, tvOS, all device + simulator). The full script
# eats 30-60 min and 7-20 GB of disk. Production iOS builds and the
# release IPA happen in CI (.github/workflows); this script exists so a
# single dev machine can sideload-test on a connected iPhone/iPad
# without paying the full multi-platform tax.
#
# Output: $CRISPASR_DIR/build-apple/crispasr.xcframework with two
# slices (ios-arm64, ios-arm64_x86_64-simulator). Drag that into
# Runner.xcodeproj with "Embed & Sign" — the framework's install_name
# is @rpath/crispasr.framework/crispasr, which matches the third
# candidate the package:crispasr loader tries.
#
# Usage: scripts/build_ios_xcframework.sh
#
# Env:
#   CRISPASR_DIR          path to sibling CrispASR repo
#                         (default: ../CrispASR)
#   IOS_MIN_OS_VERSION    minimum iOS deployment target (default: 13.0,
#                         matching CrisperWeaver's Podfile)
#   COREML                "ON"/"OFF" (default: ON) — wires the .mlmodelc
#                         encoder for whisper backends, ~2-3× faster on
#                         the Apple Neural Engine.
#   CLEAN                 "1" to wipe build dirs first, "0" (default) to
#                         resume from existing cmake caches.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CRISPASR_DIR="${CRISPASR_DIR:-$(cd "$REPO_ROOT/.." && pwd)/CrispASR}"
IOS_MIN_OS_VERSION="${IOS_MIN_OS_VERSION:-13.0}"
COREML="${COREML:-ON}"
CLEAN="${CLEAN:-0}"

if [[ ! -d "$CRISPASR_DIR" ]]; then
  echo "error: sibling CrispASR repo not at $CRISPASR_DIR" >&2
  echo "       Clone it: git clone https://github.com/CrispStrobe/CrispASR \"$CRISPASR_DIR\"" >&2
  exit 1
fi

cd "$CRISPASR_DIR"

if [[ "$CLEAN" == "1" ]]; then
  echo "==> cleaning previous iOS build dirs"
  rm -rf build-ios-sim build-ios-device build-apple
fi

# COREML on iOS needs deployment target ≥ 14.0; if the user picked
# something lower, drop COREML rather than fail at link time.
EFFECTIVE_COREML="$COREML"
if [[ "$EFFECTIVE_COREML" == "ON" ]]; then
  major="${IOS_MIN_OS_VERSION%%.*}"
  if [[ "$major" -lt 14 ]]; then
    echo "warn: IOS_MIN_OS_VERSION=$IOS_MIN_OS_VERSION < 14.0; disabling CoreML" >&2
    EFFECTIVE_COREML="OFF"
  fi
fi

COMMON_C_FLAGS="-Wno-macro-redefined -Wno-shorten-64-to-32 -Wno-unused-command-line-argument -g"
COMMON_CXX_FLAGS="$COMMON_C_FLAGS"

COMMON_CMAKE_ARGS=(
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY=
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO
  -DCMAKE_XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT=dwarf-with-dsym
  -DCMAKE_XCODE_ATTRIBUTE_GCC_GENERATE_DEBUGGING_SYMBOLS=YES
  -DCMAKE_XCODE_ATTRIBUTE_COPY_PHASE_STRIP=NO
  -DCMAKE_XCODE_ATTRIBUTE_STRIP_INSTALLED_PRODUCT=NO
  -DBUILD_SHARED_LIBS=OFF
  -DCRISPASR_BUILD_EXAMPLES=OFF
  -DCRISPASR_BUILD_TESTS=OFF
  -DCRISPASR_BUILD_SERVER=OFF
  -DGGML_METAL_EMBED_LIBRARY=ON
  -DGGML_BLAS_DEFAULT=ON
  -DGGML_METAL=ON
  -DGGML_METAL_USE_BF16=ON
  -DGGML_NATIVE=OFF
  -DGGML_OPENMP=OFF
  # Kokoro normally links against libespeak-ng for in-process
  # phonemization. CrispASR's CMakeLists picks up homebrew's macOS
  # build at configure time, which then fails to satisfy iOS arm64
  # link-time symbols. Force OFF for iOS — kokoro falls back to its
  # popen("espeak-ng …") shellout, which doesn't exist on iOS, so
  # kokoro on iOS effectively can't phonemize. That's a known
  # limitation; the other 30 backends still work.
  -DCRISPASR_WITH_ESPEAK_NG=OFF
  -DCMAKE_OSX_DEPLOYMENT_TARGET=$IOS_MIN_OS_VERSION
)

# ---- Build iOS simulator slice (arm64, since Apple Silicon Mac) ----
echo "==> cmake configure: iOS simulator"
cmake -B build-ios-sim -G Xcode \
  "${COMMON_CMAKE_ARGS[@]}" \
  -DIOS=ON \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphonesimulator \
  -DCMAKE_OSX_ARCHITECTURES="arm64" \
  -DCMAKE_XCODE_ATTRIBUTE_SUPPORTED_PLATFORMS=iphonesimulator \
  -DCMAKE_C_FLAGS="$COMMON_C_FLAGS" \
  -DCMAKE_CXX_FLAGS="$COMMON_CXX_FLAGS" \
  -DCRISPASR_COREML="$EFFECTIVE_COREML" \
  -DCRISPASR_COREML_ALLOW_FALLBACK=ON \
  -S .
echo "==> cmake build: iOS simulator"
cmake --build build-ios-sim --config Release -- -quiet

# ---- Build iOS device slice (arm64) ----
echo "==> cmake configure: iOS device"
cmake -B build-ios-device -G Xcode \
  "${COMMON_CMAKE_ARGS[@]}" \
  -DIOS=ON \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphoneos \
  -DCMAKE_OSX_ARCHITECTURES="arm64" \
  -DCMAKE_XCODE_ATTRIBUTE_SUPPORTED_PLATFORMS=iphoneos \
  -DCMAKE_C_FLAGS="$COMMON_C_FLAGS" \
  -DCMAKE_CXX_FLAGS="$COMMON_CXX_FLAGS" \
  -DCRISPASR_COREML="$EFFECTIVE_COREML" \
  -DCRISPASR_COREML_ALLOW_FALLBACK=ON \
  -S .
echo "==> cmake build: iOS device"
cmake --build build-ios-device --config Release -- -quiet

# ---- Wrap each slice into a crispasr.framework bundle ----
# Mirrors setup_framework_structure() and combine_static_libraries()
# from CrispASR/build-xcframework.sh, restricted to iOS.
setup_framework() {
  local build_dir="$1"
  local plat_dir="${CRISPASR_DIR}/${build_dir}"
  local fw="${plat_dir}/framework/crispasr.framework"
  rm -rf "$fw"
  mkdir -p "$fw/Headers" "$fw/Modules"

  cp include/crispasr.h          "$fw/Headers/"
  cp ggml/include/ggml.h         "$fw/Headers/"
  cp ggml/include/ggml-alloc.h   "$fw/Headers/"
  cp ggml/include/ggml-backend.h "$fw/Headers/"
  cp ggml/include/ggml-metal.h   "$fw/Headers/"
  cp ggml/include/ggml-cpu.h     "$fw/Headers/"
  cp ggml/include/ggml-blas.h    "$fw/Headers/"
  cp ggml/include/gguf.h         "$fw/Headers/"

  cat > "$fw/Modules/module.modulemap" <<EOF
framework module crispasr {
    header "crispasr.h"
    header "ggml.h"
    header "ggml-alloc.h"
    header "ggml-backend.h"
    header "ggml-metal.h"
    header "ggml-cpu.h"
    header "ggml-blas.h"
    header "gguf.h"

    link "c++"
    link framework "Accelerate"
    link framework "Metal"
    link framework "Foundation"

    export *
}
EOF

  cat > "$fw/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>crispasr</string>
    <key>CFBundleIdentifier</key><string>org.ggml.crispasr</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>crispasr</string>
    <key>CFBundlePackageType</key><string>FMWK</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>MinimumOSVersion</key><string>${IOS_MIN_OS_VERSION}</string>
    <key>CFBundleSupportedPlatforms</key><array><string>iPhoneOS</string></array>
    <key>UIDeviceFamily</key><array><integer>1</integer><integer>2</integer></array>
    <key>DTPlatformName</key><string>iphoneos</string>
    <key>DTSDKName</key><string>iphoneos${IOS_MIN_OS_VERSION}</string>
</dict>
</plist>
EOF
}

combine() {
  local build_dir="$1"        # build-ios-sim or build-ios-device
  local release_dir="$2"      # Release-iphonesimulator or Release-iphoneos
  local sdk="$3"              # iphonesimulator or iphoneos
  local archs="$4"            # arm64 (or arm64+x86_64 for sim, but we kept sim arm64 only)
  local min_flag="$5"         # -mios-version-min=… or -mios-simulator-version-min=…
  local plat_dir="${CRISPASR_DIR}/${build_dir}"
  local fw="${plat_dir}/framework/crispasr.framework"
  local out_lib="${fw}/crispasr"

  # CrispASR's main libcrispasr.a calls into ~30 per-backend static
  # libs (libparakeet.a, libvoxtral.a, libkokoro.a, …). With
  # BUILD_SHARED_LIBS=OFF those backends aren't transitively pulled
  # into libcrispasr.a — the shared-lib link step would normally pull
  # them via target_link_libraries, but for a static archive we have
  # to list them all explicitly. Glob `src/${release_dir}/lib*.a` to
  # pick up every backend without hardcoding the list. The CrispASR
  # build-xcframework.sh upstream only enumerates libcrispasr+ggml*,
  # which is why the iOS link there fails on the same symbols if you
  # try it standalone — this is the working fix.
  local libs=(
    "${plat_dir}/ggml/src/${release_dir}/libggml.a"
    "${plat_dir}/ggml/src/${release_dir}/libggml-base.a"
    "${plat_dir}/ggml/src/${release_dir}/libggml-cpu.a"
    "${plat_dir}/ggml/src/ggml-metal/${release_dir}/libggml-metal.a"
    "${plat_dir}/ggml/src/ggml-blas/${release_dir}/libggml-blas.a"
  )
  while IFS= read -r -d '' lib; do
    libs+=("$lib")
  done < <(find "${plat_dir}/src/${release_dir}" -maxdepth 1 -name 'lib*.a' -print0)
  # crisp_audio is its own subdir (not under src/). qwen3_asr +
  # voxtral both call into it via crisp_audio_compute_mel etc.
  if [[ -f "${plat_dir}/crisp_audio/${release_dir}/libcrisp_audio.a" ]]; then
    libs+=("${plat_dir}/crisp_audio/${release_dir}/libcrisp_audio.a")
  fi

  local temp_dir="${plat_dir}/temp"
  rm -rf "$temp_dir"
  mkdir -p "$temp_dir"

  # Dedup .o objects across libs. moonshine + moonshine_streaming
  # both ship their own copy of moonshine-tokenizer.o; libtool's plain
  # `-static -o combined.a lib*.a` would let both through and the
  # subsequent `clang++ -dynamiclib -force_load combined.a` errors out
  # with "duplicate symbol". We extract .o files into per-lib subdirs
  # to keep names like crispasr_c_api.o (which appear in libcrispasr
  # AND libcrispasr-core) unique by directory, then dedup by basename
  # taking the FIRST occurrence (libs earlier in the list win — order
  # matters: libcrispasr.a before per-backend libs so the C-ABI's
  # crispasr_session_open dispatch wins over duplicates).
  local extract_dir="${temp_dir}/extract"
  mkdir -p "$extract_dir"
  local i=0
  for lib in "${libs[@]}"; do
    [[ -f "$lib" ]] || continue
    local sub="$extract_dir/$(printf '%03d' $i)_$(basename "$lib" .a)"
    mkdir -p "$sub"
    (cd "$sub" && ar -x "$lib")
    i=$((i+1))
  done

  local dedup_dir="${temp_dir}/dedup"
  mkdir -p "$dedup_dir"
  # Iterate in lexical order on the per-lib subdirs (000_, 001_, …) so
  # the FIRST library's copy of any given .o wins.
  find "$extract_dir" -name "*.o" -print | sort | while read obj; do
    base=$(basename "$obj")
    [[ -f "$dedup_dir/$base" ]] || cp "$obj" "$dedup_dir/$base"
  done

  ar -rcs "${temp_dir}/combined.a" "$dedup_dir"/*.o 2>/dev/null
  rm -rf "$extract_dir" "$dedup_dir"

  local arch_flags=""
  for a in $archs; do arch_flags+=" -arch $a"; done

  local frameworks="-framework Foundation -framework Metal -framework Accelerate"
  if [[ "$EFFECTIVE_COREML" == "ON" ]]; then
    frameworks+=" -framework CoreML"
  fi

  echo "==> linking ${build_dir} → crispasr.framework/crispasr"
  xcrun -sdk "$sdk" clang++ -dynamiclib \
    -isysroot "$(xcrun --sdk $sdk --show-sdk-path)" \
    $arch_flags \
    $min_flag \
    -Wl,-force_load,"${temp_dir}/combined.a" \
    $frameworks \
    -install_name "@rpath/crispasr.framework/crispasr" \
    -o "$out_lib"

  # iOS device builds need vtool to mark the binary as a framework
  # binary so App Store validation accepts it.
  if [[ "$sdk" == "iphoneos" ]] && command -v xcrun >/dev/null && xcrun vtool 2>/dev/null; then
    xcrun vtool -set-build-version ios "$IOS_MIN_OS_VERSION" "$IOS_MIN_OS_VERSION" -replace \
      -output "$out_lib" "$out_lib" 2>/dev/null || true
  fi

  # Generate dSYM next to the framework, then strip the in-framework
  # copy so the binary inside the .framework is small.
  mkdir -p "${plat_dir}/dSYMs"
  xcrun dsymutil "$out_lib" -o "${plat_dir}/dSYMs/crispasr.dSYM" 2>/dev/null
  xcrun strip -S "$out_lib" -o "${temp_dir}/stripped" 2>/dev/null && \
    mv "${temp_dir}/stripped" "$out_lib"

  rm -rf "$temp_dir"
}

echo "==> framework setup: simulator"
setup_framework "build-ios-sim"
combine "build-ios-sim" "Release-iphonesimulator" "iphonesimulator" "arm64" \
  "-mios-simulator-version-min=$IOS_MIN_OS_VERSION"

echo "==> framework setup: device"
setup_framework "build-ios-device"
combine "build-ios-device" "Release-iphoneos" "iphoneos" "arm64" \
  "-mios-version-min=$IOS_MIN_OS_VERSION"

# ---- xcframework with both slices ----
mkdir -p build-apple
rm -rf build-apple/crispasr.xcframework
echo "==> xcodebuild -create-xcframework"
xcodebuild -create-xcframework \
  -framework "${CRISPASR_DIR}/build-ios-sim/framework/crispasr.framework" \
  -debug-symbols "${CRISPASR_DIR}/build-ios-sim/dSYMs/crispasr.dSYM" \
  -framework "${CRISPASR_DIR}/build-ios-device/framework/crispasr.framework" \
  -debug-symbols "${CRISPASR_DIR}/build-ios-device/dSYMs/crispasr.dSYM" \
  -output "${CRISPASR_DIR}/build-apple/crispasr.xcframework"

# ---- Mirror into CrisperWeaver/ios/Frameworks/ for the wiring step ----
DEST="$REPO_ROOT/ios/Frameworks/crispasr.xcframework"
mkdir -p "$REPO_ROOT/ios/Frameworks"
rm -rf "$DEST"
cp -R "${CRISPASR_DIR}/build-apple/crispasr.xcframework" "$DEST"

echo
echo "==> done"
echo "    xcframework: $DEST"
echo "    next: scripts/wire_ios_xcframework.rb (adds it to Runner.xcodeproj"
echo "          with Embed & Sign), then flutter build ios"
