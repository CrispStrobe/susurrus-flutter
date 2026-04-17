// lib/engines/whisper_cpp_engine.dart
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import 'transcription_engine.dart';
import '../services/model_service.dart';

/// Production Whisper.cpp based transcription engine
class WhisperCppEngine implements TranscriptionEngine {
  static const MethodChannel _channel = MethodChannel('com.susurrus.whisper_cpp');
  
  bool _isInitialized = false;
  bool _isProcessing = false;
  String? _currentModelId;
  String? _currentModelPath;
  Map<String, dynamic> _config = {};
  ModelService? _modelService;

  @override
  String get engineId => 'whisper_cpp';

  @override
  String get engineName => 'Whisper.cpp';

  @override
  String get version => '1.5.4';

  @override
  bool get supportsStreaming => false; // Whisper.cpp limitation

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
      _modelService = ModelService();
      await _modelService!.initialize();

      // Test native library availability
      try {
        final isAvailable = await _channel.invokeMethod('isModelLoaded');
        _isInitialized = true;
        return true;
      } catch (e) {
        print('Native library not available: $e');
        throw EngineInitializationException(
          'Whisper.cpp native library not available. Please ensure the app is built with native support.',
          engineId,
          e,
        );
      }
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
    if (_currentModelPath != null) {
      try {
        await _channel.invokeMethod('freeModel');
      } catch (e) {
        print('Error freeing model: $e');
      }
    }
    
