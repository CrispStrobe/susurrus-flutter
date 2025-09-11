import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../main.dart'; // For TranscriptionSegment
import 'audio_service.dart';
import 'model_service.dart';
import 'diarization_service.dart';

enum TranscriptionBackend {
  whisperCpp,
  coreML,
  auto,
  mock, // Add mock for testing
}

class TranscriptionService {
  final AudioService _audioService;
  final ModelService _modelService = ModelService();
  final DiarizationService _diarizationService = DiarizationService();

  // Current implementation state
  TranscriptionBackend _currentBackend = TranscriptionBackend.mock;
  String? _currentModel;
  bool _isTranscribing = false;
  Timer? _mockTimer;

  // Mock engine state
  bool _isMockInitialized = false;
  final List<String> _mockTranscriptions = [
    "This is a mock transcription result. The audio quality appears to be good and the speech is clear.",
    "Welcome to the mock transcription engine. This demonstrates the interface without requiring actual models.",
    "The mock engine simulates realistic transcription behavior including processing delays and segment boundaries.",
    "For testing purposes, this engine generates predictable responses with timing information.",
    "Production engines will replace this mock with actual speech recognition capabilities.",
  ];

  TranscriptionService(this._audioService);

  bool get isTranscribing => _isTranscribing;
  TranscriptionBackend get currentBackend => _currentBackend;
  String? get currentModel => _currentModel;

