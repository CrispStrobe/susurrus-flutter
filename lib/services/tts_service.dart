import 'dart:io';
import 'dart:typed_data';

import 'package:crispasr/crispasr.dart' as crispasr;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../main.dart' show modelServiceProvider;
import 'log_service.dart';
import 'model_service.dart';

/// Synthesised audio plus the sample rate the backend declares (kokoro:
/// 24 kHz, vibevoice: 24 kHz, qwen3-tts: 24 kHz, orpheus: 24 kHz).
class SynthesizedAudio {
  final Float32List samples;
  final int sampleRate;
  const SynthesizedAudio({required this.samples, required this.sampleRate});

  double get durationSeconds => samples.length / sampleRate;
}

/// Wraps `CrispasrSession` for the TTS backends (kokoro, vibevoice-tts,
/// qwen3-tts, orpheus). One session per (model, voice/codec) tuple is
/// cached and reused across synth calls — opening these models is the
/// slow part (mmap + first prefill); per-utterance synth is much cheaper.
///
/// Caller responsibilities:
/// * supply `modelDef` for a downloaded TTS GGUF (kind == ModelKind.tts);
/// * supply `voiceDef` for the matching voicepack (kokoro / vibevoice);
/// * supply `codecDef` for the matching codec/tokenizer (qwen3-tts /
///   orpheus). For kokoro / vibevoice the codec is None.
class TtsService {
  final ModelService modelService;
  TtsService(this.modelService);

  // Cached session keyed by `<modelPath>|<voicePath>|<codecPath>` so
  // changing voice mid-session reopens.
  String? _key;
  crispasr.CrispasrSession? _session;
  String? _backend;

  String _makeKey(String? m, String? v, String? c) =>
      '${m ?? ""}|${v ?? ""}|${c ?? ""}';

  Future<String?> _resolvePath(String modelName) async {
    final p = await modelService.getWhisperCppModelPath(modelName);
    if (p == null) return null;
    return await File(p).exists() ? p : null;
  }

  /// Prepare a session for the given combination, opening the model if
  /// needed. Returns the resolved on-disk paths so the UI can surface
  /// "needs download" hints when something is missing.
  Future<TtsLoadStatus> prepare({
    required String modelName,
    String? voiceName,
    String? codecName,
  }) async {
    final modelPath = await _resolvePath(modelName);
    if (modelPath == null) {
      return TtsLoadStatus.missing(modelName: modelName);
    }
    final voicePath = voiceName == null ? null : await _resolvePath(voiceName);
    if (voiceName != null && voicePath == null) {
      return TtsLoadStatus.missing(voiceName: voiceName);
    }
    final codecPath = codecName == null ? null : await _resolvePath(codecName);
    if (codecName != null && codecPath == null) {
      return TtsLoadStatus.missing(codecName: codecName);
    }

    final key = _makeKey(modelPath, voicePath, codecPath);
    if (_session != null && _key == key) {
      return TtsLoadStatus.ready(_backend!);
    }

    // Reopen.
    _session?.close();
    _session = null;
    _key = null;
    _backend = null;

    try {
      final s = crispasr.CrispasrSession.open(modelPath);
      if (codecPath != null) s.setCodecPath(codecPath);
      if (voicePath != null) s.setVoice(voicePath);
      _session = s;
      _key = key;
      _backend = s.backend;
      Log.instance.i('tts', 'session opened', fields: {
        'model': p.basename(modelPath),
        'voice': voicePath == null ? '' : p.basename(voicePath),
        'codec': codecPath == null ? '' : p.basename(codecPath),
        'backend': _backend,
      });
      return TtsLoadStatus.ready(_backend!);
    } catch (e, st) {
      Log.instance.e('tts', 'session open failed', error: e, stack: st);
      return TtsLoadStatus.error(e.toString());
    }
  }

