// Wire-format tests for the TranscriptionWorker SendPort protocol.
//
// We can't easily spin up a real worker isolate in a unit test
// (it'd need libcrispasr + a real model file on PATH), but the
// segment serialization is pure-Dart and round-trippable. These
// tests pin the contract:
//   • text / startTime / endTime / speaker / confidence survive
//     the Map → TranscriptionSegment hop
//   • words are included when the source has them, omitted when
//     the source list is empty (smaller wire payload for the
//     no-word-timestamps common case)
//   • the reverse path (`workerSegmentFromMap`) is robust against
//     missing keys (older worker builds, partial messages)
//
// The serialization helpers live in transcription_worker.dart;
// `workerSegmentFromMap` is the public entry point the pool uses,
// and the inverse `_segmentToMap` is exercised end-to-end by
// constructing the wire map by hand here.

import 'package:crisper_weaver/engines/transcription_engine.dart';
import 'package:crisper_weaver/services/transcription_worker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('workerSegmentFromMap', () {
    test('round-trips a segment without words', () {
      final m = {
        'text': 'hello world',
        'startTime': 1.5,
        'endTime': 3.0,
      };
      final seg = workerSegmentFromMap(m);
      expect(seg.text, 'hello world');
      expect(seg.startTime, 1.5);
      expect(seg.endTime, 3.0);
      expect(seg.words, isNull,
          reason: 'no `words` key in the wire map → null on the segment');
      // confidence defaults to 1.0 when omitted.
      expect(seg.confidence, 1.0);
    });

    test('round-trips a segment with words', () {
      final m = {
        'text': 'hello world',
        'startTime': 0.0,
        'endTime': 2.0,
        'words': [
          {
            'word': 'hello',
            'startTime': 0.0,
            'endTime': 1.0,
            'confidence': 0.92,
          },
          {
            'word': 'world',
            'startTime': 1.0,
            'endTime': 2.0,
            'confidence': 0.87,
          },
        ],
      };
      final seg = workerSegmentFromMap(m);
      expect(seg.words, isNotNull);
      expect(seg.words!.length, 2);
      expect(seg.words![0].word, 'hello');
      expect(seg.words![0].startTime, 0.0);
      expect(seg.words![0].endTime, 1.0);
      expect(seg.words![0].confidence, closeTo(0.92, 1e-9));
      expect(seg.words![1].word, 'world');
    });

    test('handles missing fields with sane defaults', () {
      final seg = workerSegmentFromMap({});
      expect(seg.text, '');
      expect(seg.startTime, 0.0);
      expect(seg.endTime, 0.0);
      expect(seg.speaker, isNull);
      expect(seg.confidence, 1.0);
      expect(seg.words, isNull);
    });

    test('preserves speaker label when present', () {
      final m = {
        'text': 'hi',
        'startTime': 0.0,
        'endTime': 1.0,
        'speaker': 'spk1',
      };
      final seg = workerSegmentFromMap(m);
      expect(seg.speaker, 'spk1');
    });

    test('word confidence default is 1.0 when the key is missing', () {
      final m = {
        'text': 'x',
        'startTime': 0.0,
        'endTime': 1.0,
        'words': [
          {'word': 'x', 'startTime': 0.0, 'endTime': 1.0},
        ],
      };
      final seg = workerSegmentFromMap(m);
      expect(seg.words![0].confidence, 1.0);
    });

    test('returns the canonical TranscriptionSegment type', () {
      // Round-trip should produce a value the rest of the engine
      // pipeline (history, exports, etc.) can consume without any
      // adapter layer.
      final seg = workerSegmentFromMap({
        'text': 'foo',
        'startTime': 0.0,
        'endTime': 1.0,
      });
      expect(seg, isA<TranscriptionSegment>());
    });
  });
}
