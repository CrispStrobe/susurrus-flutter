// Tests for CrispASREngine.sliceTranscribeWindow — the static
// helper backing the §5.8 `--offset-t / --duration` window
// feature. The arithmetic (sample-rate × seconds, end clamp,
// no-window short-circuit) is what guards against silently
// dropping or doubling audio when the user enters edge values.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:crisper_weaver/engines/crispasr_engine.dart';
import 'package:crisper_weaver/engines/transcription_engine.dart';

void main() {
  // 5 seconds of fake PCM at 16 kHz so we have a known-length
  // buffer to slice. Values are just incrementing indexes —
  // makes off-by-one mistakes obvious in assertion failures.
  Float32List makeBuf(int seconds) {
    final n = seconds * 16000;
    final out = Float32List(n);
    for (var i = 0; i < n; i++) out[i] = i.toDouble();
    return out;
  }

  group('CrispASREngine.sliceTranscribeWindow', () {
    test('start=0, duration=0 returns the buffer unchanged (identity)',
        () {
      final buf = makeBuf(5);
      final out = CrispASREngine.sliceTranscribeWindow(buf, 16000, 0, 0);
      // The "no window" path is supposed to skip a copy — both the
      // length AND the identity should match (sublistView would be
      // a separate Float32List even if it views the same bytes).
      expect(identical(out, buf), isTrue,
          reason: 'no-window case must short-circuit without copying');
    });

    test('start>0, duration=0 = open-ended from start to EOF', () {
      final buf = makeBuf(5);
      // 1.5 s in → keep the last 3.5 s = 56000 samples.
      final out =
          CrispASREngine.sliceTranscribeWindow(buf, 16000, 1.5, 0);
      expect(out.length, 16000 * 5 - (1.5 * 16000).round());
      expect(out[0], 24000.0,
          reason: 'open-ended start should begin at 1.5*16000 = 24000');
      expect(out.last, buf.last,
          reason: 'open-ended end should land on the final sample');
    });

    test('start=0, duration>0 = leading slice from start of file', () {
      final buf = makeBuf(5);
      // First 2 s of a 5 s buffer.
      final out =
          CrispASREngine.sliceTranscribeWindow(buf, 16000, 0, 2.0);
      expect(out.length, 32000);
      expect(out[0], 0.0);
      expect(out.last, 31999.0);
    });

    test('start+duration mid-file = bounded slice', () {
      final buf = makeBuf(5);
      // 1.0 s..3.5 s → 2.5 s = 40000 samples, indices 16000..55999.
      final out =
          CrispASREngine.sliceTranscribeWindow(buf, 16000, 1.0, 2.5);
      expect(out.length, 40000);
      expect(out[0], 16000.0);
      expect(out.last, 55999.0);
    });

    test('duration past end-of-buffer is clamped to EOF', () {
      final buf = makeBuf(5);
      // 4.0 s..(4.0+10.0) = past EOF → should clamp to 4.0..5.0.
      final out =
          CrispASREngine.sliceTranscribeWindow(buf, 16000, 4.0, 10.0);
      expect(out.length, 16000,
          reason: 'duration past EOF must clamp; only 1 s of audio remains');
      expect(out[0], 64000.0);
    });

    test('start past end-of-buffer returns an empty buffer', () {
      final buf = makeBuf(5);
      // start at 10 s — past the 5 s file.
      final out =
          CrispASREngine.sliceTranscribeWindow(buf, 16000, 10.0, 1.0);
      expect(out.length, 0);
    });

    test('negative inputs are coerced to 0 (defensive)', () {
      final buf = makeBuf(5);
      // Negative start + negative duration → no-window short-circuit.
      final out =
          CrispASREngine.sliceTranscribeWindow(buf, 16000, -1.0, -5.0);
      expect(identical(out, buf), isTrue,
          reason: 'negative inputs must collapse to no-window');
    });

    test('non-16 kHz sample rate scales the slice correctly', () {
      // 1 s of fake audio at 48 kHz.
      final buf48k = Float32List(48000);
      for (var i = 0; i < buf48k.length; i++) buf48k[i] = i.toDouble();
      // 0.25 s..0.75 s = 0.5 s = 24000 samples.
      final out =
          CrispASREngine.sliceTranscribeWindow(buf48k, 48000, 0.25, 0.5);
      expect(out.length, 24000);
      expect(out[0], 12000.0);
      expect(out.last, 35999.0);
    });
  });

  group('CrispASREngine.shiftSegmentForResume re-pin for window use',
      () {
    test('window-shifted segment timestamps are absolute file time', () {
      // The screen / service code uses shiftSegmentForResume to bring
      // window-relative timestamps back to absolute file time. Pin
      // the math here so a future refactor of the shift helper
      // doesn't silently break windowing.
      const raw = TranscriptionSegment(
        text: 'hello world',
        startTime: 0.5,
        endTime: 2.0,
        speaker: 'A',
        confidence: 0.95,
      );
      final shifted = CrispASREngine.shiftSegmentForResume(raw,
          offsetSeconds: 60.0);
      expect(shifted.startTime, 60.5);
      expect(shifted.endTime, 62.0);
      expect(shifted.text, 'hello world');
      expect(shifted.speaker, 'A');
      expect(shifted.confidence, 0.95);
    });

    test('zero offset returns the original segment unchanged', () {
      const raw = TranscriptionSegment(
        text: 'x',
        startTime: 1.0,
        endTime: 2.0,
      );
      final shifted = CrispASREngine.shiftSegmentForResume(raw,
          offsetSeconds: 0.0);
      expect(identical(shifted, raw), isTrue,
          reason: 'zero offset must short-circuit without copying');
    });
  });
}
