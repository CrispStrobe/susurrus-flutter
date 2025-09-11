import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import '../main.dart';
import 'audio_service.dart';

/// Simple speaker diarization service using clustering-based approach
/// This replaces the Python pyannote.audio functionality with a lightweight implementation
class DiarizationService {
  static const int _hopLength = 512;
  static const int _windowSize = 2048;
  static const double _frameRate = 16000.0; // 16kHz sample rate
  
  /// Perform speaker diarization on transcription segments
  Future<List<TranscriptionSegment>> diarizeSegments(
    AudioData audioData,
    List<TranscriptionSegment> segments, {
    int? minSpeakers,
    int? maxSpeakers,
    Function(double progress)? onProgress,
  }) async {
    if (segments.isEmpty) return segments;
    
    try {
      onProgress?.call(0.0);
      
      // Extract speaker embeddings for each segment
      final embeddings = await _extractSegmentEmbeddings(
        audioData.samples,
        segments,
        onProgress: (progress) => onProgress?.call(progress * 0.7),
      );
      
      onProgress?.call(0.7);
      
      // Cluster embeddings to identify speakers
      final speakerLabels = await _clusterSpeakers(
        embeddings,
        minSpeakers: minSpeakers,
        maxSpeakers: maxSpeakers,
      );
      
      onProgress?.call(0.9);
      
      // Apply speaker labels to segments
      final diarizedSegments = <TranscriptionSegment>[];
      for (int i = 0; i < segments.length; i++) {
        final segment = segments[i];
        final speakerLabel = speakerLabels.length > i ? speakerLabels[i] : 0;
        
        diarizedSegments.add(TranscriptionSegment(
          text: segment.text,
          startTime: segment.startTime,
          endTime: segment.endTime,
          speaker: 'Speaker ${speakerLabel + 1}',
          confidence: segment.confidence,
        ));
      }
      
      onProgress?.call(1.0);
      return diarizedSegments;
    } catch (e) {
      throw DiarizationException('Speaker diarization failed: $e');
    }
  }
  
  /// Extract speaker embeddings for each segment using MFCC features
  Future<List<List<double>>> _extractSegmentEmbeddings(
    Float32List audioSamples,
    List<TranscriptionSegment> segments, {
    Function(double progress)? onProgress,
  }) async {
    final embeddings = <List<double>>[];
    
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      
      // Extract audio for this segment
      final startSample = (segment.startTime * _frameRate).round();
      final endSample = (segment.endTime * _frameRate).round();
      
      if (startSample >= 0 && endSample <= audioSamples.length && startSample < endSample) {
        final segmentAudio = audioSamples.sublist(startSample, endSample);
        
        // Extract MFCC features as a simple speaker embedding
        final mfccFeatures = await _extractMFCC(segmentAudio);
        
        // Compute mean and variance as a simple speaker embedding
        final embedding = _computeStatisticalFeatures(mfccFeatures);
        embeddings.add(embedding);
      } else {
        // Add default embedding for invalid segments
        embeddings.add(List.filled(26, 0.0)); // 13 MFCC + 13 delta features
      }
      
      onProgress?.call((i + 1) / segments.length);
    }
    
