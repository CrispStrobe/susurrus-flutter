// Chunked-whisper segment shifter — pure data transformation.
// Long audio files (>60 s) get split into 30 s chunks; each chunk is
// transcribed independently and the resulting segments need their
// timestamps shifted by the chunk's start offset so the final list is
// monotonic across chunk boundaries. A regression here turns long
// transcripts into a pile of 0.0–30.0 s segments stacked on top of
// each other.
import 'package:flutter_test/flutter_test.dart';

import 'package:crisper_weaver/engines/crispasr_engine.dart';
import 'package:crisper_weaver/engines/transcription_engine.dart';

void main() {
  group('CrispASREngine.shiftSegmentByOffset', () {
    test('shifts startTime + endTime by the chunk offset', () {
      const raw = TranscriptionSegment(
        text: 'Hello world.',
        startTime: 1.5,
        endTime: 3.2,
        confidence: 0.9,
      );
      final shifted = CrispASREngine.shiftSegmentByOffset(
        raw,
        offsetSeconds: 30.0,
        chunkIndex: 1,
      );
      expect(shifted.text, 'Hello world.');
      expect(shifted.startTime, closeTo(31.5, 1e-9));
      expect(shifted.endTime, closeTo(33.2, 1e-9));
      expect(shifted.confidence, 0.9);
    });

    test('shifts every per-word timestamp', () {
      const raw = TranscriptionSegment(
        text: 'hello world',
        startTime: 0.0,
        endTime: 2.0,
        confidence: 0.95,
        words: [
          TranscriptionWord(
              word: 'hello', startTime: 0.0, endTime: 0.8, confidence: 0.9),
          TranscriptionWord(
              word: 'world', startTime: 1.0, endTime: 1.8, confidence: 0.92),
        ],
      );
      final shifted = CrispASREngine.shiftSegmentByOffset(
        raw,
        offsetSeconds: 60.0,
        chunkIndex: 2,
      );
      expect(shifted.words?.length, 2);
      expect(shifted.words![0].word, 'hello');
      expect(shifted.words![0].startTime, closeTo(60.0, 1e-9));
      expect(shifted.words![0].endTime, closeTo(60.8, 1e-9));
      expect(shifted.words![1].startTime, closeTo(61.0, 1e-9));
      expect(shifted.words![1].endTime, closeTo(61.8, 1e-9));
    });

    test('writes chunkIndex + chunkOffsetSeconds into metadata', () {
      const raw = TranscriptionSegment(
        text: 't',
        startTime: 0.0,
        endTime: 1.0,
        confidence: 1.0,
      );
      final shifted = CrispASREngine.shiftSegmentByOffset(
        raw,
        offsetSeconds: 90.0,
        chunkIndex: 3,
      );
      expect(shifted.metadata['chunkIndex'], 3);
      expect(shifted.metadata['chunkOffsetSeconds'], 90.0);
    });

    test('preserves existing metadata keys', () {
      const raw = TranscriptionSegment(
        text: 't',
        startTime: 0.0,
        endTime: 1.0,
        confidence: 1.0,
        metadata: {'someKey': 'someValue', 'lang': 'en'},
      );
      final shifted = CrispASREngine.shiftSegmentByOffset(
        raw,
        offsetSeconds: 30.0,
        chunkIndex: 1,
      );
      expect(shifted.metadata['someKey'], 'someValue');
      expect(shifted.metadata['lang'], 'en');
      expect(shifted.metadata['chunkIndex'], 1);
    });

    test('null words list stays null after shift', () {
      const raw = TranscriptionSegment(
        text: 't',
        startTime: 0.0,
        endTime: 1.0,
        confidence: 1.0,
      );
      final shifted = CrispASREngine.shiftSegmentByOffset(
        raw,
        offsetSeconds: 5.0,
        chunkIndex: 0,
      );
      expect(shifted.words, isNull);
    });

    test('zero offset is a no-op for timestamps but still tags metadata',
        () {
      const raw = TranscriptionSegment(
        text: 't',
        startTime: 1.0,
        endTime: 2.0,
        confidence: 1.0,
      );
      final shifted = CrispASREngine.shiftSegmentByOffset(
        raw,
        offsetSeconds: 0.0,
        chunkIndex: 0,
      );
      expect(shifted.startTime, 1.0);
      expect(shifted.endTime, 2.0);
      expect(shifted.metadata['chunkIndex'], 0);
      expect(shifted.metadata['chunkOffsetSeconds'], 0.0);
    });
  });
}
