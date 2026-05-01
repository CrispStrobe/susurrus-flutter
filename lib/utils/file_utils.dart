import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../engines/transcription_engine.dart';

class FileUtils {
  static const String transcriptionsFolder = 'transcriptions';
  static const String modelsFolder = 'models';
  static const String audioFolder = 'audio';
  static const String cacheFolder = 'cache';

  /// Get the app's documents directory
  static Future<Directory> getAppDocumentsDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  /// Get the app's cache directory
  static Future<Directory> getAppCacheDirectory() async {
    return await getTemporaryDirectory();
  }

  /// Create a directory if it doesn't exist
  static Future<Directory> ensureDirectoryExists(String dirPath) async {
    final directory = Directory(dirPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  /// Get transcriptions directory
  static Future<Directory> getTranscriptionsDirectory() async {
    final appDir = await getAppDocumentsDirectory();
    final transcriptionsDir = path.join(appDir.path, transcriptionsFolder);
    return await ensureDirectoryExists(transcriptionsDir);
  }

  /// Get models directory
  static Future<Directory> getModelsDirectory() async {
    final appDir = await getAppDocumentsDirectory();
    final modelsDir = path.join(appDir.path, modelsFolder);
    return await ensureDirectoryExists(modelsDir);
  }

  /// Get audio directory
  static Future<Directory> getAudioDirectory() async {
    final appDir = await getAppDocumentsDirectory();
    final audioDir = path.join(appDir.path, audioFolder);
    return await ensureDirectoryExists(audioDir);
  }

  /// Get cache directory
  static Future<Directory> getCacheDirectory() async {
    final cacheDir = await getAppCacheDirectory();
    final appCacheDir = path.join(cacheDir.path, cacheFolder);
    return await ensureDirectoryExists(appCacheDir);
  }

  /// Generate unique filename with timestamp
  static String generateUniqueFilename(String baseName, String extension) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitizedBaseName = sanitizeFilename(baseName);
    return '$sanitizedBaseName-$timestamp.$extension';
  }

  /// Sanitize filename by removing invalid characters
  static String sanitizeFilename(String filename) {
    // Remove or replace invalid characters
    return filename
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_{2,}'), '_')
        .trim();
  }

  /// Save transcription to file
  static Future<File> saveTranscription(
    String text,
    String fileName, {
    TranscriptFormat format = TranscriptFormat.txt,
    List<TranscriptionSegment>? segments,
  }) async {
    final transcriptionsDir = await getTranscriptionsDirectory();
    final extension = _getExtensionForFormat(format);
    final safeFileName = sanitizeFilename(fileName);
    final filePath =
        path.join(transcriptionsDir.path, '$safeFileName.$extension');

    final file = File(filePath);

    String content;
    switch (format) {
      case TranscriptFormat.txt:
        content = text;
        break;
      case TranscriptFormat.srt:
        content = _generateSrtContent(segments ?? []);
        break;
      case TranscriptFormat.vtt:
        content = _generateVttContent(segments ?? []);
        break;
      case TranscriptFormat.json:
        content = _generateJsonContent(segments ?? []);
        break;
    }

    await file.writeAsString(content, encoding: utf8);
    return file;
  }

  /// Save audio data to file
  static Future<File> saveAudioData(
    Uint8List audioData,
    String fileName, {
    String extension = 'wav',
  }) async {
    final audioDir = await getAudioDirectory();
    final safeFileName = sanitizeFilename(fileName);
    final filePath = path.join(audioDir.path, '$safeFileName.$extension');

    final file = File(filePath);
    await file.writeAsBytes(audioData);
    return file;
  }

  /// Read file as bytes
  static Future<Uint8List> readFileAsBytes(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }
    return await file.readAsBytes();
  }

