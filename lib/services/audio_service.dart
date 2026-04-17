import 'dart:io';
import 'dart:typed_data';
import 'package:crispasr/crispasr.dart' as crispasr;
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

import 'log_service.dart';

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
  
  /// Convert an arbitrary audio file to mono 16 kHz float32 PCM.
  ///
  /// Tiered approach, fastest-first:
  ///   1. **CrispASR FFI decoder** — `crispasr_audio_load`, shipped inside
  ///      libcrispasr. Handles WAV / MP3 / FLAC with internal resample
  ///      + down-mix. Cross-platform everywhere libwhisper runs.
  ///   2. **Legacy iOS/macOS method channel** — only if the FFI decoder
  ///      isn't in the bundled library (pre-0.4.1 CrispASR).
  ///   3. **Pure-Dart WAV parser** — last-resort for .wav files.
  Future<WavData> _convertToWav(File audioFile) async {
    // 1. FFI decoder. Runs on any platform that loaded libcrispasr.
    try {
      final decoded = crispasr.decodeAudioFile(audioFile.path);
      Log.instance.d('audio',
          'Decoded ${path.basename(audioFile.path)} via FFI: '
          '${decoded.samples.length} samples @${decoded.sampleRate} Hz');
      return WavData(
        samples: decoded.samples,
        sampleRate: decoded.sampleRate,
        channels: 1,
      );
    } on UnsupportedError catch (e) {
      // FFI binding missing — older dylib. Fall through to tier 2.
      Log.instance.w('audio', 'FFI decoder not available: $e');
    } catch (e, st) {
      // Decoder present but the file failed to load — could be an unsupported
      // container (Ogg Vorbis) or a corrupt file. Fall back to legacy path.
      Log.instance.w('audio',
          'FFI decoder rejected ${audioFile.path}; trying fallbacks',
          error: e, stack: st);
    }

    // 2. Legacy method channel (iOS/macOS only).
    try {
      const platform = MethodChannel('com.susurrus.audio_processing');
      final result = await platform.invokeMethod('convertToWav', {
        'filePath': audioFile.path,
        'sampleRate': 16000,
        'channels': 1,
      });
      final samples = Float32List.fromList(
        (result['samples'] as List).cast<double>(),
      );
      return WavData(
        samples: samples,
        sampleRate: result['sampleRate'] as int,
        channels: result['channels'] as int,
      );
    } catch (_) {
      // Method channel missing / rejected — fall through.
    }

    // 3. Pure-Dart WAV header parser. Only succeeds for actual .wav files.
    return await _basicWavProcessing(audioFile);
  }
  
  /// Basic WAV file processing fallback
  Future<WavData> _basicWavProcessing(File audioFile) async {
    final bytes = await audioFile.readAsBytes();
    final byteData = ByteData.sublistView(bytes);

    // Simple WAV header parsing
    if (bytes.length < 12) {
      throw AudioProcessingException('Invalid WAV file: too short');
    }

    // Check WAV signature
    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    final wave = String.fromCharCodes(bytes.sublist(8, 12));

    if (riff != 'RIFF' || wave != 'WAVE') {
      throw AudioProcessingException('Not a valid WAV file');
    }

    int channels = 0;
    int sampleRate = 0;
    int bitsPerSample = 0;
    int dataOffset = -1;
    int dataSize = 0;

    // Iterate through chunks starting from offset 12
    int offset = 12;
    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = byteData.getUint32(offset + 4, Endian.little);
      offset += 8;

      if (chunkId == 'fmt ') {
        if (chunkSize < 16) {
          throw AudioProcessingException('Invalid fmt chunk size');
        }
        channels = byteData.getUint16(offset + 2, Endian.little);
        sampleRate = byteData.getUint32(offset + 4, Endian.little);
        bitsPerSample = byteData.getUint16(offset + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataOffset = offset;
        dataSize = chunkSize;
        // We found data, but we might still need fmt if it comes later (rare but possible)
        // or we can break if we already have fmt.
        if (channels > 0) break;
      }

      offset += chunkSize;
      // WAV chunks are padded to 2 bytes
      if (chunkSize % 2 != 0) offset++;
    }

    if (dataOffset == -1) {
      throw AudioProcessingException('No data chunk found in WAV file');
    }
    if (channels == 0) {
      throw AudioProcessingException('No fmt chunk found in WAV file');
    }

    // Ensure we don't read past the end of the file
    final actualDataSize = (bytes.length - dataOffset);
    final sizeToRead = dataSize < actualDataSize ? dataSize : actualDataSize;
    
    final samplesCount = sizeToRead ~/ (bitsPerSample ~/ 8);
    final samples = Float32List(samplesCount);

    if (bitsPerSample == 16) {
      for (int i = 0; i < samplesCount; i++) {
        final pos = dataOffset + i * 2;
        if (pos + 1 >= bytes.length) break;
        var raw = byteData.getInt16(pos, Endian.little);
        samples[i] = raw / 32768.0;
      }
    } else if (bitsPerSample == 32) {
      for (int i = 0; i < samplesCount; i++) {
        final pos = dataOffset + i * 4;
        if (pos + 3 >= bytes.length) break;
        samples[i] = byteData.getFloat32(pos, Endian.little);
      }
    } else {
      throw AudioProcessingException('Unsupported bits per sample: $bitsPerSample');
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