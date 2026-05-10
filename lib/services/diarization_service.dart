import 'dart:io';

import 'package:crispasr/crispasr.dart' as crispasr;
import 'package:path/path.dart' as p;

import '../engines/transcription_engine.dart';
import 'audio_service.dart';
import 'log_service.dart';
import 'model_service.dart';

/// Speaker diarization via CrispASR 0.4.5+ shared-lib `diarizeSegments`.
///
/// Four methods are available upstream (energy / xcorr / vad-turns /
/// pyannote). We default to `vadTurns` because it's mono-friendly, needs
/// no extra model file, and returns a stable alternating-speaker
/// labelling on typical conversational audio. The pyannote path (GGUF-
/// based ML diarization, up to 3 speakers) is available when callers
/// ship the pyannote-v3-seg.gguf and pass `method:
/// DiarizeMethod.pyannote`; that wiring is deferred behind a model-
/// manager flow.
///
/// This replaces a ~474 LOC MFCC + k-means stopgap that predated the
/// upstream C-ABI. The shared-lib call runs in one FFI hop and matches
/// exactly what `crispasr --diarize --diarize-method vad-turns`
/// produces on the CLI.
class DiarizationService {
  /// Optional ModelService — used to auto-locate the pyannote-v3-seg
  /// GGUF when the user picks `DiarizeMethod.pyannote` and a model path
  /// isn't supplied explicitly. Null in tests / fixtures.
  final ModelService? modelService;

  DiarizationService({this.modelService});

  /// Locate the pyannote-v3-seg GGUF on disk so the caller doesn't have
  /// to know its exact name. Returns null if no matching file is found.
  Future<String?> _findPyannoteModel() async {
    final svc = modelService;
    if (svc == null) return null;
    try {
      final dir = Directory(svc.whisperCppDir());
      if (!await dir.exists()) return null;
      await for (final ent in dir.list()) {
        if (ent is! File) continue;
        final base = p.basename(ent.path).toLowerCase();
        if (base.startsWith('pyannote') && base.endsWith('.gguf')) {
          return ent.path;
        }
      }
    } catch (e, st) {
      Log.instance.w('diarize', 'failed to locate pyannote GGUF',
          error: e, stack: st);
    }
    return null;
  }

  /// Fill `seg.speaker` for every segment using the shared-lib diarizer.
  ///
  /// `audioData.samples` is treated as mono 16 kHz float PCM. We don't
  /// have per-channel access in CrisperWeaver today, so the stereo-only
  /// methods (energy / xcorr) aren't selectable here; passing them
  /// would produce no-op labels.
  ///
  /// `minSpeakers` / `maxSpeakers` are accepted for API compatibility
  /// with older callers but currently ignored — the lib methods pick
  /// speaker counts internally (vad-turns alternates 0/1; pyannote can
  /// emit up to 3).
  Future<List<TranscriptionSegment>> diarizeSegments(
    AudioData audioData,
    List<TranscriptionSegment> segments, {
    int? minSpeakers,
    int? maxSpeakers,
    crispasr.DiarizeMethod method = crispasr.DiarizeMethod.vadTurns,
    String? pyannoteModelPath,
    void Function(double progress)? onProgress,
  }) async {
    if (segments.isEmpty) return segments;

    onProgress?.call(0.0);

    final libSegs = segments
        .map((s) => crispasr.DiarizeSegment(t0: s.startTime, t1: s.endTime))
        .toList();

    onProgress?.call(0.2);

    // Resolve a pyannote GGUF path if the user picked the pyannote
    // method but didn't supply a model path explicitly. Falls back to
    // whatever the caller passed in.
    String? resolvedPyannotePath = pyannoteModelPath;
    if (method == crispasr.DiarizeMethod.pyannote &&
        (resolvedPyannotePath == null || resolvedPyannotePath.isEmpty)) {
      resolvedPyannotePath = await _findPyannoteModel();
      if (resolvedPyannotePath == null) {
        Log.instance.w(
            'diarize',
            'pyannote method requested but pyannote-*.gguf not on disk — '
                'falling back to vad-turns');
        method = crispasr.DiarizeMethod.vadTurns;
      }
    }

    try {
      final ok = crispasr.diarizeSegments(
        segs: libSegs,
        left: audioData.samples,
        isStereo: false,
        method: method,
        pyannoteModelPath: resolvedPyannotePath,
      );
      if (!ok) {
        Log.instance.w('diarize',
            'crispasr.diarizeSegments returned false — leaving speakers unassigned');
        return segments;
      }
    } catch (e, st) {
      Log.instance.e('diarize', 'diarizeSegments threw', error: e, stack: st);
      return segments;
    }

    onProgress?.call(0.9);

    final out = <TranscriptionSegment>[];
    for (var i = 0; i < segments.length; i++) {
      final spk = libSegs[i].speaker;
      final label = spk >= 0 ? 'Speaker ${spk + 1}' : segments[i].speaker;
      out.add(TranscriptionSegment(
        text: segments[i].text,
        startTime: segments[i].startTime,
        endTime: segments[i].endTime,
        speaker: label,
        confidence: segments[i].confidence,
        words: segments[i].words,
        metadata: segments[i].metadata,
      ));
    }

    onProgress?.call(1.0);
    Log.instance.i('diarize', 'diarizeSegments done', fields: {
      'method': method.name,
      'segments': out.length,
      'speakers_seen':
          libSegs.map((s) => s.speaker).where((s) => s >= 0).toSet().length,
    });
    return out;
  }
}
