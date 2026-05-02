import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crispasr/crispasr.dart' as crispasr;

import 'transcription_engine.dart';
import '../services/aligner_service.dart';
import '../services/lid_service.dart';
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
  crispasr.CrispasrSession? _session;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _cancelRequested = false;
  String? _currentModelId;
  String? _currentModelPath;
  Map<String, dynamic> _config = {};
  ModelService? _modelService;
  final AlignerService _alignerService = AlignerService();
  LidService? _lidService;

  @override
  String get engineId => 'crispasr';

  @override
  String get engineName => 'CrispASR (ggml)';

  @override
  String get version => '0.5.4';

  @override
  bool get supportsStreaming => _model?.supportsStreaming ?? _session != null;

  @override
  bool get supportsLanguageDetection => true;

  @override
  bool get supportsWordTimestamps => true;

  @override
  bool get supportsSpeakerDiarization => false;

  @override
  List<String> get supportedLanguages => const [
        'auto',
        'en',
        'zh',
        'de',
        'es',
        'ru',
        'ko',
        'fr',
        'ja',
        'pt',
        'tr',
        'pl',
        'ca',
        'nl',
        'ar',
        'sv',
        'it',
        'id',
        'hi',
        'fi',
        'vi',
        'he',
        'uk',
        'el',
        'ms',
        'cs',
        'ro',
        'da',
        'hu',
        'ta',
        'no',
        'th',
        'ur',
        'hr',
        'bg',
        'lt',
        'la',
        'mi',
        'ml',
        'cy',
        'sk',
        'te',
        'fa',
        'lv',
        'bn',
        'sr',
        'az',
        'sl',
        'kn',
        'et',
        'mk',
        'br',
        'eu',
        'is',
        'hy',
        'ne',
        'mn',
        'bs',
        'kk',
        'sq',
        'sw',
        'gl',
        'mr',
        'pa',
        'si',
        'km',
        'sn',
        'yo',
        'so',
        'af',
        'oc',
        'ka',
        'be',
        'tg',
        'sd',
        'gu',
        'am',
        'yi',
        'lo',
        'uz',
        'fo',
        'ht',
        'ps',
        'tk',
        'nn',
        'mt',
        'sa',
        'lb',
        'my',
        'bo',
        'tl',
        'mg',
        'as',
        'tt',
        'haw',
        'ln',
        'ha',
        'ba',
        'jw',
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
  Future<bool> initialize(
      {ModelService? modelService, Map<String, dynamic>? config}) async {
    try {
      _config = Map<String, dynamic>.from(config ?? const {});
      _modelService = modelService;
      if (_modelService != null) {
        await _modelService!.initialize();
        _lidService = LidService(_modelService!);
      }
      _isInitialized = true;
      final libName = crispasr.CrispASR.defaultLibName();
      final backends = crispasr.CrispasrSession.availableBackends();
      Log.instance.i('crispasr', 'engine initialised', fields: {
        'lib': libName,
        'backends': backends.join(','),
        'count': backends.length,
      });
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
                'backend': m.backend,
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
    if (_currentModelId == modelId && (_model != null || _session != null)) {
      onProgress?.call(1.0);
      return true;
    }

    final def = _modelService!.lookupDefinition(modelId);
    if (def == null) {
      throw ModelLoadException(
        'Model definition not found for $modelId',
        engineId,
        modelId,
      );
    }

    // Check if the backend is available in the bundled dylib.
    final available = crispasr.CrispasrSession.availableBackends();
    Log.instance.d('crispasr',
        'Available backends in libwhisper: ${available.join(", ")}');
    if (!available.contains(def.backend)) {
      throw ModelLoadException(
        'Model uses the ${def.backend} backend. The bundled libwhisper '
        'was built with {${available.join(", ")}}. Rebuild CrispASR '
        'with the ${def.backend} backend linked in.',
        engineId,
        modelId,
      );
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
    await unloadModel();

    int fileBytes = 0;
    try {
      fileBytes = await File(modelPath).length();
    } catch (_) {}
    final done = Log.instance.stopwatch(
      'crispasr',
      msg: 'model loaded',
      fields: {
        'model': modelId,
        'backend': def.backend,
        'path': modelPath,
        'bytes': fileBytes,
        'quant': def.quantization,
      },
    );
    try {
      Log.instance.d('crispasr', 'loading model', fields: {
        'model': modelId,
        'backend': def.backend,
        'path': modelPath,
        'bytes': fileBytes
      });
      if (def.backend == 'whisper') {
        _model = crispasr.CrispASR(modelPath);
      } else {
        _session =
            crispasr.CrispasrSession.open(modelPath, backend: def.backend);
        // Some backends need a companion file before they can run:
        //   * qwen3-tts → tokenizer GGUF via setCodecPath
        //   * orpheus    → SNAC codec GGUF via setCodecPath
        //   * mimo-asr   → mimo_tokenizer GGUF via setCodecPath
        //   * vibevoice-tts / kokoro → voicepack GGUF via setVoice
        // Walk the def.companions list in order; route by ModelKind so
        // codec entries go through setCodecPath and voice entries go
        // through setVoice. Missing companions fail loudly here rather
        // than at the first transcribe/synthesize call.
        for (final companion in def.companions) {
          final cdef = _modelService!.lookupDefinition(companion);
          if (cdef == null) {
            throw ModelLoadException(
                'Companion "$companion" not found in model catalog '
                '(required by ${def.backend})',
                engineId,
                modelId);
          }
          final cpath =
              await _modelService!.getWhisperCppModelPath(companion);
          if (cpath == null || !await File(cpath).exists()) {
            throw ModelLoadException(
                'Companion "${cdef.displayName}" not downloaded '
                '(required by ${def.backend} — open Models and download it first)',
                engineId,
                modelId);
          }
          if (cdef.kind == ModelKind.codec) {
            _session!.setCodecPath(cpath);
            Log.instance.d('crispasr', 'companion: codec loaded',
                fields: {'backend': def.backend, 'companion': companion});
          } else if (cdef.kind == ModelKind.voice) {
            _session!.setVoice(cpath);
            Log.instance.d('crispasr', 'companion: voice loaded',
                fields: {'backend': def.backend, 'companion': companion});
          }
        }
      }
      _currentModelId = modelId;
      _currentModelPath = modelPath;
      onProgress?.call(1.0);
      done();
      return true;
    } catch (e, st) {
      _model = null;
      _session = null;
      _currentModelId = null;
      _currentModelPath = null;
      done(error: e);
      Log.instance.e('crispasr', 'Model load failed',
          error: e,
          stack: st,
          fields: {
            'model': modelId,
            'backend': def.backend,
            'path': modelPath
          });
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
    _session?.close();
    _session = null;
    _currentModelId = null;
    _currentModelPath = null;
  }

  /// Detect the spoken language of a PCM buffer via CrispASR's
  /// `crispasr_detect_language` helper. Returns null when the loaded dylib
  /// is from the pre-0.2.0 era (or the detection fails internally) — the
  /// caller should treat "null" as "keep whatever language was configured".
  Future<String?> detectLanguage(Float32List audio) async {
    if (_model == null) {
      return null; // Only whisper class supports LID currently
    }
    if (!_model!.supportsExtended) return null;
    final det = _model!.detectLanguage(audio);
    if (!det.ok) {
      Log.instance.w('crispasr',
          'Language detection unavailable (probability=${det.probability})');
      return null;
    }
    Log.instance.i('crispasr',
        'Detected language: ${det.code} (${(det.probability * 100).toStringAsFixed(1)}%)');
    return det.code;
  }

  @override
  Future<TranscriptionResult> transcribe(
    Float32List audioData, {
    String? language,
    bool enableWordTimestamps = false,
    bool enableSpeakerDiarization = false,
    bool translate = false,
    bool beamSearch = false,
    String? initialPrompt,
    bool vad = false,
    String? vadModelPath,
    void Function(TranscriptionSegment segment)? onSegment,
    void Function(double progress)? onProgress,
  }) async {
    if (!_isInitialized) {
      throw const EngineInitializationException(
        'Engine not initialized',
        'crispasr',
      );
    }
    if (_model == null && _session == null) {
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

    final audioSeconds0 = audioData.length / 16000.0;

    // Calculate RMS to see if we have actual signal
    double sumSq = 0.0;
    for (var i = 0; i < audioData.length; i++) {
      sumSq += audioData[i] * audioData[i];
    }
    final rms = sqrt(sumSq / audioData.length);

    Log.instance.i('crispasr', 'transcribe start', fields: {
      'model': _currentModelId,
      'backend': _model != null ? 'whisper' : 'session',
      'samples': audioData.length,
      'audio_s': audioSeconds0.toStringAsFixed(2),
      'rms': rms.toStringAsFixed(6),
      'lang': language ?? 'auto',
      'word_ts': enableWordTimestamps,
      'diarize': enableSpeakerDiarization,
      'translate': translate,
      'beam': beamSearch,
      'prompt_chars': initialPrompt?.length ?? 0,
      'vad': vad,
    });

    try {
      List<TranscriptionSegment> segments;

      if (_model != null) {
        // Whisper-specific path
        final nativeSegments = await _runTranscription(
          audioData,
          language: language,
          wordTimestamps: enableWordTimestamps,
          translate: translate,
          beamSearch: beamSearch,
          initialPrompt: initialPrompt,
          vad: vad,
          vadModelPath: vadModelPath,
        );
        segments = _mapWhisperSegments(
            nativeSegments, enableWordTimestamps, onSegment);
      } else {
        // Unified session path (Parakeet, Canary, etc.)
        final sessionSegments = await _runSessionTranscription(
          audioData,
          language: language,
          vad: vad,
          vadModelPath: vadModelPath,
        );
        segments = _mapSessionSegments(sessionSegments, onSegment);

        // Post-step: if word timestamps were requested and this session
        // backend didn't emit any (qwen3, voxtral, voxtral4b, granite,
        // cohere), run the CTC aligner. `AlignerService` silently no-ops
        // when no aligner GGUF is on disk, so the happy path for
        // parakeet/canary (which already emit word times) is unchanged.
        if (enableWordTimestamps && segments.isNotEmpty) {
          final anyMissing =
              segments.any((s) => s.words == null || s.words!.isEmpty);
          if (anyMissing) {
            segments =
                await _alignerService.addWordTimestamps(segments, audioData);
          }
        }
      }

      onProgress?.call(0.95);
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

      Log.instance.i('crispasr', 'transcribe done', fields: {
        'model': _currentModelId,
        'audio_s': audioSeconds.toStringAsFixed(2),
        'wall_s': wallSeconds.toStringAsFixed(3),
        'rtf': rtf.toStringAsFixed(2),
        'segments': segments.length,
        'words': wordCount,
        'wps': wps.toStringAsFixed(1),
        'avg_conf': averageConfidence?.toStringAsFixed(3) ?? 'n/a',
        'chars': fullText.length,
      });

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
    } catch (e, st) {
      if (e is EngineException) rethrow;
      Log.instance.e('crispasr', 'Transcription failed', error: e, stack: st);
      throw TranscriptionException(
          'CrispASR transcription failed: $e', engineId, e);
    } finally {
      _isProcessing = false;
    }
  }

  Future<List<crispasr.Segment>> _runTranscription(
    Float32List pcm, {
    String? language,
    bool wordTimestamps = false,
    bool translate = false,
    bool beamSearch = false,
    String? initialPrompt,
    bool vad = false,
    String? vadModelPath,
  }) async {
    // Keep FFI call off the UI thread where possible. `Isolate.run` requires
    // sending the model handle across isolates which FFI can't do, so we
    // instead yield briefly to pump the event loop before the blocking call.
    await Future<void>.delayed(Duration.zero);
    // NOTE: whisper.cpp's `params.detect_language = true` is a detect-ONLY
    // mode — it returns as soon as the language is identified and never
    // runs transcription. For auto-detect we just leave `language = null`;
    // whisper then transcribes in auto-language mode, picking up the
    // detected language internally on the first window.
    final prompt = (initialPrompt == null || initialPrompt.trim().isEmpty)
        ? null
        : initialPrompt.trim();
    final useVad = vad && vadModelPath != null && vadModelPath.isNotEmpty;
    return _model!.transcribePcm(
      pcm,
      options: crispasr.TranscribeOptions(
        language: (language == null || language == 'auto') ? null : language,
        detectLanguage: false,
        wordTimestamps: wordTimestamps,
        silent: false,
        translate: translate,
        strategy: beamSearch ? 1 : 0, // 0 = greedy, 1 = beam search
        initialPrompt: prompt,
        vad: useVad,
        vadModelPath: useVad ? vadModelPath : null,
      ),
    );
  }

  Future<List<crispasr.SessionSegment>> _runSessionTranscription(
    Float32List pcm, {
    String? language,
    bool vad = false,
    String? vadModelPath,
  }) async {
    // Yield once so the FFI call doesn't block the current microtask batch
    // in the UI thread (same pattern as `_runTranscription`).
    await Future<void>.delayed(Duration.zero);

    // Language resolution:
    //  * user picked a concrete ISO code ("en", "de", ...) → pass through
    //  * user picked "auto" (or left blank) and we have a multilingual
    //    whisper model on disk → run LID, use its result
    //  * otherwise → null, backends fall back to their historical
    //    defaults ("en" for canary/cohere/voxtral/voxtral4b, auto for
    //    parakeet/qwen3, no hint for granite/wav2vec2/ctc)
    String? langHint;
    if (language != null && language.isNotEmpty && language != 'auto') {
      langHint = language;
    } else if (_lidService != null) {
      langHint = await _lidService!.detectIfModelAvailable(pcm);
      if (langHint != null) {
        Log.instance.i('crispasr', 'session path: LID', fields: {
          'detected': langHint,
          'backend': _session?.backend,
        });
      }
    }

    // Non-whisper backends (parakeet, cohere, canary, voxtral, qwen3,
    // granite, wav2vec2, ...) all go through CrispasrSession. When the
    // user has VAD enabled and a Silero model path is available, route
    // through `transcribeVad` — it performs the same Silero-VAD slicing
    // + whisper.cpp-style stitching CrispASR's CLI uses internally. For
    // O(T²) encoders (parakeet/cohere/canary) that's a large win because
    // silence between utterances no longer multiplies encoder cost, and
    // one stitched call preserves cross-segment decoder context.
    final useVad = vad && vadModelPath != null && vadModelPath.isNotEmpty;
    if (useVad) {
      Log.instance.d('crispasr', 'session path: transcribeVad', fields: {
        'backend': _session?.backend,
        'vad_model': vadModelPath,
        'samples': pcm.length,
        'lang': langHint ?? 'default',
      });
      return _session!.transcribeVad(pcm, vadModelPath, language: langHint);
    }
    return _session!.transcribe(pcm, language: langHint);
  }

  List<TranscriptionSegment> _mapWhisperSegments(
    List<crispasr.Segment> nativeSegments,
    bool enableWordTimestamps,
    void Function(TranscriptionSegment segment)? onSegment,
  ) {
    Log.instance
        .d('crispasr', 'Mapping ${nativeSegments.length} native segments');
    final segments = <TranscriptionSegment>[];
    for (var i = 0; i < nativeSegments.length; i++) {
      if (_cancelRequested) break;
      final s = nativeSegments[i];
      Log.instance.d('crispasr',
          'Native segment $i text: "[${s.text}]" words: ${s.words.length}');
      if (s.text.trim().isEmpty) {
        Log.instance.d('crispasr', 'Segment $i is empty, skipping');
        continue;
      }
      final confidence = (1.0 - s.noSpeechProb).clamp(0.0, 1.0).toDouble();

      // Map CrispASR's per-token `Word` onto the app's `TranscriptionWord`
      // shape. Only populated when `enableWordTimestamps` was requested
      // and the loaded dylib is >= 0.2.0 (empty list otherwise).
      List<TranscriptionWord>? words;
      if (enableWordTimestamps && s.words.isNotEmpty) {
        words = s.words
            .map((w) => TranscriptionWord(
                  word: w.text,
                  startTime: w.start,
                  endTime: w.end,
                  confidence: w.p.clamp(0.0, 1.0).toDouble(),
                ))
            .toList();
      }

      final seg = TranscriptionSegment(
        text: s.text.trim(),
        startTime: s.start,
        endTime: s.end,
        confidence: confidence,
        words: words,
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
    return segments;
  }

  List<TranscriptionSegment> _mapSessionSegments(
    List<crispasr.SessionSegment> sessionSegments,
    void Function(TranscriptionSegment segment)? onSegment,
  ) {
    final segments = <TranscriptionSegment>[];
    for (var i = 0; i < sessionSegments.length; i++) {
      if (_cancelRequested) break;
      final s = sessionSegments[i];

      List<TranscriptionWord>? words;
      if (s.words.isNotEmpty) {
        words = s.words
            .map((w) => TranscriptionWord(
                  word: w.text,
                  startTime: w.start,
                  endTime: w.end,
                  // crispasr 0.5.5+ exposes per-word probability via
                  // crispasr_session_result_word_p; older builds (and
                  // backends that don't compute one) report -1, which
                  // the binding clamps to 1.0 so we render neutrally.
                  confidence: w.p.clamp(0.0, 1.0),
                ))
            .toList();
      }

      // Segment-level confidence is the mean of its words' p when we
      // have them, otherwise 1.0. Lets the segment header badge agree
      // with the per-word colours instead of always showing "100%".
      final segConfidence = (words == null || words.isEmpty)
          ? 1.0
          : words.map((w) => w.confidence).reduce((a, b) => a + b) /
              words.length;

      final seg = TranscriptionSegment(
        text: s.text.trim(),
        startTime: s.start,
        endTime: s.end,
        confidence: segConfidence,
        words: words,
        metadata: {
          'engine': engineId,
          'model': _currentModelId,
          'segmentIndex': i,
          'backend': _session?.backend,
        },
      );
      segments.add(seg);
      onSegment?.call(seg);
    }
    return segments;
  }

  @override
  Stream<TranscriptionSegment>? transcribeStream(
    Stream<Float32List> audioStream, {
    String? language,
    bool enableWordTimestamps = false,
  }) {
    if (_model == null || !_model!.supportsStreaming) return null;

    final session = _model!.openStream(
      language: (language == null || language == 'auto') ? null : language,
      stepMs: 3000,
      lengthMs: 10000,
      keepMs: 200,
      nThreads: 4,
    );
    Log.instance.i('crispasr', 'Streaming session opened');

    final controller = StreamController<TranscriptionSegment>(
      onCancel: () {
        if (!session.isClosed) {
          final last = session.flush();
          if (last != null) {
            Log.instance
                .d('crispasr', 'Stream flush: ${last.text.length} chars');
          }
          session.close();
        }
        Log.instance.i('crispasr', 'Streaming session closed');
      },
    );

    // Subscribe to the incoming PCM, run feed() on the caller's audio
    // thread, and forward each commit as a TranscriptionSegment. We
    // synthesize a synthetic index so downstream UI can tell consecutive
    // commits apart even though the text grows monotonically.
    audioStream.listen(
      (chunk) {
        if (controller.isClosed || session.isClosed) return;
        try {
          final update = session.feed(chunk);
          if (update != null && update.text.isNotEmpty) {
            controller.add(TranscriptionSegment(
              text: update.text.trim(),
              startTime: update.start,
              endTime: update.end,
              confidence: 1.0,
              metadata: {
                'engine': engineId,
                'streaming': true,
                'decodeCounter': update.counter,
              },
            ));
          }
        } catch (e, st) {
          Log.instance.w('crispasr', 'stream.feed failed', error: e, stack: st);
          controller.addError(e, st);
        }
      },
      onDone: () {
        // Drain any final partial before closing.
        try {
          final last = session.flush();
          if (last != null && last.text.isNotEmpty) {
            controller.add(TranscriptionSegment(
              text: last.text.trim(),
              startTime: last.start,
              endTime: last.end,
              confidence: 1.0,
              metadata: {
                'engine': engineId,
                'streaming': true,
                'final': true,
                'decodeCounter': last.counter,
              },
            ));
          }
        } catch (_) {
          // Flush failures at stream end are not worth surfacing.
        }
        session.close();
        controller.close();
      },
      onError: controller.addError,
      cancelOnError: false,
    );

    return controller.stream;
  }

  @override
  Future<void> cancel() async {
    _cancelRequested = true;
  }

  @override
  Future<void> updateConfig(Map<String, dynamic> config) async {
    _config.addAll(config);
  }
}
