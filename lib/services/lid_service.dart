import 'dart:io';
import 'dart:typed_data';

import 'package:crispasr/crispasr.dart' as crispasr;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../main.dart' show modelServiceProvider;
import 'log_service.dart';
import 'model_service.dart';

/// Language identification via CrispASR 0.4.6+ `crispasr_detect_language_pcm`.
///
/// Two methods are available upstream (whisper encoder + language head
/// on a multilingual ggml-*.bin, or the native Silero 95-language GGUF).
/// CrisperWeaver reuses whichever multilingual whisper model the user
/// has already downloaded via Model Management — we don't bundle a 75 MB
/// asset for a pre-step that's rarely on the critical path.
///
/// Usage:
/// ```dart
/// final code = await LidService().detectIfModelAvailable(pcm);
/// if (code != null) opts = opts.copyWith(language: code);
/// ```
class LidService {
  final ModelService modelService;
  LidService(this.modelService);

  String? _cachedPath;

  /// Returns the on-disk path to a multilingual whisper ggml-*.bin model
  /// the user has already downloaded, or null if none is present. Prefers
  /// smaller models (tiny > base > small > medium > large) for LID —
  /// whisper-tiny is accurate enough for 30 s of audio and is the
  /// fastest to encode.
  Future<String?> _findMultilingualModel() async {
    if (_cachedPath != null && await File(_cachedPath!).exists()) {
      return _cachedPath;
    }
    try {
      final models = await modelService.getWhisperCppModels();
      // Filter: downloaded + multilingual. English-only files have `.en.`
      // in their filename (tiny.en, base.en, …); any other ggml-*.bin is
      // multilingual.
      final candidates = models
          .where((m) =>
              m.isDownloaded &&
              m.localPath != null &&
              !m.localPath!.contains('.en.') &&
              p.basename(m.localPath!).startsWith('ggml-'))
          .toList();
      if (candidates.isEmpty) return null;

      // Prefer size order: tiny < base < small < medium < large.
      const sizeOrder = ['tiny', 'base', 'small', 'medium', 'large'];
      candidates.sort((a, b) {
        int rank(String path) {
          final name = p.basename(path).toLowerCase();
          for (var i = 0; i < sizeOrder.length; i++) {
            if (name.contains(sizeOrder[i])) return i;
          }
          return sizeOrder.length; // unknown → last
        }

        return rank(a.localPath!).compareTo(rank(b.localPath!));
      });
      _cachedPath = candidates.first.localPath;
      return _cachedPath;
    } catch (e, st) {
      Log.instance.w('lid', 'failed to enumerate whisper models',
          error: e, stack: st);
      return null;
    }
  }

  /// Return a cache directory override suitable for the sandboxed
  /// platforms (iOS / Android). The CrispASR lib's default is
  /// `$HOME/.cache/crispasr` which doesn't exist on mobile sandboxes;
  /// we point it at the app documents directory instead.
  Future<String> _cacheDirOverride() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'crispasr-cache'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  /// Run LID on [pcm] using the first available multilingual whisper
  /// model. Returns the ISO 639-1 code (e.g. "en", "de") or null when
  /// either no model is available, the lib call failed, or the
  /// confidence is too low to be useful.
  Future<String?> detectIfModelAvailable(Float32List pcm,
      {double minConfidence = 0.35}) async {
    if (pcm.isEmpty) return null;
    final modelPath = await _findMultilingualModel();
    if (modelPath == null) {
      Log.instance.d('lid',
          'no multilingual whisper model available — skipping LID pre-step');
      return null;
    }
    try {
      final r = crispasr.detectLanguagePcm(
        pcm: pcm,
        method: crispasr.LidMethod.whisper,
        modelPath: modelPath,
      );
      if (r.isEmpty || r.confidence < minConfidence) {
        Log.instance.d('lid',
            'LID inconclusive (code="${r.langCode}", p=${r.confidence.toStringAsFixed(3)})');
        return null;
      }
      Log.instance.i('lid', 'detected language', fields: {
        'code': r.langCode,
        'confidence': r.confidence.toStringAsFixed(3),
        'model': p.basename(modelPath),
      });
      return r.langCode;
    } catch (e, st) {
      Log.instance.w('lid', 'detectLanguagePcm threw',
          error: e, stack: st);
      return null;
    }
  }

  /// Force the cache override dir to be materialised. Currently unused
  /// by the whisper LID path (which takes a concrete model file path),
  /// but kept here for future auto-download flow that would hand the
  /// override to `crispasr.cacheEnsureFile`.
  // ignore: unused_element
  Future<String> warmCacheDir() => _cacheDirOverride();
}

final lidServiceProvider =
    Provider<LidService>((ref) => LidService(ref.watch(modelServiceProvider)));
