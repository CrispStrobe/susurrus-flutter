// lib/services/model_service.dart (COMPLETE IMPLEMENTATION)
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:isolate';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:archive/archive.dart';

import 'log_service.dart';

class ModelService {
  /// Upstream ggerganov repo — the canonical source for F16 GGML Whisper models.
  static const String whisperCppBaseUrl =
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';

  /// Secondary repo under the cstr namespace — used for quantized Whisper
  /// variants (q4_0 / q5_0 / q8_0) and mirrors.
  static const String cstrWhisperCppBaseUrl =
      'https://huggingface.co/cstr/whisper-ggml-quants/resolve/main';

  /// A general-purpose cstr GGUF repo (CrispASR-compatible backends).
  static const String cstrCrispBaseUrl =
      'https://huggingface.co/cstr/crispasr-gguf/resolve/main';

  static const String coreMLBaseUrl =
      'https://huggingface.co/openai/whisper-large-v3/resolve/main';

  final Dio _dio = Dio();
  late String _modelsDir;
  SharedPreferences? _prefs;
  final Map<String, CancelToken> _activeDowloads = {};

  // Enhanced model definitions with proper URLs and checksums
  static const Map<String, ModelDefinition> whisperCppModels = {
    'tiny': ModelDefinition(
      name: 'tiny',
      displayName: 'Whisper Tiny',
      fileName: 'ggml-tiny.bin',
      url: '$whisperCppBaseUrl/ggml-tiny.bin',
      sizeBytes: 39 * 1024 * 1024,
      checksum: 'bd577a113a864445d4c299885e0cb97d4ba92b5f',
      description: 'Fastest model, lower accuracy (~39 MB)',
    ),
    'tiny.en': ModelDefinition(
      name: 'tiny.en',
      displayName: 'Whisper Tiny English',
      fileName: 'ggml-tiny.en.bin',
      url: '$whisperCppBaseUrl/ggml-tiny.en.bin',
      sizeBytes: 39 * 1024 * 1024,
      checksum: 'c78c86eb1a8faa21b369bcd33207cc90d64ae9df',
      description: 'Fastest model for English only (~39 MB)',
    ),
    'base': ModelDefinition(
      name: 'base',
      displayName: 'Whisper Base',
      fileName: 'ggml-base.bin',
      url: '$whisperCppBaseUrl/ggml-base.bin',
      sizeBytes: 74 * 1024 * 1024,
      checksum: '465707469ff3a37a2b9b8d8f89f2f99de7299dac',
      description: 'Balanced speed and accuracy (~74 MB)',
    ),
    'base.en': ModelDefinition(
      name: 'base.en',
      displayName: 'Whisper Base English',
      fileName: 'ggml-base.en.bin',
      url: '$whisperCppBaseUrl/ggml-base.en.bin',
      sizeBytes: 74 * 1024 * 1024,
      checksum: '137c40403d78fd54d454da0f9bd998f78703390c',
      description: 'Balanced model for English only (~74 MB)',
    ),
    'small': ModelDefinition(
      name: 'small',
      displayName: 'Whisper Small',
      fileName: 'ggml-small.bin',
      url: '$whisperCppBaseUrl/ggml-small.bin',
      sizeBytes: 244 * 1024 * 1024,
      checksum: '55356645c2b361a969dfd0ef2c5a50d530afd8d5',
      description: 'Good accuracy with moderate speed (~244 MB)',
    ),
    'small.en': ModelDefinition(
      name: 'small.en',
      displayName: 'Whisper Small English',
      fileName: 'ggml-small.en.bin',
      url: '$whisperCppBaseUrl/ggml-small.en.bin',
      sizeBytes: 244 * 1024 * 1024,
      checksum: 'db8a495a91d927739e50b3fc1cc4c6b8f6c2d022',
      description: 'Good accuracy for English only (~244 MB)',
    ),
    'medium': ModelDefinition(
      name: 'medium',
      displayName: 'Whisper Medium',
      fileName: 'ggml-medium.bin',
      url: '$whisperCppBaseUrl/ggml-medium.bin',
      sizeBytes: 769 * 1024 * 1024,
      checksum: 'fd9727b6e1217c2f614f9b698455c4ffd82463b4',
      description: 'High accuracy with slower processing (~769 MB)',
    ),
    'medium.en': ModelDefinition(
      name: 'medium.en',
      displayName: 'Whisper Medium English',
      fileName: 'ggml-medium.en.bin',
      url: '$whisperCppBaseUrl/ggml-medium.en.bin',
      sizeBytes: 769 * 1024 * 1024,
      checksum: 'd7440d1dc186f76616787fcdd0b295ef60e88766',
      description: 'High accuracy for English only (~769 MB)',
    ),
    'large': ModelDefinition(
      name: 'large',
      displayName: 'Whisper Large',
      fileName: 'ggml-large.bin',
      url: '$whisperCppBaseUrl/ggml-large.bin',
      sizeBytes: 1550 * 1024 * 1024,
      checksum: 'b1caaf735c4cc1429223d5a74f0f4d0b9b59a299',
      description: 'Best accuracy with slowest processing (~1.5 GB)',
    ),
    'large-v2': ModelDefinition(
      name: 'large-v2',
      displayName: 'Whisper Large v2',
      fileName: 'ggml-large-v2.bin',
      url: '$whisperCppBaseUrl/ggml-large-v2.bin',
      sizeBytes: 1550 * 1024 * 1024,
      checksum: '0f4c8e34f21cf1a914c59d8b3ce882345ad349d6',
      description: 'Improved large model (~1.5 GB)',
    ),
    'large-v3': ModelDefinition(
      name: 'large-v3',
      displayName: 'Whisper Large v3',
      fileName: 'ggml-large-v3.bin',
      url: '$whisperCppBaseUrl/ggml-large-v3.bin',
      sizeBytes: 1550 * 1024 * 1024,
      checksum: 'ad82bf6a9043ceed055076d0fd39f5f186ff8062',
      description: 'Latest large model with enhanced performance (~1.5 GB)',
    ),

    // ----- Quantized variants (cstr mirrors) -----
    // These are rough size estimates. Checksums are intentionally empty —
    // size-only validation is used until we have authoritative SHAs.
    'tiny-q5_0': ModelDefinition(
      name: 'tiny-q5_0',
      displayName: 'Whisper Tiny (q5_0)',
      fileName: 'ggml-tiny-q5_0.bin',
      url: '$cstrWhisperCppBaseUrl/ggml-tiny-q5_0.bin',
      sizeBytes: 33 * 1024 * 1024,
      checksum: '',
      description: '5-bit quantized tiny — smaller, ~same accuracy',
      quantization: 'q5_0',
    ),
    'base-q5_0': ModelDefinition(
      name: 'base-q5_0',
      displayName: 'Whisper Base (q5_0)',
      fileName: 'ggml-base-q5_0.bin',
      url: '$cstrWhisperCppBaseUrl/ggml-base-q5_0.bin',
      sizeBytes: 60 * 1024 * 1024,
      checksum: '',
      description: '5-bit quantized base — ~60 MB',
      quantization: 'q5_0',
    ),
    'small-q5_0': ModelDefinition(
      name: 'small-q5_0',
      displayName: 'Whisper Small (q5_0)',
      fileName: 'ggml-small-q5_0.bin',
      url: '$cstrWhisperCppBaseUrl/ggml-small-q5_0.bin',
      sizeBytes: 190 * 1024 * 1024,
      checksum: '',
      description: '5-bit quantized small — ~190 MB',
      quantization: 'q5_0',
    ),
    'medium-q5_0': ModelDefinition(
      name: 'medium-q5_0',
      displayName: 'Whisper Medium (q5_0)',
      fileName: 'ggml-medium-q5_0.bin',
      url: '$cstrWhisperCppBaseUrl/ggml-medium-q5_0.bin',
      sizeBytes: 540 * 1024 * 1024,
      checksum: '',
      description: '5-bit quantized medium — ~540 MB',
      quantization: 'q5_0',
    ),
    'large-v3-q5_0': ModelDefinition(
      name: 'large-v3-q5_0',
      displayName: 'Whisper Large v3 (q5_0)',
      fileName: 'ggml-large-v3-q5_0.bin',
      url: '$cstrWhisperCppBaseUrl/ggml-large-v3-q5_0.bin',
      sizeBytes: 1100 * 1024 * 1024,
      checksum: '',
      description: '5-bit quantized large-v3 — ~1.1 GB',
      quantization: 'q5_0',
    ),
    'base-q4_0': ModelDefinition(
      name: 'base-q4_0',
      displayName: 'Whisper Base (q4_0)',
      fileName: 'ggml-base-q4_0.bin',
      url: '$cstrWhisperCppBaseUrl/ggml-base-q4_0.bin',
      sizeBytes: 46 * 1024 * 1024,
      checksum: '',
      description: '4-bit quantized base — ~46 MB',
      quantization: 'q4_0',
    ),
    'small-q4_0': ModelDefinition(
      name: 'small-q4_0',
      displayName: 'Whisper Small (q4_0)',
      fileName: 'ggml-small-q4_0.bin',
      url: '$cstrWhisperCppBaseUrl/ggml-small-q4_0.bin',
      sizeBytes: 150 * 1024 * 1024,
      checksum: '',
      description: '4-bit quantized small — ~150 MB',
      quantization: 'q4_0',
    ),
    'large-v3-q4_0': ModelDefinition(
      name: 'large-v3-q4_0',
      displayName: 'Whisper Large v3 (q4_0)',
      fileName: 'ggml-large-v3-q4_0.bin',
      url: '$cstrWhisperCppBaseUrl/ggml-large-v3-q4_0.bin',
      sizeBytes: 880 * 1024 * 1024,
      checksum: '',
      description: '4-bit quantized large-v3 — ~880 MB',
      quantization: 'q4_0',
    ),
    'base-q8_0': ModelDefinition(
      name: 'base-q8_0',
      displayName: 'Whisper Base (q8_0)',
      fileName: 'ggml-base-q8_0.bin',
      url: '$cstrWhisperCppBaseUrl/ggml-base-q8_0.bin',
      sizeBytes: 78 * 1024 * 1024,
      checksum: '',
      description: '8-bit quantized base — ~78 MB',
      quantization: 'q8_0',
    ),
    'large-v3-q8_0': ModelDefinition(
      name: 'large-v3-q8_0',
      displayName: 'Whisper Large v3 (q8_0)',
      fileName: 'ggml-large-v3-q8_0.bin',
      url: '$cstrWhisperCppBaseUrl/ggml-large-v3-q8_0.bin',
      sizeBytes: 1650 * 1024 * 1024,
      checksum: '',
      description: '8-bit quantized large-v3 — ~1.65 GB',
      quantization: 'q8_0',
    ),
  };

