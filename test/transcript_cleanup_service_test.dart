// Hermetic unit tests for TranscriptCleanupService.
//
// Pure functions, no Flutter / FFI / network. Pins each
// transform's behaviour individually plus the composed
// cleanupText pipeline.

import 'package:flutter_test/flutter_test.dart';

import 'package:crisper_weaver/services/transcript_cleanup_service.dart';

void main() {
  const svc = TranscriptCleanupService();

  group('resolveFillers', () {
    test('English defaults are present', () {
      final f = svc.resolveFillers(const CleanupOptions());
      expect(f, containsAll(['um', 'uh', 'ah', 'mm']));
    });

    test('German hint switches the default set', () {
      final f = svc.resolveFillers(
          const CleanupOptions(languageHint: 'de'));
      expect(f, containsAll(['äh', 'ähm', 'ähem']));
      expect(f, isNot(contains('um'))); // EN default not included
    });

    test('customFillers merge on top of defaults', () {
      final f = svc.resolveFillers(const CleanupOptions(
          customFillers: ['like', 'basically', '  ']));
      expect(f, containsAll(['like', 'basically']));
      expect(f, isNot(contains('  '))); // whitespace-only dropped
    });

    test('unknown language falls back to English', () {
      final f = svc.resolveFillers(
          const CleanupOptions(languageHint: 'xx-fake'));
      expect(f, contains('um'));
    });
  });

  group('removeFillers', () {
    final fillers = {'um', 'uh', 'mm'};

    test('strips standalone occurrences', () {
      expect(
        svc.removeFillers('Well, um, the thing is.', fillers),
        'Well, the thing is.',
      );
    });

    test('case-insensitive', () {
      expect(
        svc.removeFillers('UH, that one', fillers),
        'that one',
      );
    });

    test('leaves substrings inside other words alone', () {
      expect(
        svc.removeFillers('Hummingbird mumbled', fillers),
        'Hummingbird mumbled',
      );
    });

    test('empty fillers set is a no-op', () {
      expect(
        svc.removeFillers('um uh ah', const <String>{}),
        'um uh ah',
      );
    });
  });

  group('collapseRepeats', () {
    test('removes adjacent duplicates', () {
      expect(svc.collapseRepeats('the the cat'), 'the cat');
    });

    test('removes runs of triplicates+', () {
      expect(svc.collapseRepeats('the the the cat'), 'the cat');
    });

    test('case-insensitive match, keeps first casing', () {
      expect(svc.collapseRepeats('The the cat'), 'The cat');
    });

    test('preserves non-adjacent repeats', () {
      expect(
        svc.collapseRepeats('the cat and the dog'),
        'the cat and the dog',
      );
    });
  });

  group('normalizeWhitespace', () {
    test('collapses multiple spaces', () {
      expect(
        svc.normalizeWhitespace('hello    world'),
        'hello world',
      );
    });

    test('strips space before punctuation', () {
      expect(
        svc.normalizeWhitespace('hello , world .'),
        'hello, world.',
      );
    });

    test('trims ends', () {
      expect(svc.normalizeWhitespace('  hello  '), 'hello');
    });
  });

  group('fixPunctuation', () {
    test('collapses double dots that are not ellipsis', () {
      expect(svc.fixPunctuation('hello.. world'), 'hello. world');
    });

    test('preserves three-dot ellipsis', () {
      expect(svc.fixPunctuation('hello... world'), 'hello... world');
    });

    test('strips trailing comma before period', () {
      expect(svc.fixPunctuation('hello,.'), 'hello.');
    });

    test('collapses repeated commas', () {
      expect(svc.fixPunctuation('hello,, world'), 'hello, world');
    });
  });

  group('sentenceCase', () {
    test('capitalises the very first letter', () {
      expect(svc.sentenceCase('hello world.'), 'Hello world.');
    });

    test('capitalises after period/question/bang', () {
      expect(
        svc.sentenceCase('hello world. how are you? fine!'),
        'Hello world. How are you? Fine!',
      );
    });

    test('leaves already-capital letters alone', () {
      expect(
        svc.sentenceCase('Hello World. How are you?'),
        'Hello World. How are you?',
      );
    });

    test('handles unicode letters', () {
      expect(svc.sentenceCase('über alles.'), 'Über alles.');
    });
  });

  group('stripAnnotations', () {
    test('strips square-bracket tags', () {
      expect(
        svc.stripAnnotations('hello [laughter] world'),
        'hello  world',
      );
    });

    test('strips parenthetical tags', () {
      expect(
        svc.stripAnnotations('hello (applause) world'),
        'hello  world',
      );
    });

    test('strips angle-bracket tags', () {
      expect(
        svc.stripAnnotations('hello <noise> world'),
        'hello  world',
      );
    });
  });

  group('cleanupText (composed pipeline)', () {
    test('all defaults — filler+repeat+whitespace+capitalisation', () {
      final out = svc.cleanupText(
        'um, the the cat sat on the mat. uh, and then it slept.',
        const CleanupOptions(),
      );
      expect(out, 'The cat sat on the mat. And then it slept.');
    });

    test('honours custom fillers', () {
      final out = svc.cleanupText(
        'like, basically the cat sat down.',
        const CleanupOptions(customFillers: ['like', 'basically']),
      );
      expect(out, 'The cat sat down.');
    });

    test('annotations off by default', () {
      final out = svc.cleanupText(
        '[laughter] um the the cat sat.',
        const CleanupOptions(),
      );
      // [laughter] kept; um stripped, the the → the, capitalised
      expect(out, '[laughter] The cat sat.');
    });

    test('annotations on strips them', () {
      final out = svc.cleanupText(
        '[laughter] um the cat sat.',
        const CleanupOptions(stripAnnotations: true),
      );
      expect(out, 'The cat sat.');
    });

    test('idempotent — second pass is a no-op', () {
      const input = 'um, the the cat. uh, dog.';
      final pass1 = svc.cleanupText(input, const CleanupOptions());
      final pass2 = svc.cleanupText(pass1, const CleanupOptions());
      expect(pass2, pass1);
    });

    test('empty text is a no-op', () {
      expect(svc.cleanupText('', const CleanupOptions()), '');
    });

    test('preserves trailing punctuation', () {
      final out = svc.cleanupText(
        'hello world.',
        const CleanupOptions(),
      );
      expect(out, endsWith('.'));
    });
  });
}
