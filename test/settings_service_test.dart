// SettingsService persistence — drives the actual SharedPreferences
// round-trip via the in-memory mock. Catches typos in storage keys
// that pure-code review can miss and verifies sensible fallback
// defaults when nothing is stored.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crisper_weaver/engines/engine_factory.dart';
import 'package:crisper_weaver/services/log_service.dart';
import 'package:crisper_weaver/services/settings_service.dart';

void main() {
  late SharedPreferences prefs;
  late SettingsService svc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    svc = SettingsService(prefs);
  });

  group('SettingsService defaults (empty store)', () {
    test('falls back to documented defaults for every field', () {
      expect(svc.preferredEngine, EngineType.crispasr);
      expect(svc.defaultModel, 'base');
      expect(svc.defaultBackend, 'whisper');
      expect(svc.defaultLanguage, 'auto');
      expect(svc.autoDetectLanguage, isTrue);
      expect(svc.enableWordTimestamps, isFalse);
      expect(svc.audioQuality, 0.8);
      expect(svc.keepAudioFiles, isFalse);
      expect(svc.enableDiarizationByDefault, isFalse);
      expect(svc.appLocale, isNull);
      expect(svc.logToFile, isFalse);
      expect(svc.skipChecksum, isFalse);
      expect(svc.hfToken, '');
      expect(svc.customModelsDir, '');
    });
  });

  group('SettingsService round-trip', () {
    test('every setter persists to SharedPreferences', () {
      svc.preferredEngine = EngineType.mock;
      svc.defaultModel = 'tiny';
      svc.defaultBackend = 'parakeet';
      svc.defaultLanguage = 'de';
      svc.autoDetectLanguage = false;
      svc.enableWordTimestamps = true;
      svc.audioQuality = 0.5;
      svc.keepAudioFiles = true;
      svc.enableDiarizationByDefault = true;
      svc.appLocale = 'de';
      svc.logLevel = LogLevel.debug;
      svc.logToFile = true;
      svc.skipChecksum = true;
      svc.hfToken = 'hf_secret_token';
      svc.customModelsDir = '/Volumes/backups/ai/crispasr-models';

      // Fresh service over the same backing store reads everything
      // back — confirms keys, types, and defaults all line up.
      final reloaded = SettingsService(prefs);
      expect(reloaded.preferredEngine, EngineType.mock);
      expect(reloaded.defaultModel, 'tiny');
      expect(reloaded.defaultBackend, 'parakeet');
      expect(reloaded.defaultLanguage, 'de');
      expect(reloaded.autoDetectLanguage, isFalse);
      expect(reloaded.enableWordTimestamps, isTrue);
      expect(reloaded.audioQuality, 0.5);
      expect(reloaded.keepAudioFiles, isTrue);
      expect(reloaded.enableDiarizationByDefault, isTrue);
      expect(reloaded.appLocale, 'de');
      expect(reloaded.logLevel, LogLevel.debug);
      expect(reloaded.logToFile, isTrue);
      expect(reloaded.skipChecksum, isTrue);
      expect(reloaded.hfToken, 'hf_secret_token');
      expect(reloaded.customModelsDir, '/Volumes/backups/ai/crispasr-models');
    });

    test('appLocale = null clears the override', () {
      svc.appLocale = 'de';
      expect(svc.appLocale, 'de');
      svc.appLocale = null;
      expect(svc.appLocale, isNull);
    });

    test('preferredEngine survives roundtrip for every EngineType', () {
      for (final t in EngineType.values) {
        svc.preferredEngine = t;
        expect(SettingsService(prefs).preferredEngine, t,
            reason: 'EngineType.$t did not round-trip');
      }
    });

    test('logLevel survives roundtrip for every LogLevel', () {
      for (final lv in LogLevel.values) {
        svc.logLevel = lv;
        expect(SettingsService(prefs).logLevel, lv,
            reason: 'LogLevel.$lv did not round-trip');
      }
    });
  });
}
