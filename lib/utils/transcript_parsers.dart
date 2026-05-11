// Transcript file parsers — SRT / VTT / plain-text.
//
// Used by ShareIntakeService when another app sends us a
// transcript file ("review existing transcript" flow). Pure
// Dart, no I/O outside reading the file at the top level; the
// per-format parser is fed already-decoded UTF-8 text so unit
// tests can pin the grammar handling without filesystem
// fixtures.
//
// Grammars supported:
//   - SRT  (.srt)  — index line + 'HH:MM:SS,ms --> HH:MM:SS,ms'
//                    + N text lines + blank
//   - VTT  (.vtt)  — leading 'WEBVTT' header, optional cue
//                    identifier, 'HH:MM:SS.ms --> HH:MM:SS.ms'
//                    timestamp (HH: section optional), text
//                    lines, blank
//   - TXT  (.txt)  — a single segment spanning 0.0 → 0.0 with
//                    the entire file as `text`. Not strictly a
//                    "transcript" format but accepting it makes
//                    "open in CrisperWeaver" work for hand-written
//                    notes too.
//
// What the parsers don't do: speaker-tag inference, language
// detection, cue alignment. The intake path treats the result
// as immutable post-transcription content — the user can
// edit segments inline same as a freshly-transcribed file.

import 'dart:io';

import 'package:path/path.dart' as p;

import '../engines/transcription_engine.dart';

/// Successfully-parsed transcript content.
class ParsedTranscript {
  const ParsedTranscript({
    required this.segments,
    required this.plainText,
    required this.source,
  });

  /// Parsed segments in document order. Empty for [SOURCE.txt]
  /// when there are no timestamps to anchor — callers still get
  /// the joined plaintext via [plainText].
  final List<TranscriptionSegment> segments;

  /// Concatenated plaintext — segments' text joined by '\n', or
  /// the verbatim file content for plaintext sources.
  final String plainText;

  /// Which parser produced this result. Useful for telemetry +
  /// for the intake snackbar to surface the right format name.
  final TranscriptSource source;
}

enum TranscriptSource { srt, vtt, txt }

class TranscriptParsers {
  /// File-extension whitelist for [parseFile]. Use this from
  /// share-intake code to decide whether to ingest a non-audio
  /// share as a transcript before falling through to "ignored".
  static bool isSupportedTranscript(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    return ext == '.srt' || ext == '.vtt' || ext == '.txt';
  }

  /// Read [filePath] and parse based on extension. Returns null
  /// when the extension doesn't match a known transcript format
  /// or when reading / parsing fails — callers should fall
  /// through to "ignored" rather than treat a parse failure as
  /// fatal (e.g. a malformed .srt is still better as plaintext
  /// than nothing).
  static Future<ParsedTranscript?> parseFile(String filePath) async {
    if (!isSupportedTranscript(filePath)) return null;
    final file = File(filePath);
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    final ext = p.extension(filePath).toLowerCase();
    switch (ext) {
      case '.srt':
        return parseSrt(content);
      case '.vtt':
        return parseVtt(content);
      case '.txt':
        return parsePlainText(content);
    }
    return null;
  }

  // -------------------------------------------------------------------
  // Format parsers — exposed publicly so unit tests can pin them
  // without needing filesystem fixtures.
  // -------------------------------------------------------------------

  static ParsedTranscript parseSrt(String content) {
    final segments = <TranscriptionSegment>[];
    // SRT is block-separated by blank lines. We split on \n\n
    // (CRLF tolerated by normalising first).
    final blocks = content.replaceAll('\r\n', '\n').split('\n\n');
    for (final raw in blocks) {
      final block = raw.trim();
      if (block.isEmpty) continue;
      final lines = block.split('\n');
      // Skip the optional numeric index line if the first line
      // is just digits.
      var i = 0;
      if (lines[i].trim().isNotEmpty &&
          RegExp(r'^\d+$').hasMatch(lines[i].trim())) {
        i++;
      }
      if (i >= lines.length) continue;
      final ts = _parseSrtTimestamp(lines[i]);
      if (ts == null) continue;
      i++;
      final text = lines.skip(i).join('\n').trim();
      if (text.isEmpty) continue;
      final (start, end, speaker, payload) = _extractSpeakerPrefix(text, ts);
      segments.add(TranscriptionSegment(
        text: payload,
        startTime: start,
        endTime: end,
        speaker: speaker,
      ));
    }
    return ParsedTranscript(
      segments: segments,
      plainText: segments.map((s) => s.text).join('\n'),
      source: TranscriptSource.srt,
    );
  }

