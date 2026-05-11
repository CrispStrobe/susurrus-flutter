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

    test('isSupported returns false on non-macOS platforms without '
        'invoking a MethodChannel', () async {
      // We can't easily fake `Platform.isMacOS` from a test, but if
      // we ARE on macOS the native side may not be registered in the
      // test harness — accept either outcome with the rationale that
      // the platform branch in the source is what we're pinning.
      final svc = SystemAudioCaptureService();
      final ok = await svc.isSupported();
      if (!Platform.isMacOS) {
        expect(ok, isFalse,
            reason: 'non-macOS platforms must short-circuit '
                'before calling the MethodChannel');
      } else {
        // macOS: result depends on macOS version + whether the
        // harness loaded our SystemAudioCapture.swift handler.
        // Accept either bool; pin only that no exception escapes.
        expect(ok, anyOf(isTrue, isFalse));
      }
    });

    test('start() throws SystemAudioUnsupportedException on non-macOS',
        () async {
      if (Platform.isMacOS) {
        // Skip on macOS — the native side might actually be
        // wired here and a real Start would prompt for Screen
        // Recording permission, which we don't want from a test.
        return;
      }
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
