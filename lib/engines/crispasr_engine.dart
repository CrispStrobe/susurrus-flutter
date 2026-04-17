import 'dart:io';
import 'dart:typed_data';

import 'package:crispasr/crispasr.dart' as crispasr;

import 'transcription_engine.dart';
import '../services/log_service.dart';
import '../services/model_service.dart';

/// Transcription engine backed by the CrispASR FFI package.
///
/// CrispASR is a ggml-based, pure-Dart FFI bridge to a unified ASR runtime
/// that supports Whisper, Parakeet, Canary, Qwen3-ASR, Voxtral, and
/// FastConformer models. This engine exposes the Whisper-compatible API
/// exported by `package:crispasr` through the app's `TranscriptionEngine`
/// abstraction.
class CrispASREngine implements TranscriptionEngine {
  crispasr.CrispASR? _model;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _cancelRequested = false;
  String? _currentModelId;
  String? _currentModelPath;
  String? _libPath;
  Map<String, dynamic> _config = {};
  ModelService? _modelService;

  @override
  String get engineId => 'crispasr';

  @override
  String get engineName => 'CrispASR (ggml)';

  @override
  String get version => '0.1.0';

  @override
  bool get supportsStreaming => false;

  @override
  bool get supportsLanguageDetection => true;

  @override
  bool get supportsWordTimestamps => true;

  @override
  bool get supportsSpeakerDiarization => false;

  @override
  List<String> get supportedLanguages => const [
        'auto', 'en', 'zh', 'de', 'es', 'ru', 'ko', 'fr', 'ja', 'pt', 'tr',
        'pl', 'ca', 'nl', 'ar', 'sv', 'it', 'id', 'hi', 'fi', 'vi', 'he',
        'uk', 'el', 'ms', 'cs', 'ro', 'da', 'hu', 'ta', 'no', 'th', 'ur',
        'hr', 'bg', 'lt', 'la', 'mi', 'ml', 'cy', 'sk', 'te', 'fa', 'lv',
        'bn', 'sr', 'az', 'sl', 'kn', 'et', 'mk', 'br', 'eu', 'is', 'hy',
        'ne', 'mn', 'bs', 'kk', 'sq', 'sw', 'gl', 'mr', 'pa', 'si', 'km',
        'sn', 'yo', 'so', 'af', 'oc', 'ka', 'be', 'tg', 'sd', 'gu', 'am',
        'yi', 'lo', 'uz', 'fo', 'ht', 'ps', 'tk', 'nn', 'mt', 'sa', 'lb',
        'my', 'bo', 'tl', 'mg', 'as', 'tt', 'haw', 'ln', 'ha', 'ba', 'jw',
        'su',
      ];

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isProcessing => _isProcessing;

  @override
  String? get currentModelId => _currentModelId;

  @override
  Map<String, dynamic> get currentConfig => Map.unmodifiable(_config);

  @override
  Future<bool> initialize({Map<String, dynamic>? config}) async {
    try {
      _config = Map<String, dynamic>.from(config ?? const {});
      _libPath = _config['libPath'] as String? ?? _autoDetectLibPath();
      _modelService = ModelService();
      await _modelService!.initialize();
      _isInitialized = true;
      Log.instance.i('crispasr', 'Initialized (libPath=${_libPath ?? "platform-default"})');
      return true;
    } catch (e, st) {
      Log.instance.e('crispasr', 'Initialize failed', error: e, stack: st);
      throw EngineInitializationException(
        'Failed to initialize CrispASR engine: $e',
        engineId,
        e,
      );
    }
  }

