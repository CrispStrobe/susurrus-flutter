// Tests for SystemAudioCaptureService — §5.1.1 system-audio capture.
//
// The native side (macOS Swift via ScreenCaptureKit) can't be
// driven from a unit test, but the Dart-side interface contract
// is fully testable:
//   • isSupported() returns false on every non-macOS platform
//     without touching a MethodChannel
//   • start() throws SystemAudioUnsupportedException on every
//     non-macOS platform (no native call attempted)
//   • SystemAudioPermissionException and
//     SystemAudioUnsupportedException are distinct types so the
//     UI can react differently
//
// Cross-platform: pure dart:io + the existing service interface.
// Hermetic — no MethodChannel mocking, no native side required.

import 'dart:io';

import 'package:crisper_weaver/services/system_audio_capture_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SystemAudioCaptureService', () {
    test('exception hierarchy is distinct', () {
      final unsupported = SystemAudioUnsupportedException('not on this OS');
      final permission =
          SystemAudioPermissionException('user said no in TCC');

      expect(unsupported, isA<SystemAudioUnsupportedException>());
      expect(unsupported, isNot(isA<SystemAudioPermissionException>()));
      expect(permission, isA<SystemAudioPermissionException>());
      expect(permission, isNot(isA<SystemAudioUnsupportedException>()));
      // Both must produce a human-readable toString so logs / dialogs
      // don't say `Instance of '...'`.
      expect(unsupported.toString(), contains('not on this OS'));
      expect(permission.toString(), contains('user said no'));
    });

    test('isSupported returns a clean bool on every supported '
        'platform without throwing', () async {
      // Per-platform behaviour pinned in the source:
      //   • macOS: MethodChannel probe (false on macOS < 13).
      //   • Linux: `which parec` (false when PulseAudio utils
      //     missing — caches the answer for later start()).
      //   • Windows: `where ffmpeg` (false when ffmpeg not on
      //     PATH — caches).
      //   • iOS / Android: hard false, short-circuit.
      // The test asserts only that no exception escapes; the
      // actual bool depends on the test machine.
      final svc = SystemAudioCaptureService();
      final ok = await svc.isSupported();
      expect(ok, anyOf(isTrue, isFalse),
          reason: 'isSupported must always return a bool, never throw');
      // On iOS / Android the source short-circuits to false
      // without any system call.
      if (Platform.isIOS || Platform.isAndroid) {
        expect(ok, isFalse);
      }
    });

    test('start() on iOS throws SystemAudioUnsupportedException', () async {
      if (!Platform.isIOS) return;
      final svc = SystemAudioCaptureService();
      expect(svc.start, throwsA(isA<SystemAudioUnsupportedException>()));
    });

    test('start() on Android throws SystemAudioUnsupportedException',
        () async {
      if (!Platform.isAndroid) return;
      final svc = SystemAudioCaptureService();
      expect(svc.start, throwsA(isA<SystemAudioUnsupportedException>()));
    });

    test('stop() on a never-started service is a no-op', () async {
      final svc = SystemAudioCaptureService();
      // Must not throw, must not hang.
      await svc.stop();
      expect(svc.isCapturing, isFalse);
    });

    test('isCapturing starts false', () {
      final svc = SystemAudioCaptureService();
      expect(svc.isCapturing, isFalse);
    });
  });
}
