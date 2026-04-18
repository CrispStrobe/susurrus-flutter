import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:path/path.dart' as path;

class AudioUtils {
  static const int defaultSampleRate = 16000;
  static const int defaultChannels = 1;
  static const int defaultBitDepth = 16;

  /// Get supported audio file extensions
  static const List<String> supportedExtensions = [
    '.wav',
    '.mp3',
    '.m4a',
    '.aac',
    '.ogg',
    '.flac',
    '.opus',
    '.webm',
    '.mp4',
  ];

  /// Check if a file is a supported audio format
  static bool isSupportedAudioFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return supportedExtensions.contains(extension);
  }

  /// Get audio format from file extension
  static String getAudioFormat(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.wav':
        return 'wav';
      case '.mp3':
        return 'mp3';
      case '.m4a':
      case '.mp4':
        return 'm4a';
      case '.aac':
        return 'aac';
      case '.ogg':
        return 'ogg';
      case '.flac':
        return 'flac';
      case '.opus':
        return 'opus';
      case '.webm':
        return 'webm';
      default:
        return 'unknown';
    }
  }

  /// Format duration in seconds to human-readable string
  static String formatDuration(double seconds) {
    if (seconds.isNaN || seconds.isInfinite) {
      return '00:00';
    }

    final hours = (seconds / 3600).floor();
    final minutes = ((seconds % 3600) / 60).floor();
    final secs = (seconds % 60).floor();

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}';
    }
  }

  /// Format file size in bytes to human-readable string
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Convert Float32List to bytes for native processing
  static Uint8List float32ListToBytes(Float32List floats) {
    final buffer = ByteData(floats.length * 4);
    for (int i = 0; i < floats.length; i++) {
      buffer.setFloat32(i * 4, floats[i], Endian.little);
    }
    return buffer.buffer.asUint8List();
  }

  /// Convert bytes to Float32List from native processing
  static Float32List bytesToFloat32List(Uint8List bytes) {
    final buffer = ByteData.sublistView(bytes);
    final floats = Float32List(bytes.length ~/ 4);
    for (int i = 0; i < floats.length; i++) {
      floats[i] = buffer.getFloat32(i * 4, Endian.little);
    }
    return floats;
  }

  /// Normalize audio samples to [-1, 1] range
  static Float32List normalizeAudio(Float32List samples) {
    if (samples.isEmpty) return samples;

    final maxValue = samples.map((s) => s.abs()).reduce(max);
    if (maxValue == 0.0) return samples;

    return Float32List.fromList(samples.map((s) => s / maxValue).toList());
  }

  /// Apply pre-emphasis filter to audio samples
  static Float32List applyPreEmphasis(Float32List samples,
      [double alpha = 0.97]) {
    if (samples.length <= 1) return samples;

    final result = Float32List(samples.length);
    result[0] = samples[0];

    for (int i = 1; i < samples.length; i++) {
      result[i] = samples[i] - alpha * samples[i - 1];
    }

    return result;
  }

  /// Calculate RMS (Root Mean Square) of audio samples
  static double calculateRMS(Float32List samples) {
    if (samples.isEmpty) return 0.0;

    double sum = 0.0;
    for (final sample in samples) {
      sum += sample * sample;
    }

    return sqrt(sum / samples.length);
  }

  /// Calculate peak amplitude of audio samples
  static double calculatePeak(Float32List samples) {
    if (samples.isEmpty) return 0.0;

    return samples.map((s) => s.abs()).reduce(max);
  }

  /// Detect silence in audio samples
  static bool isSilence(Float32List samples, {double threshold = 0.01}) {
    if (samples.isEmpty) return true;

    final rms = calculateRMS(samples);
    return rms < threshold;
  }

  /// Split audio into chunks based on silence
  static List<AudioChunk> splitOnSilence(
    Float32List samples,
    int sampleRate, {
    double minSilenceDuration = 0.5,
    double silenceThreshold = 0.01,
    double minChunkDuration = 1.0,
  }) {
    final chunks = <AudioChunk>[];
    final minSilenceSamples = (minSilenceDuration * sampleRate).round();
    final minChunkSamples = (minChunkDuration * sampleRate).round();

    int chunkStart = 0;
    int silenceStart = -1;
    int silenceLength = 0;

    for (int i = 0; i < samples.length; i++) {
      final isSilent = samples[i].abs() < silenceThreshold;

      if (isSilent) {
        if (silenceStart == -1) {
          silenceStart = i;
        }
        silenceLength = i - silenceStart + 1;
      } else {
        if (silenceLength >= minSilenceSamples &&
            silenceStart > chunkStart + minChunkSamples) {
          // Found a significant silence gap, create a chunk
          final chunkEnd = silenceStart;
          final chunkSamples = samples.sublist(chunkStart, chunkEnd);
          final startTime = chunkStart / sampleRate;
          final endTime = chunkEnd / sampleRate;

          chunks.add(AudioChunk(
            samples: Float32List.fromList(chunkSamples),
            startTime: startTime,
            endTime: endTime,
            sampleRate: sampleRate,
          ));

          chunkStart = i;
        }

        silenceStart = -1;
        silenceLength = 0;
      }
    }

    // Add the final chunk if it's long enough
    if (chunkStart < samples.length - minChunkSamples) {
      final chunkSamples = samples.sublist(chunkStart);
      final startTime = chunkStart / sampleRate;
      final endTime = samples.length / sampleRate;

      chunks.add(AudioChunk(
        samples: Float32List.fromList(chunkSamples),
        startTime: startTime,
        endTime: endTime,
        sampleRate: sampleRate,
      ));
    }

    return chunks;
  }

  /// Apply simple noise reduction using spectral subtraction
  static Float32List reduceNoise(Float32List samples,
      {double noiseReduction = 0.5}) {
    // This is a simplified noise reduction implementation
    // In production, you'd want more sophisticated algorithms

    if (samples.length < 1024) return samples;

    // Estimate noise floor from first 10% of audio
    final noiseEstimateLength = (samples.length * 0.1).round();
    final noiseEstimate = calculateRMS(samples.sublist(0, noiseEstimateLength));

    // Apply noise gate
    final threshold = noiseEstimate * (1.0 + noiseReduction);

    return Float32List.fromList(samples.map((sample) {
      final amplitude = sample.abs();
      if (amplitude < threshold) {
        return sample * (amplitude / threshold) * noiseReduction;
      }
      return sample;
    }).toList());
  }

  /// Convert stereo audio to mono by averaging channels
  static Float32List stereoToMono(Float32List stereoSamples) {
    if (stereoSamples.length % 2 != 0) {
      throw ArgumentError('Stereo audio must have an even number of samples');
    }

    final monoLength = stereoSamples.length ~/ 2;
    final monoSamples = Float32List(monoLength);

    for (int i = 0; i < monoLength; i++) {
      final leftSample = stereoSamples[i * 2];
      final rightSample = stereoSamples[i * 2 + 1];
      monoSamples[i] = (leftSample + rightSample) / 2.0;
    }

    return monoSamples;
  }

  /// Simple resampling using linear interpolation
  static Float32List resample(Float32List samples, int fromRate, int toRate) {
    if (fromRate == toRate) return samples;

    final ratio = fromRate / toRate;
    final outputLength = (samples.length / ratio).round();
    final output = Float32List(outputLength);

    for (int i = 0; i < outputLength; i++) {
      final srcIndex = i * ratio;
      final srcIndexFloor = srcIndex.floor();
      final srcIndexCeil = srcIndex.ceil();

      if (srcIndexCeil >= samples.length) {
        output[i] = samples[samples.length - 1];
      } else if (srcIndexFloor == srcIndexCeil) {
        output[i] = samples[srcIndexFloor];
      } else {
        // Linear interpolation
        final fraction = srcIndex - srcIndexFloor;
        final sample1 = samples[srcIndexFloor];
        final sample2 = samples[srcIndexCeil];
        output[i] = sample1 + (sample2 - sample1) * fraction;
      }
    }

    return output;
  }

  /// Generate a sine wave for testing
  static Float32List generateSineWave(
    double frequency,
    double duration,
    int sampleRate, {
    double amplitude = 0.5,
  }) {
    final numSamples = (duration * sampleRate).round();
    final samples = Float32List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      samples[i] = amplitude * sin(2 * pi * frequency * t);
    }

    return samples;
  }

  /// Validate audio file
  static Future<AudioValidationResult> validateAudioFile(File file) async {
    try {
      if (!await file.exists()) {
        return AudioValidationResult(
          isValid: false,
          error: 'File does not exist',
        );
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        return AudioValidationResult(
          isValid: false,
          error: 'File is empty',
        );
      }

      if (fileSize > 100 * 1024 * 1024) {
        // 100MB limit
        return AudioValidationResult(
          isValid: false,
          error: 'File is too large (max 100MB)',
        );
      }

      if (!isSupportedAudioFile(file.path)) {
        return AudioValidationResult(
          isValid: false,
          error: 'Unsupported audio format',
        );
      }

      return AudioValidationResult(
        isValid: true,
        fileSize: fileSize,
        format: getAudioFormat(file.path),
      );
    } catch (e) {
      return AudioValidationResult(
        isValid: false,
        error: 'Error validating file: $e',
      );
    }
  }
}

class AudioChunk {
  final Float32List samples;
  final double startTime;
  final double endTime;
  final int sampleRate;

  const AudioChunk({
    required this.samples,
    required this.startTime,
    required this.endTime,
    required this.sampleRate,
  });

  double get duration => endTime - startTime;
  int get sampleCount => samples.length;
  double get rms => AudioUtils.calculateRMS(samples);
  double get peak => AudioUtils.calculatePeak(samples);
}

class AudioValidationResult {
  final bool isValid;
  final String? error;
  final int? fileSize;
  final String? format;

  const AudioValidationResult({
    required this.isValid,
    this.error,
    this.fileSize,
    this.format,
  });
}
