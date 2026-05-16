// Live integration tests against a real libcrispasr + a small
// Whisper model on disk. These are intentionally tag-gated under
// `slow` so the default `flutter test` run (and CI) skips them —
// they need ~80 MB of model file plus the dylib built locally.
//
// What's pinned:
//   * decodeAudioFile() can decode the bundled `test/jfk-2s.wav`
//     into 16 kHz mono float32 PCM. End-to-end glue from the
//     binding's miniaudio wrapper to our test fixture.
//   * CrispasrSession.openWithParams(...).transcribe(pcm)
//     returns at least one segment whose text contains a known
//     JFK phrase. Validates the open-with-params dispatch arm
//     (used by transcription_worker.dart) without spinning up
//     a worker isolate.
//
// Running locally on macOS:
//   flutter test --tags slow test/crispasr_live_test.dart
//
//   # explicit overrides:
//   CRISPASR_LIB=/abs/path/libwhisper.dylib \
//   CRISPASR_TINY_MODEL=/abs/path/ggml-tiny.en.bin \
//     flutter test --tags slow test/crispasr_live_test.dart
//
// The test silently skips (not fails) when the lib OR the
// model file is absent, so non-CrispASR-equipped contributors
// can run `flutter test --tags slow` without a hard failure.

@Tags(['slow'])
library;

import 'dart:io';

import 'package:crispasr/crispasr.dart' as crispasr;
import 'package:flutter_test/flutter_test.dart';

/// Lookup a Whisper tiny.en model:
///   1. CRISPASR_TINY_MODEL env var, OR
///   2. the sibling CrispASR repo's `models/ggml-tiny.en.bin`.
String? _resolveTinyModel() {
  final env = Platform.environment['CRISPASR_TINY_MODEL'];
  if (env != null && env.isNotEmpty && File(env).existsSync()) {
    return File(env).absolute.path;
  }
  const candidates = [
    '../CrispASR/models/ggml-tiny.en.bin',
    '../CrispASR/build-flutter-bundle/models/ggml-tiny.en.bin',
  ];
  for (final c in candidates) {
    final f = File(c);
    if (f.existsSync()) return f.absolute.path;
  }
  return null;
}

/// Lookup the libcrispasr / libwhisper dylib:
///   1. CRISPASR_LIB env var, OR
///   2. the conventional build outputs under the sibling repo.
String? _resolveLibPath() {
  final env = Platform.environment['CRISPASR_LIB'];
  if (env != null && env.isNotEmpty && File(env).existsSync()) {
    return env;
  }
  const candidates = [
    '../CrispASR/build-flutter-bundle/src/libwhisper.dylib',
    '../CrispASR/build/src/libwhisper.dylib',
    '../CrispASR/build-flutter-bundle/src/libcrispasr.dylib',
    '../CrispASR/build/src/libcrispasr.dylib',
  ];
  for (final c in candidates) {
    if (File(c).existsSync()) return File(c).absolute.path;
  }
  return null;
}

void main() {
  final libPath = _resolveLibPath();
  final modelPath = _resolveTinyModel();
  final libSkip = libPath == null
      ? 'libwhisper / libcrispasr dylib not found — build CrispASR or set CRISPASR_LIB.'
      : null;
  final modelSkip = modelPath == null
      ? 'ggml-tiny.en.bin not found — drop it at ../CrispASR/models/ or set CRISPASR_TINY_MODEL.'
      : null;
  // Compose: if either is missing we skip both tests with one message.
  final skip = libSkip ?? modelSkip;

  group('CrispASR live (Whisper tiny.en)', () {
    test('decodeAudioFile decodes the JFK fixture into 16 kHz PCM',
        () async {
      // jfk-2s.wav is a 2-second mono 16 kHz clip. miniaudio's
      // resampler still runs even when source rate matches the
      // target — so the test exercises the same code path that
      // arbitrary user input would.
      final wav = File('test/jfk-2s.wav');
      expect(wav.existsSync(), isTrue,
          reason: 'fixture missing from the repo — re-add test/jfk-2s.wav');

      final decoded =
          crispasr.decodeAudioFile(wav.absolute.path, libPath: libPath);
      expect(decoded.sampleRate, 16000,
          reason: 'decoder must always emit 16 kHz mono');
      // 2 seconds at 16 kHz ≈ 32k samples, with miniaudio's
      // header/trailer rounding give-or-take a couple of frames.
      expect(decoded.samples.length, greaterThan(28000));
      expect(decoded.samples.length, lessThan(36000));
    }, skip: skip);

    test('CrispasrSession transcribes the JFK fixture', () async {
      // Open the tiny.en model — this is the smallest Whisper
      // model that still reliably produces real English text on
      // a 2-second clip. Anything smaller starts hallucinating.
      crispasr.CrispasrSession? session;
      try {
        session = crispasr.CrispasrSession.openWithParams(
          modelPath!,
          nThreads: 4,
          useGpu: true,
          flashAttn: true,
          libPath: libPath,
        );
      } on UnsupportedError {
        // libcrispasr predates 0.6.1's openWithParams — fall
        // back to the legacy factory. Same as transcription_worker
        // does at runtime.
        session = crispasr.CrispasrSession.open(modelPath!,
            nThreads: 4, libPath: libPath);
      }
      try {
        final decoded =
            crispasr.decodeAudioFile('test/jfk-2s.wav', libPath: libPath);
        final segs = session.transcribe(decoded.samples, language: 'en');
        expect(segs, isNotEmpty,
            reason: 'tiny.en should produce ≥1 segment on this fixture');
        final fullText = segs.map((s) => s.text).join(' ').toLowerCase();
        // The 2-second clip captures the opening of the famous
        // JFK line — "And so my fellow Americans…". tiny.en
        // reliably hits one of these phrases; the full version
        // ("ask not what your country") shows up on longer clips
        // (jfk.wav) but the 2-second crop ends earlier.
        final containsCue = fullText.contains('fellow americ') ||
            fullText.contains('and so my') ||
            fullText.contains('ask not') ||
            fullText.contains('country');
        expect(containsCue, isTrue,
            reason: 'transcription should contain a recognisable JFK '
                'phrase, got: "$fullText"');
      } finally {
        session.close();
      }
    }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));
  });
}
