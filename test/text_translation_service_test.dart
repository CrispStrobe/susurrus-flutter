// Pure-Dart sanity check on the language list TextTranslationService
// exposes to the Translate screen's dropdowns. Nothing here exercises
// FFI — the C-side translation path is opt-in slow, gated on a real
// m2m100 GGUF (see backend_dispatch_test.dart).

import 'package:flutter_test/flutter_test.dart';

import 'package:crisper_weaver/services/text_translation_service.dart';

void main() {
  group('TextTranslationService.supportedLanguages', () {
    test('contains the canonical M2M-100 anchor languages', () {
      // M2M-100 is famous for its 100-language coverage; the dropdown
      // must at minimum offer the major scripts. Spot-check a few
      // anchors so a typo / accidental drop in the list is caught.
      final keys = TextTranslationService.supportedLanguages
          .map((e) => e.key)
          .toSet();
      for (final code in ['en', 'de', 'fr', 'es', 'zh', 'ja', 'ar', 'hi']) {
        expect(keys, contains(code),
            reason: '$code missing from supportedLanguages — '
                'Translate screen dropdowns won\'t let users pick it');
      }
    });

    test('every entry is an ISO 639-1 code (2 lowercase letters)', () {
      // Catches accidental "EN-US" or "english" entries that would
      // mis-route to a backend expecting the canonical code.
      for (final e in TextTranslationService.supportedLanguages) {
        expect(e.key.length, 2,
            reason: 'unexpected key "${e.key}" — must be a 2-letter '
                'ISO 639-1 code');
        expect(e.key, e.key.toLowerCase(),
            reason: 'key "${e.key}" must be lowercase');
      }
    });

    test('list is deduplicated', () {
      final keys =
          TextTranslationService.supportedLanguages.map((e) => e.key).toList();
      expect(keys.toSet().length, keys.length,
          reason: 'duplicate language code in supportedLanguages');
    });

    test('list is broad enough to cover M2M-100\'s headline range', () {
      // M2M-100 is a 100-language model; we don't require every code
      // to be selectable here (the dropdown would be unwieldy), but
      // we should at least ship a serious subset.
      expect(TextTranslationService.supportedLanguages.length,
          greaterThanOrEqualTo(60),
          reason: 'language list is too short for a translator that '
              'advertises 100-language coverage');
    });
  });
}
