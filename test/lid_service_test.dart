// Tests for the LID method <-> filename mapping in LidService.
//
// The routing is what guards against a "user picked Firered in
// the Advanced picker but only has a Silero GGUF on disk"
// mismatch — the C side returns rc=-2 on that, so the service
// trusts the FILE over the user's enum pick. This test pins
// every basename pattern we accept so a registry rename (e.g.
// the upstream silero-lang95 → silero-lid-95 transition that
// triggered this entire patch) doesn't silently break LID at
// runtime.

import 'package:crispasr/crispasr.dart' as crispasr;
import 'package:flutter_test/flutter_test.dart';

import 'package:crisper_weaver/services/lid_service.dart';

void main() {
  group('LidService.methodForFilename', () {
    test('whisper ggml-*.bin → LidMethod.whisper', () {
      // Every multilingual whisper variant — tiny / base / small /
      // medium / large — routes to the whisper LID encoder.
      const cases = [
        '/Users/x/models/ggml-tiny.bin',
        '/Users/x/models/ggml-base.bin',
        '/Users/x/models/ggml-small.bin',
        '/Users/x/models/ggml-medium.bin',
        '/Users/x/models/ggml-large-v3.bin',
        // Quantised variants follow the same prefix.
        '/Users/x/models/ggml-medium-q5_0.bin',
        '/Users/x/models/ggml-large-v3-q8_0.bin',
      ];
      for (final c in cases) {
        expect(LidService.methodForFilename(c), crispasr.LidMethod.whisper,
            reason: 'expected whisper for $c');
      }
    });

    test('silero LID variants → LidMethod.silero', () {
      const cases = [
        // Legacy CrisperWeaver registry filename (pre-0.5.8).
        '/Users/x/models/silero-lang95-v1-f16.gguf',
        // New CrispASR-registry-canonical filename (0.5.8+).
        '/Users/x/models/silero-lid-95-f16.gguf',
        // Case-insensitivity — basename gets lowercased before match.
        '/Users/x/models/Silero-Lid-95-f16.gguf',
      ];
      for (final c in cases) {
        expect(LidService.methodForFilename(c), crispasr.LidMethod.silero,
            reason: 'expected silero for $c');
      }
    });

    test('FireRed LID → LidMethod.firered', () {
      const cases = [
        '/Users/x/models/firered-lid-f16.gguf',
        // Defend against a future q4_0 variant landing under the same
        // basename prefix — the upstream registry only ships f16
        // today but the routing should already handle quantised
        // variants when they appear.
        '/Users/x/models/firered-lid-q4_0.gguf',
      ];
      for (final c in cases) {
        expect(LidService.methodForFilename(c), crispasr.LidMethod.firered,
            reason: 'expected firered for $c');
      }
    });

    test('ECAPA-TDNN LID → LidMethod.ecapa', () {
      const cases = [
        '/Users/x/models/ecapa-lid-107-f16.gguf',
        '/Users/x/models/ECAPA-lid-107-f16.gguf',
      ];
      for (final c in cases) {
        expect(LidService.methodForFilename(c), crispasr.LidMethod.ecapa,
            reason: 'expected ecapa for $c');
      }
    });

    test('unknown filename falls back to LidMethod.whisper', () {
      // Mismatched / typo'd filenames don't error — they default
      // to whisper, which is the safe option since every user with
      // a multilingual model already has it on disk.
      expect(LidService.methodForFilename('/Users/x/models/random.gguf'),
          crispasr.LidMethod.whisper);
      expect(LidService.methodForFilename('/Users/x/no-extension'),
          crispasr.LidMethod.whisper);
    });

    test('directory name with a matching prefix does NOT trigger match',
        () {
      // Routing keys off the FILE basename, never the parent dirs —
      // otherwise a user with a `Silero/` folder full of unrelated
      // models would have every file misrouted. Pin that here.
      expect(LidService.methodForFilename('/Users/x/silero/random.gguf'),
          crispasr.LidMethod.whisper,
          reason: '/silero/ directory must not force silero method');
      expect(LidService.methodForFilename('/firered-lid/random.gguf'),
          crispasr.LidMethod.whisper);
    });

    test('LidMethod enum still has 4 values (regression guard)', () {
      // The C-side enum is Whisper=0, Silero=1, Firered=2, Ecapa=3.
      // If the upstream binding drops a variant or reorders, this
      // catches it fast — the dispatch in detect_language_pcm uses
      // method.index, so any drift is a silent miscall.
      expect(crispasr.LidMethod.values.length, 4);
      expect(crispasr.LidMethod.whisper.index, 0);
      expect(crispasr.LidMethod.silero.index, 1);
      expect(crispasr.LidMethod.firered.index, 2);
      expect(crispasr.LidMethod.ecapa.index, 3);
    });
  });
}
