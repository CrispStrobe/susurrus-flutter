import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engines/engine_factory.dart';
import '../services/log_service.dart';

/// Central service for managing application settings and persistence.
class SettingsService {
  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  // --- Transcription Settings ---

  EngineType get preferredEngine {
    final id = _prefs.getString('preferred_engine');
    return EngineType.values.firstWhere(
      (e) => e.id == id,
      orElse: () => EngineFactory.getRecommendedEngine(),
    );
  }

  set preferredEngine(EngineType type) {
    Log.instance.d('settings', 'Saving preferredEngine: ${type.id}');
    _prefs.setString('preferred_engine', type.id);
  }

  String get defaultModel => _prefs.getString('default_model') ?? 'base';
  set defaultModel(String model) {
    Log.instance.d('settings', 'Saving defaultModel: $model');
    _prefs.setString('default_model', model);
  }

  String get defaultBackend => _prefs.getString('default_backend') ?? 'whisper';
  set defaultBackend(String backend) {
    Log.instance.d('settings', 'Saving defaultBackend: $backend');
    _prefs.setString('default_backend', backend);
  }

  String get defaultLanguage => _prefs.getString('default_language') ?? 'auto';
  set defaultLanguage(String lang) {
    Log.instance.d('settings', 'Saving defaultLanguage: $lang');
    _prefs.setString('default_language', lang);
  }

  bool get autoDetectLanguage => _prefs.getBool('auto_detect_language') ?? true;
  set autoDetectLanguage(bool value) {
    Log.instance.d('settings', 'Saving autoDetectLanguage: $value');
    _prefs.setBool('auto_detect_language', value);
  }

  bool get enableWordTimestamps =>
      _prefs.getBool('enable_word_timestamps') ?? false;
  set enableWordTimestamps(bool value) {
    Log.instance.d('settings', 'Saving enableWordTimestamps: $value');
    _prefs.setBool('enable_word_timestamps', value);
  }

  // --- Audio Settings ---

  double get audioQuality => _prefs.getDouble('audio_quality') ?? 0.8;
  set audioQuality(double value) {
    Log.instance.d('settings', 'Saving audioQuality: $value');
    _prefs.setDouble('audio_quality', value);
  }

  bool get keepAudioFiles => _prefs.getBool('keep_audio_files') ?? false;
  set keepAudioFiles(bool value) {
    Log.instance.d('settings', 'Saving keepAudioFiles: $value');
    _prefs.setBool('keep_audio_files', value);
  }

  // --- Diarization Settings ---

  bool get enableDiarizationByDefault =>
      _prefs.getBool('enable_diarization_by_default') ?? false;
  set enableDiarizationByDefault(bool value) {
    Log.instance.d('settings', 'Saving enableDiarizationByDefault: $value');
    _prefs.setBool('enable_diarization_by_default', value);
  }

  // --- App Locale (i18n) ---

  String? get appLocale => _prefs.getString('app_locale');
  set appLocale(String? locale) {
    Log.instance.d('settings', 'Saving appLocale: $locale');
    if (locale == null || locale.isEmpty) {
      _prefs.remove('app_locale');
    } else {
      _prefs.setString('app_locale', locale);
    }
  }

  // --- Developer / Debug Settings ---

  LogLevel get logLevel {
    final levelName = _prefs.getString('log_level');
    return LogLevel.values.firstWhere(
      (l) => l.name == levelName,
      orElse: () => LogLevel.info,
    );
  }

  set logLevel(LogLevel level) {
    Log.instance.d('settings', 'Saving logLevel: ${level.name}');
    _prefs.setString('log_level', level.name);
  }

  bool get logToFile => _prefs.getBool('log_to_file') ?? false;
  set logToFile(bool value) {
    Log.instance.d('settings', 'Saving logToFile: $value');
    _prefs.setBool('log_to_file', value);
  }

  bool get skipChecksum => _prefs.getBool('skip_checksum') ?? false;
  set skipChecksum(bool value) {
    Log.instance.d('settings', 'Saving skipChecksum: $value');
    _prefs.setBool('skip_checksum', value);
  }

  String get hfToken => _prefs.getString('hf_token') ?? '';
  set hfToken(String token) {
    Log.instance
        .d('settings', 'Saving hfToken: ${token.isNotEmpty ? "SET" : "EMPTY"}');
    _prefs.setString('hf_token', token);
  }

  /// Override directory for model GGUFs / .bin files. Empty / null
  /// means "use the platform-default `<app-docs>/models/whisper_cpp`".
  /// Useful for users who keep a shared library on an external disk
  /// (e.g. `/Volumes/backups/ai/crispasr-models`) and don't want
  /// CrisperWeaver to re-download every quant into its sandbox.
  ///
  /// ModelService.getModelsDirOverride reads this on every call so the
  /// effect is live — change the setting and the next download lands
  /// at the new path without an app restart.
  String get customModelsDir => _prefs.getString('custom_models_dir') ?? '';
  set customModelsDir(String dir) {
    Log.instance.d('settings',
        'Saving customModelsDir: ${dir.isEmpty ? "DEFAULT" : dir}');
    _prefs.setString('custom_models_dir', dir);
  }

