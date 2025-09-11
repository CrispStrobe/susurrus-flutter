import 'dart:typed_data';
import 'dart:io';

import 'transcription_engine.dart';
import '../native/whisper_bindings.dart';

/// Whisper.cpp based transcription engine
class WhisperCppEngine implements TranscriptionEngine {
  WhisperTranscriber? _transcriber;
  bool _isInitialized = false;
  bool _isProcessing = false;
  String? _currentModelId;
  Map<String, dynamic> _config = {};

  @override
  String get engineId => 'whisper_cpp';

  @override
  String get engineName => 'Whisper.cpp';

  @override
  String get version => '1.5.4'; // Current whisper.cpp version

  @override
  bool get supportsStreaming => false; // Current limitation

  @override
  bool get supportsLanguageDetection => true;

  @override
  bool get supportsWordTimestamps => true;

  @override
  bool get supportsSpeakerDiarization => false; // Handled separately

  @override
  List<String> get supportedLanguages => [
    'auto', 'en', 'zh', 'de', 'es', 'ru', 'ko', 'fr', 'ja', 'pt', 'tr', 'pl',
    'ca', 'nl', 'ar', 'sv', 'it', 'id', 'hi', 'fi', 'vi', 'he', 'uk', 'el',
    'ms', 'cs', 'ro', 'da', 'hu', 'ta', 'no', 'th', 'ur', 'hr', 'bg', 'lt',
    'la', 'mi', 'ml', 'cy', 'sk', 'te', 'fa', 'lv', 'bn', 'sr', 'az', 'sl',
    'kn', 'et', 'mk', 'br', 'eu', 'is', 'hy', 'ne', 'mn', 'bs', 'kk', 'sq',
    'sw', 'gl', 'mr', 'pa', 'si', 'km', 'sn', 'yo', 'so', 'af', 'oc', 'ka',
    'be', 'tg', 'sd', 'gu', 'am', 'yi', 'lo', 'uz', 'fo', 'ht', 'ps', 'tk',
    'nn', 'mt', 'sa', 'lb', 'my', 'bo', 'tl', 'mg', 'as', 'tt', 'haw', 'ln',
    'ha', 'ba', 'jw', 'su'
  ];

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isProcessing => _isProcessing;

  @override
  String? get currentModelId => _currentModelId;

  @override
  Map<String, dynamic> get currentConfig => Map.from(_config);

  @override
  Future<bool> initialize({Map<String, dynamic>? config}) async {
    try {
      _config = config ?? {};
      _transcriber = WhisperTranscriber();
      _isInitialized = true;
      return true;
    } catch (e) {
      throw EngineInitializationException(
        'Failed to initialize Whisper.cpp engine: $e',
        engineId,
        e,
      );
    }
  }

  @override
  Future<void> dispose() async {
    _transcriber?.dispose();
    _transcriber = null;
    _isInitialized = false;
    _isProcessing = false;
    _currentModelId = null;
    _config.clear();
  }

  @override
  Future<List<EngineModel>> getAvailableModels() async {
    return [
      const EngineModel(
        id: 'whisper-tiny',
        name: 'Whisper Tiny',
        description: 'Fastest model, lower accuracy',
        sizeBytes: 39 * 1024 * 1024,
        supportedLanguages: ['auto', 'en', 'zh', 'de', 'es', 'ru', 'ko', 'fr', 'ja', 'pt'],
      ),
      const EngineModel(
        id: 'whisper-base',
        name: 'Whisper Base',
        description: 'Balanced speed and accuracy',
        sizeBytes: 74 * 1024 * 1024,
        supportedLanguages: ['auto', 'en', 'zh', 'de', 'es', 'ru', 'ko', 'fr', 'ja', 'pt'],
      ),
      const EngineModel(
        id: 'whisper-small',
        name: 'Whisper Small',
        description: 'Good accuracy, moderate speed',
        sizeBytes: 244 * 1024 * 1024,
        supportedLanguages: ['auto', 'en', 'zh', 'de', 'es', 'ru', 'ko', 'fr', 'ja', 'pt'],
      ),
      const EngineModel(
        id: 'whisper-medium',
        name: 'Whisper Medium',
        description: 'High accuracy, slower processing',
        sizeBytes: 769 * 1024 * 1024,
        supportedLanguages: ['auto', 'en', 'zh', 'de', 'es', 'ru', 'ko', 'fr', 'ja', 'pt'],
      ),
      const EngineModel(
        id: 'whisper-large-v3',
        name: 'Whisper Large v3',
        description: 'Best accuracy, slowest processing',
        sizeBytes: 1550 * 1024 * 1024,
        supportedLanguages: ['auto', 'en', 'zh', 'de', 'es', 'ru', 'ko', 'fr', 'ja', 'pt'],
      ),
    ];
  }