  static ParsedTranscript parseVtt(String content) {
    final segments = <TranscriptionSegment>[];
    final normalised = content.replaceAll('\r\n', '\n');
    final blocks = normalised.split('\n\n');
    for (final raw in blocks) {
      final block = raw.trim();
      if (block.isEmpty) continue;
      // Skip the WEBVTT header (first block, or a cue with that
      // single line) and NOTE / STYLE / REGION metadata blocks.
      if (block.startsWith('WEBVTT')) continue;
      if (block.startsWith('NOTE') ||
          block.startsWith('STYLE') ||
          block.startsWith('REGION')) {
        continue;
      }
      final lines = block.split('\n');
      var i = 0;
      // Optional cue identifier — anything that isn't a
      // timestamp line. Skip if the first line lacks ' --> '.
      if (!lines[i].contains(' --> ')) {
        i++;
        if (i >= lines.length) continue;
      }
      final ts = _parseVttTimestamp(lines[i]);
      if (ts == null) continue;
      i++;
      final text = lines.skip(i).join('\n').trim();
      if (text.isEmpty) continue;
      final (start, end, speaker, payload) = _extractSpeakerPrefix(text, ts);
      segments.add(TranscriptionSegment(
        text: payload,
        startTime: start,
        endTime: end,
        speaker: speaker,
      ));
    }
    return ParsedTranscript(
      segments: segments,
      plainText: segments.map((s) => s.text).join('\n'),
      source: TranscriptSource.vtt,
    );
  }

  /// Plain text → empty segments + the raw content as
  /// `plainText`. Callers should treat an empty segments list as
  /// "this is a flat text dump, not a timestamped transcript".
  static ParsedTranscript parsePlainText(String content) {
    return ParsedTranscript(
      segments: const [],
      plainText: content.trim(),
      source: TranscriptSource.txt,
    );
  }

  // -------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------

  /// Parse an SRT timestamp line: `HH:MM:SS,ms --> HH:MM:SS,ms`.
  /// Returns (start, end) seconds or null on malformed input.
  static (double, double)? _parseSrtTimestamp(String line) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2}):(\d{2}),(\d{1,3})\s*-->\s*'
      r'(\d{1,2}):(\d{2}):(\d{2}),(\d{1,3})',
    ).firstMatch(line.trim());
    if (match == null) return null;
    final start = _hmsToSeconds(
        match.group(1)!, match.group(2)!, match.group(3)!, match.group(4)!);
    final end = _hmsToSeconds(
        match.group(5)!, match.group(6)!, match.group(7)!, match.group(8)!);
    return (start, end);
  }

  /// Parse a VTT timestamp line: `[HH:]MM:SS.ms --> [HH:]MM:SS.ms`.
  static (double, double)? _parseVttTimestamp(String line) {
    final pattern = RegExp(
      r'^(?:(\d{1,2}):)?(\d{1,2}):(\d{2})\.(\d{1,3})\s*-->\s*'
      r'(?:(\d{1,2}):)?(\d{1,2}):(\d{2})\.(\d{1,3})',
    );
    final match = pattern.firstMatch(line.trim());
    if (match == null) return null;
    final start = _hmsToSeconds(
        match.group(1) ?? '0',
        match.group(2)!,
        match.group(3)!,
        match.group(4)!);
    final end = _hmsToSeconds(
        match.group(5) ?? '0',
        match.group(6)!,
        match.group(7)!,
        match.group(8)!);
    return (start, end);
  }

  static double _hmsToSeconds(String h, String m, String s, String ms) {
    final hh = int.tryParse(h) ?? 0;
    final mm = int.tryParse(m) ?? 0;
    final ss = int.tryParse(s) ?? 0;
    final mss = int.tryParse(ms.padRight(3, '0')) ?? 0;
    return hh * 3600 + mm * 60 + ss + mss / 1000.0;
  }

  /// Pull a leading `Speaker:` prefix off the segment text when
  /// our own SRT/VTT writers stamped one in. Falls through to
  /// `null` speaker when no prefix is present. Returns the
  /// 4-tuple `(start, end, speaker, payload)` for the caller.
  static (double, double, String?, String) _extractSpeakerPrefix(
      String text, (double, double) ts) {
    // Match "Speaker: rest" only when the speaker portion looks
    // like a real label — no whitespace before the colon, the
    // label is at most 64 chars, and the colon is followed by a
    // space (rules out URLs and timestamps inside the text).
    final match = RegExp(r'^([^\s:][^:]{0,63}):\s').firstMatch(text);
    if (match == null) return (ts.$1, ts.$2, null, text);
    final speaker = match.group(1)!;
    final rest = text.substring(match.end);
    // Defensive: an empty `rest` means the prefix swallowed
    // everything — drop the speaker, treat as plain text.
    if (rest.trim().isEmpty) return (ts.$1, ts.$2, null, text);
    return (ts.$1, ts.$2, speaker, rest);
  }
}