  /// Synthesise [text] using the currently-prepared session.
  Future<SynthesizedAudio?> synthesize(String text) async {
    final session = _session;
    if (session == null || text.trim().isEmpty) return null;
    try {
      final pcm = session.synthesize(text);
      // CrispASR's TTS backends all output 24 kHz mono float32.
      Log.instance.i('tts', 'synth done', fields: {
        'samples': pcm.length,
        'seconds': (pcm.length / 24000.0).toStringAsFixed(2),
        'backend': _backend,
      });
      return SynthesizedAudio(samples: pcm, sampleRate: 24000);
    } catch (e, st) {
      Log.instance.e('tts', 'synth failed', error: e, stack: st);
      return null;
    }
  }

  /// Write the synthesised PCM as a 16-bit WAV to a temp file. Returns
  /// the file path so the caller can hand it to the share sheet / save
  /// dialog.
  Future<File> writeWav(SynthesizedAudio audio, {String? basename}) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final name = basename ?? 'crisperweaver-synth-$stamp.wav';
    final out = File(p.join(dir.path, name));
    final bytes = _floatPcmToWavBytes(audio.samples, audio.sampleRate);
    await out.writeAsBytes(bytes, flush: true);
    return out;
  }

  void dispose() {
    _session?.close();
    _session = null;
    _key = null;
    _backend = null;
  }

  // 16-bit PCM WAV header + body. Mono. Float input is clamped to
  // [-1, 1] then scaled to int16. Cheap enough that we don't need a
  // dedicated audio-encoding dep.
  Uint8List _floatPcmToWavBytes(Float32List samples, int sampleRate) {
    final dataBytes = samples.length * 2; // int16 mono
    final fileBytes = 44 + dataBytes;
    final out = Uint8List(fileBytes);
    final bd = ByteData.view(out.buffer);

    // RIFF
    out.setRange(0, 4, 'RIFF'.codeUnits);
    bd.setUint32(4, fileBytes - 8, Endian.little);
    out.setRange(8, 12, 'WAVE'.codeUnits);
    // fmt
    out.setRange(12, 16, 'fmt '.codeUnits);
    bd.setUint32(16, 16, Endian.little); // chunk size
    bd.setUint16(20, 1, Endian.little); // PCM format
    bd.setUint16(22, 1, Endian.little); // mono
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    bd.setUint16(32, 2, Endian.little); // block align
    bd.setUint16(34, 16, Endian.little); // bits per sample
    // data
    out.setRange(36, 40, 'data'.codeUnits);
    bd.setUint32(40, dataBytes, Endian.little);

    var off = 44;
    for (var i = 0; i < samples.length; i++) {
      var s = samples[i];
      if (s > 1.0) s = 1.0;
      if (s < -1.0) s = -1.0;
      bd.setInt16(off, (s * 32767).round(), Endian.little);
      off += 2;
    }
    return out;
  }
}

class TtsLoadStatus {
  final bool ready;
  final String? backend;

  /// When non-null, the user needs to download this model name first.
  final String? missingModelName;

  /// When non-null, the user needs to download this voicepack first.
  final String? missingVoiceName;

  /// When non-null, the user needs to download this codec/tokenizer first.
  final String? missingCodecName;
  final String? errorMessage;

  const TtsLoadStatus._({
    required this.ready,
    this.backend,
    this.missingModelName,
    this.missingVoiceName,
    this.missingCodecName,
    this.errorMessage,
  });

  factory TtsLoadStatus.ready(String backend) =>
      TtsLoadStatus._(ready: true, backend: backend);
  factory TtsLoadStatus.missing(
          {String? modelName, String? voiceName, String? codecName}) =>
      TtsLoadStatus._(
        ready: false,
        missingModelName: modelName,
        missingVoiceName: voiceName,
        missingCodecName: codecName,
      );
  factory TtsLoadStatus.error(String msg) =>
      TtsLoadStatus._(ready: false, errorMessage: msg);
}

final ttsServiceProvider = Provider<TtsService>((ref) {
  final svc = TtsService(ref.watch(modelServiceProvider));
  ref.onDispose(svc.dispose);
  return svc;
});
