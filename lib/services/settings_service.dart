import 'package:flutter/material.dart';
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
  set preferredEngine(EngineType type) => _prefs.setString('preferred_engine', type.id);

  String get defaultModel => _prefs.getString('default_model') ?? 'base';
  set defaultModel(String model) => _prefs.setString('default_model', model);

  String get defaultBackend => _prefs.getString('default_backend') ?? 'whisper';
  set defaultBackend(String backend) => _prefs.setString('default_backend', backend);

  String get defaultLanguage => _prefs.getString('default_language') ?? 'auto';
  set defaultLanguage(String lang) => _prefs.setString('default_language', lang);

  bool get autoDetectLanguage => _prefs.getBool('auto_detect_language') ?? true;
  set autoDetectLanguage(bool value) => _prefs.setBool('auto_detect_language', value);

  bool get enableWordTimestamps => _prefs.getBool('enable_word_timestamps') ?? false;
  set enableWordTimestamps(bool value) => _prefs.setBool('enable_word_timestamps', value);

  // --- Audio Settings ---

  double get audioQuality => _prefs.getDouble('audio_quality') ?? 0.8;
  set audioQuality(double value) => _prefs.setDouble('audio_quality', value);

  bool get keepAudioFiles => _prefs.getBool('keep_audio_files') ?? false;
  set keepAudioFiles(bool value) => _prefs.setBool('keep_audio_files', value);

  // --- Diarization Settings ---

  bool get enableDiarizationByDefault => _prefs.getBool('enable_diarization_by_default') ?? false;
  set enableDiarizationByDefault(bool value) => _prefs.setBool('enable_diarization_by_default', value);

  // --- App Locale (i18n) ---

  String? get appLocale => _prefs.getString('app_locale');
  set appLocale(String? locale) {
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
  set logLevel(LogLevel level) => _prefs.setString('log_level', level.name);

  bool get logToFile => _prefs.getBool('log_to_file') ?? false;
  set logToFile(bool value) => _prefs.setBool('log_to_file', value);

  bool get skipChecksum => _prefs.getBool('skip_checksum') ?? false;
  set skipChecksum(bool value) => _prefs.setBool('skip_checksum', value);

  String get hfToken => _prefs.getString('hf_token') ?? '';
  set hfToken(String token) => _prefs.setString('hf_token', token);

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
