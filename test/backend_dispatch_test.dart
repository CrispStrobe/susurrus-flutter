// Integration test for the CrispASR C-API dispatch arms.
//
// What this catches:
//   * regressions in `crispasr_session_available_backends` — every
//     backend we ship a UI catalog entry for must show up in the CSV
//     the C side returns, otherwise the model picker offers downloads
//     for unrunnable models;
//   * regressions in `crispasr_session_open_explicit` for every backend
//     we recently wired (kokoro / orpheus / mimo-asr) — opens with a
//     bogus path and asserts the dispatch arm rejects it cleanly
//     instead of crashing;
//   * end-to-end `synthesize` / `transcribe` for every backend whose
//     model file is on disk (opt-in via env vars). Skipped silently
//     when the model isn't downloaded so CI stays green without
//     gigabyte fixtures.
//
// Running:
//   # finds libwhisper.dylib under the sibling CrispASR repo
//   flutter test test/backend_dispatch_test.dart
//
//   # explicit lib path (CI):
//   CRISPASR_LIB=/abs/path/libwhisper.dylib flutter test test/backend_dispatch_test.dart
//
//   # opt-in real-model checks:
//   CRISPASR_TEST_KOKORO_MODEL=/path/kokoro-82m-q8_0.gguf \
//   CRISPASR_TEST_KOKORO_VOICE=/path/kokoro-voice-af_heart.gguf \
//   flutter test test/backend_dispatch_test.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:crispasr/crispasr.dart' as crispasr;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Resolve `libwhisper.dylib` (or .so / .dll) from the env or by
/// probing the conventional sibling-checkout layout.
String? _resolveLibPath() {
  final envOverride = Platform.environment['CRISPASR_LIB'];
  if (envOverride != null && envOverride.isNotEmpty) {
    return File(envOverride).existsSync() ? envOverride : null;
  }
  // Project-root-relative fallback. `flutter test` runs from the
  // package root, so `../CrispASR/...` aligns with the local dev
  // checkout convention documented in README.md.
  for (final cand in [
    '../CrispASR/build-flutter-bundle/src/libwhisper.dylib',
    '../CrispASR/build/src/libwhisper.dylib',
    '../CrispASR/build-flutter-bundle/src/libcrispasr.dylib',
    '../CrispASR/build/src/libcrispasr.dylib',
  ]) {
    if (File(cand).existsSync()) return File(cand).absolute.path;
  }
  return null;
}

