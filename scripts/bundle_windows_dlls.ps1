# scripts/bundle_windows_dlls.ps1
#
# Copy every CrispASR DLL next to the Flutter Windows runner's exe so
# `DynamicLibrary.open()` in the Dart FFI binding finds them on app
# start-up.
#
# Env:
#   CRISPASR_DIR          path to the CrispASR checkout
#                         (default: ..\CrispASR)
#   CRISPASR_BUILD_SUBDIR cmake binary dir under CRISPASR_DIR
#                         (default: build — but build_windows.ps1
#                         passes "build-flutter-bundle" to match the
#                         macOS flow)
#   RUNNER_DIR            path to the runner output directory
#                         (default: build\windows\x64\runner\Release)
#
# Usage: pwsh -File scripts\bundle_windows_dlls.ps1
#
# Normally invoked by scripts\build_windows.ps1 — call it directly only
# if you've already produced whisper.dll and the flutter runner.

$ErrorActionPreference = "Stop"

$crispasrDir         = if ($env:CRISPASR_DIR)          { $env:CRISPASR_DIR }          else { "..\CrispASR" }
$crispasrBuildSubdir = if ($env:CRISPASR_BUILD_SUBDIR) { $env:CRISPASR_BUILD_SUBDIR } else { "build" }
$runnerDir           = if ($env:RUNNER_DIR)            { $env:RUNNER_DIR }            else { "build\windows\x64\runner\Release" }
$cBase               = Join-Path $crispasrDir $crispasrBuildSubdir

if (-not (Test-Path $runnerDir)) {
    throw "Runner dir not found: $runnerDir. Run flutter build windows --release first."
}
if (-not (Test-Path $cBase)) {
    throw "CrispASR build tree not found: $cBase. Build CrispASR first or override CRISPASR_BUILD_SUBDIR."
}

# Helper: probe each known per-config output layout MSVC may produce.
function Find-Dll($baseDir, $name) {
    $candidates = @(
        "$baseDir\bin\Release\$name.dll",
        "$baseDir\src\Release\$name.dll",
        "$baseDir\Release\$name.dll",
        "$baseDir\bin\$name.dll",
        "$baseDir\src\$name.dll",
        "$baseDir\$name.dll"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    return $null
}

# Core library — whisper.dll. Required.
$whisperDll = Find-Dll $cBase "whisper"
if (-not $whisperDll) {
    throw "whisper.dll not found under $cBase. Run scripts\build_windows.ps1 (or `cmake --build $crispasrBuildSubdir --config Release --target crispasr`) first."
}

Write-Host "Bundling from: $whisperDll"
Copy-Item $whisperDll "$runnerDir\whisper.dll" -Force
# crispasr.dll alias — Dart FFI loader probes this name first.
Copy-Item $whisperDll "$runnerDir\crispasr.dll" -Force

# Sibling backend DLLs — DT_NEEDED via the import table. If whisper.dll
# was linked with these as PUBLIC dependencies, the DLLs must sit
# alongside it or LoadLibrary fails. List mirrors the BACKEND_TARGETS
# in scripts/build_macos.sh so TTS + post-processors are covered too.
$siblings = @(
    "parakeet", "canary", "canary_ctc", "qwen3_asr", "cohere",
    "granite_speech", "granite_nle", "voxtral", "voxtral4b",
    "wav2vec2-ggml", "glm-asr", "kyutai-stt", "firered-asr",
    "firered-vad", "marblenet-vad", "firered-lid", "omniasr",
    "vibevoice", "ecapa-lid", "moonshine", "moonshine_streaming",
    "gemma4_e2b", "mimo_tokenizer", "mimo_asr", "qwen3_tts", "orpheus",
    "kokoro", "pyannote-seg", "silero-lid", "fireredpunc"
)
foreach ($name in $siblings) {
    $dll = Find-Dll $cBase $name
    if ($dll) {
        Copy-Item $dll "$runnerDir\$name.dll" -Force
        Write-Host "  bundled $name.dll"
    } else {
        Write-Host "  skip:  $name.dll (built as STATIC archive — already in whisper.dll)" -ForegroundColor DarkGray
    }
}

# ggml runtime (new-style CrispASR builds ship it as separate DLLs).
foreach ($g in @("ggml", "ggml-cpu", "ggml-base", "ggml-blas")) {
    $dll = Find-Dll $cBase $g
    if ($dll) {
        Copy-Item $dll "$runnerDir\$g.dll" -Force
        Write-Host "  bundled $g.dll"
    }
}

Write-Host "`nFinal runner dir contents:"
Get-ChildItem $runnerDir -Filter *.dll | ForEach-Object { Write-Host "  $($_.Name)  $($_.Length) bytes" }
