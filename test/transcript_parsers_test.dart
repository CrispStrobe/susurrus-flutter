// Tests for the SRT / VTT / TXT parsers used by the inbound
// transcript-file share intake. Pins the grammar handling we
// depend on for §share-intake-A3 — speaker-prefix extraction,
// HH:MM:SS,ms vs HH:MM:SS.ms timestamps, optional VTT cue
// identifiers, and the fall-through plaintext shape.

import 'package:flutter_test/flutter_test.dart';

import 'package:crisper_weaver/utils/transcript_parsers.dart';

void main() {
  group('parseSrt', () {
    test('two-block SRT with speaker prefixes', () {
      const src = '''
1
00:00:01,500 --> 00:00:03,000
Alice: Hello there.

2
00:00:03,200 --> 00:00:05,750
Bob: General Kenobi.
''';
      final r = TranscriptParsers.parseSrt(src);
      expect(r.source, TranscriptSource.srt);
      expect(r.segments, hasLength(2));
      expect(r.segments[0].startTime, closeTo(1.5, 1e-6));
      expect(r.segments[0].endTime, closeTo(3.0, 1e-6));
      expect(r.segments[0].speaker, 'Alice');
      expect(r.segments[0].text, 'Hello there.');
      expect(r.segments[1].speaker, 'Bob');
      expect(r.segments[1].text, 'General Kenobi.');
    });

    test('tolerates CRLF line endings + missing trailing blank',
        () {
      const src =
          '1\r\n00:00:00,000 --> 00:00:02,000\r\nFirst.\r\n\r\n2\r\n00:00:02,500 --> 00:00:03,800\r\nSecond.';
      final r = TranscriptParsers.parseSrt(src);
      expect(r.segments, hasLength(2));
      expect(r.segments[0].text, 'First.');
      expect(r.segments[1].text, 'Second.');
    });

    test('segments without a speaker prefix keep speaker null', () {
      const src = '''
1
00:00:00,000 --> 00:00:01,000
Just a line.
''';
      final r = TranscriptParsers.parseSrt(src);
      expect(r.segments, hasLength(1));
      expect(r.segments[0].speaker, isNull);
      expect(r.segments[0].text, 'Just a line.');
    });

    test('URLs in text are not mistaken for speaker prefixes', () {
      const src = '''
1
00:00:00,000 --> 00:00:02,000
See https://example.com for details.
''';
      final r = TranscriptParsers.parseSrt(src);
      expect(r.segments[0].speaker, isNull,
          reason: 'https://… must not be parsed as "https" speaker');
      expect(r.segments[0].text,
          'See https://example.com for details.');
    });

    test('malformed timestamp block is silently skipped', () {
      const src = '''
1
not-a-timestamp
Should be dropped.

2
00:00:05,000 --> 00:00:07,000
Should survive.
''';
      final r = TranscriptParsers.parseSrt(src);
      expect(r.segments, hasLength(1));
      expect(r.segments[0].text, 'Should survive.');
    });

    test('plainText is the segments joined by newline', () {
      const src = '''
1
00:00:00,000 --> 00:00:01,000
Alice: a

2
00:00:01,000 --> 00:00:02,000
Bob: b
''';
      final r = TranscriptParsers.parseSrt(src);
      expect(r.plainText, 'a\nb');
    });
  });

  group('parseVtt', () {
    test('classic VTT header + two cues, no cue ids', () {
      const src = '''
WEBVTT

00:00:01.500 --> 00:00:03.000
Alice: Hello there.

00:00:03.200 --> 00:00:05.750
Bob: General Kenobi.
''';
      final r = TranscriptParsers.parseVtt(src);
      expect(r.source, TranscriptSource.vtt);
      expect(r.segments, hasLength(2));
      expect(r.segments[0].startTime, closeTo(1.5, 1e-6));
      expect(r.segments[0].speaker, 'Alice');
      expect(r.segments[1].speaker, 'Bob');
    });

    test('MM:SS.ms short-form timestamp is accepted (no HH)', () {
      const src = '''
WEBVTT

00:01.000 --> 00:03.500
Short form.
''';
      final r = TranscriptParsers.parseVtt(src);
      expect(r.segments, hasLength(1));
      expect(r.segments[0].startTime, closeTo(1.0, 1e-6));
      expect(r.segments[0].endTime, closeTo(3.5, 1e-6));
      expect(r.segments[0].text, 'Short form.');
    });

    test('optional cue identifier line is skipped', () {
      const src = '''
WEBVTT

intro-cue
00:00:00.000 --> 00:00:02.000
With identifier.
''';
      final r = TranscriptParsers.parseVtt(src);
      expect(r.segments, hasLength(1));
      expect(r.segments[0].text, 'With identifier.');
    });

    test('NOTE / STYLE / REGION blocks are ignored', () {
      const src = '''
WEBVTT

NOTE this is metadata, not a cue

STYLE
::cue { color: red }

00:00:01.000 --> 00:00:02.000
Real cue.
''';
      final r = TranscriptParsers.parseVtt(src);
      expect(r.segments, hasLength(1));
      expect(r.segments[0].text, 'Real cue.');
    });
  });

  group('parsePlainText', () {
    test('returns no segments and the trimmed plaintext', () {
      const src = '\n  Hello world.  \n';
      final r = TranscriptParsers.parsePlainText(src);
      expect(r.source, TranscriptSource.txt);
      expect(r.segments, isEmpty);
      expect(r.plainText, 'Hello world.');
    });
  });

  group('isSupportedTranscript', () {
    test('case-insensitive on extension', () {
      expect(TranscriptParsers.isSupportedTranscript('/x/y.SRT'), isTrue);
      expect(TranscriptParsers.isSupportedTranscript('/x/y.Vtt'), isTrue);
      expect(TranscriptParsers.isSupportedTranscript('/x/y.txt'), isTrue);
    });

    test('rejects audio and other extensions', () {
      expect(
          TranscriptParsers.isSupportedTranscript('/x/y.wav'), isFalse);
      expect(
          TranscriptParsers.isSupportedTranscript('/x/y.json'), isFalse);
      expect(TranscriptParsers.isSupportedTranscript('/x/y'), isFalse);
    });
  });
}
