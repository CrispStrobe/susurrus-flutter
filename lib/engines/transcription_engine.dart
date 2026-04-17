// lib/engines/transcription_engine.dart
import 'dart:typed_data';
import '../services/model_service.dart';

/// Abstract interface for all transcription engines
abstract class TranscriptionEngine {
  /// Engine identification
  String get engineId;
  String get engineName;
  String get version;

  /// Engine capabilities
  bool get supportsStreaming;
  bool get supportsLanguageDetection;
  bool get supportsWordTimestamps;
  bool get supportsSpeakerDiarization;
  List<String> get supportedLanguages;

  /// Engine status
  bool get isInitialized;
  bool get isProcessing;

  /// Lifecycle methods
  Future<bool> initialize({ModelService? modelService, Map<String, dynamic>? config});
  Future<void> dispose();

  /// Model management
  Future<List<EngineModel>> getAvailableModels();
  Future<bool> loadModel(String modelId, {void Function(double progress)? onProgress});
  Future<void> unloadModel();
  String? get currentModelId;

  /// Transcription methods
  Future<TranscriptionResult> transcribe(
    Float32List audioData, {
    String? language,
    bool enableWordTimestamps = false,
    bool enableSpeakerDiarization = false,
    void Function(TranscriptionSegment segment)? onSegment,
    void Function(double progress)? onProgress,
  });

  /// Streaming transcription (if supported)
  Stream<TranscriptionSegment>? transcribeStream(
    Stream<Float32List> audioStream, {
    String? language,
    bool enableWordTimestamps = false,
  });

  /// Cancel ongoing operations
  Future<void> cancel();

  /// Engine-specific configuration
  Future<void> updateConfig(Map<String, dynamic> config);
  Map<String, dynamic> get currentConfig;
}

/// Engine model information
class EngineModel {
  final String id;
  final String name;
  final String description;
  final int sizeBytes;
  final List<String> supportedLanguages;
  final bool isDownloaded;
  final String? localPath;
  final Map<String, dynamic> metadata;

  const EngineModel({
    required this.id,
    required this.name,
    required this.description,
    required this.sizeBytes,
    required this.supportedLanguages,
    this.isDownloaded = false,
    this.localPath,
    this.metadata = const {},
  });
}

/// Transcription result
class TranscriptionResult {
  final String fullText;
  final List<TranscriptionSegment> segments;
  final Duration processingTime;
  final String? detectedLanguage;
  final double? confidence;
  final Map<String, dynamic> metadata;

  const TranscriptionResult({
    required this.fullText,
    required this.segments,
    required this.processingTime,
    this.detectedLanguage,
    this.confidence,
    this.metadata = const {},
  });
}

/// Individual transcription segment
class TranscriptionSegment {
  final String text;
  final double startTime;
  final double endTime;
  final String? speaker;
  final double confidence;
  final List<TranscriptionWord>? words;
  final Map<String, dynamic> metadata;

  const TranscriptionSegment({
    required this.text,
    required this.startTime,
    required this.endTime,
    this.speaker,
    this.confidence = 1.0,
    this.words,
    this.metadata = const {},
  });

  String get formattedTime {
    final start = _formatTime(startTime);
    final end = _formatTime(endTime);
    return '[$start -> $end]';
  }

  String _formatTime(double seconds) {
    final minutes = (seconds / 60).floor();
    final secs = (seconds % 60);
    return '${minutes.toString().padLeft(2, '0')}:${secs.toStringAsFixed(3).padLeft(6, '0')}';
  }
}

/// Word-level transcription information
class TranscriptionWord {
  final String word;
  final double startTime;
  final double endTime;
  final double confidence;

  const TranscriptionWord({
    required this.word,
    required this.startTime,
    required this.endTime,
    required this.confidence,
  });
}

/// Engine-specific exceptions
abstract class EngineException implements Exception {
  final String message;
  final String engineId;
  final dynamic originalError;

  const EngineException(this.message, this.engineId, [this.originalError]);

  @override
  String toString() => 'EngineException($engineId): $message';
}

class EngineInitializationException extends EngineException {
  const EngineInitializationException(String message, String engineId, [dynamic originalError])
      : super(message, engineId, originalError);
}

class ModelLoadException extends EngineException {
  final String modelId;

  const ModelLoadException(String message, String engineId, this.modelId, [dynamic originalError])
      : super(message, engineId, originalError);
}

class TranscriptionException extends EngineException {
  const TranscriptionException(String message, String engineId, [dynamic originalError])
      : super(message, engineId, originalError);
}

/// A concrete fallback for engine errors that don't fit a more specific type.
class GenericEngineException extends EngineException {
  const GenericEngineException(String message, String engineId, [dynamic originalError])
      : super(message, engineId, originalError);
}