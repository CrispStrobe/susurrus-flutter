// SystemAudioCaptureService — PLAN §5.1.1 system-audio capture.
//
// "Transcribe what's playing in Zoom / YouTube / a podcast app."
// Cross-platform interface; v1 implementation supports macOS only
// (via ScreenCaptureKit, requires macOS 12.3+). Linux / Windows /
// Android implementations are platform-specific TODOs tracked in
// PLAN.md §5.1.1; the Dart side surfaces a clean
// [SystemAudioUnsupportedException] on those for now.
//
// Wire-level protocol with the native side (macOS Swift today):
//
//   MethodChannel `crisperweaver/system_audio_capture` — control:
//     • method `start()` → bool — returns true on success, throws
//       PlatformException with code `'unsupported'`,
//       `'permission_denied'`, or `'os_too_old'` on failure
//     • method `stop()` → null
//     • method `isSupported()` → bool
//
//   EventChannel `crisperweaver/system_audio_capture/stream` —
//     a stream of `Float32List` PCM frames, always 16 kHz mono.
//     Native side handles resampling + mono mix; Dart receives
//     decoder-ready buffers. Native may chunk frames at any size
//     (currently ~25ms = 400 samples).
//
// Cross-platform: the `MethodChannel` boundary is wire-stable; the
// Dart caller treats `start() → Stream<Float32List>` identically
// on every platform. Unsupported platforms (iOS / Linux / Windows
// / Android in v1) throw [SystemAudioUnsupportedException].
//
// Permission model: macOS prompts for Screen Recording permission
// (TCC) on first start() call. If the user declines we get a
// `permission_denied` PlatformException; the caller should
// surface a localized "open System Settings → Privacy → Screen
// Recording" hint. On macOS 11 the SCStream APIs aren't
// available — `os_too_old`.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'log_service.dart';

const MethodChannel _control =
    MethodChannel('crisperweaver/system_audio_capture');
const EventChannel _stream =
    EventChannel('crisperweaver/system_audio_capture/stream');

/// Thrown when system audio capture isn't supported on the active
/// platform. Callers should disable the toggle in the UI.
class SystemAudioUnsupportedException implements Exception {
  SystemAudioUnsupportedException(this.message);
  final String message;
  @override
  String toString() => 'SystemAudioUnsupportedException: $message';
}

/// Thrown when the user has not granted Screen Recording permission
/// (macOS) or the equivalent on other platforms.
class SystemAudioPermissionException implements Exception {
  SystemAudioPermissionException(this.message);
  final String message;
  @override
  String toString() => 'SystemAudioPermissionException: $message';
}

class SystemAudioCaptureService {
  SystemAudioCaptureService();

  StreamSubscription<dynamic>? _activeSub;
  StreamController<Float32List>? _activeController;

  /// Quick capability probe — returns true when the active platform
  /// can capture system audio. UI uses this to enable / disable the
  /// "Capture system audio" toggle without having to attempt a
  /// start() and catch the error.
  ///
  /// Conservative defaults: returns false on platforms we haven't
  /// wired yet, true on macOS where the native side can do a
  /// runtime version probe (returns false on macOS < 12.3).
  Future<bool> isSupported() async {
    if (!Platform.isMacOS) return false;
    try {
      final ok = await _control.invokeMethod<bool>('isSupported') ?? false;
      return ok;
    } catch (e) {
      Log.instance.d('sysaudio', 'isSupported probe failed: $e');
      return false;
    }
  }

  /// Start the capture. Returns a stream of 16 kHz mono Float32List
  /// PCM chunks. Caller listens; calling [stop] closes the stream.
  ///
  /// Throws [SystemAudioUnsupportedException] when the platform
  /// doesn't support it (or when macOS < 12.3 is running), and
  /// [SystemAudioPermissionException] when the user has declined
  /// Screen Recording permission.
  Future<Stream<Float32List>> start() async {
    if (!Platform.isMacOS) {
      throw SystemAudioUnsupportedException(
          'System audio capture is not yet implemented on '
          '${Platform.operatingSystem}. Tracked in PLAN §5.1.1.');
    }
    if (_activeController != null) {
      // Already running — reuse the existing stream. Cheap idempotency.
      return _activeController!.stream;
    }
    try {
      final ok = await _control.invokeMethod<bool>('start') ?? false;
      if (!ok) {
        throw SystemAudioUnsupportedException(
            'native start() returned false — see Console.app for SCStream errors');
      }
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'permission_denied':
          throw SystemAudioPermissionException(
              e.message ?? 'Screen Recording permission denied');
        case 'os_too_old':
          throw SystemAudioUnsupportedException(
              e.message ?? 'macOS 12.3 or later required');
        case 'unsupported':
        default:
          throw SystemAudioUnsupportedException(
              e.message ?? 'native side declined to start');
      }
    }

    final controller = StreamController<Float32List>.broadcast(
      onCancel: () {
        // Last listener gone — keep the native side running until
        // explicit stop() so callers can re-listen without paying
        // the SCStream startup cost twice. Mirrors how
        // AudioRecorder treats stream subscriptions.
      },
    );
    _activeController = controller;

    _activeSub = _stream.receiveBroadcastStream().listen(
      (event) {
        if (event is Uint8List) {
          // Native passes Float32 as a raw byte buffer; reinterpret.
          // `Uint8List.buffer.asFloat32List()` is zero-copy on every
          // platform Flutter ships on.
          final f = event.buffer
              .asFloat32List(event.offsetInBytes, event.length ~/ 4);
          if (controller.isClosed) return;
          controller.add(f);
        } else if (event is Float32List) {
          // Some bridges pre-cast for us; respect either form.
          if (controller.isClosed) return;
          controller.add(event);
        }
      },
      onError: (Object e, StackTrace st) {
        Log.instance.w('sysaudio', 'stream error', error: e, stack: st);
        if (!controller.isClosed) controller.addError(e, st);
      },
      onDone: () {
        if (!controller.isClosed) controller.close();
      },
    );

    Log.instance.i('sysaudio', 'capture started');
    return controller.stream;
  }

  /// Stop the capture cleanly. Idempotent — safe to call when no
  /// capture is active.
  Future<void> stop() async {
    await _activeSub?.cancel();
    _activeSub = null;
    final c = _activeController;
    _activeController = null;
    if (c != null && !c.isClosed) {
      await c.close();
    }
    if (Platform.isMacOS) {
      try {
        await _control.invokeMethod<void>('stop');
      } catch (e) {
        Log.instance.d('sysaudio', 'native stop threw: $e');
      }
    }
    Log.instance.i('sysaudio', 'capture stopped');
  }

  bool get isCapturing => _activeController != null;
}

/// Singleton — survives navigation so a streaming transcription
/// keeps running across screen changes.
final systemAudioCaptureServiceProvider =
    Provider<SystemAudioCaptureService>(
        (ref) => SystemAudioCaptureService());
