# CrispASR Dart package — missing capabilities

This document enumerates what `package:crispasr` (at
`../CrispASR/flutter/crispasr/`) would need to expose through Dart FFI so
CrisperWeaver can surface the matching feature in the UI. Until these land
upstream, the status matrix in the README will have ⚠️ / ❌ entries
regardless of how much work we do in CrisperWeaver.

## What the Dart package exposes today

Only Whisper-compatible C symbols from `libwhisper`:

| C symbol                                      | Dart binding              |
| --------------------------------------------- | ------------------------- |
| `whisper_init_from_file_with_params`          | constructor               |
| `whisper_full_default_params_by_ref`          | strategy                  |
| `whisper_context_default_params_by_ref`       | ctor-time init            |
| `whisper_full`                                | `transcribePcm(...)`      |
| `whisper_full_n_segments`                     | segment count             |
| `whisper_full_get_segment_text`               | `Segment.text`            |
| `whisper_full_get_segment_{t0,t1}`            | `Segment.start/end`       |
| `whisper_full_get_segment_no_speech_prob`     | `Segment.noSpeechProb`    |
| `whisper_free_params`, `whisper_free`         | dispose                   |

Everything else CrispASR ships is invisible to Dart.

## What's missing and what it would unblock

### 1. Streaming transcription

CrispASR CLI runs `--stream` / `--mic` / `--live` by passing rolling 10 s
windows to `whisper_full` with `stride` + `context-carry`. Dart can do this
today if we're willing to just re-call `transcribePcm` on 10 s buffers, but
every call re-loads encoder state. For a proper stream mode we'd want:

```c
whisper_state * whisper_init_state(struct whisper_context *);
int whisper_stream_feed(whisper_state *, const float *, int n_samples);
const char * whisper_stream_partial_text(whisper_state *);
const char * whisper_stream_committed_text(whisper_state *);
void whisper_stream_free(whisper_state *);
```

Then the Dart package exposes a `CrispASR.stream()` returning a
`Stream<PartialTranscript>`.

**Unblocks:** live mic transcription, real-time captioning, the
"streaming transcription" matrix row.

### 2. Backend dispatch (non-Whisper GGUF)

CrispASR's C++ factory auto-selects a backend from GGUF metadata and there
are separate shared libraries per backend (`libparakeet.dylib`,
`libcanary.dylib`, `libqwen3_asr.dylib`, …). The Dart package hardcodes
`libwhisper.{so,dylib,framework}`. To reach the other backends we need:

```c
struct crispasr_context;
crispasr_context * crispasr_open(const char * gguf_path);
// Automatic dispatch — or explicit:
crispasr_context * crispasr_open_with_backend(const char * path, int backend_id);
int crispasr_transcribe(crispasr_context *, const float *, int n, ...);
```

plus the existing Whisper FFI routed through `crispasr_context` so one
Dart class serves all backends.

**Unblocks:** Parakeet (fast), Canary (translation), Qwen3-ASR
(multilingual, inc. Chinese dialects), Voxtral (speech translation),
FastConformer-CTC, Wav2Vec2 — and the ability to point users at the
`cstr/crispasr-gguf` repo directly instead of just quantized Whispers.

### 3. Speaker diarization

CrispASR does post-processing diarization via four backends: `energy`,
`xcorr`, `pyannote-gguf`, `sherpa-onnx`. In the Dart layer we still fall
back to our own MFCC + k-means which is meaningfully worse. We'd want:

```c
crispasr_diarization_result * crispasr_diarize(
    const float * pcm, int n_samples,
    int backend,              // 0=energy 1=xcorr 2=pyannote 3=sherpa
    const char * model_path,  // pyannote-gguf / sherpa-onnx path
    int min_speakers, int max_speakers
);
int crispasr_diarization_n_segments(crispasr_diarization_result *);
void crispasr_diarization_get(crispasr_diarization_result *, int idx,
                              float *start, float *end, int *speaker);
void crispasr_diarization_free(crispasr_diarization_result *);
```

**Unblocks:** real speaker diarization end-to-end, closes the
`⚠️ Pure-Dart MFCC fallback only` matrix row.

### 4. VAD-driven chunking

For audio longer than ~5 minutes the current Dart pipeline loads the whole
PCM into memory and hands it to `whisper_full` in one shot. CrispASR has
Silero VAD built in and auto-downloads the ~885 KB model. Exposing it:

```c
typedef struct { float start; float end; } crispasr_vad_span;
int crispasr_vad_detect(const float * pcm, int n, crispasr_vad_span * out, int out_capacity);
```

**Unblocks:** memory-efficient long-audio transcription without the whole
WAV living in RAM; progressive UI updates as each voiced chunk completes.

### 5. Explicit language detection

Currently the Dart package runs Whisper with `language = "auto"` and reports
nothing about the detection. The CrispASR CLI supports a standalone LID pre-
step (`whisper-tiny` or Silero 95-lang GGUF). Expose:

```c
const char * crispasr_detect_language(const float * pcm, int n_samples);
float crispasr_language_confidence(const char * code);
```

**Unblocks:** showing the user "Detected: de (92%)" before transcription
kicks off — useful when choosing a non-multilingual model.

### 6. Word-level timestamps

`whisper_full_params` already supports word-timestamps via `token_timestamps
= true` but the Dart wrapper doesn't expose that param or the per-word
getters (`whisper_full_get_token_*`, `whisper_full_get_segment_tokens`).

**Unblocks:** SRT karaoke-style output, segment-level click-to-play at word
granularity, and the `enableWordTimestamps` flag in our engine interface
doing anything.

## Suggested upstream rollout

1. Add `ffi/crispasr_ext.h` to CrispASR with the combined C header for #1–#6.
2. Bump `package:crispasr` to `0.2.0`, wrapping the new symbols behind
   `CrispASR.streaming()`, `CrispASR.diarize()`, `CrispASR.detectLanguage()`,
   `CrispASR.vad()` constructors/methods. Keep existing `transcribePcm`
   behaviour byte-identical for backward compat.
3. CrisperWeaver-side: add `CrispASRStreamingEngine`, upgrade
   `DiarizationService` to call `CrispASR.diarize()` when available, feed
   VAD spans into the transcribe loop for memory capping.

No CrisperWeaver-side shortcut I know of; the "upgrade CrispASR Dart first"
gate is real.
