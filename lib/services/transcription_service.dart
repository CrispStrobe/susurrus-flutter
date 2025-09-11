import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:isolate';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../native/whisper_bindings.dart';
import '../native/coreml_whisper.dart';
import '../main.dart';
import 'audio_service.dart';
import 'model_service.dart';
import 'diarization_service.dart';

enum TranscriptionBackend {
  whisperCpp,
  coreML,
  auto,
}

class TranscriptionService {
  final AudioService _audioService;
  final ModelService _modelService = ModelService();
  final DiarizationService _diarizationService = DiarizationService();
  
  WhisperTranscriber? _whisperTranscriber;
  CoreMLWhisper? _coreMLTranscriber;
  TranscriptionBackend _currentBackend = TranscriptionBackend.auto;
  String? _currentModel;
  bool _isTranscribing = false;
  Isolate? _transcriptionIsolate;
  
  TranscriptionService(this._audioService);
  
  bool get isTranscribing => _isTranscribing;
  TranscriptionBackend get currentBackend => _currentBackend;
  String? get currentModel => _currentModel;
  
  /// Initialize the transcription service with a specific backend
  Future<void> initialize({
    TranscriptionBackend backend = TranscriptionBackend.auto,
    String modelName = 'base',
  }) async {
    try {
      _currentBackend = await _selectBestBackend(backend);
      
      switch (_currentBackend) {
        case TranscriptionBackend.coreML:
          await _initializeCoreML(modelName);
          break;
        case TranscriptionBackend.whisperCpp:
          await _initializeWhisperCpp(modelName);
          break;
        case TranscriptionBackend.auto:
          // This should not happen after _selectBestBackend
          throw TranscriptionException('Failed to select backend');
      }
      
      _currentModel = modelName;
    } catch (e) {
      throw TranscriptionException('Failed to initialize transcription service: $e');
    }
  }
  
  /// Transcribe an audio file
  Future<List<TranscriptionSegment>> transcribeFile(
    File audioFile, {
    String? language,
    bool enableDiarization = false,
    int? minSpeakers,
    int? maxSpeakers,
    Function(double progress)? onProgress,
    Function(TranscriptionSegment segment)? onSegment,
  }) async {
    if (_isTranscribing) {
      throw TranscriptionException('Already transcribing');
    }
    
    _isTranscribing = true;
    onProgress?.call(0.0);
    
    try {
      // Load and process audio
      onProgress?.call(0.1);
      final audioData = await _audioService.loadAudioFile(audioFile);
      
      // Perform transcription
      onProgress?.call(0.2);
      final segments = await _performTranscription(
        audioData.samples,
        language: language,
        onProgress: (progress) => onProgress?.call(0.2 + progress * 0.6),
        onSegment: onSegment,
      );
      
      // Perform speaker diarization if enabled
      if (enableDiarization && segments.isNotEmpty) {
        onProgress?.call(0.8);
        final diarizedSegments = await _diarizationService.diarizeSegments(
          audioData,
          segments,
          minSpeakers: minSpeakers,
          maxSpeakers: maxSpeakers,
          onProgress: (progress) => onProgress?.call(0.8 + progress * 0.2),
        );
        
        onProgress?.call(1.0);
        return diarizedSegments;
      }
      
      onProgress?.call(1.0);
      return segments;
    } catch (e) {
      throw TranscriptionException('Transcription failed: $e');
    } finally {
      _isTranscribing = false;
    }
  }
  
  /// Transcribe audio from URL
  Future<List<TranscriptionSegment>> transcribeUrl(
    String url, {
    String? language,
    bool enableDiarization = false,
    int? minSpeakers,
    int? maxSpeakers,
    Function(double progress)? onProgress,
    Function(TranscriptionSegment segment)? onSegment,
  }) async {
    if (_isTranscribing) {
      throw TranscriptionException('Already transcribing');
    }
    
    try {
      // Download audio file
      onProgress?.call(0.0);
      final audioFile = await _audioService.downloadAudioFromUrl(
        url,
        onProgress: (progress) => onProgress?.call(progress * 0.1),
      );
      
      // Transcribe the downloaded file
      return await transcribeFile(
        audioFile,
        language: language,
        enableDiarization: enableDiarization,
        minSpeakers: minSpeakers,
        maxSpeakers: maxSpeakers,
        onProgress: (progress) => onProgress?.call(0.1 + progress * 0.9),
        onSegment: onSegment,
      );
    } catch (e) {
      throw TranscriptionException('URL transcription failed: $e');
    }
  }
  
  /// Stop ongoing transcription
  void stopTranscription() {
    if (_transcriptionIsolate != null) {
      _transcriptionIsolate!.kill(priority: Isolate.immediate);
      _transcriptionIsolate = null;
    }
    _isTranscribing = false;
  }
  
  /// Change the transcription model
  Future<bool> changeModel(String modelName) async {
    if (_isTranscribing) {
      throw TranscriptionException('Cannot change model while transcribing');
    }
    
    try {
      // Ensure model is downloaded
      final modelPath = await _modelService.getModelPath(modelName);
      if (modelPath == null) {
        await _modelService.downloadModel(modelName);
      }
      
      switch (_currentBackend) {
        case TranscriptionBackend.coreML:
          return await _initializeCoreML(modelName);
        case TranscriptionBackend.whisperCpp:
          return await _initializeWhisperCpp(modelName);
        case TranscriptionBackend.auto:
          return false;
      }
    } catch (e) {
      print('Error changing model: $e');
      return false;
    }
  }
  
