import 'dart:typed_data';
import 'dart:io';

import 'transcription_engine.dart';
import '../native/coreml_whisper.dart';

/// CoreML-based transcription engine for iOS
class CoreMLEngine implements TranscriptionEngine {
  CoreMLWhisper? _coreMLWhisper;
  bool _isInitialized = false;
  bool _isProcessing = false;
  String? _currentModelId;
  Map<String, dynamic> _config = {};

  @override
  String get engineId => 'coreml';

  @override
  String get engineName => 'CoreML Whisper';

  @override
  String get version => '1.0.0';

  @override
  bool get supportsStreaming => false; // CoreML batch processing

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
    'ms', 'cs', 'ro', 'da', 'hu', 'ta', 'no', 'th', 'ur', 'hr', 'bg', 'lt'
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
    if (!Platform.isIOS) {
      throw EngineInitializationException(
        'CoreML engine is only available on iOS',
        engineId,
      );
    }

    try {
      _config = config ?? {};
      _coreMLWhisper = CoreMLWhisper.instance;
      
      final isAvailable = await _coreMLWhisper!.isAvailable;
      if (!isAvailable) {
        throw EngineInitializationException(
          'CoreML not available on this device',
          engineId,
        );
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      throw EngineInitializationException(
        'Failed to initialize CoreML engine: $e',
        engineId,
        e,
      );
    }
  }

  @override
  Future<void> dispose() async {
    await _coreMLWhisper?.unloadModel();
    _coreMLWhisper = null;
    _isInitialized = false;
    _isProcessing = false;
    _currentModelId = null;
    _config.clear();
  }

  @override
  Future<List<EngineModel>> getAvailableModels() async {
    if (!_isInitialized || _coreMLWhisper == null) {
      throw EngineInitializationException(
        'Engine not initialized',
        engineId,
      );
    }

    try {
      final availableModels = await _coreMLWhisper!.getAvailableModels();
      
      return availableModels.map((modelName) {
        return _createModelInfo(modelName);
      }).toList();
    } catch (e) {
      throw EngineException(
        'Failed to get available models: $e',
        engineId,
        e,
      );
    }
  }

  @override
  Future<bool> loadModel(String modelId, {Function(double progress)? onProgress}) async {
    if (!_isInitialized || _coreMLWhisper == null) {
      throw EngineInitializationException(
        'Engine not initialized',
        engineId,
      );
    }

    try {
      onProgress?.call(0.1);
      
      final modelPath = await _resolveModelPath(modelId);
      if (modelPath == null) {
        throw ModelLoadException(
          'Model not found: $modelId',
          engineId,
          modelId,
        );
      }

      onProgress?.call(0.5);

      final success = await _coreMLWhisper!.loadModel(modelPath);
      
      onProgress?.call(1.0);

      if (success) {
        _currentModelId = modelId;
        return true;
      } else {
        throw ModelLoadException(
          'Failed to load CoreML model: $modelId',
          engineId,
          modelId,
        );
      }
    } catch (e) {
      if (e is EngineException) rethrow;
      throw ModelLoadException(
        'Error loading CoreML model $modelId: $e',
        engineId,
        modelId,
        e,
      );
    }
  }

  @override
  Future<void> unloadModel() async {
    await _coreMLWhisper?.unloadModel();
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
    if (!_isInitialized || _coreMLWhisper == null) {
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

      // Call CoreML transcription
      final coreMLSegments = await _coreMLWhisper!.transcribe(
        audioData,
        language: language,
        wordTimestamps: enableWordTimestamps,
      );

      onProgress?.call(0.9);

      // Convert CoreML segments to engine format
      final segments = coreMLSegments.map((coreMLSegment) {
        final transcriptionSegment = TranscriptionSegment(
          text: coreMLSegment.text,
          startTime: coreMLSegment.startTime,
          endTime: coreMLSegment.endTime,
          confidence: coreMLSegment.confidence,
          words: coreMLSegment.words?.map((word) => TranscriptionWord(
            word: word.word,
            startTime: word.startTime,
            endTime: word.endTime,
            confidence: word.confidence,
          )).toList(),
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
          'wordTimestamps': enableWordTimestamps,
        },
      );
    } catch (e) {
      throw TranscriptionException(
        'CoreML transcription failed: $e',
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
    // CoreML typically uses batch processing, not streaming
    return null;
  }

  @override
  Future<void> cancel() async {
    _isProcessing = false;
    // CoreML models don't typically support cancellation mid-inference
  }

  @override
  Future<void> updateConfig(Map<String, dynamic> config) async {
    _config.addAll(config);
    // Apply configuration changes if needed
  }

  // Helper methods

  EngineModel _createModelInfo(String modelName) {
    // Map model names to their properties
    final modelSizes = {
      'whisper-tiny': 39 * 1024 * 1024,
      'whisper-base': 74 * 1024 * 1024,
      'whisper-small': 244 * 1024 * 1024,
      'whisper-medium': 769 * 1024 * 1024,
      'whisper-large-v3': 1550 * 1024 * 1024,
    };

    final displayNames = {
      'whisper-tiny': 'Whisper Tiny (CoreML)',
      'whisper-base': 'Whisper Base (CoreML)',
      'whisper-small': 'Whisper Small (CoreML)',
      'whisper-medium': 'Whisper Medium (CoreML)',
      'whisper-large-v3': 'Whisper Large v3 (CoreML)',
    };

    final descriptions = {
      'whisper-tiny': 'Fastest CoreML model, optimized for iOS',
      'whisper-base': 'Balanced CoreML model for iOS',
      'whisper-small': 'High quality CoreML model',
      'whisper-medium': 'Very high quality CoreML model',
      'whisper-large-v3': 'Best quality CoreML model',
    };

    return EngineModel(
      id: modelName,
      name: displayNames[modelName] ?? modelName,
      description: descriptions[modelName] ?? 'CoreML optimized model',
      sizeBytes: modelSizes[modelName] ?? 100 * 1024 * 1024,
      supportedLanguages: supportedLanguages,
      metadata: {
        'framework': 'CoreML',
        'platform': 'iOS',
        'optimized': true,
      },
    );
  }

  Future<String?> _resolveModelPath(String modelId) async {
    // TODO: Implement proper CoreML model path resolution
    // This should check the iOS app bundle and documents directory
    
    // CoreML models are typically stored in the app bundle or documents directory
    try {
      // Check app bundle first
      final bundlePath = '/path/to/bundle/$modelId.mlmodel';
      if (await File(bundlePath).exists()) {
        return bundlePath;
      }
      
      // Check documents directory
      final documentsPath = '/path/to/documents/$modelId.mlmodel';
      if (await File(documentsPath).exists()) {
        return documentsPath;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
}