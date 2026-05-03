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
      // Translation: shipped backends with `-tl` support today.
      expect(AdvancedOptions.translationCapableBackends, {
        'canary',
        'cohere',
        'voxtral',
        'voxtral4b',
        'qwen3',
        'whisper',
      });
      // Q&A: instruct-tuned audio LLMs.
      expect(AdvancedOptions.askCapableBackends, {
        'voxtral',
        'voxtral4b',
        'qwen3',
      });
      // Temperature: `crispasr_session_set_temperature` honourers per
      // the CrispASR doc comment.
      expect(AdvancedOptions.temperatureCapableBackends, {
        'canary',
        'cohere',
        'parakeet',
        'moonshine',
      });
    });
  });
}
