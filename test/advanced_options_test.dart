// AdvancedOptions is a value class threaded through every transcribe
// call. copyWith must preserve every other field when one is changed,
// or sliders silently reset their neighbours on each rebuild — the
// kind of bug that's easy to introduce when adding a new field and
// hard to spot in the UI.
import 'package:flutter_test/flutter_test.dart';

import 'package:crisper_weaver/widgets/advanced_options_widget.dart';

void main() {
  group('AdvancedOptions', () {
    test('default construction', () {
      const o = AdvancedOptions();
      expect(o.translate, isFalse);
      expect(o.beamSearch, isFalse);
      expect(o.initialPrompt, '');
      expect(o.vad, isFalse);
      expect(o.restorePunctuation, isFalse);
      expect(o.targetLanguage, '');
      expect(o.askPrompt, '');
      expect(o.temperature, 0.0);
      expect(o.sourceLanguage, '');
      expect(o.bestOf, 1);
    });

    test('copyWith with no args returns identical-valued copy', () {
      const original = AdvancedOptions(
        translate: true,
        beamSearch: true,
        initialPrompt: 'context line',
        vad: true,
        restorePunctuation: true,
        targetLanguage: 'de',
        askPrompt: 'Summarize the audio.',
        temperature: 0.7,
        sourceLanguage: 'en',
      );
      final copy = original.copyWith();
      expect(copy.translate, original.translate);
      expect(copy.beamSearch, original.beamSearch);
      expect(copy.initialPrompt, original.initialPrompt);
      expect(copy.vad, original.vad);
      expect(copy.restorePunctuation, original.restorePunctuation);
      expect(copy.targetLanguage, original.targetLanguage);
      expect(copy.askPrompt, original.askPrompt);
      expect(copy.temperature, original.temperature);
      expect(copy.sourceLanguage, original.sourceLanguage);
    });

    test('sourceLanguage roundtrips through copyWith', () {
      const original = AdvancedOptions(targetLanguage: 'en');
      final updated = original.copyWith(sourceLanguage: 'de');
      expect(updated.sourceLanguage, 'de');
      expect(updated.targetLanguage, 'en');

      final cleared = updated.copyWith(sourceLanguage: '');
      expect(cleared.sourceLanguage, '');
      expect(cleared.targetLanguage, 'en');
    });

    test('bestOf roundtrips through copyWith', () {
      const original = AdvancedOptions();
      final five = original.copyWith(bestOf: 5);
      expect(five.bestOf, 5);

      final back = five.copyWith(bestOf: 1);
      expect(back.bestOf, 1);
    });

    test('copyWith preserves untouched fields when one is changed', () {
      const original = AdvancedOptions(
        translate: true,
        beamSearch: true,
        targetLanguage: 'de',
        temperature: 0.5,
      );
      final adjusted = original.copyWith(temperature: 0.8);
      expect(adjusted.temperature, 0.8);
      expect(adjusted.translate, isTrue);
      expect(adjusted.beamSearch, isTrue);
      expect(adjusted.targetLanguage, 'de');
    });

    test('copyWith allows setting fields back to their defaults', () {
      const original = AdvancedOptions(
        beamSearch: true,
        targetLanguage: 'de',
        temperature: 0.7,
      );
      final reset = original.copyWith(
        beamSearch: false,
        targetLanguage: '',
        temperature: 0.0,
      );
      expect(reset.beamSearch, isFalse);
      expect(reset.targetLanguage, '');
      expect(reset.temperature, 0.0);
    });

    test('capability sets cover the documented backends', () {
      // Translation: shipped backends with `-tl` support today,
      // including the Granite Speech 4.1 family added in the CrispASR
      // 0.6 parity sweep.
      expect(
          AdvancedOptions.translationCapableBackends.containsAll([
            'canary',
            'cohere',
            'voxtral',
            'voxtral4b',
            'qwen3',
            'whisper',
            'granite',
            'granite-4.1',
            'granite-4.1-plus',
            'granite-4.1-nar',
          ]),
          isTrue);
      // Q&A: instruct-tuned audio LLMs — Granite + GLM-ASR joined in
      // the parity sweep.
      expect(
          AdvancedOptions.askCapableBackends.containsAll([
            'voxtral',
            'voxtral4b',
            'qwen3',
            'granite',
            'glm-asr',
          ]),
          isTrue);
      // Temperature: every backend `crispasr_session_set_temperature`
      // honours per the CrispASR CLI surface. Sweep added the LLM
      // backends (voxtral, qwen3, granite, glm-asr, gemma4-e2b,
      // omniasr-llm).
      expect(
          AdvancedOptions.temperatureCapableBackends.containsAll([
            'canary',
            'cohere',
            'parakeet',
            'moonshine',
            'voxtral',
            'voxtral4b',
            'qwen3',
            'granite',
            'glm-asr',
            'gemma4-e2b',
            'omniasr-llm',
          ]),
          isTrue);
      // Source-language: strict superset of translation-capable
      // (every translator accepts a source-lang pin) plus the
      // multilingual ASR backends that auto-detect language and
      // benefit from a pinned override on short clips.
      expect(
          AdvancedOptions.sourceLanguageCapableBackends
              .containsAll(AdvancedOptions.translationCapableBackends),
          isTrue,
          reason: 'every translation-capable backend also accepts a '
              'source-lang pin');
      expect(
          AdvancedOptions.sourceLanguageCapableBackends.containsAll([
            'parakeet',
            'mimo-asr',
            'firered-asr',
            'kyutai-stt',
            'glm-asr',
            'gemma4-e2b',
            'omniasr-llm',
            'omniasr-llm-unlimited',
            'moonshine',
          ]),
          isTrue,
          reason: 'multilingual ASR backends should get the source-lang '
              'picker too — not just translators');
      // English-only / non-ASR backends are excluded — the dropdown
      // would be useless on them.
      for (final excluded in const [
        'wav2vec2',
        'fastconformer-ctc',
        'kokoro',
        'orpheus',
        'chatterbox',
        'indextts',
        'vibevoice-tts',
        'pyannote',
        'firered-punc',
        'fullstop-punc',
      ]) {
        expect(
            AdvancedOptions.sourceLanguageCapableBackends.contains(excluded),
            isFalse,
            reason: '$excluded is English-only / non-ASR — no source-lang');
      }
    });

    test('new CrispASR 0.6 parity fields roundtrip', () {
      const opts = AdvancedOptions();
      // Defaults match the historical behaviour so old call sites
      // see no change.
      expect(opts.vadThreshold, 0.5);
      expect(opts.vadMinSpeechMs, 250);
      expect(opts.vadMinSilenceMs, 100);
      expect(opts.vadSpeechPadMs, 30);
      expect(opts.tdrz, isFalse);
      expect(opts.tokenTimestamps, isFalse);
      expect(opts.puncFamily, 'firered');
      // Perf defaults: GPU off (so first run on a Metal box doesn't
      // surprise the user), flash-attn on (matches CrispASR CLI), 4
      // threads (CrispASR's historical n_threads).
      expect(opts.lidUseGpu, isFalse);
      expect(opts.lidFlashAttn, isTrue);
      expect(opts.nThreads, 4);

      final tuned = opts.copyWith(
        vadThreshold: 0.65,
        vadMinSpeechMs: 400,
        tdrz: true,
        tokenTimestamps: true,
        puncFamily: 'fullstop',
        lidUseGpu: true,
        lidFlashAttn: false,
        nThreads: 8,
      );
      expect(tuned.vadThreshold, 0.65);
      expect(tuned.vadMinSpeechMs, 400);
      expect(tuned.tdrz, isTrue);
      expect(tuned.tokenTimestamps, isTrue);
      expect(tuned.puncFamily, 'fullstop');
      expect(tuned.lidUseGpu, isTrue);
      expect(tuned.lidFlashAttn, isFalse);
      expect(tuned.nThreads, 8);
      // Unrelated fields preserved.
      expect(tuned.vadMinSilenceMs, opts.vadMinSilenceMs);
      expect(tuned.bestOf, opts.bestOf);
    });
  });
}