  /// Reorder a batch queue so jobs with the same
  /// (backend, modelId, language) run consecutively, sparing the
  /// expensive session swap between them. Stable — preserves the
  /// enqueue order within each bundle. Default off so the user's
  /// drag-and-drop order is honoured verbatim by the drain loop.
  /// §5.23 Q1 grouping sub-bullet.
  bool get groupBatchByBackend =>
      _prefs.getBool('group_batch_by_backend') ?? false;
  set groupBatchByBackend(bool value) {
    Log.instance.d('settings', 'Saving groupBatchByBackend: $value');
    _prefs.setBool('group_batch_by_backend', value);
  }

  /// How many transcription jobs the drain loop runs in pipeline-
  /// parallel mode (§5.23 Q2). Stored as 1..[maxConcurrentLimit].
  ///
  /// v1 (shipped): "pipeline parallelism" — slider > 1 enables
  /// async audio prefetch of the next queued file in a worker
  /// isolate, overlapping its decode + Mel computation with the
  /// current file's GPU transcription. One session, one model
  /// copy in RAM, real-world speedup of 5–15% on batches of
  /// compressed audio (mp3 / m4a / opus) where decode is a non-
  /// trivial slice of total wall time.
  ///
  /// v2 (deferred — see PLAN §5.23): true N-way session pool with
  /// per-isolate `CrispasrSession` instances. Memory cost is
  /// N × model size; gated behind a future "I have RAM to burn"
  /// affordance.
  int get maxConcurrentTranscriptions {
    final raw = _prefs.getInt('max_concurrent_transcriptions') ?? 1;
    if (raw < 1) return 1;
    final cap = maxConcurrentTranscriptionsLimit;
    return raw > cap ? cap : raw;
  }

  set maxConcurrentTranscriptions(int value) {
    final cap = maxConcurrentTranscriptionsLimit;
    final clamped = value < 1 ? 1 : (value > cap ? cap : value);
    Log.instance.d('settings',
        'Saving maxConcurrentTranscriptions: $clamped (requested $value, cap $cap)');
    _prefs.setInt('max_concurrent_transcriptions', clamped);
  }

  /// Per-platform upper bound for the concurrent-transcriptions
  /// slider. iOS caps at 2 because of the tight memory budget on
  /// even the largest iPhone (8 GB); desktop/Android caps at 4
  /// because beyond that Metal queue contention dominates and the
  /// marginal speedup tapers.
  int get maxConcurrentTranscriptionsLimit => Platform.isIOS ? 2 : 4;

  /// How many *true* parallel session workers the drain loop spawns
  /// (§5.23 Q2 v2). 1 = no pool (the v1 prefetch is what the other
  /// slider controls). 2+ spins up N persistent worker isolates,
  /// each holding its own CrispasrSession against the same model.
  /// Real GPU + decoder concurrency; cost is N × model size in RAM.
  ///
  /// At batch start the drain loop runs `MemoryEstimator.estimate`
  /// against the active model + this slider value, and clamps the
  /// actual worker count down to what fits in
  /// `physicalMemory × 50% − 400 MB`. The user-set value is what's
  /// requested; the actual spawn count is what's affordable.
  int get maxConcurrentSessions {
    final raw = _prefs.getInt('max_concurrent_sessions') ?? 1;
    if (raw < 1) return 1;
    final cap = maxConcurrentSessionsLimit;
    return raw > cap ? cap : raw;
  }

  set maxConcurrentSessions(int value) {
    final cap = maxConcurrentSessionsLimit;
    final clamped = value < 1 ? 1 : (value > cap ? cap : value);
    Log.instance.d('settings',
        'Saving maxConcurrentSessions: $clamped (requested $value, cap $cap)');
    _prefs.setInt('max_concurrent_sessions', clamped);
  }

  /// Same per-platform shape as the prefetch slider — iOS caps at 2
  /// (very tight memory), everything else at 4 (beyond which Metal
  /// queue contention dominates). The pre-flight check may clamp
  /// lower at runtime when the chosen model is too big.
  int get maxConcurrentSessionsLimit => Platform.isIOS ? 2 : 4;

  /// §5.1.5 Phase C — whether the EditAudioScreen's transcript
  /// pane is expanded by default. Persists so users who treat
  /// the editor as audio-only collapse once and never see the
  /// pane again; users who treat it as a Descript-style joint
  /// editor leave it open. Default false to favour the pure-
  /// audio-editing flow on first launch.
  bool get editAudioShowTranscript =>
      _prefs.getBool('edit_audio_show_transcript') ?? false;
  set editAudioShowTranscript(bool value) {
    Log.instance
        .d('settings', 'Saving editAudioShowTranscript: $value');
    _prefs.setBool('edit_audio_show_transcript', value);
  }

  /// Helper to clear all settings (for reset)
  Future<void> clearAll() async {
    await _prefs.clear();
  }
}

/// Provider for the SettingsService.
/// Note: Requires initialization in main() before use.
final settingsServiceProvider = Provider<SettingsService>((ref) {
  throw UnimplementedError('SettingsService not initialized');
});
