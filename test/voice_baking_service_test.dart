// Pure-Dart smoke check on VoiceBakingService — pins the platform-
// support contract and the default script path. The real Process.start
// flow is opt-in slow (needs Python + chatterbox-tts on the test
// host), so we don't exercise that here.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:crisper_weaver/services/voice_baking_service.dart';

void main() {
  group('VoiceBakingService', () {
    test('isSupported is true on desktop and false on mobile', () {
      // Mobile sandboxes ship no python3 — the bake screen disables
      // itself there to avoid a misleading "not found" error after
      // the user files a WAV picker.
      final expected = Platform.isMacOS || Platform.isLinux || Platform.isWindows;
      expect(VoiceBakingService.isSupported, expected);
    });

    test('default script path follows the sibling-checkout convention', () {
      // README documents the CrispASR + CrisperWeaver side-by-side
      // layout; the bake script lives under that sibling repo. If
      // we ever move CrispASR's tree, update this AND the README.
      expect(VoiceBakingService.defaultScriptPath,
          '../CrispASR/models/bake-chatterbox-voice-from-wav.py');
    });

    test('VoiceBakingException carries a user-readable message', () {
      // Surfaced verbatim into a SnackBar by the Bake screen.
      const e = VoiceBakingException('python3 not found on PATH');
      expect(e.message, 'python3 not found on PATH');
      expect(e.toString(), contains('python3 not found on PATH'));
    });
  });
}