  /// Check a handful of well-known dylib/framework locations so the engine
  /// works out-of-the-box during macOS/Linux dev without the user having to
  /// set `libPath` explicitly.
  String? _autoDetectLibPath() {
    final candidates = <String>[];
    if (Platform.isMacOS) {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      candidates.addAll([
        '$exeDir/../Frameworks/libwhisper.dylib',
        '$exeDir/../Resources/libwhisper.dylib',
        '${Platform.environment['HOME']}/code/CrispASR/build/src/libwhisper.dylib',
        '/usr/local/lib/libwhisper.dylib',
      ]);
    } else if (Platform.isLinux) {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      candidates.addAll([
        // Flutter bundles native libs under `bundle/lib/` next to the binary.
        '$exeDir/lib/libwhisper.so',
        '$exeDir/libwhisper.so',
        '${Platform.environment['HOME']}/code/CrispASR/build/src/libwhisper.so',
        '/usr/local/lib/libwhisper.so',
      ]);
    } else if (Platform.isWindows) {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      candidates.addAll([
        '$exeDir\\whisper.dll',
        '${Platform.environment['USERPROFILE']}\\code\\CrispASR\\build\\src\\whisper.dll',
      ]);
    }
    for (final path in candidates) {
      if (File(path).existsSync()) {
        Log.instance.d('crispasr', 'Found libwhisper at $path');
        return path;
      }
    }
    return null;
  }

  @override
  Future<void> dispose() async {
    await unloadModel();
    _isInitialized = false;
    _isProcessing = false;
    _config.clear();
  }

  @override
  Future<List<EngineModel>> getAvailableModels() async {
    if (!_isInitialized || _modelService == null) {
      throw const EngineInitializationException(
        'Engine not initialized',
        'crispasr',
      );
    }

    final whisperModels = await _modelService!.getWhisperCppModels();
    return whisperModels
        .map((m) => EngineModel(
              id: m.name,
              name: m.displayName,
              description: m.description,
              sizeBytes: m.sizeBytes,
              supportedLanguages: supportedLanguages,
              isDownloaded: m.isDownloaded,
              localPath: m.localPath,
              metadata: {
                'framework': 'crispasr',
                'runtime': 'ggml',
                'backend': 'whisper',
              },
            ))
        .toList();
  }

  @override
  Future<bool> loadModel(
    String modelId, {
    void Function(double progress)? onProgress,
  }) async {
    if (!_isInitialized || _modelService == null) {
      throw const EngineInitializationException(
        'Engine not initialized',
        'crispasr',
      );
    }
    if (_currentModelId == modelId && _model != null) {
      onProgress?.call(1.0);
      return true;
    }

    onProgress?.call(0.05);

    final modelPath = await _modelService!.getWhisperCppModelPath(modelId);
    if (modelPath == null) {
      throw ModelLoadException(
        'Model $modelId is not downloaded yet.',
        engineId,
        modelId,
      );
    }

    if (!await File(modelPath).exists()) {
      throw ModelLoadException(
        'Model file missing on disk: $modelPath',
        engineId,
        modelId,
      );
    }

    onProgress?.call(0.4);

    // Free previous model before loading a new one.
    _model?.dispose();
    _model = null;

    final loadStart = DateTime.now();
    try {
      Log.instance.d('crispasr', 'Loading model $modelId from $modelPath');
      _model = crispasr.CrispASR(modelPath, libPath: _libPath);
      _currentModelId = modelId;
      _currentModelPath = modelPath;
      onProgress?.call(1.0);
      final ms = DateTime.now().difference(loadStart).inMilliseconds;
      Log.instance.i('crispasr', 'Loaded $modelId in ${ms}ms');
      return true;
    } catch (e, st) {
      _model = null;
      _currentModelId = null;
      _currentModelPath = null;
      Log.instance.e('crispasr', 'Model load failed for $modelId', error: e, stack: st);
      throw ModelLoadException(
        'CrispASR failed to load $modelId: $e',
        engineId,
        modelId,
        e,
      );
    }
  }

  @override
  Future<void> unloadModel() async {
    _model?.dispose();
    _model = null;
    _currentModelId = null;
    _currentModelPath = null;
  }