  /// Read file as string
  static Future<String> readFileAsString(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }
    return await file.readAsString(encoding: utf8);
  }

  /// Copy file to another location
  static Future<File> copyFile(
      String sourcePath, String destinationPath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException('Source file not found', sourcePath);
    }
    final destinationDir = Directory(path.dirname(destinationPath));
    await destinationDir.create(recursive: true);
    return await sourceFile.copy(destinationPath);
  }

  /// Move file to another location
  static Future<File> moveFile(
      String sourcePath, String destinationPath) async {
    final sourceFile = File(sourcePath);

    if (!await sourceFile.exists()) {
      throw FileSystemException('Source file not found', sourcePath);
    }

    // Ensure destination directory exists
    final destinationDir = Directory(path.dirname(destinationPath));
    await destinationDir.create(recursive: true);

    return await sourceFile.rename(destinationPath);
  }

  /// Delete file
  static Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get file size
  static Future<int> getFileSize(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return 0;
    }
    return await file.length();
  }

  /// Get file modification date
  static Future<DateTime> getFileModificationDate(String filePath) async {
    final file = File(filePath);
    final stat = await file.stat();
    return stat.modified;
  }

  /// List files in directory
  static Future<List<FileInfo>> listFilesInDirectory(
    String directoryPath, {
    List<String>? extensions,
    bool recursive = false,
  }) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      return [];
    }

    final files = <FileInfo>[];
    final entities =
        recursive ? directory.list(recursive: true) : directory.list();

    await for (final entity in entities) {
      if (entity is File) {
        final extension = path.extension(entity.path).toLowerCase();

        if (extensions == null || extensions.contains(extension)) {
          final stat = await entity.stat();
          files.add(FileInfo(
            path: entity.path,
            name: path.basename(entity.path),
            size: stat.size,
            modified: stat.modified,
            extension: extension,
          ));
        }
      }
    }

    return files;
  }

  /// Get all transcription files
  static Future<List<FileInfo>> getTranscriptionFiles() async {
    final transcriptionsDir = await getTranscriptionsDirectory();
    return await listFilesInDirectory(
      transcriptionsDir.path,
      extensions: ['.txt', '.srt', '.vtt', '.json'],
    );
  }

  /// Get all audio files
  static Future<List<FileInfo>> getAudioFiles() async {
    final audioDir = await getAudioDirectory();
    return await listFilesInDirectory(
      audioDir.path,
      extensions: ['.wav', '.mp3', '.m4a', '.aac', '.ogg', '.flac'],
    );
  }

  /// Share file
  static Future<void> shareFile(String filePath, {String? subject}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    await SharePlus.instance.share(ShareParams(
      files: [XFile(filePath)],
      subject: subject ?? path.basename(filePath),
    ));
  }

  /// Clear cache directory
  static Future<void> clearCache() async {
    final cacheDir = await getCacheDirectory();
    if (await cacheDir.exists()) {
      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      }
    }
  }

  /// Get total size of directory
  static Future<int> getDirectorySize(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      return 0;
    }

    int totalSize = 0;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        final stat = await entity.stat();
        totalSize += stat.size;
      }
    }

    return totalSize;
  }

  /// Get app storage usage
  static Future<StorageUsage> getStorageUsage() async {
    final documentsDir = await getAppDocumentsDirectory();
    final cacheDir = await getAppCacheDirectory();

    final transcriptionsSize = await getDirectorySize(
        path.join(documentsDir.path, transcriptionsFolder));
    final modelsSize =
        await getDirectorySize(path.join(documentsDir.path, modelsFolder));
    final audioSize =
        await getDirectorySize(path.join(documentsDir.path, audioFolder));
    final cacheSize = await getDirectorySize(cacheDir.path);

    return StorageUsage(
      transcriptions: transcriptionsSize,
      models: modelsSize,
      audio: audioSize,
      cache: cacheSize,
    );
  }

  // Private helper methods
  static String _getExtensionForFormat(TranscriptFormat format) {
    switch (format) {
      case TranscriptFormat.txt:
        return 'txt';
      case TranscriptFormat.srt:
        return 'srt';
      case TranscriptFormat.vtt:
        return 'vtt';
      case TranscriptFormat.json:
        return 'json';
    }
  }

  static String _generateSrtContent(List<TranscriptionSegment> segments) {
    final buffer = StringBuffer();
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      buffer.writeln('${i + 1}');
      buffer.writeln(
          '${_formatSrtTime(segment.startTime)} --> ${_formatSrtTime(segment.endTime)}');
      buffer.writeln('${segment.speaker ?? ''}: ${segment.text}');
      buffer.writeln();
    }
    return buffer.toString();
  }

  static String _generateVttContent(List<TranscriptionSegment> segments) {
    final buffer = StringBuffer();
    buffer.writeln('WEBVTT');
    buffer.writeln();

    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      buffer.writeln('${i + 1}');
      buffer.writeln(
          '${_formatVttTime(segment.startTime)} --> ${_formatVttTime(segment.endTime)}');
      buffer.writeln('${segment.speaker ?? ''}: ${segment.text}');
      buffer.writeln();
    }
    return buffer.toString();
  }

  static String _generateJsonContent(List<TranscriptionSegment> segments) {
    final data = segments
        .map((segment) => {
              'text': segment.text,
              'startTime': segment.startTime,
              'endTime': segment.endTime,
              'speaker': segment.speaker,
              'confidence': segment.confidence,
            })
        .toList();

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static String _formatSrtTime(double seconds) {
    final hours = (seconds / 3600).floor();
    final minutes = ((seconds % 3600) / 60).floor();
    final secs = seconds % 60;
    final ms = ((secs % 1) * 1000).round();

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${secs.floor().toString().padLeft(2, '0')},'
        '${ms.toString().padLeft(3, '0')}';
  }

  static String _formatVttTime(double seconds) {
    final hours = (seconds / 3600).floor();
    final minutes = ((seconds % 3600) / 60).floor();
    final secs = seconds % 60;
    final ms = ((secs % 1) * 1000).round();

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${secs.floor().toString().padLeft(2, '0')}.'
        '${ms.toString().padLeft(3, '0')}';
  }
}

enum TranscriptFormat {
  txt,
  srt,
  vtt,
  json,
}

class FileInfo {
  final String path;
  final String name;
  final int size;
  final DateTime modified;
  final String extension;

  const FileInfo({
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
    required this.extension,
  });

  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String get formattedDate {
    return '${modified.day}/${modified.month}/${modified.year}';
  }
}

class StorageUsage {
  final int transcriptions;
  final int models;
  final int audio;
  final int cache;

  const StorageUsage({
    required this.transcriptions,
    required this.models,
    required this.audio,
    required this.cache,
  });

  int get total => transcriptions + models + audio + cache;

  String formatSize(int bytes) {
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

  String get formattedTranscriptions => formatSize(transcriptions);
  String get formattedModels => formatSize(models);
  String get formattedAudio => formatSize(audio);
  String get formattedCache => formatSize(cache);
  String get formattedTotal => formatSize(total);
}