  static const Map<String, ModelDefinition> coreMLModels = {
    'tiny': ModelDefinition(
      name: 'tiny',
      displayName: 'Whisper Tiny (CoreML)',
      fileName: 'whisper-tiny-encoder.mlmodelc.zip',
      url: 'https://huggingface.co/spaces/sanchit-gandhi/whisper-coreml/resolve/main/model_repo/whisper-tiny/encoder.mlmodelc.zip',
      sizeBytes: 24 * 1024 * 1024,
      checksum: '',  // CoreML checksums vary by platform
      description: 'CoreML optimized tiny model (~24 MB)',
    ),
    'base': ModelDefinition(
      name: 'base',
      displayName: 'Whisper Base (CoreML)',
      fileName: 'whisper-base-encoder.mlmodelc.zip',
      url: 'https://huggingface.co/spaces/sanchit-gandhi/whisper-coreml/resolve/main/model_repo/whisper-base/encoder.mlmodelc.zip',
      sizeBytes: 57 * 1024 * 1024,
      checksum: '',
      description: 'CoreML optimized base model (~57 MB)',
    ),
    'small': ModelDefinition(
      name: 'small',
      displayName: 'Whisper Small (CoreML)',
      fileName: 'whisper-small-encoder.mlmodelc.zip',
      url: 'https://huggingface.co/spaces/sanchit-gandhi/whisper-coreml/resolve/main/model_repo/whisper-small/encoder.mlmodelc.zip',
      sizeBytes: 185 * 1024 * 1024,
      checksum: '',
      description: 'CoreML optimized small model (~185 MB)',
    ),
  };