void main() {
  final libPath = _resolveLibPath();

  // Guard against running these tests on a machine where libwhisper
  // wasn't built yet — they need the real shared library, not a stub.
  // We don't fail the suite; we report skipped so the run stays green
  // and the message tells the next person what to build.
  final libAvailable = libPath != null;
  final libSkipReason = libAvailable
      ? null
      : 'libwhisper.dylib not found — run scripts/build_macos.sh or '
          'set CRISPASR_LIB=<path>.';

  group('CrispASR backend dispatch', () {
    test('availableBackends() exposes every wired backend', () {
      final backends = crispasr.CrispasrSession.availableBackends(
          libPath: libPath);
      // Whisper is always built in.
      expect(backends, contains('whisper'),
          reason: 'libwhisper should always include the whisper backend');
      // The 11 ASR backends we already shipped before this session.
      // If the bundled libwhisper drops one, the CrisperWeaver UI
      // surfaces "Rebuild CrispASR with the X backend linked in" for
      // every model download — catch that here, fast.
      const requiredAsr = [
        'parakeet',
        'canary',
        'canary-ctc',
        'qwen3',
        'cohere',
        'granite',
        'fastconformer-ctc',
        'voxtral',
        'voxtral4b',
        'wav2vec2',
        'omniasr',
      ];
      for (final name in requiredAsr) {
        expect(backends, contains(name),
            reason: 'libwhisper must include the $name backend');
      }
      // The three backends wired in this session — kokoro / orpheus /
      // mimo-asr were built into libwhisper but unreachable until we
      // added their dispatch arms in crispasr_c_api.cpp.
      const newlyWired = ['kokoro', 'orpheus', 'mimo-asr'];
      for (final name in newlyWired) {
        expect(backends, contains(name),
            reason: '$name dispatch arm regressed in '
                'crispasr_session_available_backends');
      }
      // The two TTS backends that were already exposed.
      const tts = ['vibevoice-tts', 'qwen3-tts'];
      for (final name in tts) {
        expect(backends, contains(name),
            reason: 'TTS backend $name should be exposed via the session API');
      }
    }, skip: libSkipReason);

    test('open() with a non-existent file fails cleanly per backend', () {
      // For every dispatch arm, a non-existent model path should make
      // the open() call throw — never crash, never hang. This catches
      // null-deref regressions in the per-backend init path before they
      // reach a real user.
      const dispatched = [
        'kokoro',
        'orpheus',
        'mimo-asr',
        'vibevoice-tts',
        'qwen3-tts',
      ];
      const bogus = '/tmp/this-file-definitely-does-not-exist.gguf';
      for (final backend in dispatched) {
        expect(
          () => crispasr.CrispasrSession.open(bogus,
              backend: backend, libPath: libPath),
          throwsA(isA<Exception>()),
          reason: '$backend dispatch arm should reject missing files cleanly',
        );
      }
    }, skip: libSkipReason);
  });

  // ---------------------------------------------------------------------
  // Opt-in end-to-end checks. These need a real model GGUF on disk and
  // are gated behind env vars so a vanilla `flutter test` stays cheap.
  // Each block skips silently when its env var isn't set.
  // ---------------------------------------------------------------------

  group('CrispASR end-to-end synth (opt-in)', () {
    final kokoroModel =
        Platform.environment['CRISPASR_TEST_KOKORO_MODEL'];
    final kokoroVoice =
        Platform.environment['CRISPASR_TEST_KOKORO_VOICE'];
    final orpheusModel =
        Platform.environment['CRISPASR_TEST_ORPHEUS_MODEL'];
    final orpheusCodec =
        Platform.environment['CRISPASR_TEST_ORPHEUS_CODEC'];
    final qwen3TtsModel =
        Platform.environment['CRISPASR_TEST_QWEN3_TTS_MODEL'];
    final qwen3TtsCodec =
        Platform.environment['CRISPASR_TEST_QWEN3_TTS_CODEC'];
    final vibevoiceModel =
        Platform.environment['CRISPASR_TEST_VIBEVOICE_MODEL'];
    final vibevoiceVoice =
        Platform.environment['CRISPASR_TEST_VIBEVOICE_VOICE'];

    test('kokoro synthesises non-zero PCM', () {
      final s = crispasr.CrispasrSession.open(kokoroModel!,
          backend: 'kokoro', libPath: libPath);
      addTearDown(s.close);
      s.setVoice(kokoroVoice!);
      final pcm = s.synthesize('Hello world.');
      expect(pcm, isA<Float32List>());
      expect(pcm.length, greaterThan(0));
    },
        skip: !libAvailable
            ? libSkipReason
            : (kokoroModel == null || kokoroVoice == null)
                ? 'set CRISPASR_TEST_KOKORO_MODEL + CRISPASR_TEST_KOKORO_VOICE '
                    'to a downloaded kokoro-82m-*.gguf + voicepack'
                : null);

    test('orpheus synthesises non-zero PCM', () {
      final s = crispasr.CrispasrSession.open(orpheusModel!,
          backend: 'orpheus', libPath: libPath);
      addTearDown(s.close);
      s.setCodecPath(orpheusCodec!);
      // Orpheus base/finetune GGUFs bake 8 fixed speakers (canopylabs
      // English: tara/leo/leah/...; Kartoffel German: Anton/Sophie/...).
      // Pick the first one to avoid an empty-voice synth — the same
      // pattern qwen3-tts customvoice uses.
      final speakers = s.speakers();
      if (speakers.isNotEmpty) {
        s.setSpeakerName(speakers.first);
      }
      final pcm = s.synthesize('Hello world.');
      expect(pcm.length, greaterThan(0));
    },
        skip: !libAvailable
            ? libSkipReason
            : (orpheusModel == null || orpheusCodec == null)
                ? 'set CRISPASR_TEST_ORPHEUS_MODEL + CRISPASR_TEST_ORPHEUS_CODEC '
                    'to a downloaded orpheus-3b-*.gguf + snac-24khz.gguf'
                : null);

    test('qwen3-tts synthesises non-zero PCM', () {
      final s = crispasr.CrispasrSession.open(qwen3TtsModel!,
          backend: 'qwen3-tts', libPath: libPath);
      addTearDown(s.close);
      s.setCodecPath(qwen3TtsCodec!);
      // qwen3-tts-base needs an ICL voice prompt (wav + ref text) before
      // synthesize; qwen3-tts-customvoice has 9 baked speakers reachable
      // via setSpeakerName. The customvoice variant is the simpler test
      // path — pick any baked speaker the GGUF reports.
      final speakers = s.speakers();
      if (speakers.isNotEmpty) {
        s.setSpeakerName(speakers.first);
      }
      final pcm = s.synthesize('Hello world.');
      expect(pcm.length, greaterThan(0));
    },
        skip: !libAvailable
            ? libSkipReason
            : (qwen3TtsModel == null || qwen3TtsCodec == null)
                ? 'set CRISPASR_TEST_QWEN3_TTS_MODEL + CRISPASR_TEST_QWEN3_TTS_CODEC '
                    'to a downloaded qwen3-tts-customvoice-*.gguf + tokenizer.gguf '
                    '(or supply a base model + WAV reference via the new ICL path)'
                : null);

    test('vibevoice-tts synthesises non-zero PCM', () {
      final s = crispasr.CrispasrSession.open(vibevoiceModel!,
          backend: 'vibevoice-tts', libPath: libPath);
      addTearDown(s.close);
      s.setVoice(vibevoiceVoice!);
      final pcm = s.synthesize('Hello world.');
      expect(pcm.length, greaterThan(0));
    },
        skip: !libAvailable
            ? libSkipReason
            : (vibevoiceModel == null || vibevoiceVoice == null)
                ? 'set CRISPASR_TEST_VIBEVOICE_MODEL + CRISPASR_TEST_VIBEVOICE_VOICE '
                    'to a downloaded vibevoice-realtime-*.gguf + voicepack'
                : null);
  });

  // `test/jfk.wav` ships with the repo (~12s); good enough for any
  // English-capable backend. We probe several paths because `flutter
  // test` doesn't guarantee Directory.current is the project root —
  // newer SDKs run each file from its own directory.
  //
  // NOTE: this MUST run synchronously before any `test(...)` call,
  // because `skip:` is evaluated at test-registration time. Doing the
  // probe inside `setUpAll` would always leave jfkPcm null when the
  // skip condition fires, silently skipping every ASR test even when
  // the env vars are set correctly.
  String? findJfkWav() {
    final candidates = <String>[
      Platform.environment['CRISPASR_TEST_JFK_WAV'] ?? '',
      p.join(Directory.current.path, 'test', 'jfk.wav'),
      p.join(Directory.current.path, 'jfk.wav'),
      for (var dir = Directory.current;
          dir.parent.path != dir.path;
          dir = dir.parent)
        p.join(dir.path, 'test', 'jfk.wav'),
    ];
    for (final c in candidates) {
      if (c.isEmpty) continue;
      if (File(c).existsSync()) return c;
    }
    return null;
  }

  Float32List? jfkPcm;
  if (libAvailable) {
    final wavPath = findJfkWav();
    if (wavPath != null) {
      try {
        jfkPcm = crispasr.decodeAudioFile(wavPath, libPath: libPath).samples;
      } catch (_) {
        // Decoder unavailable in the loaded dylib — leave jfkPcm null
        // and the ASR tests will skip with a clear reason.
      }
    }
  }

  group('CrispASR end-to-end ASR (opt-in)', () {
    final mimoAsrModel = Platform.environment['CRISPASR_TEST_MIMO_ASR_MODEL'];
    final whisperModel = Platform.environment['CRISPASR_TEST_WHISPER_MODEL'];

    final mimoAsrTokenizer =
        Platform.environment['CRISPASR_TEST_MIMO_ASR_TOKENIZER'];

    test('mimo-asr transcribes jfk.wav', () {
      final s = crispasr.CrispasrSession.open(mimoAsrModel!,
          backend: 'mimo-asr', libPath: libPath);
      addTearDown(s.close);
      // mimo-asr is a 2-file backend: the main model plus a separate
      // mimo_tokenizer companion. crispasr_c_api.cpp routes the
      // tokenizer through set_codec_path (the same setter qwen3-tts
      // and orpheus use for their codec/tokenizer companions).
      s.setCodecPath(mimoAsrTokenizer!);
      final segments = s.transcribe(jfkPcm!);
      expect(segments, isNotEmpty);
      final fullText = segments.map((seg) => seg.text).join(' ').trim();
      expect(fullText, isNotEmpty,
          reason: 'mimo-asr should produce non-empty transcript on jfk.wav');
    },
        skip: !libAvailable
            ? libSkipReason
            : mimoAsrModel == null
                ? 'set CRISPASR_TEST_MIMO_ASR_MODEL to a downloaded mimo-asr-*.gguf'
                : mimoAsrTokenizer == null
                    ? 'set CRISPASR_TEST_MIMO_ASR_TOKENIZER to a downloaded '
                        'mimo-tokenizer-*.gguf companion'
                    : jfkPcm == null
                        ? 'jfk.wav not found — set CRISPASR_TEST_JFK_WAV or run from project root'
                        : null);

    // Sanity check that the audio decoder + a known-working backend
    // produce a non-trivial transcript. Catches FFI / decode regressions
    // independent of the new backends.
    test('whisper transcribes jfk.wav', () {
      final s = crispasr.CrispasrSession.open(whisperModel!,
          backend: 'whisper', libPath: libPath);
      addTearDown(s.close);
      final segments = s.transcribe(jfkPcm!);
      expect(segments, isNotEmpty);
      final fullText = segments.map((seg) => seg.text).join(' ').toLowerCase();
      // The JFK clip is the famous "ask not what your country can do
      // for you" line — every Whisper size gets the gist.
      expect(fullText, contains('ask'),
          reason: 'jfk.wav transcript should mention "ask"');
    },
        skip: !libAvailable
            ? libSkipReason
            : whisperModel == null
                ? 'set CRISPASR_TEST_WHISPER_MODEL to a downloaded ggml-*.bin'
                : jfkPcm == null
                    ? 'jfk.wav not found — set CRISPASR_TEST_JFK_WAV or run from project root'
                    : null);
  });
}