  /// Get available models for current backend
  Future<List<ModelInfo>> getAvailableModels() async {
    switch (_currentBackend) {
      case TranscriptionBackend.coreML:
        return await _modelService.getCoreMLModels();
      case TranscriptionBackend.whisperCpp:
        return await _modelService.getWhisperCppModels();
      case TranscriptionBackend.auto:
        return [];
    }
  }
  
  Future<TranscriptionBackend> _selectBestBackend(TranscriptionBackend requested) async {
    if (requested != TranscriptionBackend.auto) {
      return requested;
    }
    
    // Check CoreML availability (iOS only)
    if (Platform.isIOS) {
      final coreMLAvailable = await CoreMLWhisper.instance.isAvailable;
      if (coreMLAvailable) {
        return TranscriptionBackend.coreML;
      }
    }
    
    // Default to whisper.cpp
    return TranscriptionBackend.whisperCpp;
  }
  
  Future<bool> _initializeCoreML(String modelName) async {
    if (!Platform.isIOS) return false;
    
    try {
      _coreMLTranscriber = CoreMLWhisper.instance;
      
      final modelPath = await _modelService.getCoreMLModelPath(modelName);
      if (modelPath == null) {
        throw TranscriptionException('CoreML model not found: $modelName');
      }
      
      return await _coreMLTranscriber!.loadModel(modelPath);
    } catch (e) {
      print('CoreML initialization failed: $e');
      return false;
    }
  }
  
  Future<bool> _initializeWhisperCpp(String modelName) async {
    try {
      _whisperTranscriber = WhisperTranscriber();
      
      final modelPath = await _modelService.getWhisperCppModelPath(modelName);
      if (modelPath == null) {
        throw TranscriptionException('Whisper.cpp model not found: $modelName');
      }
      
      return await _whisperTranscriber!.loadModel(modelPath);
    } catch (e) {
      print('Whisper.cpp initialization failed: $e');
      return false;
    }
  }
  
  Future<List<TranscriptionSegment>> _performTranscription(
    Float32List audioSamples, {
    String? language,
    Function(double progress)? onProgress,
    Function(TranscriptionSegment segment)? onSegment,
  }) async {
    switch (_currentBackend) {
      case TranscriptionBackend.coreML:
        return await _transcribeWithCoreML(audioSamples, language: language, onProgress: onProgress, onSegment: onSegment);
      case TranscriptionBackend.whisperCpp:
        return await _transcribeWithWhisperCpp(audioSamples, onProgress: onProgress, onSegment: onSegment);
      case TranscriptionBackend.auto:
        throw TranscriptionException('Backend not initialized');
    }
  }
  
  Future<List<TranscriptionSegment>> _transcribeWithCoreML(
    Float32List audioSamples, {
    String? language,
    Function(double progress)? onProgress,
    Function(TranscriptionSegment segment)? onSegment,
  }) async {
    if (_coreMLTranscriber == null) {
      throw TranscriptionException('CoreML not initialized');
    }
    
    try {
      final coreMLSegments = await _coreMLTranscriber!.transcribe(
        audioSamples,
        language: language,
        wordTimestamps: true,
      );
      
      final segments = coreMLSegments.map((s) => TranscriptionSegment(
        text: s.text,
        startTime: s.startTime,
        endTime: s.endTime,
        confidence: s.confidence,
      )).toList();
      
      // Call onSegment for each segment
      for (final segment in segments) {
        onSegment?.call(segment);
      }
      
      return segments;
    } catch (e) {
      throw TranscriptionException('CoreML transcription failed: $e');
    }
  }
  
  Future<List<TranscriptionSegment>> _transcribeWithWhisperCpp(
    Float32List audioSamples, {
    Function(double progress)? onProgress,
    Function(TranscriptionSegment segment)? onSegment,
  }) async {
    if (_whisperTranscriber == null) {
      throw TranscriptionException('Whisper.cpp not initialized');
    }
    
    try {
      final whisperSegments = await _whisperTranscriber!.transcribe(audioSamples);
      
      final segments = whisperSegments.map((s) => TranscriptionSegment(
        text: s.text,
        startTime: s.startTime,
        endTime: s.endTime,
      )).toList();
      
      // Call onSegment for each segment
      for (final segment in segments) {
        onSegment?.call(segment);
      }
      
      return segments;
    } catch (e) {
      throw TranscriptionException('Whisper.cpp transcription failed: $e');
    }
  }
  
  void dispose() {
    stopTranscription();
    _whisperTranscriber?.dispose();
    _coreMLTranscriber?.unloadModel();
  }
}

class ModelInfo {
  final String name;
  final String displayName;
  final String size;
  final bool isDownloaded;
  final String? localPath;
  final TranscriptionBackend backend;
  
  const ModelInfo({
    required this.name,
    required this.displayName,
    required this.size,
    required this.isDownloaded,
    this.localPath,
    required this.backend,
  });
}

class TranscriptionException implements Exception {
  final String message;
  const TranscriptionException(this.message);
  
  @override
  String toString() => 'TranscriptionException: $message';
}