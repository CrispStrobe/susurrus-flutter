// Live integration test for TranscriptSummarizeService.
//
// Same opt-in pattern as the cleanup live test: tag-gated +
// RUN_LIVE_TESTS=1 + key in process env or in a dotenv pointed
// at by CRISPER_WEAVER_DOTENV. Default `flutter test` stays
// offline.

@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:crisper_weaver/services/cloud_llm_cleanup_service.dart';
import 'package:crisper_weaver/services/transcript_summarize_service.dart';

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

bool get _liveOptIn => Platform.environment['RUN_LIVE_TESTS'] == '1';

void main() {
  final groqKey = _resolveKey('GROQ_API_KEY');

  group('live summarize against Groq', () {
    test('action-items section round-trip', () async {
      if (!_liveOptIn) {
        markTestSkipped('RUN_LIVE_TESTS=1 not set');
        return;
      }
      if (groqKey.isEmpty) {
        markTestSkipped('GROQ_API_KEY not in env or dotenv');
        return;
      }
      final svc = TranscriptSummarizeService();
      addTearDown(svc.dispose);
      final cfg = CloudLlmConfig(
        apiUrl: 'https://api.groq.com/openai/v1/chat/completions',
        apiKey: groqKey,
        // 70B for higher-fidelity structured output; the 8B
        // instant model occasionally drops the H2 headers.
        model: 'llama-3.3-70b-versatile',
        timeout: const Duration(seconds: 30),
      );
      const transcript = '''
Alice: We agreed the v0.5 release candidate ships next Friday.
Bob:   I'll send the QA report by Wednesday.
Alice: Great. We also discussed the Q3 hiring plan briefly.
Bob:   Decision: we'll open the senior engineer rec next quarter.
''';
      final r = await svc.summarize(
        transcript: transcript,
        kinds: {SummaryKind.actionItems, SummaryKind.decisions},
        config: cfg,
      );
      // At least one bullet in each requested section; key
      // entities preserved verbatim. We don't pin exact text —
      // the model is non-deterministic even at temperature=0.
      expect(r.actionItems.length, greaterThanOrEqualTo(1),
          reason: 'should produce at least one action item');
      expect(r.decisions.length, greaterThanOrEqualTo(1),
          reason: 'should produce at least one decision');
      expect(r.keyTopics, isEmpty,
          reason: 'unrequested section should stay empty');
      final all = (r.actionItems + r.decisions).join(' ').toLowerCase();
      expect(all, anyOf(contains('bob'), contains('alice')),
          reason: 'should preserve named entities');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
