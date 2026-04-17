// lib/services/transcription_service.dart (FIXED)
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

import '../engines/engine_factory.dart';
import '../engines/transcription_engine.dart';
import 'audio_service.dart';
import 'model_service.dart';
import 'diarization_service.dart';

/// Main transcription service that coordinates engines, audio processing, and diarization
class TranscriptionService {
  final AudioService _audioService;
  final ModelService _modelService;
  final DiarizationService _diarizationService = DiarizationService();
  final EngineManager _engineManager = EngineManager();

  bool _isTranscribing = false;
  StreamSubscription<TranscriptionSegment>? _streamSubscription;

  /// The full result (including metadata) from the most recent successful
  /// transcription — populated after [transcribeFile] / [transcribeUrl]
  /// returns. Exposed so the UI can surface perf metrics and language
  /// detection without plumbing a new return type through every layer.
  TranscriptionResult? lastResult;

  TranscriptionService(this._audioService, this._modelService);

  bool get isTranscribing => _isTranscribing;
  TranscriptionEngine? get currentEngine => _engineManager.currentEngine;
  EngineType? get currentEngineType => _engineManager.currentEngineType;

  /// Initialize the transcription service
  Future<bool> initialize({
    EngineType? preferredEngine,
    String? modelName,
  }) async {
    try {
      await _modelService.initialize();

      // Initialize with preferred engine or use mock as safe fallback
      final engineType = preferredEngine ?? EngineType.mock;
      final success = await _engineManager.switchEngine(engineType, modelService: _modelService);

      if (!success) {
        // Fallback to mock engine if preferred engine fails
        print('Failed to initialize $engineType engine, falling back to mock');
        return await _engineManager.initializeWithMock(modelService: _modelService);
      }

      // Load model if specified and engine supports it
      if (modelName != null && currentEngine != null) {
        try {
          await currentEngine!.loadModel(modelName);
        } catch (e) {
          print('Failed to load model $modelName: $e');
          // Continue with engine initialization even if model loading fails
        }
      }

      return success;
    } catch (e) {
      print('Failed to initialize transcription service: $e');
      // Ensure we have at least a mock engine working
      return await _engineManager.initializeWithMock();
    }
  }

  /// Transcribe an audio file
  Future<List<TranscriptionSegment>> transcribeFile(
    File audioFile, {
    String? language,
    bool enableDiarization = false,
    bool enableWordTimestamps = false,
    int? minSpeakers,
    int? maxSpeakers,
    void Function(double progress)? onProgress,
    void Function(TranscriptionSegment segment)? onSegment,
  }) async {
    if (_isTranscribing) {
      throw TranscriptionServiceException('Already transcribing. Stop current transcription first.');
    }

    if (currentEngine == null) {
      throw TranscriptionServiceException('No transcription engine available. Please initialize first.');
    }

    _isTranscribing = true;
    onProgress?.call(0.0);

    try {
      // Step 1: Load and process audio (10% of progress)
      onProgress?.call(0.05);
      final audioData = await _audioService.loadAudioFile(audioFile);
      onProgress?.call(0.1);

      // Step 2: Perform transcription (60% of progress)
      final engineSegments = await _performTranscription(
        audioData.samples,
        language: language,
        enableWordTimestamps: enableWordTimestamps,
        onProgress: (progress) => onProgress?.call(0.1 + progress * 0.6),
        onSegment: onSegment,
      );

      onProgress?.call(0.7);

      // Use segments directly from engine (they're already TranscriptionSegment)
      List<TranscriptionSegment> segments = engineSegments;

      // Step 3: Speaker diarization if enabled (30% of progress)
      if (enableDiarization && segments.isNotEmpty) {
        onProgress?.call(0.75);

        segments = await _diarizationService.diarizeSegments(
          audioData,
          segments,
          minSpeakers: minSpeakers,
          maxSpeakers: maxSpeakers,
          onProgress: (progress) => onProgress?.call(0.75 + progress * 0.25),
        );
      }

      onProgress?.call(1.0);
      return segments;

    } catch (e) {
      throw TranscriptionServiceException('File transcription failed: $e');
    } finally {
      _isTranscribing = false;
    }
  }

