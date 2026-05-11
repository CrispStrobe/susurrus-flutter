// Hermetic tests for CloudLlmCleanupService.
//
// Uses http's MockClient so no real network calls; pins the
// request body shape (URL, headers, JSON envelope), the
// response parsing for the OpenAI chat-completions schema,
// and the per-segment error swallowing of batch cleanup.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:crisper_weaver/services/cloud_llm_cleanup_service.dart';

void main() {
  CloudLlmConfig config(
      {String apiUrl = 'https://api.example.com/v1/chat/completions',
      String apiKey = 'sk-test',
      String model = 'gpt-4o-mini'}) {
    return CloudLlmConfig(
      apiUrl: apiUrl,
      apiKey: apiKey,
      model: model,
      timeout: const Duration(seconds: 5),
    );
  }

  String chatBody(String content) => jsonEncode(<String, dynamic>{
        'id': 'chatcmpl-xyz',
        'object': 'chat.completion',
        'created': 1234567890,
        'model': 'gpt-4o-mini',
        'choices': [
          {
            'index': 0,
            'message': {'role': 'assistant', 'content': content},
            'finish_reason': 'stop',
          }
        ],
      });

  group('cleanupSegment', () {
    test('disabled config throws CloudLlmDisabledException', () async {
      final svc = CloudLlmCleanupService(client: MockClient((_) async {
        throw StateError('should not be called');
      }));
      addTearDown(svc.dispose);
      await expectLater(
        svc.cleanupSegment(
          text: 'um the cat',
          config: const CloudLlmConfig(
              apiUrl: '', apiKey: '', model: 'gpt-4o-mini'),
        ),
        throwsA(isA<CloudLlmDisabledException>()),
      );
    });

    test('empty text short-circuits without an HTTP call', () async {
      var calls = 0;
      final svc = CloudLlmCleanupService(client: MockClient((_) async {
        calls++;
        return http.Response(chatBody(''), 200);
      }));
      addTearDown(svc.dispose);
      final out =
          await svc.cleanupSegment(text: '   ', config: config());
      expect(out, '   ');
      expect(calls, 0);
    });

    test('happy path — sends bearer auth + OpenAI envelope, parses content',
        () async {
      late String capturedAuth;
      late String capturedContentType;
      late Map<String, dynamic> capturedBody;
      final svc = CloudLlmCleanupService(client: MockClient((req) async {
        capturedAuth = req.headers['Authorization'] ?? '';
        capturedContentType = req.headers['Content-Type'] ?? '';
        capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
            chatBody('The cat sat on the mat.'), 200,
            headers: {'content-type': 'application/json'});
      }));
      addTearDown(svc.dispose);
      final out = await svc.cleanupSegment(
          text: 'the cat sat on the mat',
          config: config(apiKey: 'sk-abc123'));
      expect(out, 'The cat sat on the mat.');
      expect(capturedAuth, 'Bearer sk-abc123');
      expect(capturedContentType, 'application/json');
      expect(capturedBody['model'], 'gpt-4o-mini');
      expect(capturedBody['temperature'], 0.0);
      expect(capturedBody['messages'], isA<List<dynamic>>());
      final msgs = (capturedBody['messages'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(msgs.first['role'], 'system');
      expect(msgs.last['role'], 'user');
      expect(msgs.last['content'], 'the cat sat on the mat');
    });

    test('contextHint inserts a second system message', () async {
      late Map<String, dynamic> capturedBody;
      final svc = CloudLlmCleanupService(client: MockClient((req) async {
        capturedBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(chatBody('clean'), 200);
      }));
      addTearDown(svc.dispose);
      await svc.cleanupSegment(
          text: 'whatever',
          config: config(),
          contextHint: 'speakers are software engineers');
      final msgs = (capturedBody['messages'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(msgs, hasLength(3));
      expect(msgs[1]['role'], 'system');
      expect(msgs[1]['content'], contains('software engineers'));
    });

    test('non-2xx response throws CloudLlmHttpException', () async {
      final svc = CloudLlmCleanupService(client: MockClient((_) async {
        return http.Response('{"error":"rate_limited"}', 429);
      }));
      addTearDown(svc.dispose);
      await expectLater(
        svc.cleanupSegment(text: 'hello', config: config()),
        throwsA(isA<CloudLlmHttpException>().having(
            (e) => e.statusCode, 'statusCode', 429)),
      );
    });

    test('malformed response (no choices) throws', () async {
      final svc = CloudLlmCleanupService(client: MockClient((_) async {
        return http.Response('{"weird":"shape"}', 200);
      }));
      addTearDown(svc.dispose);
      await expectLater(
        svc.cleanupSegment(text: 'hello', config: config()),
        throwsA(isA<CloudLlmHttpException>()),
      );
    });

    test('slow server triggers TimeoutException', () async {
      final svc = CloudLlmCleanupService(client: MockClient((_) async {
        // Sleep past the 5 s timeout we configure in the helper.
        await Future<void>.delayed(const Duration(seconds: 6));
        return http.Response(chatBody('eventual'), 200);
      }));
      addTearDown(svc.dispose);
      await expectLater(
        svc.cleanupSegment(
            text: 'hello',
            config: config()),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('trims trailing whitespace from model output', () async {
      final svc = CloudLlmCleanupService(client: MockClient((_) async {
        return http.Response(
            chatBody('  \n The cat.  \n\n'), 200);
      }));
      addTearDown(svc.dispose);
      final out = await svc.cleanupSegment(
          text: 'the cat', config: config());
      expect(out, 'The cat.');
    });
  });

  group('cleanupBatch', () {
    test('per-segment failures fall through unchanged', () async {
      var calls = 0;
      final svc = CloudLlmCleanupService(client: MockClient((req) async {
        calls++;
        // Fail every other call so we can check both branches.
        if (calls.isEven) return http.Response('{"err":"500"}', 500);
        return http.Response(chatBody('GOOD'), 200);
      }));
      addTearDown(svc.dispose);
      final cancel = CleanupCancelToken();
      final out = await svc.cleanupBatch(
        texts: ['one', 'two', 'three'],
        config: config(),
        cancel: cancel,
      );
      // 1st (odd call) → GOOD, 2nd (even call) → fallback to 'two',
      // 3rd (odd call) → GOOD.
      expect(out, ['GOOD', 'two', 'GOOD']);
    });

    test('cancel token aborts mid-batch', () async {
      final cancel = CleanupCancelToken();
      var calls = 0;
      final svc = CloudLlmCleanupService(client: MockClient((_) async {
        calls++;
        // After the first call, set the flag so the loop bails
        // out before issuing the second.
        if (calls == 1) cancel.cancelled = true;
        return http.Response(chatBody('OK'), 200);
      }));
      addTearDown(svc.dispose);
      final out = await svc.cleanupBatch(
        texts: ['a', 'b', 'c'],
        config: config(),
        cancel: cancel,
      );
      // First segment processed; rest skipped.
      expect(out, hasLength(1));
      expect(out.first, 'OK');
      expect(calls, 1);
    });

    test('progress callback fires once per segment', () async {
      final svc = CloudLlmCleanupService(client: MockClient((_) async {
        return http.Response(chatBody('CLEAN'), 200);
      }));
      addTearDown(svc.dispose);
      final progress = <int>[];
      await svc.cleanupBatch(
        texts: ['x', 'y', 'z'],
        config: config(),
        cancel: CleanupCancelToken(),
        onProgress: (done, total) {
          expect(total, 3);
          progress.add(done);
        },
      );
      expect(progress, [1, 2, 3]);
    });

    test('empty batch returns empty list, no HTTP calls', () async {
      var calls = 0;
      final svc = CloudLlmCleanupService(client: MockClient((_) async {
        calls++;
        return http.Response(chatBody(''), 200);
      }));
      addTearDown(svc.dispose);
      final out = await svc.cleanupBatch(
        texts: const [],
        config: config(),
        cancel: CleanupCancelToken(),
      );
      expect(out, isEmpty);
      expect(calls, 0);
    });
  });

  group('CloudLlmConfig', () {
    test('enabled is true only when both URL and key are set', () {
      expect(const CloudLlmConfig(apiUrl: '', apiKey: '', model: 'm').enabled,
          false);
      expect(
          const CloudLlmConfig(apiUrl: 'u', apiKey: '', model: 'm').enabled,
          false);
      expect(
          const CloudLlmConfig(apiUrl: '', apiKey: 'k', model: 'm').enabled,
          false);
      expect(
          const CloudLlmConfig(apiUrl: 'u', apiKey: 'k', model: 'm').enabled,
          true);
    });
  });
}
