// Live integration tests for CloudLlmCleanupService.
//
// Tag-gated: `flutter test --tags=live` to run; the default
// `flutter test` skips this file so CI / regular dev loops
// don't hit a live network or charge against a real API key.
//
// Key resolution (first match wins; the key never enters the
// repo):
//   1. `GROQ_API_KEY` in the process environment, OR
//   2. `GROQ_API_KEY` in a dotenv-style file pointed at by the
//      `CRISPER_WEAVER_DOTENV` env var.
//
// Run example:
//   flutter test --tags=live \
//     --dart-define=… \                  # not needed; env reads
//     GROQ_API_KEY=sk-… flutter test --tags=live
//   or:
//     CRISPER_WEAVER_DOTENV=$HOME/code/.env flutter test --tags=live
//
// Tests assert the LLM produced *some* output and that it's at
// least plausibly a cleaned-up version of the input (length
// within a reasonable band, contains some original content);
// they deliberately do NOT pin exact output strings because the
// model's response is non-deterministic and even temperature=0
// can drift across model versions / providers.

@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:crisper_weaver/services/cloud_llm_cleanup_service.dart';

/// Resolve a key from the process env first, then from a
/// dotenv-style file at the path in `CRISPER_WEAVER_DOTENV`.
/// Returns empty when neither source has it.
String _resolveKey(String name) {
  final fromProc = Platform.environment[name];
  if (fromProc != null && fromProc.isNotEmpty) return fromProc;
  final dotenvPath = Platform.environment['CRISPER_WEAVER_DOTENV'];
  if (dotenvPath == null || dotenvPath.isEmpty) return '';
  final f = File(dotenvPath);
  if (!f.existsSync()) return '';
  for (final raw in f.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    if (line.substring(0, eq).trim() != name) continue;
    var v = line.substring(eq + 1).trim();
    if (v.length >= 2 &&
        ((v.startsWith('"') && v.endsWith('"')) ||
            (v.startsWith("'") && v.endsWith("'")))) {
      v = v.substring(1, v.length - 1);
    }
    return v;
  }
  return '';
}

/// Default `flutter test` stays offline. Live tests only run
/// when the user explicitly opts in by setting `RUN_LIVE_TESTS=1`
/// — same per-test opt-in pattern as the `slow` tag. The tag
/// is for filtering (e.g. `flutter test --tags=live`); the env
/// var is for safety against accidentally hitting the network
/// when a key happens to be in the shell env.
bool get _liveOptIn => Platform.environment['RUN_LIVE_TESTS'] == '1';

void main() {
  final groqKey = _resolveKey('GROQ_API_KEY');

  group('live LLM cleanup against Groq', () {
    test('cleanupSegment produces a non-empty cleaned response', () async {
      if (!_liveOptIn) {
        markTestSkipped('RUN_LIVE_TESTS=1 not set');
        return;
      }
      if (groqKey.isEmpty) {
        markTestSkipped('GROQ_API_KEY not in env or dotenv');
        return;
      }
      final svc = CloudLlmCleanupService();
      addTearDown(svc.dispose);
      // llama-3.1-8b-instant is fast (~100ms) and cheap; if it
      // gets deprecated, swap to whatever Groq currently fronts.
      final cfg = CloudLlmConfig(
        apiUrl: 'https://api.groq.com/openai/v1/chat/completions',
        apiKey: groqKey,
        model: 'llama-3.1-8b-instant',
        timeout: const Duration(seconds: 20),
      );
      final out = await svc.cleanupSegment(
        text: 'um so like the the cat sat on the mat uh you know',
        config: cfg,
      );
      // We don't pin the exact string because the model is
      // non-deterministic. We assert the response is non-
      // empty, shorter than the input (fillers removed), and
      // mentions cat + mat (preserves meaning).
      expect(out, isNotEmpty);
      expect(out.length, lessThan(60),
          reason: 'cleaned should be shorter than original');
      final lower = out.toLowerCase();
      expect(lower.contains('cat'), true,
          reason: 'should preserve "cat"');
      expect(lower.contains('mat'), true,
          reason: 'should preserve "mat"');
      // Should have removed at least one of the filler words.
      expect(lower.contains('um') && lower.contains('uh'), false,
          reason: 'at least one filler should be gone');
    }, timeout: const Timeout(Duration(seconds: 45)));

    test('cleanupBatch processes multiple segments end-to-end',
        () async {
      if (!_liveOptIn) {
        markTestSkipped('RUN_LIVE_TESTS=1 not set');
        return;
      }
      if (groqKey.isEmpty) {
        markTestSkipped('GROQ_API_KEY not in env or dotenv');
        return;
      }
      final svc = CloudLlmCleanupService();
      addTearDown(svc.dispose);
      final cfg = CloudLlmConfig(
        apiUrl: 'https://api.groq.com/openai/v1/chat/completions',
        apiKey: groqKey,
        model: 'llama-3.1-8b-instant',
        timeout: const Duration(seconds: 20),
      );
      final progress = <int>[];
      final out = await svc.cleanupBatch(
        texts: [
          'um the the cat sat on the mat',
          'uh and then it slept for hours and hours',
          'and then it woke up',
        ],
        config: cfg,
        cancel: CleanupCancelToken(),
        onProgress: (done, total) {
          expect(total, 3);
          progress.add(done);
        },
      );
      expect(out, hasLength(3));
      for (final s in out) {
        expect(s, isNotEmpty);
      }
      expect(progress, [1, 2, 3]);
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('401 response on bad key surfaces CloudLlmHttpException',
        () async {
      if (!_liveOptIn) {
        markTestSkipped('RUN_LIVE_TESTS=1 not set');
        return;
      }
      if (groqKey.isEmpty) {
        markTestSkipped('GROQ_API_KEY not in env or dotenv');
        return;
      }
      final svc = CloudLlmCleanupService();
      addTearDown(svc.dispose);
      final cfg = CloudLlmConfig(
        apiUrl: 'https://api.groq.com/openai/v1/chat/completions',
        apiKey: 'sk-deliberately-wrong',
        model: 'llama-3.1-8b-instant',
        timeout: const Duration(seconds: 20),
      );
      await expectLater(
        svc.cleanupSegment(text: 'hello', config: cfg),
        throwsA(isA<CloudLlmHttpException>().having(
            (e) => e.statusCode >= 400 && e.statusCode < 500,
            'is4xx',
            true)),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