  /// Transcribe audio from URL
  Future<List<TranscriptionSegment>> transcribeUrl(
    String url, {
    String? language,
    bool enableDiarization = false,
    bool enableWordTimestamps = false,
    int? minSpeakers,
    int? maxSpeakers,
    void Function(double progress)? onProgress,
    void Function(TranscriptionSegment segment)? onSegment,
  }) async {
    if (_isTranscribing) {
      throw TranscriptionServiceException('Already transcribing. Stop current transcription first.');
    }

    try {
      // Step 1: Download audio (10% of progress)
      onProgress?.call(0.0);
      final audioFile = await _audioService.downloadAudioFromUrl(
        url,
        onProgress: (progress) => onProgress?.call(progress * 0.1),
      );

      // Step 2: Transcribe the downloaded file (90% of progress)
      return await transcribeFile(
        audioFile,
        language: language,
        enableDiarization: enableDiarization,
        enableWordTimestamps: enableWordTimestamps,
        minSpeakers: minSpeakers,
        maxSpeakers: maxSpeakers,
        onProgress: (progress) => onProgress?.call(0.1 + progress * 0.9),
        onSegment: onSegment,
      );
    } catch (e) {
      throw TranscriptionServiceException('URL transcription failed: $e');
    }
  }

  /// Start streaming transcription (if supported by current engine)
  Stream<TranscriptionSegment>? transcribeStream(
    Stream<Float32List> audioStream, {
    String? language,
    bool enableWordTimestamps = false,
  }) {
    final engine = currentEngine;
    if (engine == null) {
      throw TranscriptionServiceException('No transcription engine available');
    }

    if (!engine.supportsStreaming) {
      return null; // Engine doesn't support streaming
    }

    return engine.transcribeStream(
      audioStream,
      language: language,
      enableWordTimestamps: enableWordTimestamps,
    );
  }

  /// Stop ongoing transcription
  Future<void> stopTranscription() async {
    _isTranscribing = false;
    await _streamSubscription?.cancel();
    _streamSubscription = null;

    final engine = currentEngine;
    if (engine != null) {
      try {
        await engine.cancel();
      } catch (e) {
        print('Error stopping transcription: $e');
      }
    }
  }

  /// Switch to a different transcription engine
  Future<bool> switchEngine(EngineType engineType, {Map<String, dynamic>? config}) async {
    if (_isTranscribing) {
      throw TranscriptionServiceException('Cannot change engine while transcribing');
    }

    try {
      return await _engineManager.switchEngine(engineType, modelService: _modelService, config: config);
    } catch (e) {
      print('Error switching engine to $engineType: $e');
      return false;
    }
  }

  /// Get available models for the current engine
  Future<List<EngineModel>> getAvailableModels() async {
    final engine = currentEngine;
    if (engine == null) {
      throw TranscriptionServiceException('No engine initialized');
    }

    try {
      return await engine.getAvailableModels();
    } catch (e) {
      throw TranscriptionServiceException('Failed to get available models: $e');
    }
  }

  /// Load a specific model for the current engine
  Future<bool> loadModel(String modelId, {void Function(double progress)? onProgress}) async {
    final engine = currentEngine;
    if (engine == null) {
      throw TranscriptionServiceException('No engine initialized');
    }

    if (_isTranscribing) {
      throw TranscriptionServiceException('Cannot load model while transcribing');
    }

    try {
      return await engine.loadModel(modelId, onProgress: onProgress);
    } catch (e) {
      throw TranscriptionServiceException('Failed to load model $modelId: $e');
    }
  }

  /// Unload the current model
  Future<void> unloadModel() async {
    final engine = currentEngine;
    if (engine == null) return;

    if (_isTranscribing) {
      throw TranscriptionServiceException('Cannot unload model while transcribing');
    }

    try {
      await engine.unloadModel();
    } catch (e) {
      print('Error unloading model: $e');
    }
  }

