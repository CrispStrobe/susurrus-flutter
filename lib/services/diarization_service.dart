import 'dart:io';
import 'dart:typed_data';

import 'package:crispasr/crispasr.dart' as crispasr;
import 'package:path/path.dart' as p;

import '../engines/transcription_engine.dart';
import 'audio_service.dart';
import 'log_service.dart';
import 'model_service.dart';
import 'speaker_id_service.dart';

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

  /// §5.8.1 — Optional SpeakerIdService for the post-diarisation TitaNet
  /// match pass that resolves cluster labels to enrolled names. Null in
  /// tests / when speaker ID is unavailable.
  final SpeakerIdService? speakerIdService;

  DiarizationService({this.modelService, this.speakerIdService});

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
    bool enableSpeakerRecognition = false,
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

    onProgress?.call(0.85);

    // §5.8.1 — Optional speaker-recognition pass. Resolve numeric
    // cluster labels to enrolled names via TitaNet when the caller
    // opted in and the prerequisites are met. One match per unique
    // cluster — embeddings are roughly stable per speaker.
    Map<int, String>? clusterToName;
    if (enableSpeakerRecognition && speakerIdService != null) {
      try {
        clusterToName = await _resolveSpeakerNames(audioData, libSegs);
      } catch (e, st) {
        Log.instance.w(
            'diarize', 'speaker recognition pass failed — keeping numeric labels',
            error: e, stack: st);
      }
    }

    onProgress?.call(0.95);

    final out = <TranscriptionSegment>[];
    for (var i = 0; i < segments.length; i++) {
      final spk = libSegs[i].speaker;
      final String? label;
      if (spk < 0) {
        label = segments[i].speaker;
      } else {
        label = clusterToName?[spk] ?? 'Speaker ${spk + 1}';
      }
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
      'speakers_resolved': clusterToName?.length ?? 0,
    });
    return out;
  }

  /// For every unique numeric speaker label, find the longest segment
  /// tagged with it, extract a representative ~3 s PCM slice from its
  /// middle, run the TitaNet matcher once, and build the cluster → name
  /// map. Returns an empty map when speaker ID isn't available
  /// (e.g. TitaNet not downloaded, no enrolled profiles) — callers
  /// just fall back to numeric labels.
  Future<Map<int, String>> _resolveSpeakerNames(
    AudioData audioData,
    List<crispasr.DiarizeSegment> libSegs,
  ) async {
    final svc = speakerIdService;
    if (svc == null) return const {};
    if (!await svc.isAvailable) {
      Log.instance.d('diarize',
          'speaker recognition requested but TitaNet not available — skipping');
      return const {};
    }
    // Longest-segment-per-cluster pick. The longest contiguous chunk
    // gives the most stable embedding (TitaNet was trained on >=3 s
    // utterances).
    final longestPerCluster = <int, int>{}; // speaker → segment index
    for (var i = 0; i < libSegs.length; i++) {
      final spk = libSegs[i].speaker;
      if (spk < 0) continue;
      final cur = longestPerCluster[spk];
      if (cur == null) {
        longestPerCluster[spk] = i;
        continue;
      }
      final curDur = libSegs[cur].t1 - libSegs[cur].t0;
      final candDur = libSegs[i].t1 - libSegs[i].t0;
      if (candDur > curDur) longestPerCluster[spk] = i;
    }

    if (longestPerCluster.isEmpty) return const {};

    final samples = audioData.samples;
    const sampleRate = 16000;
    const targetSeconds = 3.0;

    final out = <int, String>{};
    for (final entry in longestPerCluster.entries) {
      final spk = entry.key;
      final seg = libSegs[entry.value];
      final pcm = _slicePcm(samples, sampleRate, seg.t0, seg.t1, targetSeconds);
      if (pcm.isEmpty) continue;
      try {
        final (name, score) = await svc.matchSegment(pcm);
        if (name != null) {
          out[spk] = name;
          Log.instance.d('diarize', 'resolved speaker cluster', fields: {
            'cluster': spk,
            'name': name,
            'score': score.toStringAsFixed(3),
          });
        }
      } catch (e, st) {
        Log.instance
            .w('diarize', 'matchSegment failed for cluster $spk',
                error: e, stack: st);
      }
    }
    return out;
  }

  /// Carve a [targetSeconds]-long centred slice out of [samples] for
  /// the half-open time window `[t0, t1)`. Falls back to the full
  /// available slice when the segment is shorter than the target.
  Float32List _slicePcm(
    Float32List samples,
    int sampleRate,
    double t0,
    double t1,
    double targetSeconds,
  ) {
    final segStart = (t0 * sampleRate).round().clamp(0, samples.length);
    final segEnd = (t1 * sampleRate).round().clamp(segStart, samples.length);
    final segLen = segEnd - segStart;
    if (segLen <= 0) return Float32List(0);
    final targetLen = (targetSeconds * sampleRate).round();
    if (segLen <= targetLen) {
      return Float32List.fromList(samples.sublist(segStart, segEnd));
    }
    final pad = ((segLen - targetLen) / 2).floor();
    final start = segStart + pad;
    final end = start + targetLen;
    return Float32List.fromList(samples.sublist(start, end));
  }
}