  @override
  Future<TranscriptionResult> transcribe(
    Float32List audioData, {
    String? language,
    bool enableWordTimestamps = false,
    bool enableSpeakerDiarization = false,
    void Function(TranscriptionSegment segment)? onSegment,
    void Function(double progress)? onProgress,
  }) async {
    if (!_isInitialized) {
      throw const EngineInitializationException(
        'Engine not initialized',
        'crispasr',
      );
    }
    if (_model == null) {
      throw const ModelLoadException(
        'No model loaded — call loadModel() first',
        'crispasr',
        'none',
      );
    }
    if (audioData.isEmpty) {
      throw const TranscriptionException(
        'Empty audio data',
        'crispasr',
      );
    }

    _isProcessing = true;
    _cancelRequested = false;
    final started = DateTime.now();
    onProgress?.call(0.05);

    try {
      // CrispASR native call is synchronous and CPU-bound. Running it directly
      // blocks the UI thread; for a better UX use `Isolate.run` when available.
      final nativeSegments = await _runTranscription(audioData);
      onProgress?.call(0.9);

      final segments = <TranscriptionSegment>[];
      for (var i = 0; i < nativeSegments.length; i++) {
        if (_cancelRequested) break;
        final s = nativeSegments[i];
        final confidence = (1.0 - s.noSpeechProb).clamp(0.0, 1.0).toDouble();
        final seg = TranscriptionSegment(
          text: s.text.trim(),
          startTime: s.start,
          endTime: s.end,
          confidence: confidence,
          metadata: {
            'engine': engineId,
            'model': _currentModelId,
            'segmentIndex': i,
            'noSpeechProb': s.noSpeechProb,
          },
        );
        segments.add(seg);
        onSegment?.call(seg);
      }

      onProgress?.call(1.0);

      final fullText = segments.map((s) => s.text).join(' ').trim();
      final averageConfidence = segments.isEmpty
          ? null
          : segments.map((s) => s.confidence).reduce((a, b) => a + b) /
              segments.length;

      final elapsed = DateTime.now().difference(started);
      final audioSeconds = audioData.length / 16000.0;
      final wallSeconds =
          elapsed.inMicroseconds / Duration.microsecondsPerSecond;
      final rtf = wallSeconds > 0 ? audioSeconds / wallSeconds : 0.0;
      final wordCount = fullText.isEmpty
          ? 0
          : fullText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      final wps = wallSeconds > 0 ? wordCount / wallSeconds : 0.0;

      Log.instance.i(
        'crispasr',
        'Transcribed ${audioSeconds.toStringAsFixed(1)}s of audio in '
        '${wallSeconds.toStringAsFixed(2)}s → RTF ${rtf.toStringAsFixed(2)}× '
        '/ $wordCount words / ${wps.toStringAsFixed(1)} wps',
      );

      return TranscriptionResult(
        fullText: fullText,
        segments: segments,
        processingTime: elapsed,
        detectedLanguage: language ?? 'auto',
        confidence: averageConfidence,
        metadata: {
          'engine': engineId,
          'model': _currentModelId,
          'modelPath': _currentModelPath,
          'audioSamples': audioData.length,
          'sampleRate': 16000,
          'audioSeconds': audioSeconds,
          'wallSeconds': wallSeconds,
          'rtf': rtf,
          'wordCount': wordCount,
          'wordsPerSecond': wps,
        },
      );
    } catch (e) {
      if (e is EngineException) rethrow;
      throw TranscriptionException('CrispASR transcription failed: $e', engineId, e);
    } finally {
      _isProcessing = false;
    }
  }

  Future<List<crispasr.Segment>> _runTranscription(Float32List pcm) async {
    // Keep FFI call off the UI thread where possible. `Isolate.run` requires
    // sending the model handle across isolates which FFI can't do, so we
    // instead yield briefly to pump the event loop before the blocking call.
    await Future<void>.delayed(Duration.zero);
    return _model!.transcribePcm(pcm);
  }

  @override
  Stream<TranscriptionSegment>? transcribeStream(
    Stream<Float32List> audioStream, {
    String? language,
    bool enableWordTimestamps = false,
  }) {
    return null;
  }

  @override
  Future<void> cancel() async {
    _cancelRequested = true;
  }

  @override
  Future<void> updateConfig(Map<String, dynamic> config) async {
    _config.addAll(config);
    if (config.containsKey('libPath')) {
      _libPath = config['libPath'] as String?;
    }
  }
}