  /// Update engine configuration
  Future<void> updateEngineConfig(Map<String, dynamic> config) async {
    final engine = currentEngine;
    if (engine == null) {
      throw TranscriptionServiceException('No engine initialized');
    }

    try {
      await engine.updateConfig(config);
    } catch (e) {
      throw TranscriptionServiceException('Failed to update engine config: $e');
    }
  }

  /// Get current engine information
  EngineInfo? getCurrentEngineInfo() {
    if (currentEngineType == null) return null;

    final availableEngines = EngineFactory.getAvailableEngines();
    final engineType = currentEngineType!;

    return EngineInfo(
      type: engineType,
      isActive: true,
      isSupported: availableEngines.contains(engineType),
    );
  }

  /// Get all available engines for selection
  List<EngineInfo> getAvailableEngines() {
    return _engineManager.getAvailableEnginesInfo();
  }

  /// Get engine status information
  EngineStatus getEngineStatus() {
    final engine = currentEngine;

    return EngineStatus(
      engineType: currentEngineType,
      isInitialized: engine?.isInitialized ?? false,
      isProcessing: engine?.isProcessing ?? false,
      currentModelId: engine?.currentModelId,
      supportsStreaming: engine?.supportsStreaming ?? false,
      supportsSpeakerDiarization: engine?.supportsSpeakerDiarization ?? false,
      supportsWordTimestamps: engine?.supportsWordTimestamps ?? false,
      supportedLanguages: engine?.supportedLanguages ?? [],
    );
  }

  // Private helper methods

  /// Perform transcription using the current engine
  Future<List<TranscriptionSegment>> _performTranscription(
    Float32List audioSamples, {
    String? language,
    bool enableWordTimestamps = false,
    void Function(double progress)? onProgress,
    void Function(TranscriptionSegment segment)? onSegment,
  }) async {
    final engine = currentEngine;
    if (engine == null) {
      throw TranscriptionServiceException('No engine available for transcription');
    }

    try {
      final result = await engine.transcribe(
        audioSamples,
        language: language,
        enableWordTimestamps: enableWordTimestamps,
        enableSpeakerDiarization: false, // We handle diarization separately
        onSegment: onSegment,
        onProgress: onProgress,
      );
      lastResult = result;
      return result.segments;
    } catch (e) {
      throw TranscriptionServiceException('Engine transcription failed: $e');
    }
  }

  /// Clean up resources
  void dispose() {
    stopTranscription();
    _engineManager.dispose();
  }
}

/// Engine status information
class EngineStatus {
  final EngineType? engineType;
  final bool isInitialized;
  final bool isProcessing;
  final String? currentModelId;
  final bool supportsStreaming;
  final bool supportsSpeakerDiarization;
  final bool supportsWordTimestamps;
  final List<String> supportedLanguages;

  const EngineStatus({
    this.engineType,
    required this.isInitialized,
    required this.isProcessing,
    this.currentModelId,
    required this.supportsStreaming,
    required this.supportsSpeakerDiarization,
    required this.supportsWordTimestamps,
    required this.supportedLanguages,
  });

  bool get hasActiveEngine => engineType != null && isInitialized;
  bool get canTranscribe => hasActiveEngine && !isProcessing;
  bool get hasModelLoaded => currentModelId != null;

  String get statusDescription {
    if (!hasActiveEngine) return 'No engine initialized';
    if (isProcessing) return 'Processing...';
    if (!hasModelLoaded) return 'No model loaded';
    return 'Ready';
  }
}

/// Service-level transcription failure.
///
/// The per-engine [TranscriptionException] type from
/// `transcription_engine.dart` wraps engine-originated errors; this one is
/// thrown by the orchestrating service itself.
class TranscriptionServiceException implements Exception {
  final String message;
  final dynamic originalError;

  const TranscriptionServiceException(this.message, [this.originalError]);

  @override
  String toString() {
    if (originalError != null) {
      return 'TranscriptionServiceException: $message (caused by: $originalError)';
    }
    return 'TranscriptionServiceException: $message';
  }
}