    return embeddings;
  }
  
  /// Extract MFCC features from audio segment
  Future<List<List<double>>> _extractMFCC(Float32List audioSamples) async {
    // Simplified MFCC extraction
    // In a production app, you might want to use a more sophisticated implementation
    // or call native code for better performance
    
    const int numMfcc = 13;
    const int numFrames = 100; // Fixed number of frames for consistency
    
    // Pre-emphasis filter
    final preEmphasized = _preEmphasis(audioSamples);
    
    // Frame the signal
    final frames = _frameSignal(preEmphasized, _windowSize, _hopLength);
    
    // Compute power spectrum
    final powerSpectra = frames.map((frame) => _computePowerSpectrum(frame)).toList();
    
    // Apply mel filter bank
    final melFeatures = powerSpectra.map((spectrum) => _applyMelFilterBank(spectrum)).toList();
    
    // Apply DCT to get MFCC
    final mfccFeatures = melFeatures.map((mel) => _dct(mel).take(numMfcc).toList()).toList();
    
    // Ensure consistent number of frames
    return _normalizeFrameCount(mfccFeatures, numFrames);
  }
  
  /// Pre-emphasis filter to balance the frequency spectrum
  Float32List _preEmphasis(Float32List signal, [double alpha = 0.97]) {
    final result = Float32List(signal.length);
    result[0] = signal[0];
    
    for (int i = 1; i < signal.length; i++) {
      result[i] = signal[i] - alpha * signal[i - 1];
    }
    
    return result;
  }
  
  /// Frame the signal into overlapping windows
  List<Float32List> _frameSignal(Float32List signal, int frameSize, int hopLength) {
    final frames = <Float32List>[];
    
    for (int start = 0; start + frameSize <= signal.length; start += hopLength) {
      final frame = signal.sublist(start, start + frameSize);
      
      // Apply Hamming window
      final windowedFrame = Float32List(frameSize);
      for (int i = 0; i < frameSize; i++) {
        final window = 0.54 - 0.46 * cos(2 * pi * i / (frameSize - 1));
        windowedFrame[i] = frame[i] * window;
      }
      
      frames.add(windowedFrame);
    }
    
    return frames;
  }
  
  /// Compute power spectrum using simplified FFT
  List<double> _computePowerSpectrum(Float32List frame) {
    // Simplified power spectrum computation
    // In production, you'd use a proper FFT implementation
    final spectrum = <double>[];
    
    for (int k = 0; k < frame.length ~/ 2; k++) {
      double real = 0.0;
      double imag = 0.0;
      
      for (int n = 0; n < frame.length; n++) {
        final angle = -2 * pi * k * n / frame.length;
        real += frame[n] * cos(angle);
        imag += frame[n] * sin(angle);
      }
      
      spectrum.add(real * real + imag * imag);
    }
    
    return spectrum;
  }
  
  /// Apply mel filter bank
  List<double> _applyMelFilterBank(List<double> powerSpectrum, [int numFilters = 26]) {
    // Simplified mel filter bank
    final melFilters = <double>[];
    
    for (int i = 0; i < numFilters; i++) {
      final filterResponse = _triangularFilter(powerSpectrum, i, numFilters);
      melFilters.add(filterResponse);
    }
    
    return melFilters;
  }
  
  /// Triangular filter for mel filter bank
  double _triangularFilter(List<double> spectrum, int filterIndex, int numFilters) {
    double sum = 0.0;
    final filterWidth = spectrum.length / numFilters;
    final start = (filterIndex * filterWidth).round();
    final end = ((filterIndex + 1) * filterWidth).round();
    
    for (int i = start; i < end && i < spectrum.length; i++) {
      sum += spectrum[i];
    }
    
    return sum / (end - start);
  }
  
  /// Discrete Cosine Transform
  List<double> _dct(List<double> input) {
    final output = <double>[];
    final N = input.length;
    
    for (int k = 0; k < N; k++) {
      double sum = 0.0;
      
      for (int n = 0; n < N; n++) {
        sum += input[n] * cos(pi * k * (2 * n + 1) / (2 * N));
      }
      
      output.add(sum);
    }
    
    return output;
  }
  
  /// Normalize frame count for consistent embeddings
  List<List<double>> _normalizeFrameCount(List<List<double>> frames, int targetFrames) {
    if (frames.length == targetFrames) return frames;
    
    if (frames.length < targetFrames) {
      // Repeat frames if too few
      final result = <List<double>>[];
      for (int i = 0; i < targetFrames; i++) {
        result.add(frames[i % frames.length]);
      }
      return result;
    } else {
      // Subsample if too many
      final step = frames.length / targetFrames;
      final result = <List<double>>[];
      for (int i = 0; i < targetFrames; i++) {
        final index = (i * step).round();
        result.add(frames[index.clamp(0, frames.length - 1)]);
      }
      return result;
    }
  }
  
  /// Compute statistical features from MFCC frames
  List<double> _computeStatisticalFeatures(List<List<double>> mfccFrames) {
    if (mfccFrames.isEmpty) return List.filled(26, 0.0);
    
    final numCoeffs = mfccFrames.first.length;
    final features = <double>[];
    
    // Compute mean and standard deviation for each MFCC coefficient
    for (int coeff = 0; coeff < numCoeffs; coeff++) {
      final values = mfccFrames.map((frame) => frame[coeff]).toList();
      
      // Mean
      final mean = values.reduce((a, b) => a + b) / values.length;
      features.add(mean);
      
      // Standard deviation
      final variance = values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
      features.add(sqrt(variance));
    }
    
    return features;
  }
  
  /// Cluster speaker embeddings using K-means
  Future<List<int>> _clusterSpeakers(
    List<List<double>> embeddings, {
    int? minSpeakers,
    int? maxSpeakers,
  }) async {
    if (embeddings.isEmpty) return [];
    
    // Determine optimal number of clusters
    int numClusters = _determineOptimalClusters(
      embeddings,
      minSpeakers: minSpeakers,
      maxSpeakers: maxSpeakers,
    );
    
    // Perform K-means clustering
    return _kMeansCluster(embeddings, numClusters);
  }
  
  /// Determine optimal number of clusters using elbow method
  int _determineOptimalClusters(
    List<List<double>> embeddings, {
    int? minSpeakers,
    int? maxSpeakers,
  }) {
    final minK = minSpeakers ?? 1;
    final maxK = maxSpeakers ?? min(embeddings.length, 6);
    
    if (minK == maxK) return minK;
    
    // Use elbow method to find optimal K
    final inertias = <double>[];
    
    for (int k = minK; k <= maxK; k++) {
      final labels = _kMeansCluster(embeddings, k);
      final inertia = _computeInertia(embeddings, labels, k);
      inertias.add(inertia);
    }
    
    // Find elbow (simplified approach)
    int optimalK = minK;
    double maxDecrease = 0.0;
    
    for (int i = 1; i < inertias.length; i++) {
      final decrease = inertias[i - 1] - inertias[i];
      if (decrease > maxDecrease) {
        maxDecrease = decrease;
        optimalK = minK + i;
      }
    }
    
    return optimalK;
  }
  
  /// K-means clustering implementation
  List<int> _kMeansCluster(List<List<double>> embeddings, int k) {
    if (embeddings.isEmpty || k <= 0) return [];
    if (k >= embeddings.length) {
      return List.generate(embeddings.length, (i) => i);
    }
    
    final random = Random();
    final dimensions = embeddings.first.length;
    
    // Initialize centroids randomly
    final centroids = <List<double>>[];
    for (int i = 0; i < k; i++) {
      final centroid = <double>[];
      for (int d = 0; d < dimensions; d++) {
        centroid.add(random.nextDouble() * 2 - 1); // Random value between -1 and 1
      }
      centroids.add(centroid);
    }
    
    List<int> labels = List.filled(embeddings.length, 0);
    const maxIterations = 100;
    
    for (int iteration = 0; iteration < maxIterations; iteration++) {
      final newLabels = <int>[];
      
      // Assign each point to nearest centroid
      for (final embedding in embeddings) {
        double minDistance = double.infinity;
        int nearestCentroid = 0;
        
        for (int c = 0; c < centroids.length; c++) {
          final distance = _euclideanDistance(embedding, centroids[c]);
          if (distance < minDistance) {
            minDistance = distance;
            nearestCentroid = c;
          }
        }
        
        newLabels.add(nearestCentroid);
      }
      
      // Check for convergence
      if (listEquals(labels, newLabels)) break;
      labels = newLabels;
      
      // Update centroids
      for (int c = 0; c < k; c++) {
        final clusterPoints = <List<double>>[];
        for (int i = 0; i < embeddings.length; i++) {
          if (labels[i] == c) {
            clusterPoints.add(embeddings[i]);
          }
        }
        
        if (clusterPoints.isNotEmpty) {
          for (int d = 0; d < dimensions; d++) {
            centroids[c][d] = clusterPoints.map((p) => p[d]).reduce((a, b) => a + b) / clusterPoints.length;
          }
        }
      }
    }
    
    return labels;
  }
  
  /// Compute clustering inertia (within-cluster sum of squares)
  double _computeInertia(List<List<double>> embeddings, List<int> labels, int k) {
    final centroids = <List<double>>[];
    final dimensions = embeddings.first.length;
    
    // Compute centroids
    for (int c = 0; c < k; c++) {
      final clusterPoints = <List<double>>[];
      for (int i = 0; i < embeddings.length; i++) {
        if (labels[i] == c) {
          clusterPoints.add(embeddings[i]);
        }
      }
      
      if (clusterPoints.isNotEmpty) {
        final centroid = <double>[];
        for (int d = 0; d < dimensions; d++) {
          centroid.add(clusterPoints.map((p) => p[d]).reduce((a, b) => a + b) / clusterPoints.length);
        }
        centroids.add(centroid);
      } else {
        centroids.add(List.filled(dimensions, 0.0));
      }
    }
    
    // Compute inertia
    double inertia = 0.0;
    for (int i = 0; i < embeddings.length; i++) {
      final clusterIndex = labels[i];
      if (clusterIndex < centroids.length) {
        final distance = _euclideanDistance(embeddings[i], centroids[clusterIndex]);
        inertia += distance * distance;
      }
    }
    
    return inertia;
  }
  
  /// Calculate Euclidean distance between two vectors
  double _euclideanDistance(List<double> a, List<double> b) {
    if (a.length != b.length) return double.infinity;
    
    double sum = 0.0;
    for (int i = 0; i < a.length; i++) {
      final diff = a[i] - b[i];
      sum += diff * diff;
    }
    
    return sqrt(sum);
  }
}

class DiarizationException implements Exception {
  final String message;
  const DiarizationException(this.message);
  
  @override
  String toString() => 'DiarizationException: $message';
}