  @override
  Future<bool> loadModel(String modelId, {Function(double progress)? onProgress}) async {
    if (!_isInitialized || _transcriber == null) {
      throw EngineInitializationException(
        'Engine not initialized',
        engineId,
      );
    }

    try {
      // TODO: Implement actual model path resolution
      final modelPath = await _resolveModelPath(modelId);
      if (modelPath == null) {
        throw ModelLoadException(
          'Model not found: $modelId',
          engineId,
          modelId,
        );
      }

      onProgress?.call(0.1);
      
      // Load model using native bindings
      final success = await _transcriber!.loadModel(modelPath);
      
      onProgress?.call(1.0);
      
      if (success) {
        _currentModelId = modelId;
        return true;
      } else {
        throw ModelLoadException(
          'Failed to load model: $modelId',
          engineId,
          modelId,
        );
      }
    } catch (e) {
      if (e is EngineException) rethrow;
      throw ModelLoadException(
        'Error loading model $modelId: $e',
        engineId,
        modelId,
        e,
      );
    }
  }

  @override
  Future<void> unloadModel() async {
    _transcriber?.dispose();
    _currentModelId = null;
  }

  @override
  Future<TranscriptionResult> transcribe(
    Float32List audioData, {
    String? language,
    bool enableWordTimestamps = false,
    bool enableSpeakerDiarization = false,
    Function(TranscriptionSegment segment)? onSegment,
    Function(double progress)? onProgress,
  }) async {
    if (!_isInitialized || _transcriber == null) {
      throw EngineInitializationException(
        'Engine not initialized',
        engineId,
      );
    }

    if (_currentModelId == null) {
      throw ModelLoadException(
        'No model loaded',
        engineId,
        'none',
      );
    }

    _isProcessing = true;
    final startTime = DateTime.now();

    try {
      onProgress?.call(0.1);

      // Call native transcription
      final nativeSegments = await _transcriber!.transcribe(audioData);
      
      onProgress?.call(0.9);

      // Convert to engine format
      final segments = nativeSegments.map((segment) {
        final transcriptionSegment = TranscriptionSegment(
          text: segment.text,
          startTime: segment.startTime,
          endTime: segment.endTime,
          confidence: 0.9, // Whisper.cpp doesn't provide confidence scores
          metadata: {
            'engine': engineId,
            'model': _currentModelId,
          },
        );

        onSegment?.call(transcriptionSegment);
        return transcriptionSegment;
      }).toList();

      onProgress?.call(1.0);

      final endTime = DateTime.now();
      final processingTime = endTime.difference(startTime);
      final fullText = segments.map((s) => s.text).join(' ');

      return TranscriptionResult(
        fullText: fullText,
        segments: segments,
        processingTime: processingTime,
        detectedLanguage: language ?? 'auto',
        metadata: {
          'engine': engineId,
          'model': _currentModelId,
          'audioLength': audioData.length,
          'language': language,
        },
      );
    } catch (e) {
      throw TranscriptionException(
        'Transcription failed: $e',
        engineId,
        e,
      );
    } finally {
      _isProcessing = false;
    }
  }

  @override
  Stream<TranscriptionSegment>? transcribeStream(
    Stream<Float32List> audioStream, {
    String? language,
    bool enableWordTimestamps = false,
  }) {
    // Whisper.cpp doesn't support streaming in current implementation
    return null;
  }

  @override
  Future<void> cancel() async {
    _isProcessing = false;
    // TODO: Implement cancellation in native code
  }

  @override
  Future<void> updateConfig(Map<String, dynamic> config) async {
    _config.addAll(config);
    // TODO: Apply config to native engine if needed
  }

  // Helper methods

  Future<String?> _resolveModelPath(String modelId) async {
    // TODO: Implement proper model path resolution
    // This should check local model storage and return path if available
    
    // Placeholder implementation
    if (Platform.isIOS) {
      return '/path/to/ios/models/$modelId.bin';
    } else if (Platform.isAndroid) {
      return '/path/to/android/models/$modelId.bin';
    }
    
    return null;
  }
}