# scripts/bundle_windows_dlls.ps1
#
# Copy every CrispASR DLL next to the Flutter Windows runner's exe so
# `DynamicLibrary.open()` in the Dart FFI binding finds them on app
# start-up.
#
# Env:
#   CRISPASR_DIR  — path to the CrispASR checkout (default ../CrispASR)
#   RUNNER_DIR    — path to build/windows/x64/runner/Release
#                   (default build\windows\x64\runner\Release)
#
# Usage: pwsh ./scripts/bundle_windows_dlls.ps1

$ErrorActionPreference = "Stop"

$crispasrDir = if ($env:CRISPASR_DIR) { $env:CRISPASR_DIR } else { "..\CrispASR" }
$runnerDir   = if ($env:RUNNER_DIR)   { $env:RUNNER_DIR }   else { "build\windows\x64\runner\Release" }

if (-not (Test-Path $runnerDir)) {
    throw "Runner dir not found: $runnerDir. Run flutter build windows --release first."
}

# Core library — whisper.dll (and maybe ggml.dll alongside it for
# newer CrispASR builds that split them out).
$candidates = @(
    "$crispasrDir\build\bin\Release\whisper.dll",
    "$crispasrDir\build\src\Release\whisper.dll",
    "$crispasrDir\build\Release\whisper.dll"
)
$whisperDll = $null
foreach ($c in $candidates) {
    if (Test-Path $c) { $whisperDll = $c; break }
}
if (-not $whisperDll) {
    throw "whisper.dll not found. Looked in: $($candidates -join ', '). Run `cmake --build build --config Release --target whisper` in CrispASR first."
}

Write-Host "Bundling from: $whisperDll"
Copy-Item $whisperDll "$runnerDir\whisper.dll" -Force
# crispasr.dll alias — Dart FFI loader probes this first.
Copy-Item $whisperDll "$runnerDir\crispasr.dll" -Force

# Sibling backend DLLs — DT_NEEDED via the import table; if whisper.dll
# was linked with parakeet / canary / etc. as PUBLIC dependencies, those
# DLLs must sit alongside it or LoadLibrary will fail.
$siblings = @(
    "parakeet", "canary", "qwen3_asr", "cohere", "granite_speech",
    "canary_ctc", "voxtral", "voxtral4b"
)
foreach ($name in $siblings) {
    $dll = "$crispasrDir\build\bin\Release\$name.dll"
    if (-not (Test-Path $dll)) { $dll = "$crispasrDir\build\src\Release\$name.dll" }
    if (-not (Test-Path $dll)) { $dll = "$crispasrDir\build\Release\$name.dll" }
    if (Test-Path $dll) {
        Copy-Item $dll "$runnerDir\$name.dll" -Force
        Write-Host "  bundled $name.dll"
    } else {
        Write-Host "  warn: $name.dll missing (backend not runtime-ready)" -ForegroundColor Yellow
    }
}

# ggml runtime (new-style CrispASR builds ship it as a separate DLL).
foreach ($g in @("ggml", "ggml-cpu", "ggml-base", "ggml-blas")) {
    $dll = "$crispasrDir\build\bin\Release\$g.dll"
    if (Test-Path $dll) {
        Copy-Item $dll "$runnerDir\$g.dll" -Force
        Write-Host "  bundled $g.dll"
    }
}

Write-Host "`nFinal runner dir contents:"
Get-ChildItem $runnerDir -Filter *.dll | ForEach-Object { Write-Host "  $($_.Name)  $($_.Length) bytes" }
