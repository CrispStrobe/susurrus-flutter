// Hermetic tests for PresetService — JSON round-trip of the
// AdvancedOptions surface, name-collision handling, defensive
// fromJson with unknown / missing keys.

import 'package:crispasr/crispasr.dart' as crispasr;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crisper_weaver/services/preset_service.dart';
import 'package:crisper_weaver/services/vad_service.dart';
import 'package:crisper_weaver/widgets/advanced_options_widget.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AdvancedOptions JSON round-trip', () {
    test('defaults round-trip cleanly', () {
      const opts = AdvancedOptions();
      final json = advancedOptionsToJson(opts);
      final restored = advancedOptionsFromJson(json);
      // Pin the 27 fields one by one — easier to debug than a
      // single ==() check would be.
      expect(restored.translate, opts.translate);
      expect(restored.beamSearch, opts.beamSearch);
      expect(restored.initialPrompt, opts.initialPrompt);
      expect(restored.vad, opts.vad);
      expect(restored.restorePunctuation, opts.restorePunctuation);
      expect(restored.targetLanguage, opts.targetLanguage);
      expect(restored.askPrompt, opts.askPrompt);
      expect(restored.temperature, opts.temperature);
      expect(restored.sourceLanguage, opts.sourceLanguage);
      expect(restored.bestOf, opts.bestOf);
      expect(restored.vadBackend, opts.vadBackend);
      expect(restored.vadThreshold, opts.vadThreshold);
      expect(restored.vadMinSpeechMs, opts.vadMinSpeechMs);
      expect(restored.vadMinSilenceMs, opts.vadMinSilenceMs);
      expect(restored.vadSpeechPadMs, opts.vadSpeechPadMs);
      expect(restored.diarizeMethod, opts.diarizeMethod);
      expect(restored.lidMethod, opts.lidMethod);
      expect(restored.tdrz, opts.tdrz);
      expect(restored.tokenTimestamps, opts.tokenTimestamps);
      expect(restored.puncFamily, opts.puncFamily);
      expect(restored.lidUseGpu, opts.lidUseGpu);
      expect(restored.lidFlashAttn, opts.lidFlashAttn);
      expect(restored.nThreads, opts.nThreads);
      expect(restored.asrUseGpu, opts.asrUseGpu);
      expect(restored.asrFlashAttn, opts.asrFlashAttn);
      expect(restored.asrNGpuLayers, opts.asrNGpuLayers);
      expect(restored.vocabulary, opts.vocabulary);
      expect(restored.maxLen, opts.maxLen);
      expect(restored.splitOnWord, opts.splitOnWord);
    });

    test('non-default values round-trip', () {
      const opts = AdvancedOptions(
        translate: true,
        beamSearch: true,
        initialPrompt: 'API kubectl',
        vad: true,
        restorePunctuation: true,
        targetLanguage: 'de',
        askPrompt: 'Summarize',
        temperature: 0.7,
        sourceLanguage: 'fr',
        bestOf: 5,
        vadBackend: VadBackend.firered,
        vadThreshold: 0.6,
        vadMinSpeechMs: 300,
        vadMinSilenceMs: 200,
        vadSpeechPadMs: 50,
        diarizeMethod: crispasr.DiarizeMethod.pyannote,
        lidMethod: crispasr.LidMethod.silero,
        tdrz: true,
        tokenTimestamps: true,
        puncFamily: 'fullstop',
        lidUseGpu: true,
        lidFlashAttn: false,
        nThreads: 8,
        asrUseGpu: false,
        asrFlashAttn: false,
        asrNGpuLayers: 16,
        vocabulary: ['API', 'kubectl', 'Alice'],
        maxLen: 80,
        splitOnWord: true,
        grammarText: 'root ::= "yes" | "no"\n',
        grammarRootRule: 'root',
        grammarPenalty: 75.0,
        // Whisper decoder-fallback thresholds — every field set
        // to a non-default value so a regression in any one of
        // them surfaces here instead of silently reverting to the
        // stock whisper.cpp default.
        entropyThold: 3.0,
        logprobThold: -2.0,
        noSpeechThold: 0.45,
        temperatureInc: 0.0, // = `--no-fallback`
        // Whisper text-suppression + prompt-carry extras — same
        // logic, every field non-default so the round-trip pins
        // the JSON keys explicitly.
        suppressNonSpeechTokens: true,
        suppressTokensRegex: r'\[NOISE\]',
        carryInitialPrompt: true,
        // §5.1.10 — audio enhancement pre-step. Non-default value
        // so the round-trip pins the JSON key explicitly.
        enhanceAudio: true,
      );
      final json = advancedOptionsToJson(opts);
      final restored = advancedOptionsFromJson(json);
      expect(restored.translate, true);
      expect(restored.bestOf, 5);
      expect(restored.vadBackend, VadBackend.firered);
      expect(restored.diarizeMethod, crispasr.DiarizeMethod.pyannote);
      expect(restored.lidMethod, crispasr.LidMethod.silero);
      expect(restored.targetLanguage, 'de');
      expect(restored.askPrompt, 'Summarize');
      expect(restored.temperature, 0.7);
      expect(restored.vocabulary, ['API', 'kubectl', 'Alice']);
      expect(restored.maxLen, 80);
      expect(restored.splitOnWord, true);
      // §5.8 — GBNF fields round-trip with the rest. A user
      // saving a "force-JSON" preset should pick it up later
      // without re-typing the grammar.
      expect(restored.grammarText, 'root ::= "yes" | "no"\n');
      expect(restored.grammarRootRule, 'root');
      expect(restored.grammarPenalty, 75.0);
      // Whisper decoder-fallback thresholds. A "hard audio"
      // preset should survive restart with all four overrides
      // intact — defaults silently sneaking back in would
      // change behaviour without the user noticing.
      expect(restored.entropyThold, 3.0);
      expect(restored.logprobThold, -2.0);
      expect(restored.noSpeechThold, 0.45);
      expect(restored.temperatureInc, 0.0);
      // Whisper text-suppression + prompt-carry. A "drop laughter
      // markers + carry prompt" preset should survive restart.
      expect(restored.suppressNonSpeechTokens, isTrue);
      expect(restored.suppressTokensRegex, r'\[NOISE\]');
      expect(restored.carryInitialPrompt, isTrue);
      // §5.1.10 — audio-enhancement toggle survives the round trip.
      expect(restored.enhanceAudio, isTrue);
    });

    test('missing keys fall through to ctor defaults', () {
      final json = <String, dynamic>{
        // Only bestOf is set; everything else missing.
        'bestOf': 3,
      };
      final restored = advancedOptionsFromJson(json);
      expect(restored.bestOf, 3);
      expect(restored.translate, false);
      expect(restored.vadThreshold, 0.5);
      expect(restored.vadBackend, VadBackend.silero);
      expect(restored.diarizeMethod, crispasr.DiarizeMethod.vadTurns);
      expect(restored.lidMethod, crispasr.LidMethod.whisper);
    });

    test('unknown enum names fall through to ctor defaults', () {
      final json = <String, dynamic>{
        'vadBackend': 'martian-vad',
        'diarizeMethod': 'sentient-router',
        'lidMethod': 'magic-8-ball',
      };
      final restored = advancedOptionsFromJson(json);
      expect(restored.vadBackend, VadBackend.silero);
      expect(restored.diarizeMethod, crispasr.DiarizeMethod.vadTurns);
      expect(restored.lidMethod, crispasr.LidMethod.whisper);
    });

    test('integer-typed temperature is coerced to double', () {
      final json = <String, dynamic>{'temperature': 1};
      final restored = advancedOptionsFromJson(json);
      expect(restored.temperature, 1.0);
    });

    test('unknown extra keys are ignored (forward-compat)', () {
      final json = <String, dynamic>{
        'futureFeatureFlag': true,
        'someNewSetting': 42,
        'vad': true, // and a real one
      };
      final restored = advancedOptionsFromJson(json);
      expect(restored.vad, true);
      // No throw; forward-compat OK.
    });
  });

  group('PresetService', () {
    test('all() on a fresh prefs returns empty list', () async {
      final prefs = await SharedPreferences.getInstance();
      final svc = PresetService(prefs);
      expect(svc.all(), isEmpty);
    });

    test('add → all returns the row in createdAt order', () async {
      final prefs = await SharedPreferences.getInstance();
      final svc = PresetService(prefs);
      final p1 = await svc.add(
        name: 'Podcast prep',
        backend: 'whisper',
        modelId: 'base',
        language: 'en',
        options: const AdvancedOptions(beamSearch: true),
      );
      final p2 = await svc.add(
        name: 'Voice memos',
        backend: 'moonshine',
        modelId: 'tiny',
        language: 'auto',
        options: const AdvancedOptions(vad: true),
      );
      final list = svc.all();
      expect(list, hasLength(2));
      expect(list[0].id, p1.id);
      expect(list[0].name, 'Podcast prep');
      expect(list[0].backend, 'whisper');
      expect(list[0].options.beamSearch, true);
      expect(list[1].id, p2.id);
      expect(list[1].name, 'Voice memos');
      expect(list[1].options.vad, true);
    });

    test('name collision gets " (2)" suffix', () async {
      final prefs = await SharedPreferences.getInstance();
      final svc = PresetService(prefs);
      await svc.add(
        name: 'Default',
        backend: 'whisper',
        modelId: 'base',
        language: 'auto',
        options: const AdvancedOptions(),
      );
      final p2 = await svc.add(
        name: 'Default',
        backend: 'whisper',
        modelId: 'tiny',
        language: 'auto',
        options: const AdvancedOptions(),
      );
      expect(p2.name, 'Default (2)');
    });

    test('update overwrites in place', () async {
      final prefs = await SharedPreferences.getInstance();
      final svc = PresetService(prefs);
      final p = await svc.add(
        name: 'Original',
        backend: 'whisper',
        modelId: 'base',
        language: 'en',
        options: const AdvancedOptions(),
      );
      await svc.update(p.copyWith(
          name: 'Renamed',
          options: const AdvancedOptions(beamSearch: true)));
      final list = svc.all();
      expect(list, hasLength(1));
      expect(list[0].name, 'Renamed');
      expect(list[0].options.beamSearch, true);
    });

    test('remove drops the row by id', () async {
      final prefs = await SharedPreferences.getInstance();
      final svc = PresetService(prefs);
      final p = await svc.add(
        name: 'temp',
        backend: '',
        modelId: '',
        language: 'auto',
        options: const AdvancedOptions(),
      );
      await svc.remove(p.id);
      expect(svc.all(), isEmpty);
    });

    test('remove with unknown id is a no-op', () async {
      final prefs = await SharedPreferences.getInstance();
      final svc = PresetService(prefs);
      await svc.add(
        name: 'kept',
        backend: '',
        modelId: '',
        language: 'auto',
        options: const AdvancedOptions(),
      );
      await svc.remove('p-no-such-id');
      expect(svc.all(), hasLength(1));
    });

    test('clear empties the list', () async {
      final prefs = await SharedPreferences.getInstance();
      final svc = PresetService(prefs);
      await svc.add(
        name: 'a',
        backend: '',
        modelId: '',
        language: 'auto',
        options: const AdvancedOptions(),
      );
      await svc.add(
        name: 'b',
        backend: '',
        modelId: '',
        language: 'auto',
        options: const AdvancedOptions(),
      );
      await svc.clear();
      expect(svc.all(), isEmpty);
    });

    test('persists across PresetService instances on same prefs', () async {
      final prefs = await SharedPreferences.getInstance();
      final svc1 = PresetService(prefs);
      await svc1.add(
        name: 'persisted',
        backend: 'voxtral',
        modelId: 'voxtral-mini-3b',
        language: 'auto',
        options: const AdvancedOptions(askPrompt: 'Summarize'),
      );
      // New service instance, same prefs blob — simulates app restart.
      final svc2 = PresetService(prefs);
      final list = svc2.all();
      expect(list, hasLength(1));
      expect(list[0].name, 'persisted');
      expect(list[0].backend, 'voxtral');
      expect(list[0].options.askPrompt, 'Summarize');
    });

    test('Preset.id is unique across rapid add calls', () async {
      final prefs = await SharedPreferences.getInstance();
      final svc = PresetService(prefs);
      final ids = <String>{};
      for (var i = 0; i < 10; i++) {
        final p = await svc.add(
          name: 'r$i',
          backend: '',
          modelId: '',
          language: 'auto',
          options: const AdvancedOptions(),
        );
        ids.add(p.id);
      }
      expect(ids, hasLength(10));
    });
  });
}
