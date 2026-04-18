import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../main.dart';
import '../utils/audio_utils.dart';
import 'log_service.dart';

/// Listens for audio files shared *into* the app — via the OS share sheet
/// (Android), "Open In…" from other apps (iOS), drag-and-drop onto the Dock
/// icon (macOS), etc. — and routes the first usable file into
/// [selectedAudioPathProvider] so the transcription screen picks it up.
///
/// iOS requires a separate share-extension target (an Xcode target that the
/// `flutter create` template does not generate automatically) to receive
/// arbitrary files from the share sheet. What we get for free is the
/// document-type-based "Open In…" handoff already declared in Info.plist.
class ShareIntakeService {
  ShareIntakeService(this._ref);
  final Ref _ref;

  StreamSubscription<List<SharedMediaFile>>? _streamSub;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    // `receive_sharing_intent` only implements Android and iOS. Calling it
    // on desktop platforms just throws `MissingPluginException` — skip it
    // and rely on macOS/Linux/Windows document-type handoff instead.
    if (!(Platform.isIOS || Platform.isAndroid)) {
      Log.instance.d('share',
          'Share intake not supported on ${Platform.operatingSystem}; skipping');
      return;
    }

    // Files that arrived while the app was suspended.
    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      _handleBatch(initial);
    } catch (e, st) {
      Log.instance
          .w('share', 'Initial media fetch failed', error: e, stack: st);
    }

    // Files that arrive while the app is running.
    _streamSub = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(_handleBatch, onError: (Object e, StackTrace st) {
      Log.instance.w('share', 'Share stream error', error: e, stack: st);
    });
  }

  void _handleBatch(List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    for (final f in files) {
      final path = f.path;
      if (path.isEmpty) continue;
      if (!AudioUtils.isSupportedAudioFile(path)) {
        Log.instance.d('share', 'Ignoring non-audio share: $path');
        continue;
      }
      if (!File(path).existsSync()) {
        Log.instance.w('share', 'Shared file does not exist: $path');
        continue;
      }
      Log.instance.i('share', 'Ingested shared audio: $path');
      _ref.read(selectedAudioPathProvider.notifier).state = path;
      // Only take the first usable file in a batch — the UI shows a single
      // source at a time.
      return;
    }
  }

  Future<void> dispose() async {
    await _streamSub?.cancel();
    _streamSub = null;
  }
}

/// Riverpod provider: call `.start()` once at app boot.
final shareIntakeServiceProvider = Provider<ShareIntakeService>((ref) {
  final svc = ShareIntakeService(ref);
  ref.onDispose(svc.dispose);
  return svc;
});