    _isInitialized = false;
    _isProcessing = false;
    _currentModelId = null;
    _currentModelPath = null;
    _config.clear();
  }

  @override
  Future<List<EngineModel>> getAvailableModels() async {
    if (_modelService == null) {
      throw EngineInitializationException('Engine not initialized', engineId);
    }

    try {
      final whisperModels = await _modelService!.getWhisperCppModels();
      
      return whisperModels.map((modelInfo) => EngineModel(
        id: modelInfo.name,
        name: modelInfo.displayName,
        description: _getModelDescription(modelInfo.name),
        sizeBytes: _parseModelSize(modelInfo.size),
        supportedLanguages: supportedLanguages,
        isDownloaded: modelInfo.isDownloaded,
        localPath: modelInfo.localPath,
        metadata: {
          'framework': 'whisper.cpp',
          'backend': 'whisper_cpp',
          'quantization': _getQuantizationType(modelInfo.name),
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
  Future<bool> loadModel(String modelId, {void Function(double progress)? onProgress}) async {
    if (!_isInitialized) {
      throw EngineInitializationException('Engine not initialized', engineId);
    }

    if (_currentModelId == modelId) {
      return true; // Already loaded
    }

    try {
      onProgress?.call(0.1);

      // Get model path
      final modelPath = await _modelService!.getWhisperCppModelPath(modelId);
      if (modelPath == null) {
        throw ModelLoadException(
          'Model not found: $modelId. Please download it first.',
          engineId,
          modelId,
        );
      }

      // Verify model file exists
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        throw ModelLoadException(
          'Model file not found: $modelPath',
          engineId,
          modelId,
        );
      }

      onProgress?.call(0.3);

      // Free current model if loaded
      if (_currentModelPath != null) {
        await _channel.invokeMethod('freeModel');
      }

      onProgress?.call(0.5);

      // Load new model via native method
      final success = await _channel.invokeMethod('initModel', {
        'modelPath': modelPath,
      });

      onProgress?.call(0.9);

      if (success == true) {
        _currentModelId = modelId;
        _currentModelPath = modelPath;
        onProgress?.call(1.0);
        return true;
      } else {
        throw ModelLoadException(
          'Failed to load model: $modelId. The model file may be corrupted.',
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
    if (_currentModelPath != null) {
      try {
        await _channel.invokeMethod('freeModel');
      } catch (e) {
        print('Error unloading model: $e');
      }
      
      _currentModelId = null;
      _currentModelPath = null;
    }
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
      throw EngineInitializationException('Engine not initialized', engineId);
    }

    if (_currentModelId == null) {
      throw ModelLoadException('No model loaded', engineId, 'none');
    }

    if (audioData.isEmpty) {
      throw TranscriptionException('Empty audio data provided', engineId);
    }

    _isProcessing = true;
    final startTime = DateTime.now();

    try {
      onProgress?.call(0.1);

      // Prepare audio data for native processing
      final processedAudio = await _preprocessAudio(audioData);
      
      onProgress?.call(0.2);

      // Call native transcription
      final result = await _channel.invokeMethod('transcribe', {
        'audioData': processedAudio,
        'language': language ?? 'auto',
      });

      onProgress?.call(0.8);

      // Parse native result
      final segments = await _parseNativeResult(result, onSegment);

      onProgress?.call(1.0);

      final endTime = DateTime.now();
      final processingTime = endTime.difference(startTime);
      final fullText = segments.map((s) => s.text).join(' ');

      return TranscriptionResult(
        fullText: fullText,
        segments: segments,
        processingTime: processingTime,
        detectedLanguage: language ?? 'auto',
        confidence: segments.isNotEmpty 
          ? segments.map((s) => s.confidence).reduce((a, b) => a + b) / segments.length 
          : null,
        metadata: {
          'engine': engineId,
          'model': _currentModelId,
          'audioLength': audioData.length,
          'sampleRate': 16000,
          'language': language,
          'wordTimestamps': enableWordTimestamps,
          'processingTimeMs': processingTime.inMilliseconds,
        },
      );
    } catch (e) {
      if (e is EngineException) rethrow;
      
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
    // Whisper.cpp doesn't support streaming transcription
    return null;
  }

  @override
  Future<void> cancel() async {
    _isProcessing = false;
    // Note: Actual cancellation would require native implementation
    // For now, we just set the flag to stop processing
  }

  @override
  Future<void> updateConfig(Map<String, dynamic> config) async {
    _config.addAll(config);
    // Apply configuration changes if needed
  }

  // Private helper methods

  Future<Float32List> _preprocessAudio(Float32List audioData) async {
    // Ensure audio is in the format expected by Whisper:
    // - 16kHz sample rate
    // - Mono channel
    // - Normalized to [-1, 1]

    // Simple normalization
    final maxValue = audioData.map((sample) => sample.abs()).reduce((a, b) => a > b ? a : b);
    
    if (maxValue > 1.0) {
      return Float32List.fromList(audioData.map((sample) => sample / maxValue).toList());
    }

    return audioData;
  }

  Future<List<TranscriptionSegment>> _parseNativeResult(
    dynamic result,
    void Function(TranscriptionSegment segment)? onSegment,
  ) async {
    final segments = <TranscriptionSegment>[];
    if (result is! List) return segments;

    for (int i = 0; i < result.length; i++) {
      // Defensive: a misbehaving native plugin could hand back nulls or
      // strings. Skip the entry rather than throwing `CastError` and
      // hiding the real problem from the log.
      final raw = result[i];
      if (raw is! Map) continue;

      final segment = TranscriptionSegment(
        text: raw['text'] as String? ?? '',
        startTime: (raw['startTime'] as num?)?.toDouble() ?? 0.0,
        endTime: (raw['endTime'] as num?)?.toDouble() ?? 0.0,
        confidence: (raw['confidence'] as num?)?.toDouble() ?? 0.9,
        metadata: {
          'engine': engineId,
          'model': _currentModelId,
          'segmentIndex': i,
        },
      );

      segments.add(segment);
      onSegment?.call(segment);
    }

    return segments;
  }

  String _getModelDescription(String modelName) {
    final descriptions = {
      'tiny': 'Fastest model with lower accuracy (~39 MB)',
      'base': 'Balanced speed and accuracy (~74 MB)',
      'small': 'Good accuracy with moderate speed (~244 MB)',
      'medium': 'High accuracy with slower processing (~769 MB)',
      'large': 'Best accuracy with slowest processing (~1.5 GB)',
      'large-v2': 'Improved large model with better multilingual support (~1.5 GB)',
      'large-v3': 'Latest large model with enhanced performance (~1.5 GB)',
    };

    return descriptions[modelName] ?? 'Whisper.cpp transcription model';
  }

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

  String _getQuantizationType(String modelName) {
    // Most whisper.cpp models use Q4_0 quantization by default
    if (modelName.contains('f16')) return 'f16';
    if (modelName.contains('q8_0')) return 'q8_0';
    if (modelName.contains('q5_0')) return 'q5_0';
    if (modelName.contains('q4_0')) return 'q4_0';
    
    return 'q4_0'; // Default quantization
  }
}