import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'log_service.dart';

/// Extracts the bundled Silero VAD model to the app's documents
/// directory on first use and returns the on-disk path. The actual VAD
/// pipeline runs inside whisper.cpp via
/// `TranscribeOptions.vad = true` + `TranscribeOptions.vadModelPath` —
/// this service just makes sure the file is reachable on disk.
class VadService {
  static const String _assetPath = 'assets/vad/silero-v6.2.0-ggml.bin';
  String? _extractedPath;

  /// Path to the Silero VAD model, extracting the bundled asset on the
  /// first call. Returns null on extraction failure — the caller should
  /// treat that as "VAD unavailable" and fall back to silent-passthrough.
  Future<String?> ensureModel() async {
    if (_extractedPath != null) return _extractedPath;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'vad'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final dest = File(p.join(dir.path, 'silero-v6.2.0-ggml.bin'));
      if (!await dest.exists()) {
        final data = await rootBundle.load(_assetPath);
        await dest.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
        Log.instance.i('vad', 'extracted silero model',
            fields: {'path': dest.path, 'bytes': await dest.length()});
      }
      _extractedPath = dest.path;
      return _extractedPath;
    } catch (e, st) {
      Log.instance.w('vad', 'failed to extract silero model',
          error: e, stack: st);
      return null;
    }
  }
}

final vadServiceProvider = Provider<VadService>((_) => VadService());
