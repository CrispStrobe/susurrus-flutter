// HistoryService persistence — drives the actual save/list/delete/clear
// flow against a temp directory via the test-only `withDirectory`
// constructor. Catches regressions in the JSON write path that the
// pure HistoryEntry round-trip tests can't see (e.g. file naming,
// mtime ordering, corrupt-file resilience).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:crisper_weaver/engines/transcription_engine.dart';
import 'package:crisper_weaver/services/history_service.dart';

void main() {
  late Directory tmp;
  late HistoryService svc;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('crisper_history_test_');
    svc = HistoryService.withDirectory(tmp);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  const segs = [
    TranscriptionSegment(
        text: 'hello', startTime: 0.0, endTime: 1.0, confidence: 0.9),
    TranscriptionSegment(
        text: 'world', startTime: 1.0, endTime: 2.0, confidence: 0.8),
  ];

  group('HistoryService', () {
    test('save writes a JSON file named by entry id', () async {
      final entry = await svc.save(
        engineId: 'mock',
        segments: segs,
        sourcePath: '/tmp/recording.wav',
      );

      final f = File(p.join(tmp.path, '${entry.id}.json'));
      expect(await f.exists(), isTrue);

      // The body parses as the same shape as toJson.
      final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      expect(json['engineId'], 'mock');
      expect(json['sourcePath'], '/tmp/recording.wav');
      expect((json['segments'] as List).length, 2);
    });

    test('save → list round-trips every field', () async {
      final saved = await svc.save(
        engineId: 'crispasr',
        segments: segs,
        modelId: 'whisper-tiny',
        language: 'en',
        diarizationEnabled: true,
        processingTime: const Duration(milliseconds: 4567),
        speakerNames: const {'Speaker 1': 'Alice'},
      );

      final entries = await svc.list();
      expect(entries.length, 1);

      final loaded = entries.first;
      expect(loaded.id, saved.id);
      expect(loaded.engineId, 'crispasr');
      expect(loaded.modelId, 'whisper-tiny');
      expect(loaded.language, 'en');
      expect(loaded.diarizationEnabled, isTrue);
      expect(loaded.processingTime, const Duration(milliseconds: 4567));
      expect(loaded.speakerNames, {'Speaker 1': 'Alice'});
      expect(loaded.segments.length, 2);
    });

    test('list returns entries sorted newest-first', () async {
      final a = await svc.save(engineId: 'a', segments: const []);
      // The HistoryEntry's createdAt is set by save() and uses
      // DateTime.now(), so back-to-back saves can land on the same
      // millisecond. Wait long enough to guarantee distinct
      // timestamps for ordering.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final b = await svc.save(engineId: 'b', segments: const []);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final c = await svc.save(engineId: 'c', segments: const []);

      final ids = (await svc.list()).map((e) => e.id).toList();
      expect(ids, [c.id, b.id, a.id]);
    });

    test('skips corrupt JSON files instead of throwing', () async {
      final good = await svc.save(engineId: 'ok', segments: const []);
      // Drop a half-written file in the dir — list() should ignore it
      // rather than failing the whole list.
      await File(p.join(tmp.path, 'corrupt.json'))
          .writeAsString('{ "broken": tru');
      // Also a non-json file (legitimate sibling content).
      await File(p.join(tmp.path, 'README.txt')).writeAsString('hello');

      final entries = await svc.list();
      expect(entries.length, 1);
      expect(entries.first.id, good.id);
    });

    test('delete removes the matching file and leaves siblings alone',
        () async {
      final a = await svc.save(engineId: 'a', segments: const []);
      final b = await svc.save(engineId: 'b', segments: const []);

      await svc.delete(a.id);

      final remaining = await svc.list();
      expect(remaining.length, 1);
      expect(remaining.first.id, b.id);
    });

    test('delete on a missing id is a no-op', () async {
      await svc.save(engineId: 'a', segments: const []);
      await svc.delete('does-not-exist');
      expect((await svc.list()).length, 1);
    });

    test('clear removes every entry but keeps the directory', () async {
      await svc.save(engineId: 'a', segments: const []);
      await svc.save(engineId: 'b', segments: const []);

      await svc.clear();

      expect(await tmp.exists(), isTrue);
      expect((await svc.list()), isEmpty);
    });
  });
}
