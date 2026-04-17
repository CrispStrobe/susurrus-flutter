import 'dart:typed_data';
import 'dart:io';

import 'transcription_engine.dart';
import '../native/coreml_whisper.dart';
import '../services/model_service.dart';

/// CoreML-based transcription engine for iOS
class CoreMLEngine implements TranscriptionEngine {
  CoreMLWhisper? _coreMLWhisper;
  ModelService? _modelService;
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
      _modelService = ModelService();
      
      final isAvailable = await _coreMLWhisper!.isAvailable;
      if (!isAvailable) {
        throw EngineInitializationException(
          'CoreML not available on this device (requires iOS 13.0+)',
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
  Future<List<EngineModel>> getAvailableModels() async {
    if (!_isInitialized || _modelService == null) {
      throw EngineInitializationException(
        'Engine not initialized',
        engineId,
      );
    }

    try {
      // Get models from model service
      final modelInfos = await _modelService!.getCoreMLModels();
      
      return modelInfos.map((modelInfo) => EngineModel(
        id: modelInfo.name,
        name: modelInfo.displayName,
        description: 'CoreML optimized Whisper model',
        sizeBytes: _parseModelSize(modelInfo.size),
        supportedLanguages: supportedLanguages,
        isDownloaded: modelInfo.isDownloaded,
        localPath: modelInfo.localPath,
        metadata: {
          'framework': 'CoreML',
          'platform': 'iOS',
          'backend': 'coreml',
        },
      )).toList();
    } catch (e) {
      throw GenericEngineException(
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
      
      // Check if model is downloaded
      final modelPath = await _modelService!.getCoreMLModelPath(modelId);
      if (modelPath == null) {
        throw ModelLoadException(
          'Model not found: $modelId. Please download it first.',
          engineId,
          modelId,
        );
      }

      onProgress?.call(0.3);

      // Load model using CoreML
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

      // Preprocess audio for CoreML (ensure 16kHz, mono)
      final processedAudio = await _preprocessAudio(audioData);
      
      onProgress?.call(0.2);

      // Call CoreML transcription
      final coreMLSegments = await _coreMLWhisper!.transcribe(
        processedAudio,
        language: language,
        wordTimestamps: enableWordTimestamps,
      );

      onProgress?.call(0.9);

      // Convert CoreML segments to engine format
      final segments = <TranscriptionSegment>[];
      
      for (int i = 0; i < coreMLSegments.length; i++) {
        final coreMLSegment = coreMLSegments[i];
        
        final transcriptionSegment = TranscriptionSegment(
          text: coreMLSegment.text,
          startTime: coreMLSegment.startTime,
          endTime: coreMLSegment.endTime,
          confidence: coreMLSegment.confidence,
          words: enableWordTimestamps ? coreMLSegment.words?.map((word) => TranscriptionWord(
            word: word.word,
            startTime: word.startTime,
            endTime: word.endTime,
            confidence: word.confidence,
          )).toList() : null,
          metadata: {
            'engine': engineId,
            'model': _currentModelId,
            'segmentIndex': i,
          },
        );

        segments.add(transcriptionSegment);
        onSegment?.call(transcriptionSegment);
      }

      onProgress?.call(1.0);

      final endTime = DateTime.now();
      final processingTime = endTime.difference(startTime);
      final fullText = segments.map((s) => s.text).join(' ');

      return TranscriptionResult(
        fullText: fullText,
        segments: segments,
        processingTime: processingTime,
        detectedLanguage: language ?? 'auto',
        confidence: segments.isNotEmpty ? 
          segments.map((s) => s.confidence).reduce((a, b) => a + b) / segments.length : 
          null,
        metadata: {
          'engine': engineId,
          'model': _currentModelId,
          'audioLength': audioData.length,
          'processedAudioLength': processedAudio.length,
          'language': language,
          'wordTimestamps': enableWordTimestamps,
          'processingTimeMs': processingTime.inMilliseconds,
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
    return null;
  }

  @override
  Future<void> cancel() async {
    _isProcessing = false;
  }

  @override
  Future<void> updateConfig(Map<String, dynamic> config) async {
    _config.addAll(config);
  }

  @override
  Future<void> unloadModel() async {
    if (_currentModelId != null) {
      await _coreMLWhisper?.unloadModel();
      _currentModelId = null;
    }
  }

  @override
  Future<void> dispose() async {
    await unloadModel();
    _isInitialized = false;
    _isProcessing = false;
    _config.clear();
  }

  // Audio preprocessing for CoreML
  Future<Float32List> _preprocessAudio(Float32List audioData) async {
    // CoreML Whisper models expect:
    // - 16kHz sample rate
    // - Mono audio
    // - Normalized to [-1, 1]
    
    // For now, assume audio is already in correct format
    // In production, you'd want proper resampling and normalization
    
    // Simple normalization
    final maxValue = audioData.map((sample) => sample.abs()).reduce((a, b) => a > b ? a : b);
    if (maxValue > 1.0) {
      return Float32List.fromList(audioData.map((sample) => sample / maxValue).toList());
    }
    
    return audioData;
  }

  // Helper to parse model size strings like "74 MB" to bytes
  int _parseModelSize(String sizeString) {
    final parts = sizeString.split(' ');
    if (parts.length != 2) return 0;
    
    final value = double.tryParse(parts[0]) ?? 0;
    final unit = parts[1].toUpperCase();
    
    switch (unit) {
      case 'KB':
        return (value * 1024).round();
      case 'MB':
        return (value * 1024 * 1024).round();
      case 'GB':
        return (value * 1024 * 1024 * 1024).round();
      default:
        return value.round();
    }
  }
}