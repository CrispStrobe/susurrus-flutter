import 'dart:ffi';
import 'dart:typed_data';
import 'dart:io';
import 'package:ffi/ffi.dart';

// FFI bindings for whisper.cpp
typedef WhisperContextNew = Pointer Function(Pointer<Utf8> modelPath);
typedef WhisperContextFree = Void Function(Pointer ctx);
typedef WhisperFull = Int32 Function(
  Pointer ctx,
  Pointer<Float> samples,
  Int32 nSamples,
);
typedef WhisperFullGetSegmentCount = Int32 Function(Pointer ctx);
typedef WhisperFullGetSegmentText = Pointer<Utf8> Function(Pointer ctx, Int32 segment);
typedef WhisperFullGetSegmentT0 = Int64 Function(Pointer ctx, Int32 segment);
typedef WhisperFullGetSegmentT1 = Int64 Function(Pointer ctx, Int32 segment);

// Dart function signatures
typedef WhisperContextNewDart = Pointer Function(Pointer<Utf8> modelPath);
typedef WhisperContextFreeDart = void Function(Pointer ctx);
typedef WhisperFullDart = int Function(
  Pointer ctx,
  Pointer<Float> samples,
  int nSamples,
);
typedef WhisperFullGetSegmentCountDart = int Function(Pointer ctx);
typedef WhisperFullGetSegmentTextDart = Pointer<Utf8> Function(Pointer ctx, int segment);
typedef WhisperFullGetSegmentT0Dart = int Function(Pointer ctx, int segment);
typedef WhisperFullGetSegmentT1Dart = int Function(Pointer ctx, int segment);

class WhisperBinding {
  static WhisperBinding? _instance;
  late final DynamicLibrary _dylib;
  
  // Function pointers
  late final WhisperContextNewDart whisperInit;
  late final WhisperContextFreeDart whisperFree;
  late final WhisperFullDart whisperFull;
  late final WhisperFullGetSegmentCountDart whisperFullGetSegmentCount;
  late final WhisperFullGetSegmentTextDart whisperFullGetSegmentText;
  late final WhisperFullGetSegmentT0Dart whisperFullGetSegmentT0;
  late final WhisperFullGetSegmentT1Dart whisperFullGetSegmentT1;

  WhisperBinding._() {
    _loadLibrary();
    _bindFunctions();
  }

  static WhisperBinding get instance {
    _instance ??= WhisperBinding._();
    return _instance!;
  }

  void _loadLibrary() {
    if (Platform.isAndroid) {
      _dylib = DynamicLibrary.open('libwhisper.so');
    } else if (Platform.isIOS) {
      _dylib = DynamicLibrary.executable();
    } else if (Platform.isMacOS) {
      _dylib = DynamicLibrary.open('libwhisper.dylib');
    } else if (Platform.isWindows) {
      _dylib = DynamicLibrary.open('whisper.dll');
    } else {
      _dylib = DynamicLibrary.open('libwhisper.so');
    }
  }

  void _bindFunctions() {
    whisperInit = _dylib.lookupFunction<WhisperContextNew, WhisperContextNewDart>(
      'whisper_init_from_file'
    );
    
    whisperFree = _dylib.lookupFunction<WhisperContextFree, WhisperContextFreeDart>(
      'whisper_free'
    );
    
    whisperFull = _dylib.lookupFunction<WhisperFull, WhisperFullDart>(
      'whisper_full_default'
    );
    
    whisperFullGetSegmentCount = _dylib.lookupFunction<
      WhisperFullGetSegmentCount, 
      WhisperFullGetSegmentCountDart
    >('whisper_full_n_segments');
    
    whisperFullGetSegmentText = _dylib.lookupFunction<
      WhisperFullGetSegmentText, 
      WhisperFullGetSegmentTextDart
    >('whisper_full_get_segment_text');
    
    whisperFullGetSegmentT0 = _dylib.lookupFunction<
      WhisperFullGetSegmentT0, 
      WhisperFullGetSegmentT0Dart
    >('whisper_full_get_segment_t0');
    
    whisperFullGetSegmentT1 = _dylib.lookupFunction<
      WhisperFullGetSegmentT1, 
      WhisperFullGetSegmentT1Dart
    >('whisper_full_get_segment_t1');
  }
}

class WhisperContext {
  final Pointer _ctx;
  bool _disposed = false;

  WhisperContext._(this._ctx);

  static WhisperContext? fromFile(String modelPath) {
    final pathPtr = modelPath.toNativeUtf8();
    try {
      final ctx = WhisperBinding.instance.whisperInit(pathPtr);
      if (ctx == nullptr) {
        return null;
      }
      return WhisperContext._(ctx);
    } finally {
      malloc.free(pathPtr);
    }
  }

  List<TranscriptionSegment> transcribe(Float32List audioData) {
    if (_disposed) {
      throw StateError('WhisperContext has been disposed');
    }

    // Convert Float32List to native array
    final samplesPtr = malloc<Float>(audioData.length);
    for (int i = 0; i < audioData.length; i++) {
      samplesPtr[i] = audioData[i];
    }

    try {
      // Run transcription
      final result = WhisperBinding.instance.whisperFull(
        _ctx, 
        samplesPtr, 
        audioData.length
      );
      
      if (result != 0) {
        throw Exception('Whisper transcription failed with code: $result');
      }

      // Extract segments
      final segmentCount = WhisperBinding.instance.whisperFullGetSegmentCount(_ctx);
      final segments = <TranscriptionSegment>[];

      for (int i = 0; i < segmentCount; i++) {
        final textPtr = WhisperBinding.instance.whisperFullGetSegmentText(_ctx, i);
        final text = textPtr.toDartString();
        
        final t0 = WhisperBinding.instance.whisperFullGetSegmentT0(_ctx, i);
        final t1 = WhisperBinding.instance.whisperFullGetSegmentT1(_ctx, i);
        
        segments.add(TranscriptionSegment(
          text: text,
          startTime: t0 / 100.0, // Convert to seconds
          endTime: t1 / 100.0,   // Convert to seconds
        ));
      }

      return segments;
    } finally {
      malloc.free(samplesPtr);
    }
  }

  void dispose() {
    if (!_disposed) {
      WhisperBinding.instance.whisperFree(_ctx);
      _disposed = true;
    }
  }
}

class TranscriptionSegment {
  final String text;
  final double startTime;
  final double endTime;

  const TranscriptionSegment({
    required this.text,
    required this.startTime,
    required this.endTime,
  });

  @override
  String toString() {
    return '[${startTime.toStringAsFixed(3)} -> ${endTime.toStringAsFixed(3)}] $text';
  }
}

class WhisperTranscriber {
  WhisperContext? _context;
  String? _currentModelPath;

  bool get isLoaded => _context != null;

  Future<bool> loadModel(String modelPath) async {
    if (_currentModelPath == modelPath && _context != null) {
      return true; // Already loaded
    }

    // Dispose previous context
    _context?.dispose();

    // Load new model
    _context = WhisperContext.fromFile(modelPath);
    if (_context != null) {
      _currentModelPath = modelPath;
      return true;
    }
    
    return false;
  }

  Future<List<TranscriptionSegment>> transcribe(Float32List audioData) async {
    if (_context == null) {
      throw StateError('No model loaded. Call loadModel() first.');
    }

    return _context!.transcribe(audioData);
  }

  void dispose() {
    _context?.dispose();
    _context = null;
    _currentModelPath = null;
  }
}