import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  
  bool get isRecording => _isRecording;
  bool _isRecording = false;
  
  /// Record audio from microphone
  Future<String?> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.wav';
        final filePath = path.join(appDir.path, fileName);
        
        const config = RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 128000,
        );
        
        await _recorder.start(config, path: filePath);
        _isRecording = true;
        return filePath;
      }
      return null;
    } catch (e) {
      print('Error starting recording: $e');
      return null;
    }
  }
  
  /// Stop recording and return the file path
  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      _isRecording = false;
      return path;
    } catch (e) {
      print('Error stopping recording: $e');
      return null;
    }
  }
  
  /// Convert audio file to the required format for transcription
  Future<AudioData> loadAudioFile(File audioFile) async {
    try {
      // For now, we'll use a simple approach
      // In production, you might want to use FFmpeg through FFI
      final bytes = await audioFile.readAsBytes();
      
      // Load with just_audio to get duration and sample rate info
      await _player.setFilePath(audioFile.path);
      final duration = _player.duration?.inMilliseconds ?? 0;
      
      // Convert to WAV format if needed
      final wavData = await _convertToWav(audioFile);
      
      return AudioData(
        samples: wavData.samples,
        sampleRate: wavData.sampleRate,
        duration: Duration(milliseconds: duration),
        channels: wavData.channels,
      );
    } catch (e) {
      throw AudioProcessingException('Failed to load audio file: $e');
    }
  }
  
  /// Download audio from URL
  Future<File> downloadAudioFromUrl(String url, {
    Function(double progress)? onProgress,
  }) async {
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        throw AudioDownloadException('Failed to download audio: ${response.statusCode}');
      }
      
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'downloaded_${DateTime.now().millisecondsSinceEpoch}.${_getFileExtension(url)}';
      final file = File(path.join(appDir.path, fileName));
      
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } catch (e) {
      throw AudioDownloadException('Failed to download audio: $e');
    }
  }
  
  /// Convert audio file to WAV format using native processing
  Future<WavData> _convertToWav(File audioFile) async {
    try {
      // Use method channel to call native audio processing
      const platform = MethodChannel('com.susurrus.audio_processing');
      
      final result = await platform.invokeMethod('convertToWav', {
        'filePath': audioFile.path,
        'sampleRate': 16000,
        'channels': 1,
      });
      
      final samples = Float32List.fromList(
        (result['samples'] as List<dynamic>).cast<double>()
      );
      
      return WavData(
        samples: samples,
        sampleRate: result['sampleRate'] as int,
        channels: result['channels'] as int,
      );
    } catch (e) {
      // Fallback: basic WAV processing
      return await _basicWavProcessing(audioFile);
    }
  }
  
  /// Basic WAV file processing fallback
  Future<WavData> _basicWavProcessing(File audioFile) async {
    final bytes = await audioFile.readAsBytes();
    
    // Simple WAV header parsing
    if (bytes.length < 44) {
      throw AudioProcessingException('Invalid WAV file: too short');
    }
    
    // Check WAV signature
    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    final wave = String.fromCharCodes(bytes.sublist(8, 12));
    
    if (riff != 'RIFF' || wave != 'WAVE') {
      throw AudioProcessingException('Not a valid WAV file');
    }
    
    // Extract format information
    final channels = bytes[22] | (bytes[23] << 8);
    final sampleRate = bytes[24] | (bytes[25] << 8) | (bytes[26] << 16) | (bytes[27] << 24);
    final bitsPerSample = bytes[34] | (bytes[35] << 8);
    
    // Find data chunk
    int dataOffset = 44;
    while (dataOffset < bytes.length - 8) {
      final chunkId = String.fromCharCodes(bytes.sublist(dataOffset, dataOffset + 4));
      final chunkSize = bytes[dataOffset + 4] | (bytes[dataOffset + 5] << 8) | 
                       (bytes[dataOffset + 6] << 16) | (bytes[dataOffset + 7] << 24);
      
      if (chunkId == 'data') {
        dataOffset += 8;
        break;
      }
      
      dataOffset += 8 + chunkSize;
    }
    
    // Extract audio samples
    final audioData = bytes.sublist(dataOffset);
    final samples = Float32List(audioData.length ~/ (bitsPerSample ~/ 8));
    
    if (bitsPerSample == 16) {
      for (int i = 0; i < samples.length; i++) {
        final sample = audioData[i * 2] | (audioData[i * 2 + 1] << 8);
        samples[i] = (sample - 32768) / 32768.0; // Convert to float
      }
    } else if (bitsPerSample == 32) {
      final byteData = ByteData.sublistView(Uint8List.fromList(audioData));
      for (int i = 0; i < samples.length; i++) {
        samples[i] = byteData.getFloat32(i * 4, Endian.little);
      }
    }
    
    return WavData(
      samples: samples,
      sampleRate: sampleRate,
      channels: channels,
    );
  }
  
  /// Play audio file for preview
  Future<void> playAudio(File audioFile) async {
    try {
      await _player.setFilePath(audioFile.path);
      await _player.play();
    } catch (e) {
      throw AudioPlaybackException('Failed to play audio: $e');
    }
  }
  
  /// Stop audio playback
  Future<void> stopPlayback() async {
    await _player.stop();
  }
  
  /// Get audio file information
  Future<AudioInfo> getAudioInfo(File audioFile) async {
    try {
      await _player.setFilePath(audioFile.path);
      
      return AudioInfo(
        duration: _player.duration ?? Duration.zero,
        fileName: path.basename(audioFile.path),
        fileSize: await audioFile.length(),
        filePath: audioFile.path,
      );
    } catch (e) {
      throw AudioProcessingException('Failed to get audio info: $e');
    }
  }
  
  String _getFileExtension(String url) {
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    if (pathSegments.isNotEmpty) {
      final fileName = pathSegments.last;
      final lastDot = fileName.lastIndexOf('.');
      if (lastDot != -1) {
        return fileName.substring(lastDot + 1);
      }
    }
    return 'mp3'; // Default extension
  }
  
  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}

class AudioData {
  final Float32List samples;
  final int sampleRate;
  final Duration duration;
  final int channels;
  
  const AudioData({
    required this.samples,
    required this.sampleRate,
    required this.duration,
    required this.channels,
  });
  
  double get durationInSeconds => duration.inMilliseconds / 1000.0;
  int get totalSamples => samples.length;
}

class WavData {
  final Float32List samples;
  final int sampleRate;
  final int channels;
  
  const WavData({
    required this.samples,
    required this.sampleRate,
    required this.channels,
  });
}

class AudioInfo {
  final Duration duration;
  final String fileName;
  final int fileSize;
  final String filePath;
  
  const AudioInfo({
    required this.duration,
    required this.fileName,
    required this.fileSize,
    required this.filePath,
  });
  
  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  String get formattedFileSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}

// Exceptions
class AudioProcessingException implements Exception {
  final String message;
  const AudioProcessingException(this.message);
  
  @override
  String toString() => 'AudioProcessingException: $message';
}

class AudioDownloadException implements Exception {
  final String message;
  const AudioDownloadException(this.message);
  
  @override
  String toString() => 'AudioDownloadException: $message';
}

class AudioPlaybackException implements Exception {
  final String message;
  const AudioPlaybackException(this.message);
  
  @override
  String toString() => 'AudioPlaybackException: $message';
}