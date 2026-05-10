import 'dart:io';

import 'package:crispasr/crispasr.dart' as crispasr;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../engines/transcription_engine.dart';
import '../main.dart' show modelServiceProvider;
import 'log_service.dart';
import 'model_service.dart';

/// Punctuation restoration via CrispASR's `PuncModel` (FireRedPunc).
///
/// Several backends in the unified session API emit unpunctuated lowercase
/// text — wav2vec2 / fastconformer-ctc / firered-asr. FireRedPunc is a
/// small BERT model that restores capitalization and punctuation in one
/// pass over the full transcript. CrispASR ships it as a stand-alone GGUF
/// at `cstr/fireredpunc-GGUF`; this service finds whichever quant the
/// user downloaded and applies it on demand.
///
/// Lifecycle: a single PuncModel is loaded lazily on the first call and
/// cached for the rest of the process. Loading is cheap (~100 MB mmap)
/// but inference is per-segment, so the model is kept resident rather
/// than reopened on every transcription.
class PuncService {
  /// Filenames the service recognises as a punctuation GGUF. Both
  /// FireRedPunc (ZH+EN) and fullstop-punc (EN/DE/FR/IT) load through
  /// the same `crispasr.PuncModel` ABI; pick by user preference.
  static const List<String> _knownFilenames = [
    // FireRedPunc — Chinese + English
    'fireredpunc-q8_0.gguf',
    'fireredpunc-q4_k.gguf',
    'fireredpunc-f16.gguf',
    // Fullstop-punc multilang — EN/DE/FR/IT
    'fullstop-punc-multilang-q8_0.gguf',
    'fullstop-punc-multilang-q4_k.gguf',
    'fullstop-punc-multilang-f16.gguf',
  ];

  /// Optional ModelService injection. When present we honour the
  /// custom-models-dir setting; when null we fall back to a temp-dir
  /// path so the not-found check fires cleanly in test fixtures.
  final ModelService? modelService;
  PuncService({this.modelService});

  crispasr.PuncModel? _model;
  String? _loadedPath;
  bool _searched = false;
  String? _cachedPath;

  /// User-preferred filename hint (e.g. `"fullstop"` to prefer fullstop-punc
  /// over fireredpunc when both are on disk). Honoured by [_findModel] as
  /// a substring match against the basename. Empty / null = first match.
  String? preferredFamily;

  /// Locate a downloaded punctuation GGUF. Both FireRedPunc and
  /// fullstop-punc are recognised; pick by [preferredFamily] when both
  /// are present. Returns null if neither is on disk.
  Future<String?> _findModel() async {
    if (_searched) return _cachedPath;
    _searched = true;
    try {
      await modelService?.initialize();
      final dirPath = modelService?.whisperCppDir() ??
          p.join(Directory.systemTemp.path, 'crisper_weaver_models',
              'whisper_cpp');
      final modelsDir = Directory(dirPath);
      if (!await modelsDir.exists()) return null;
      final entries = await modelsDir.list().toList();
      final matches = <File>[];
      for (final e in entries) {
        if (e is! File) continue;
        final base = p.basename(e.path);
        final lower = base.toLowerCase();
        if (_knownFilenames.contains(base) ||
            lower.startsWith('fireredpunc') ||
            lower.startsWith('fullstop-punc')) {
          matches.add(e);
        }
      }
      if (matches.isEmpty) return null;
      // Honour the user preference: if `preferredFamily` is set,
      // prefer the file whose basename contains that substring.
      final pref = preferredFamily?.toLowerCase();
      if (pref != null && pref.isNotEmpty) {
        for (final f in matches) {
          if (p.basename(f.path).toLowerCase().contains(pref)) {
            _cachedPath = f.path;
            Log.instance.d('punc', 'found punc model (preferred)',
                fields: {'path': f.path, 'pref': pref});
            return _cachedPath;
          }
        }
      }
      _cachedPath = matches.first.path;
      Log.instance
          .d('punc', 'found punc model', fields: {'path': matches.first.path});
      return _cachedPath;
    } catch (e, st) {
      Log.instance
          .w('punc', 'failed to search models dir', error: e, stack: st);
      return null;
    }
  }

  /// Reset the search cache so a new `preferredFamily` value is honoured
  /// on the next [restore] call.
  void invalidate() {
    _searched = false;
    _cachedPath = null;
  }

  Future<crispasr.PuncModel?> _ensureLoaded() async {
    final path = await _findModel();
    if (path == null) return null;
    if (_model != null && _loadedPath == path) return _model;
    // A different file was picked since the last call (rare — e.g. user
    // deleted the q8_0 and downloaded the q4_k). Drop the stale model.
    _model?.close();
    _model = null;
    try {
      _model = crispasr.PuncModel.open(path);
      _loadedPath = path;
      Log.instance
          .i('punc', 'loaded FireRedPunc', fields: {'path': p.basename(path)});
      return _model;
    } catch (e, st) {
      Log.instance.w('punc', 'PuncModel.open failed',
          error: e, stack: st, fields: {'path': p.basename(path)});
      return null;
    }
  }

  /// Apply punctuation restoration to every non-empty segment text.
  /// Returns the input list unchanged if no FireRedPunc GGUF is on disk
  /// or the model failed to load.
  Future<List<TranscriptionSegment>> restore(
      List<TranscriptionSegment> segments) async {
    if (segments.isEmpty) return segments;
    final model = await _ensureLoaded();
    if (model == null) {
      Log.instance.d('punc',
          'no FireRedPunc GGUF available — skipping punctuation post-step');
      return segments;
    }
    final out = <TranscriptionSegment>[];
    var changed = 0;
    for (final s in segments) {
      final src = s.text.trim();
      if (src.isEmpty) {
        out.add(s);
        continue;
      }
      String dst;
      try {
        dst = model.process(src);
      } catch (e, st) {
        Log.instance.w('punc', 'PuncModel.process threw', error: e, stack: st);
        out.add(s);
        continue;
      }
      if (dst.trim().isEmpty || dst == src) {
        out.add(s);
        continue;
      }
      changed++;
      out.add(TranscriptionSegment(
        text: dst,
        startTime: s.startTime,
        endTime: s.endTime,
        speaker: s.speaker,
        confidence: s.confidence,
        words: s.words,
        metadata: s.metadata,
      ));
    }
    Log.instance.i('punc', 'punctuation restored', fields: {
      'segments': segments.length,
      'changed': changed,
    });
    return out;
  }

  /// Drop the loaded model. Safe to call multiple times.
  void dispose() {
    _model?.close();
    _model = null;
    _loadedPath = null;
    _searched = false;
    _cachedPath = null;
  }
}

final puncServiceProvider = Provider<PuncService>((ref) {
  final svc = PuncService(modelService: ref.watch(modelServiceProvider));
  ref.onDispose(svc.dispose);
  return svc;
});
