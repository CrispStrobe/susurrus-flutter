import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';

// Method channel for CoreML integration
class CoreMLWhisper {
  static const MethodChannel _channel = MethodChannel('com.susurrus.coreml_whisper');
  
  static CoreMLWhisper? _instance;
  String? _loadedModelPath;
  
  CoreMLWhisper._();
  
  static CoreMLWhisper get instance {
    _instance ??= CoreMLWhisper._();
    return _instance!;
  }
  
  /// Check if CoreML is available (iOS only)
  Future<bool> get isAvailable async {
    if (!Platform.isIOS) return false;
    
    try {
      final result = await _channel.invokeMethod('isAvailable');
      return result as bool;
    } catch (e) {
      return false;
    }
  }
  
  /// Load a CoreML Whisper model
  Future<bool> loadModel(String modelPath) async {
    if (!Platform.isIOS) return false;
    
    try {
      final result = await _channel.invokeMethod('loadModel', {
        'modelPath': modelPath,
      });
      
      if (result as bool) {
        _loadedModelPath = modelPath;
      }
      
      return result;
    } catch (e) {
      print('Error loading CoreML model: $e');
      return false;
    }
  }
  
  /// Transcribe audio using CoreML
  Future<List<CoreMLTranscriptionSegment>> transcribe(
    Float32List audioData, {
    String? language,
    bool wordTimestamps = false,
  }) async {
    if (!Platform.isIOS) {
      throw UnsupportedError('CoreML is only available on iOS');
    }
    
    if (_loadedModelPath == null) {
      throw StateError('No model loaded. Call loadModel() first.');
    }
    
    try {
      final result = await _channel.invokeMethod('transcribe', {
        'audioData': audioData,
        'language': language,
        'wordTimestamps': wordTimestamps,
      });
      
      final segments = <CoreMLTranscriptionSegment>[];
      final resultList = (result as List).cast<dynamic>();

      for (final segmentData in resultList) {
        final segment =
            Map<String, dynamic>.from(segmentData as Map);
        segments.add(CoreMLTranscriptionSegment.fromMap(segment));
      }

      return segments;
    } catch (e) {
      print('Error during CoreML transcription: $e');
      rethrow;
    }
  }
  
  /// Get available CoreML models
  Future<List<String>> getAvailableModels() async {
    if (!Platform.isIOS) return [];
    
    try {
      final result = await _channel.invokeMethod('getAvailableModels');
      return List<String>.from(result as List);
    } catch (e) {
      return [];
    }
  }
  
  /// Download a CoreML model
  Future<bool> downloadModel(String modelName, {
    Function(double progress)? onProgress,
  }) async {
    if (!Platform.isIOS) return false;
    
    try {
      // Set up progress callback
      if (onProgress != null) {
        _channel.setMethodCallHandler((call) async {
          if (call.method == 'downloadProgress') {
            final progress = call.arguments as double;
            onProgress(progress);
          }
        });
      }
      
      final result = await _channel.invokeMethod('downloadModel', {
        'modelName': modelName,
      });
      
      return result as bool;
    } catch (e) {
      print('Error downloading CoreML model: $e');
      return false;
    }
  }
  
  /// Unload the current model to free memory
  Future<void> unloadModel() async {
    if (!Platform.isIOS) return;
    
    try {
      await _channel.invokeMethod('unloadModel');
      _loadedModelPath = null;
    } catch (e) {
      print('Error unloading CoreML model: $e');
    }
  }
}

class CoreMLTranscriptionSegment {
  final String text;
  final double startTime;
  final double endTime;
  final double confidence;
  final List<CoreMLWord>? words;
  
  const CoreMLTranscriptionSegment({
    required this.text,
    required this.startTime,
    required this.endTime,
    required this.confidence,
    this.words,
  });
  
  factory CoreMLTranscriptionSegment.fromMap(Map<String, dynamic> map) {
    return CoreMLTranscriptionSegment(
      text: map['text'] as String,
      startTime: (map['startTime'] as num).toDouble(),
      endTime: (map['endTime'] as num).toDouble(),
      confidence: (map['confidence'] as num).toDouble(),
      words: map['words'] != null
          ? (map['words'] as List)
              .cast<dynamic>()
              .map((w) => CoreMLWord.fromMap(Map<String, dynamic>.from(w as Map)))
              .toList()
          : null,
    );
  }
  
  @override
  String toString() {
    return '[${startTime.toStringAsFixed(3)} -> ${endTime.toStringAsFixed(3)}] $text (${(confidence * 100).toStringAsFixed(1)}%)';
  }
}

class CoreMLWord {
  final String word;
  final double startTime;
  final double endTime;
  final double confidence;
  
  const CoreMLWord({
    required this.word,
    required this.startTime,
    required this.endTime,
    required this.confidence,
  });
  
  factory CoreMLWord.fromMap(Map<String, dynamic> map) {
    return CoreMLWord(
      word: map['word'] as String,
      startTime: (map['startTime'] as num).toDouble(),
      endTime: (map['endTime'] as num).toDouble(),
      confidence: (map['confidence'] as num).toDouble(),
    );
  }
}

/// Model information for CoreML Whisper models
class CoreMLModelInfo {
  final String name;
  final String displayName;
  final String size;
  final String language;
  final bool isDownloaded;
  final String? localPath;
  
  const CoreMLModelInfo({
    required this.name,
    required this.displayName,
    required this.size,
    required this.language,
    required this.isDownloaded,
    this.localPath,
  });
  
  static const List<CoreMLModelInfo> availableModels = [
    CoreMLModelInfo(
      name: 'whisper-tiny',
      displayName: 'Whisper Tiny',
      size: '39 MB',
      language: 'multilingual',
      isDownloaded: false,
    ),
    CoreMLModelInfo(
      name: 'whisper-base',
      displayName: 'Whisper Base',
      size: '74 MB',
      language: 'multilingual',
      isDownloaded: false,
    ),
    CoreMLModelInfo(
      name: 'whisper-small',
      displayName: 'Whisper Small',
      size: '244 MB',
      language: 'multilingual',
      isDownloaded: false,
    ),
    CoreMLModelInfo(
      name: 'whisper-medium',
      displayName: 'Whisper Medium',
      size: '769 MB',
      language: 'multilingual',
      isDownloaded: false,
    ),
    CoreMLModelInfo(
      name: 'whisper-large-v2',
      displayName: 'Whisper Large v2',
      size: '1.5 GB',
      language: 'multilingual',
      isDownloaded: false,
    ),
  ];
}