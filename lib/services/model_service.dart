import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import 'transcription_service.dart';

class ModelService {
  static const String _baseUrl = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';
  static const String _coreMLBaseUrl = 'https://huggingface.co/openai/whisper-large-v3/resolve/main';
  
  final Dio _dio = Dio();
  late String _modelsDir;
  
  ModelService() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(minutes: 10);
  }
  
  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _modelsDir = path.join(appDir.path, 'models');
    await Directory(_modelsDir).create(recursive: true);
  }
  
  /// Get available Whisper.cpp models
  Future<List<ModelInfo>> getWhisperCppModels() async {
    await initialize();
    
    const models = [
      _ModelDefinition(
        name: 'tiny',
        displayName: 'Whisper Tiny',
        fileName: 'ggml-tiny.bin',
        size: '39 MB',
        url: '$_baseUrl/ggml-tiny.bin',
      ),
      _ModelDefinition(
        name: 'base',
        displayName: 'Whisper Base',
        fileName: 'ggml-base.bin',
        size: '74 MB',
        url: '$_baseUrl/ggml-base.bin',
      ),
      _ModelDefinition(
        name: 'small',
        displayName: 'Whisper Small',
        fileName: 'ggml-small.bin',
        size: '244 MB',
        url: '$_baseUrl/ggml-small.bin',
      ),
      _ModelDefinition(
        name: 'medium',
        displayName: 'Whisper Medium',
        fileName: 'ggml-medium.bin',
        size: '769 MB',
        url: '$_baseUrl/ggml-medium.bin',
      ),
      _ModelDefinition(
        name: 'large-v3',
        displayName: 'Whisper Large v3',
        fileName: 'ggml-large-v3.bin',
        size: '1.5 GB',
        url: '$_baseUrl/ggml-large-v3.bin',
      ),
    ];
    
    final modelInfos = <ModelInfo>[];
    for (final model in models) {
      final localPath = path.join(_modelsDir, 'whisper_cpp', model.fileName);
      final isDownloaded = await File(localPath).exists();
      
      modelInfos.add(ModelInfo(
        name: model.name,
        displayName: model.displayName,
        size: model.size,
        isDownloaded: isDownloaded,
        localPath: isDownloaded ? localPath : null,
        backend: TranscriptionBackend.whisperCpp,
      ));
    }
    
    return modelInfos;
  }
  
  /// Get available CoreML models
  Future<List<ModelInfo>> getCoreMLModels() async {
    if (!Platform.isIOS) return [];
    
    await initialize();
    
    const models = [
      _ModelDefinition(
        name: 'tiny',
        displayName: 'Whisper Tiny (CoreML)',
        fileName: 'whisper-tiny.mlmodel',
        size: '39 MB',
        url: '$_coreMLBaseUrl/whisper-tiny.mlmodel',
      ),
      _ModelDefinition(
        name: 'base',
        displayName: 'Whisper Base (CoreML)',
        fileName: 'whisper-base.mlmodel',
        size: '74 MB',
        url: '$_coreMLBaseUrl/whisper-base.mlmodel',
      ),
      _ModelDefinition(
        name: 'small',
        displayName: 'Whisper Small (CoreML)',
        fileName: 'whisper-small.mlmodel',
        size: '244 MB',
        url: '$_coreMLBaseUrl/whisper-small.mlmodel',
      ),
    ];
    
    final modelInfos = <ModelInfo>[];
    for (final model in models) {
      final localPath = path.join(_modelsDir, 'coreml', model.fileName);
      final isDownloaded = await File(localPath).exists();
      
      modelInfos.add(ModelInfo(
        name: model.name,
        displayName: model.displayName,
        size: model.size,
        isDownloaded: isDownloaded,
        localPath: isDownloaded ? localPath : null,
        backend: TranscriptionBackend.coreML,
      ));
    }
    
    return modelInfos;
  }
  
  /// Download a Whisper.cpp model
  Future<bool> downloadWhisperCppModel(
    String modelName, {
    Function(double progress)? onProgress,
  }) async {
    await initialize();
    
    final modelDef = _getWhisperCppModelDefinition(modelName);
    if (modelDef == null) {
      throw ModelException('Unknown model: $modelName');
    }
    
    final modelDir = path.join(_modelsDir, 'whisper_cpp');
    await Directory(modelDir).create(recursive: true);
    
    final localPath = path.join(modelDir, modelDef.fileName);
    
    // Check if already downloaded
    if (await File(localPath).exists()) {
      return true;
    }
    
    try {
      await _downloadFile(
        modelDef.url,
        localPath,
        onProgress: onProgress,
      );
      
      // Verify download
      final file = File(localPath);
      if (await file.exists() && await file.length() > 0) {
        await _saveModelMetadata(modelName, localPath, TranscriptionBackend.whisperCpp);
        return true;
      } else {
        await file.delete();
        return false;
      }
    } catch (e) {
      throw ModelException('Failed to download model: $e');
    }
  }
  
  /// Download a CoreML model
  Future<bool> downloadCoreMLModel(
    String modelName, {
    Function(double progress)? onProgress,
  }) async {
    if (!Platform.isIOS) {
      throw ModelException('CoreML is only available on iOS');
    }
    
    await initialize();
    
    final modelDef = _getCoreMLModelDefinition(modelName);
    if (modelDef == null) {
      throw ModelException('Unknown CoreML model: $modelName');
    }
    
    final modelDir = path.join(_modelsDir, 'coreml');
    await Directory(modelDir).create(recursive: true);
    
    final localPath = path.join(modelDir, modelDef.fileName);
    
    // Check if already downloaded
    if (await File(localPath).exists()) {
      return true;
    }
    
    try {
      await _downloadFile(
        modelDef.url,
        localPath,
        onProgress: onProgress,
      );
      
      // Verify download
      final file = File(localPath);
      if (await file.exists() && await file.length() > 0) {
        await _saveModelMetadata(modelName, localPath, TranscriptionBackend.coreML);
        return true;
      } else {
        await file.delete();
        return false;
      }
    } catch (e) {
      throw ModelException('Failed to download CoreML model: $e');
    }
  }
  
  /// Generic model download method
  Future<bool> downloadModel(String modelName) async {
    // Try Whisper.cpp first
    if (_getWhisperCppModelDefinition(modelName) != null) {
      return await downloadWhisperCppModel(modelName);
    }
    
    // Try CoreML on iOS
    if (Platform.isIOS && _getCoreMLModelDefinition(modelName) != null) {
      return await downloadCoreMLModel(modelName);
    }
    
    throw ModelException('Model not found: $modelName');
  }
  
  /// Get path to a downloaded model
  Future<String?> getModelPath(String modelName) async {
    await initialize();
    
    // Check Whisper.cpp models
    final whisperPath = await getWhisperCppModelPath(modelName);
    if (whisperPath != null) return whisperPath;
    
    // Check CoreML models
    final coreMLPath = await getCoreMLModelPath(modelName);
    if (coreMLPath != null) return coreMLPath;
    
    return null;
  }
  
  /// Get path to a Whisper.cpp model
  Future<String?> getWhisperCppModelPath(String modelName) async {
    await initialize();
    
    final modelDef = _getWhisperCppModelDefinition(modelName);
    if (modelDef == null) return null;
    
    final localPath = path.join(_modelsDir, 'whisper_cpp', modelDef.fileName);
    if (await File(localPath).exists()) {
      return localPath;
    }
    
    return null;
  }
  
  /// Get path to a CoreML model
  Future<String?> getCoreMLModelPath(String modelName) async {
    if (!Platform.isIOS) return null;
    
    await initialize();
    
    final modelDef = _getCoreMLModelDefinition(modelName);
    if (modelDef == null) return null;
    
    final localPath = path.join(_modelsDir, 'coreml', modelDef.fileName);
    if (await File(localPath).exists()) {
      return localPath;
    }
    
    return null;
  }
  
  /// Delete a downloaded model
  Future<bool> deleteModel(String modelName) async {
    await initialize();
    
    bool deleted = false;
    
    // Try deleting Whisper.cpp model
    final whisperPath = await getWhisperCppModelPath(modelName);
    if (whisperPath != null) {
      await File(whisperPath).delete();
      deleted = true;
    }
    
    // Try deleting CoreML model
    final coreMLPath = await getCoreMLModelPath(modelName);
    if (coreMLPath != null) {
      await File(coreMLPath).delete();
      deleted = true;
    }
    
    if (deleted) {
      await _removeModelMetadata(modelName);
    }
    
    return deleted;
  }
  
  /// Get total size of downloaded models
  Future<int> getTotalModelSize() async {
    await initialize();
    
    int totalSize = 0;
    
    final whisperDir = Directory(path.join(_modelsDir, 'whisper_cpp'));
    if (await whisperDir.exists()) {
      await for (final entity in whisperDir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    }
    
    final coreMLDir = Directory(path.join(_modelsDir, 'coreml'));
    if (await coreMLDir.exists()) {
      await for (final entity in coreMLDir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    }
    
    return totalSize;
  }
  
  Future<void> _downloadFile(
    String url,
    String savePath, {
    Function(double progress)? onProgress,
  }) async {
    try {
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            final progress = received / total;
            onProgress(progress);
          }
        },
      );
    } catch (e) {
      // Clean up partial download
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
  }
  
  Future<void> _saveModelMetadata(
    String modelName,
    String localPath,
    TranscriptionBackend backend,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'model_${modelName}_${backend.name}';
    await prefs.setString(key, localPath);
  }
  
  Future<void> _removeModelMetadata(String modelName) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('model_$modelName'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
  
  _ModelDefinition? _getWhisperCppModelDefinition(String modelName) {
    const models = {
      'tiny': _ModelDefinition(
        name: 'tiny',
        displayName: 'Whisper Tiny',
        fileName: 'ggml-tiny.bin',
        size: '39 MB',
        url: '$_baseUrl/ggml-tiny.bin',
      ),
      'base': _ModelDefinition(
        name: 'base',
        displayName: 'Whisper Base',
        fileName: 'ggml-base.bin',
        size: '74 MB',
        url: '$_baseUrl/ggml-base.bin',
      ),
      'small': _ModelDefinition(
        name: 'small',
        displayName: 'Whisper Small',
        fileName: 'ggml-small.bin',
        size: '244 MB',
        url: '$_baseUrl/ggml-small.bin',
      ),
      'medium': _ModelDefinition(
        name: 'medium',
        displayName: 'Whisper Medium',
        fileName: 'ggml-medium.bin',
        size: '769 MB',
        url: '$_baseUrl/ggml-medium.bin',
      ),
      'large-v3': _ModelDefinition(
        name: 'large-v3',
        displayName: 'Whisper Large v3',
        fileName: 'ggml-large-v3.bin',
        size: '1.5 GB',
        url: '$_baseUrl/ggml-large-v3.bin',
      ),
    };
    
    return models[modelName];
  }
  
  _ModelDefinition? _getCoreMLModelDefinition(String modelName) {
    if (!Platform.isIOS) return null;
    
    const models = {
      'tiny': _ModelDefinition(
        name: 'tiny',
        displayName: 'Whisper Tiny (CoreML)',
        fileName: 'whisper-tiny.mlmodel',
        size: '39 MB',
        url: '$_coreMLBaseUrl/whisper-tiny.mlmodel',
      ),
      'base': _ModelDefinition(
        name: 'base',
        displayName: 'Whisper Base (CoreML)',
        fileName: 'whisper-base.mlmodel',
        size: '74 MB',
        url: '$_coreMLBaseUrl/whisper-base.mlmodel',
      ),
      'small': _ModelDefinition(
        name: 'small',
        displayName: 'Whisper Small (CoreML)',
        fileName: 'whisper-small.mlmodel',
        size: '244 MB',
        url: '$_coreMLBaseUrl/whisper-small.mlmodel',
      ),
    };
    
    return models[modelName];
  }
}

class _ModelDefinition {
  final String name;
  final String displayName;
  final String fileName;
  final String size;
  final String url;
  
  const _ModelDefinition({
    required this.name,
    required this.displayName,
    required this.fileName,
    required this.size,
    required this.url,
  });
}

class ModelException implements Exception {
  final String message;
  const ModelException(this.message);
  
  @override
  String toString() => 'ModelException: $message';
}