  /// Initialize the transcription service with a specific backend
  Future<void> initialize({
    TranscriptionBackend backend = TranscriptionBackend.mock,
    String modelName = 'base',
  }) async {
    try {
      _currentBackend = await _selectBestBackend(backend);

      switch (_currentBackend) {
        case TranscriptionBackend.mock:
          await _initializeMock(modelName);
          break;
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

      // Perform transcription based on current backend
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
    _mockTimer?.cancel();
    _mockTimer = null;
    _isTranscribing = false;
  }

  /// Change the transcription model
  Future<bool> changeModel(String modelName) async {
    if (_isTranscribing) {
      throw TranscriptionException('Cannot change model while transcribing');
    }

    try {
      switch (_currentBackend) {
        case TranscriptionBackend.mock:
          return await _initializeMock(modelName);
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
      case TranscriptionBackend.mock:
        return await _getMockModels();
      case TranscriptionBackend.coreML:
        return await _modelService.getCoreMLModels();
      case TranscriptionBackend.whisperCpp:
        return await _modelService.getWhisperCppModels();
      case TranscriptionBackend.auto:
        return [];
    }
  }

  // Backend selection and initialization

  Future<TranscriptionBackend> _selectBestBackend(TranscriptionBackend requested) async {
    if (requested != TranscriptionBackend.auto) {
      return requested;
    }

    // For now, always prefer mock for safe testing
    // Later, check platform capabilities
    if (Platform.isIOS) {
      // TODO: Check CoreML availability
      return TranscriptionBackend.mock; // Use mock until CoreML is ready
    } else if (Platform.isAndroid) {
      // TODO: Check whisper.cpp availability  
      return TranscriptionBackend.mock; // Use mock until whisper.cpp is ready
    }

    return TranscriptionBackend.mock;
  }

  Future<bool> _initializeMock(String modelName) async {
    try {
      // Simulate initialization delay
      await Future.delayed(const Duration(milliseconds: 500));
      _isMockInitialized = true;
      return true;
    } catch (e) {
      print('Mock initialization failed: $e');
      return false;
    }
  }

  Future<bool> _initializeCoreML(String modelName) async {
    if (!Platform.isIOS) {
      print('CoreML only available on iOS');
      return false;
    }

    try {
      // TODO: Implement actual CoreML initialization
      // For now, fall back to mock
      print('CoreML not yet implemented, using mock');
      return await _initializeMock(modelName);
    } catch (e) {
      print('CoreML initialization failed: $e');
      return false;
    }
  }

  Future<bool> _initializeWhisperCpp(String modelName) async {
    try {
      // TODO: Implement actual Whisper.cpp initialization
      // For now, fall back to mock
      print('Whisper.cpp not yet implemented, using mock');
      return await _initializeMock(modelName);
    } catch (e) {
      print('Whisper.cpp initialization failed: $e');
      return false;
    }
  }

  // Transcription implementation

  Future<List<TranscriptionSegment>> _performTranscription(
    Float32List audioSamples, {
    String? language,
    Function(double progress)? onProgress,
    Function(TranscriptionSegment segment)? onSegment,
  }) async {
    switch (_currentBackend) {
      case TranscriptionBackend.mock:
        return await _transcribeWithMock(audioSamples, onProgress: onProgress, onSegment: onSegment);
      case TranscriptionBackend.coreML:
        return await _transcribeWithCoreML(audioSamples, language: language, onProgress: onProgress, onSegment: onSegment);
      case TranscriptionBackend.whisperCpp:
        return await _transcribeWithWhisperCpp(audioSamples, onProgress: onProgress, onSegment: onSegment);
      case TranscriptionBackend.auto:
        throw TranscriptionException('Backend not initialized');
    }
  }

  Future<List<TranscriptionSegment>> _transcribeWithMock(
    Float32List audioSamples, {
    Function(double progress)? onProgress,
    Function(TranscriptionSegment segment)? onSegment,
  }) async {
    if (!_isMockInitialized) {
      throw TranscriptionException('Mock engine not initialized');
    }

    try {
      final segments = <TranscriptionSegment>[];
      
      // Calculate number of segments based on audio length
      final numSegments = _calculateSegmentCount(audioSamples.length);
      
      for (int i = 0; i < numSegments; i++) {
        // Simulate processing time
        await Future.delayed(const Duration(milliseconds: 300));
        
        // Report progress
        onProgress?.call((i + 1) / numSegments);
        
        // Generate mock segment
        final segment = _generateMockSegment(i, numSegments);
        segments.add(segment);
        
        // Call segment callback
        onSegment?.call(segment);
        
        // Check if transcription was cancelled
        if (!_isTranscribing) {
          break;
        }
      }

      return segments;
    } catch (e) {
      throw TranscriptionException('Mock transcription failed: $e');
    }
  }

  Future<List<TranscriptionSegment>> _transcribeWithCoreML(
    Float32List audioSamples, {
    String? language,
    Function(double progress)? onProgress,
    Function(TranscriptionSegment segment)? onSegment,
  }) async {
    // TODO: Implement actual CoreML transcription
    // For now, delegate to mock
    print('CoreML transcription not yet implemented, using mock');
    return await _transcribeWithMock(audioSamples, onProgress: onProgress, onSegment: onSegment);
  }

  Future<List<TranscriptionSegment>> _transcribeWithWhisperCpp(
    Float32List audioSamples, {
    Function(double progress)? onProgress,
    Function(TranscriptionSegment segment)? onSegment,
  }) async {
    // TODO: Implement actual Whisper.cpp transcription
    // For now, delegate to mock
    print('Whisper.cpp transcription not yet implemented, using mock');
    return await _transcribeWithMock(audioSamples, onProgress: onProgress, onSegment: onSegment);
  }

  // Mock implementation helpers

  int _calculateSegmentCount(int audioLength) {
    // Assume segments of ~5 seconds at 16kHz
    const samplesPerSecond = 16000;
    const secondsPerSegment = 5;
    const samplesPerSegment = samplesPerSecond * secondsPerSegment;
    
    return (audioLength / samplesPerSegment).ceil().clamp(1, 10);
  }

  TranscriptionSegment _generateMockSegment(int index, int totalSegments) {
    final segmentDuration = 5.0; // 5 seconds per segment
    final startTime = index * segmentDuration;
    final endTime = startTime + segmentDuration;
    
    final responseIndex = index % _mockTranscriptions.length;
    final text = _mockTranscriptions[responseIndex];
    
    return TranscriptionSegment(
      text: text,
      startTime: startTime,
      endTime: endTime,
      confidence: 0.85 + (Random().nextDouble() * 0.1), // 0.85-0.95
    );
  }

  Future<List<ModelInfo>> _getMockModels() async {
    return [
      const ModelInfo(
        name: 'mock-tiny',
        displayName: 'Mock Tiny',
        size: '39 MB',
        isDownloaded: true,
        localPath: '/mock/path/tiny.bin',
        backend: TranscriptionBackend.mock,
      ),
      const ModelInfo(
        name: 'mock-base',
        displayName: 'Mock Base',
        size: '74 MB',
        isDownloaded: true,
        localPath: '/mock/path/base.bin',
        backend: TranscriptionBackend.mock,
      ),
      const ModelInfo(
        name: 'mock-large',
        displayName: 'Mock Large',
        size: '1.5 GB',
        isDownloaded: false,
        backend: TranscriptionBackend.mock,
      ),
    ];
  }

  void dispose() {
    stopTranscription();
    _mockTimer?.cancel();
  }
}

// Keep existing ModelInfo class structure for compatibility
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