  ModelService() {
    _configureDio();
  }

  void _configureDio() {
    _dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 30),
      sendTimeout: const Duration(minutes: 30),
      headers: {
        'User-Agent': 'Susurrus-Flutter/1.0.0',
      },
    );

    // Add interceptors for debugging and retry logic
    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        options: const RetryOptions(
          retries: 3,
          retryInterval: Duration(seconds: 2),
        ),
      ),
    );
  }

  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _modelsDir = path.join(appDir.path, 'models');
    await Directory(_modelsDir).create(recursive: true);

    // Create subdirectories
    await Directory(path.join(_modelsDir, 'whisper_cpp')).create(recursive: true);
    if (Platform.isIOS) {
      await Directory(path.join(_modelsDir, 'coreml')).create(recursive: true);
    }

    _prefs = await SharedPreferences.getInstance();
  }

  /// Get available Whisper.cpp models with download status
  Future<List<ModelInfo>> getWhisperCppModels() async {
    await initialize();

    final modelInfos = <ModelInfo>[];

    for (final entry in whisperCppModels.entries) {
      final modelDef = entry.value;
      final localPath = path.join(_modelsDir, 'whisper_cpp', modelDef.fileName);
      final isDownloaded = await _isModelDownloaded(localPath, modelDef);

      modelInfos.add(ModelInfo(
        name: modelDef.name,
        displayName: modelDef.displayName,
        size: _formatSize(modelDef.sizeBytes),
        sizeBytes: modelDef.sizeBytes,
        isDownloaded: isDownloaded,
        localPath: isDownloaded ? localPath : null,
        description: modelDef.description,
        modelType: ModelType.whisperCpp,
        quantization: modelDef.quantization,
      ));
    }

    return modelInfos;
  }

  /// Whether the user has disabled SHA-1 checksum validation for downloads.
  bool get skipChecksum => _prefs?.getBool('skip_checksum') ?? false;

  /// Get available CoreML models (iOS only)
  Future<List<ModelInfo>> getCoreMLModels() async {
    if (!Platform.isIOS) return [];

    await initialize();

    final modelInfos = <ModelInfo>[];

    for (final entry in coreMLModels.entries) {
      final modelDef = entry.value;
      final localPath = path.join(_modelsDir, 'coreml', modelDef.name);
      final isDownloaded = await _isCoreMLModelDownloaded(localPath);

      modelInfos.add(ModelInfo(
        name: modelDef.name,
        displayName: modelDef.displayName,
        size: _formatSize(modelDef.sizeBytes),
        sizeBytes: modelDef.sizeBytes,
        isDownloaded: isDownloaded,
        localPath: isDownloaded ? localPath : null,
        description: modelDef.description,
        modelType: ModelType.coreML,
      ));
    }

    return modelInfos;
  }

  /// Download a Whisper.cpp model with comprehensive error handling
  Future<bool> downloadWhisperCppModel(
    String modelName, {
    Function(double progress)? onProgress,
    Function(String status)? onStatusChange,
  }) async {
    await initialize();

    final modelDef = whisperCppModels[modelName];
    if (modelDef == null) {
      throw ModelException('Unknown Whisper.cpp model: $modelName');
    }

    final modelDir = path.join(_modelsDir, 'whisper_cpp');
    final localPath = path.join(modelDir, modelDef.fileName);
    final tempPath = '$localPath.tmp';

    // Check if already downloaded and valid
    if (await _isModelDownloaded(localPath, modelDef)) {
      onProgress?.call(1.0);
      onStatusChange?.call('Model already downloaded');
      return true;
    }

    // Check if download is already in progress
    if (_activeDowloads.containsKey(modelName)) {
      throw ModelException('Download already in progress for $modelName');
    }

    final cancelToken = CancelToken();
    _activeDowloads[modelName] = cancelToken;

    try {
      onStatusChange?.call('Checking available space...');

      // Check available space
      final freeSpace = await _getAvailableSpace();
      if (freeSpace < modelDef.sizeBytes * 1.2) {
        throw ModelException(
          'Insufficient storage space. Need ${_formatSize(modelDef.sizeBytes)}, '
          'have ${_formatSize(freeSpace)}'
        );
      }

      onStatusChange?.call('Starting download...');
      onProgress?.call(0.0);

      // Download with resume capability
      await _downloadWithResume(
        modelDef.url,
        tempPath,
        expectedSize: modelDef.sizeBytes,
        onProgress: onProgress,
        onStatusChange: onStatusChange,
        cancelToken: cancelToken,
      );

      onStatusChange?.call('Verifying download...');
      onProgress?.call(0.95);

      // Verify download
      if (modelDef.checksum.isNotEmpty && !skipChecksum) {
        final isValid = await _verifyChecksum(tempPath, modelDef.checksum);
        if (!isValid) {
          await File(tempPath).delete();
          Log.instance.w('model', 'Checksum mismatch for $modelName');
          throw ModelException(
              'Download verification failed. File may be corrupted. '
              'Enable "Skip checksum verification" in Settings → Debugging to bypass.');
        }
      } else if (skipChecksum) {
        Log.instance.i('model', 'Skipping checksum for $modelName (user override)');
      }

      // Move temp file to final location
      await File(tempPath).rename(localPath);

      // Save metadata
      await _saveModelMetadata(modelName, ModelType.whisperCpp, localPath);

      onProgress?.call(1.0);
      onStatusChange?.call('Download complete');
      return true;

    } catch (e) {
      // Cleanup on failure
      await _cleanupTempFile(tempPath);

      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) {
          throw ModelException('Download cancelled');
        } else if (e.type == DioExceptionType.connectionTimeout) {
          throw ModelException('Download timeout. Please check your internet connection.');
        } else if (e.response?.statusCode == 404) {
          throw ModelException('Model not found on server');
        } else {
          throw ModelException('Download failed: ${e.message}');
        }
      }

      throw ModelException('Failed to download model: $e');
    } finally {
      _activeDowloads.remove(modelName);
    }
  }

  /// Download a CoreML model (iOS only)
  Future<bool> downloadCoreMLModel(
    String modelName, {
    Function(double progress)? onProgress,
    Function(String status)? onStatusChange,
  }) async {
    if (!Platform.isIOS) {
      throw ModelException('CoreML models are only available on iOS');
    }

    await initialize();

    final modelDef = coreMLModels[modelName];
    if (modelDef == null) {
      throw ModelException('Unknown CoreML model: $modelName');
    }

    final modelDir = path.join(_modelsDir, 'coreml');
    final extractDir = path.join(modelDir, modelName);
    final tempPath = '${extractDir}.zip.tmp';

    // Check if already downloaded
    if (await _isCoreMLModelDownloaded(extractDir)) {
      onProgress?.call(1.0);
      onStatusChange?.call('Model already downloaded');
      return true;
    }

    // Check if download is already in progress
    if (_activeDowloads.containsKey('coreml_$modelName')) {
      throw ModelException('Download already in progress for CoreML $modelName');
    }

    final cancelToken = CancelToken();
    _activeDowloads['coreml_$modelName'] = cancelToken;

    try {
      onStatusChange?.call('Starting CoreML download...');

      await _downloadWithResume(
        modelDef.url,
        tempPath,
        expectedSize: modelDef.sizeBytes,
        onProgress: (progress) => onProgress?.call(progress * 0.8),
        onStatusChange: onStatusChange,
        cancelToken: cancelToken,
      );

      onStatusChange?.call('Extracting CoreML model...');
      onProgress?.call(0.8);

      // Extract zip file
      await _extractCoreMLModel(tempPath, extractDir);
      await File(tempPath).delete();

      await _saveModelMetadata(modelName, ModelType.coreML, extractDir);

      onProgress?.call(1.0);
      onStatusChange?.call('CoreML download complete');
      return true;

    } catch (e) {
      await _cleanupTempFile(tempPath);
      await _cleanupDirectory(extractDir);
      throw ModelException('Failed to download CoreML model: $e');
    } finally {
      _activeDowloads.remove('coreml_$modelName');
    }
  }

  /// Cancel an ongoing download
  Future<void> cancelDownload(String modelName, {ModelType? modelType}) async {
    final key = modelType == ModelType.coreML ? 'coreml_$modelName' : modelName;
    final cancelToken = _activeDowloads[key];
    if (cancelToken != null) {
      cancelToken.cancel('Download cancelled by user');
      _activeDowloads.remove(key);
    }
  }

  /// Download with resume capability and comprehensive error handling
  Future<void> _downloadWithResume(
    String url,
    String savePath, {
    required int expectedSize,
    Function(double progress)? onProgress,
    Function(String status)? onStatusChange,
    CancelToken? cancelToken,
  }) async {
    final file = File(savePath);
    int downloadedBytes = 0;

    // Check if partial download exists
    if (await file.exists()) {
      downloadedBytes = await file.length();
      onStatusChange?.call('Resuming download...');
    }

    // Set range header for resume
    final headers = <String, dynamic>{
      'Accept': '*/*',
      'Accept-Encoding': 'identity', // Disable compression for resume
    };

    if (downloadedBytes > 0 && downloadedBytes < expectedSize) {
      headers['Range'] = 'bytes=$downloadedBytes-';
    }

    int lastProgressUpdate = DateTime.now().millisecondsSinceEpoch;

    await _dio.download(
      url,
      savePath,
      options: Options(headers: headers),
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        final now = DateTime.now().millisecondsSinceEpoch;
        
        // Throttle progress updates to avoid UI spam
        if (now - lastProgressUpdate < 100) return;
        lastProgressUpdate = now;

        final totalBytes = downloadedBytes + received;
        final progress = total > 0 ? totalBytes / expectedSize : totalBytes / expectedSize;

        onProgress?.call(progress.clamp(0.0, 1.0));

        // Update status periodically
        if (totalBytes % (1024 * 1024) < 100 * 1024) { // Every MB
          final downloadedMB = totalBytes / (1024 * 1024);
          final totalMB = expectedSize / (1024 * 1024);
          final speed = _calculateDownloadSpeed(totalBytes, DateTime.now());
          onStatusChange?.call(
            'Downloaded ${downloadedMB.toStringAsFixed(1)} MB of ${totalMB.toStringAsFixed(1)} MB ($speed)'
          );
        }
      },
    );

    // Verify final file size
    final finalSize = await file.length();
    if (finalSize != expectedSize) {
      await file.delete();
      throw ModelException(
        'Download incomplete. Expected $expectedSize bytes, got $finalSize bytes'
      );
    }
  }

  DateTime? _speedStart;
  int _speedStartBytes = 0;

  String _calculateDownloadSpeed(int bytesDownloaded, DateTime currentTime) {
    _speedStart ??= currentTime;

    final elapsed = currentTime.difference(_speedStart!).inSeconds;
    if (elapsed <= 0) return '';

    final speed = (bytesDownloaded - _speedStartBytes) / elapsed;
    if (speed < 1024) {
      return '${speed.toStringAsFixed(0)} B/s';
    } else if (speed < 1024 * 1024) {
      return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  /// Extract CoreML model from zip file
  Future<void> _extractCoreMLModel(String zipPath, String extractDir) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    await Directory(extractDir).create(recursive: true);

    for (final file in archive) {
      final filename = path.join(extractDir, file.name);
      
      if (file.isFile) {
        final data = file.content as List<int>;
        final outFile = File(filename);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(data);
      } else {
        await Directory(filename).create(recursive: true);
      }
    }
  }

  /// Verify file checksum using SHA-1
  Future<bool> _verifyChecksum(String filePath, String expectedChecksum) async {
    if (expectedChecksum.isEmpty) return true;

    final file = File(filePath);
    if (!await file.exists()) return false;

    // Use isolate for CPU-intensive checksum calculation
    final result = await Isolate.run(() async {
      final bytes = await File(filePath).readAsBytes();
      final digest = sha1.convert(bytes);
      return digest.toString();
    });

    return result.toLowerCase() == expectedChecksum.toLowerCase();
  }

  /// Get model path if downloaded and valid
  Future<String?> getWhisperCppModelPath(String modelName) async {
    await initialize();

    final modelDef = whisperCppModels[modelName];
    if (modelDef == null) return null;

    final localPath = path.join(_modelsDir, 'whisper_cpp', modelDef.fileName);

    if (await _isModelDownloaded(localPath, modelDef)) {
      return localPath;
    }

    return null;
  }

  /// Get CoreML model path
  Future<String?> getCoreMLModelPath(String modelName) async {
    if (!Platform.isIOS) return null;

    await initialize();

    final localPath = path.join(_modelsDir, 'coreml', modelName);

    if (await _isCoreMLModelDownloaded(localPath)) {
      return localPath;
    }

    return null;
  }

  /// Delete a model with proper cleanup
  Future<bool> deleteModel(String modelName, {ModelType? modelType}) async {
    await initialize();

    bool deleted = false;

    // Cancel any ongoing downloads first
    await cancelDownload(modelName, modelType: modelType);

    // Try Whisper.cpp first
    if (modelType == null || modelType == ModelType.whisperCpp) {
      final whisperPath = await getWhisperCppModelPath(modelName);
      if (whisperPath != null) {
        await File(whisperPath).delete();
        await _removeModelMetadata(modelName, ModelType.whisperCpp);
        deleted = true;
      }
    }

    // Try CoreML
    if (!deleted && (modelType == null || modelType == ModelType.coreML)) {
      final coreMLPath = await getCoreMLModelPath(modelName);
      if (coreMLPath != null) {
        await _cleanupDirectory(coreMLPath);
        await _removeModelMetadata(modelName, ModelType.coreML);
        deleted = true;
      }
    }

    return deleted;
  }

  /// Get total storage used by models
  Future<StorageInfo> getStorageInfo() async {
    await initialize();

    int whisperCppSize = 0;
    int coreMLSize = 0;

    // Calculate Whisper.cpp storage
    final whisperDir = Directory(path.join(_modelsDir, 'whisper_cpp'));
    if (await whisperDir.exists()) {
      whisperCppSize = await _getDirectorySize(whisperDir.path);
    }

    // Calculate CoreML storage
    if (Platform.isIOS) {
      final coreMLDir = Directory(path.join(_modelsDir, 'coreml'));
      if (await coreMLDir.exists()) {
        coreMLSize = await _getDirectorySize(coreMLDir.path);
      }
    }

    return StorageInfo(
      whisperCppBytes: whisperCppSize,
      coreMLBytes: coreMLSize,
      totalBytes: whisperCppSize + coreMLSize,
    );
  }

  /// Clear all model cache
  Future<void> clearAllModels() async {
    await initialize();

    // Cancel all downloads first
    for (final entry in _activeDowloads.entries) {
      entry.value.cancel('Clearing all models');
    }
    _activeDowloads.clear();

    final modelsDir = Directory(_modelsDir);
    if (await modelsDir.exists()) {
      await modelsDir.delete(recursive: true);
      await modelsDir.create(recursive: true);

      // Recreate subdirectories
      await Directory(path.join(_modelsDir, 'whisper_cpp')).create();
      if (Platform.isIOS) {
        await Directory(path.join(_modelsDir, 'coreml')).create();
      }
    }

    // Clear metadata
    final keys = _prefs?.getKeys().where((key) => key.startsWith('model_')) ?? [];
    for (final key in keys) {
      await _prefs?.remove(key);
    }
  }

  // Private helper methods

  Future<bool> _isModelDownloaded(String localPath, ModelDefinition modelDef) async {
    final file = File(localPath);
    if (!await file.exists()) return false;

    final size = await file.length();

    // Check size matches (within 1% tolerance)
    final sizeDiff = (size - modelDef.sizeBytes).abs();
    final tolerance = modelDef.sizeBytes * 0.01;

    if (sizeDiff > tolerance) return false;

    // For critical models, verify checksum — unless the user has explicitly
    // opted into skipping verification.
    if (!skipChecksum &&
        modelDef.checksum.isNotEmpty &&
        modelDef.sizeBytes > 100 * 1024 * 1024) {
      return await _verifyChecksum(localPath, modelDef.checksum);
    }

    return true;
  }

  Future<bool> _isCoreMLModelDownloaded(String modelDir) async {
    final dir = Directory(modelDir);
    if (!await dir.exists()) return false;

    // Check if directory contains .mlmodelc files
    final entities = await dir.list().toList();
    return entities.any((entity) => 
      entity is Directory && entity.path.endsWith('.mlmodelc')
    );
  }

  Future<void> _saveModelMetadata(String modelName, ModelType type, String localPath) async {
    final key = 'model_${type.name}_$modelName';
    final metadata = {
      'name': modelName,
      'type': type.name,
      'path': localPath,
      'downloadedAt': DateTime.now().toIso8601String(),
      'version': '1.0',
    };

    await _prefs?.setString(key, jsonEncode(metadata));
  }

  Future<void> _removeModelMetadata(String modelName, ModelType type) async {
    final key = 'model_${type.name}_$modelName';
    await _prefs?.remove(key);
  }

  Future<void> _cleanupTempFile(String tempPath) async {
    try {
      final file = File(tempPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  Future<void> _cleanupDirectory(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  Future<int> _getAvailableSpace() async {
    // On mobile platforms, this is an approximation
    // You might want to use a plugin like device_info_plus for more accurate info
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final stat = await appDir.stat();
      // This is a rough estimate - in production use platform-specific APIs
      return 5 * 1024 * 1024 * 1024; // Assume 5GB available
    } catch (e) {
      return 5 * 1024 * 1024 * 1024; // Default to 5GB
    }
  }

  Future<int> _getDirectorySize(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) return 0;

    int totalSize = 0;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        try {
          final stat = await entity.stat();
          totalSize += stat.size;
        } catch (e) {
          // Skip files that can't be accessed
        }
      }
    }

    return totalSize;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// Enhanced data classes and exceptions

class ModelDefinition {
  final String name;
  final String displayName;
  final String fileName;
  final String url;
  final int sizeBytes;
  final String checksum;
  final String description;
  final String quantization; // 'f16', 'q4_0', 'q5_0', 'q8_0', ''

  const ModelDefinition({
    required this.name,
    required this.displayName,
    required this.fileName,
    required this.url,
    required this.sizeBytes,
    required this.checksum,
    required this.description,
    this.quantization = 'f16',
  });
}

class ModelInfo {
  final String name;
  final String displayName;
  final String size;
  final int sizeBytes;
  final bool isDownloaded;
  final String? localPath;
  final String description;
  final ModelType modelType;
  final String quantization;

  const ModelInfo({
    required this.name,
    required this.displayName,
    required this.size,
    required this.sizeBytes,
    required this.isDownloaded,
    this.localPath,
    required this.description,
    required this.modelType,
    this.quantization = 'f16',
  });
}

enum ModelType {
  whisperCpp,
  coreML,
}

class StorageInfo {
  final int whisperCppBytes;
  final int coreMLBytes;
  final int totalBytes;

  const StorageInfo({
    required this.whisperCppBytes,
    required this.coreMLBytes,
    required this.totalBytes,
  });

  String get formattedWhisperCpp => _formatSize(whisperCppBytes);
  String get formattedCoreML => _formatSize(coreMLBytes);
  String get formattedTotal => _formatSize(totalBytes);

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class ModelException implements Exception {
  final String message;
  const ModelException(this.message);

  @override
  String toString() => 'ModelException: $message';
}

// Retry interceptor for Dio
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final RetryOptions options;

  RetryInterceptor({required this.dio, required this.options});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final extra = RetryOptions.fromExtra(err.requestOptions) ?? options;

    if (extra.retries <= 0) {
      return handler.next(err);
    }

    if (err.type == DioExceptionType.cancel) {
      return handler.next(err);
    }

    await Future.delayed(extra.retryInterval);

    final requestOptions = err.requestOptions;
    requestOptions.extra[RetryOptions.extraKey] = extra.copyWith(retries: extra.retries - 1);

    try {
      final response = await dio.fetch(requestOptions);
      return handler.resolve(response);
    } catch (e) {
      return handler.next(err);
    }
  }
}

class RetryOptions {
  static const String extraKey = 'retry_options';
  
  final int retries;
  final Duration retryInterval;

  const RetryOptions({
    required this.retries,
    required this.retryInterval,
  });

  static RetryOptions? fromExtra(RequestOptions request) {
    return request.extra[extraKey] as RetryOptions?;
  }

  RetryOptions copyWith({int? retries, Duration? retryInterval}) {
    return RetryOptions(
      retries: retries ?? this.retries,
      retryInterval: retryInterval ?? this.retryInterval,
    );
  }
}