// Tests for the §5.23 Q3 resume-from-checkpoint plumbing. Covers
// every layer that doesn't need an FFI session:
//
//   • BatchQueueNotifier.load() stamps resumeOffsetSec from each
//     leftover .ckpt.jsonl's last segment endTime.
//   • CrispASREngine.shiftSegmentForResume offsets timestamps +
//     words + leaves zero-offset segments untouched (identity).
//   • CrispASREngine._trimLeadingSamples (via the public path through
//     the engine — we route the chunked-whisper path with a known
//     fake audio buffer and assert the firstChunk math). Since this
//     is internal we only test via the shift helper and the
//     load()-end-to-end test below.
//
// What's NOT tested here:
//   - The CrispASR FFI runtime path (covered by the bindings smoke
//     test in CrispASR's own repo).
//   - The drain-loop wiring in transcription_screen.dart — that's a
//     widget test which would need to mock TranscriptionService.
//     Manual smoke verification + the load+resume end-to-end test
//     here is the v1 coverage.

import 'dart:io';

import 'package:crisper_weaver/engines/crispasr_engine.dart';
import 'package:crisper_weaver/engines/transcription_engine.dart';
import 'package:crisper_weaver/services/batch_persistence_service.dart';
import 'package:crisper_weaver/services/batch_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shiftSegmentForResume', () {
    test('zero offset returns identity (same instance)', () {
      const seg = TranscriptionSegment(
        text: 'hi',
        startTime: 1.0,
        endTime: 2.0,
        confidence: 0.9,
      );
      final shifted =
          CrispASREngine.shiftSegmentForResume(seg, offsetSeconds: 0);
      // For zero offset we return the input unchanged — no allocation
      // overhead on the no-op path.
      expect(identical(shifted, seg), isTrue);
    });

    test('positive offset shifts segment + word timestamps', () {
      const seg = TranscriptionSegment(
        text: 'hello world',
        startTime: 1.0,
        endTime: 2.0,
        confidence: 0.95,
        words: [
          TranscriptionWord(
            word: 'hello',
            startTime: 1.0,
            endTime: 1.5,
            confidence: 0.95,
          ),
          TranscriptionWord(
            word: 'world',
            startTime: 1.5,
            endTime: 2.0,
            confidence: 0.95,
          ),
        ],
      );
      final shifted =
          CrispASREngine.shiftSegmentForResume(seg, offsetSeconds: 30.0);
      expect(shifted.startTime, 31.0);
      expect(shifted.endTime, 32.0);
      expect(shifted.text, 'hello world');
      expect(shifted.confidence, 0.95);
      expect(shifted.words, isNotNull);
      expect(shifted.words!.length, 2);
      expect(shifted.words![0].startTime, 31.0);
      expect(shifted.words![0].endTime, 31.5);
      expect(shifted.words![1].startTime, 31.5);
      expect(shifted.words![1].endTime, 32.0);
    });

    test('shifted segment stamps resumeOffsetSec in metadata', () {
      const seg = TranscriptionSegment(
        text: 'x',
        startTime: 0.0,
        endTime: 1.0,
      );
      final shifted =
          CrispASREngine.shiftSegmentForResume(seg, offsetSeconds: 12.5);
      expect(shifted.metadata['resumeOffsetSec'], 12.5);
    });

    test('preserves speaker label across shift', () {
      const seg = TranscriptionSegment(
        text: 'x',
        startTime: 0.0,
        endTime: 1.0,
        speaker: 'spk1',
      );
      final shifted =
          CrispASREngine.shiftSegmentForResume(seg, offsetSeconds: 5.0);
      expect(shifted.speaker, 'spk1');
    });

    test('preserves arbitrary metadata fields on shift', () {
      const seg = TranscriptionSegment(
        text: 'x',
        startTime: 0.0,
        endTime: 1.0,
        metadata: {'lid': 'de', 'chunk': 3},
      );
      final shifted =
          CrispASREngine.shiftSegmentForResume(seg, offsetSeconds: 1.0);
      expect(shifted.metadata['lid'], 'de');
      expect(shifted.metadata['chunk'], 3);
      // Plus our new key …
      expect(shifted.metadata['resumeOffsetSec'], 1.0);
    });
  });

  group('BatchQueueNotifier.load() resume hydration', () {
    late Directory tempDir;
    late BatchPersistenceService persistence;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('batch-resume-test-');
      persistence = BatchPersistenceService.withDirectory(tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('stamps resumeOffsetSec from the checkpoint last segment endTime',
        () async {
      // Simulate a job that crashed mid-run with a partial ckpt.
      final crashed = BatchJob(
        id: 'crashed-1',
        filePath: '/tmp/long.wav',
        createdAt: DateTime.utc(2026, 5, 11, 10),
        status: BatchJobStatus.running, // pre-crash state
        backend: 'whisper',
        modelId: 'ggml-small.en',
      );
      await persistence.saveJob(crashed);
      for (final s in const [
        TranscriptionSegment(text: 'a', startTime: 0.0, endTime: 4.5),
        TranscriptionSegment(text: 'b', startTime: 4.5, endTime: 9.0),
        TranscriptionSegment(text: 'c', startTime: 9.0, endTime: 13.5),
      ]) {
        await persistence.appendSegmentToCheckpoint(crashed.id, s);
      }

      final notifier = BatchQueueNotifier(persistence: persistence);
      await notifier.load();

      expect(notifier.state, hasLength(1));
      final j = notifier.state.single;
      // running → demoted to queued
      expect(j.status, BatchJobStatus.queued);
      // resumeOffsetSec = last segment endTime (= 13.5)
      expect(j.resumeOffsetSec, 13.5);
      // metadata snapshot from enqueue carried through
      expect(j.backend, 'whisper');
      expect(j.modelId, 'ggml-small.en');
      notifier.dispose();
    });

    test('does not stamp resumeOffsetSec on jobs without a checkpoint',
        () async {
      final fresh = BatchJob(
        id: 'fresh-1',
        filePath: '/tmp/fresh.wav',
        createdAt: DateTime.utc(2026, 5, 11, 10),
        status: BatchJobStatus.queued,
      );
      await persistence.saveJob(fresh);

      final notifier = BatchQueueNotifier(persistence: persistence);
      await notifier.load();

      expect(notifier.state.single.resumeOffsetSec, isNull);
      notifier.dispose();
    });

    test('does not stamp resumeOffsetSec on done jobs (terminal)', () async {
      final done = BatchJob(
        id: 'done-1',
        filePath: '/tmp/done.wav',
        createdAt: DateTime.utc(2026, 5, 11, 10),
        status: BatchJobStatus.done,
      );
      await persistence.saveJob(done);
      // Leave a stale .ckpt around — setDone normally cleans this up
      // but we want to simulate the edge case where it didn't.
      await persistence.appendSegmentToCheckpoint(
        done.id,
        const TranscriptionSegment(text: 'stale', startTime: 0, endTime: 1),
      );

      final notifier = BatchQueueNotifier(persistence: persistence);
      await notifier.load();

      // Done jobs stay done; resumeOffsetSec stays null. (Whether to
      // garbage-collect the stale ckpt is a separate concern — for
      // now we leave it for the user's setDone to clean up next time
      // the job re-runs, or for a future periodic-sweep.)
      expect(notifier.state.single.status, BatchJobStatus.done);
      expect(notifier.state.single.resumeOffsetSec, isNull);
      notifier.dispose();
    });

    test('zero or negative endTime is ignored (defensive against bad data)',
        () async {
      final crashed = BatchJob(
        id: 'broken-ckpt',
        filePath: '/tmp/x.wav',
        createdAt: DateTime.utc(2026, 5, 11, 10),
        status: BatchJobStatus.running,
      );
      await persistence.saveJob(crashed);
      await persistence.appendSegmentToCheckpoint(
        crashed.id,
        const TranscriptionSegment(text: '', startTime: 0.0, endTime: 0.0),
      );

      final notifier = BatchQueueNotifier(persistence: persistence);
      await notifier.load();

      // endTime <= 0 → don't stamp; the drain loop will run from the
      // top of the file rather than committing to a malformed offset.
      expect(notifier.state.single.resumeOffsetSec, isNull);
      notifier.dispose();
    });
  });
}
