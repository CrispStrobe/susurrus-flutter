// TranscriptCleanupService — PLAN §5.1.6 v1.
//
// Pure-Dart deterministic cleanup of ASR output: remove filler
// words, collapse repeated stutters, normalise whitespace,
// capitalise sentence starts, strip annotation tags. Runs
// per-segment; the caller drives the loop and persists results
// via AppState.editSegment + HistoryService.update.
//
// v1 is deliberately not LLM-driven — it ships today without an
// extra model download and gives the user the 80% win that
// "um/uh/repeated-words/all-lowercase" produces. The LLM-driven
// v2 (see PLAN §5.1.6) layers on top once a small text-LLM
// engine joins the pool; it'll consume the same `CleanupOptions`
// surface plus an additional `runLLMPass: true` flag.
//
// Each transform is pure: takes a string + options, returns a
// string. Composed into `cleanupText` which applies them in a
// stable order. The order matters: annotation-stripping first
// (so subsequent transforms don't operate on `[laughter]`),
// then filler removal, then repeat-collapsing (so "um um the
// the cat" → "" → "the cat" not "um um the cat" → "um the
// cat"), then punctuation/whitespace fixes, then capitalisation
// last (which sees the final spacing).

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Toggle-set + custom-filler-list driving `cleanupText`. All
/// boolean flags default to `true` except `stripAnnotations` —
/// `[laughter]` / `(applause)` are useful for accessibility so
/// the default is to keep them.
class CleanupOptions {
  const CleanupOptions({
    this.removeFillers = true,
    this.collapseRepeats = true,
    this.normalizeWhitespace = true,
    this.fixPunctuation = true,
    this.sentenceCase = true,
    this.stripAnnotations = false,
    this.customFillers = const <String>[],
    this.languageHint,
  });

  final bool removeFillers;
  final bool collapseRepeats;
  final bool normalizeWhitespace;
  final bool fixPunctuation;
  final bool sentenceCase;
  final bool stripAnnotations;

  /// Extra filler words to add on top of the default per-language
  /// set. Always merged in case-insensitively.
  final List<String> customFillers;

  /// ISO-639-1 / -2 language hint (e.g. "en", "de") used to pick
  /// the default filler word set. `null` → English fillers.
  final String? languageHint;

  CleanupOptions copyWith({
    bool? removeFillers,
    bool? collapseRepeats,
    bool? normalizeWhitespace,
    bool? fixPunctuation,
    bool? sentenceCase,
    bool? stripAnnotations,
    List<String>? customFillers,
    String? languageHint,
  }) {
    return CleanupOptions(
      removeFillers: removeFillers ?? this.removeFillers,
      collapseRepeats: collapseRepeats ?? this.collapseRepeats,
      normalizeWhitespace: normalizeWhitespace ?? this.normalizeWhitespace,
      fixPunctuation: fixPunctuation ?? this.fixPunctuation,
      sentenceCase: sentenceCase ?? this.sentenceCase,
      stripAnnotations: stripAnnotations ?? this.stripAnnotations,
      customFillers: customFillers ?? this.customFillers,
      languageHint: languageHint ?? this.languageHint,
    );
  }
}

class TranscriptCleanupService {
  const TranscriptCleanupService();

  /// Default filler word set per language. Used when
  /// `CleanupOptions.languageHint` matches; otherwise falls
  /// back to the English set. Always normalised to lowercase.
  static const Map<String, List<String>> _defaultFillers = {
    'en': ['um', 'uh', 'ah', 'ahm', 'uhm', 'er', 'mm', 'mhm', 'hmm'],
    'de': ['äh', 'öh', 'ähm', 'ähem', 'mh', 'hm', 'hmm', 'naja'],
    'fr': ['euh', 'hum', 'ben', 'bah'],
    'es': ['eh', 'este', 'pues', 'bueno'],
    'it': ['eh', 'cioè', 'allora'],
  };

  /// Returns the merged filler set for the given options:
  /// language-default + customFillers, all lowercased, dedup'd.
  /// Public for unit tests; the cleanup pipeline calls it
  /// internally.
  Set<String> resolveFillers(CleanupOptions opts) {
    final lang = (opts.languageHint ?? 'en').toLowerCase();
    final base = _defaultFillers[lang] ?? _defaultFillers['en']!;
    final out = <String>{};
    for (final f in base) {
      out.add(f.toLowerCase());
    }
    for (final f in opts.customFillers) {
      final t = f.trim().toLowerCase();
      if (t.isNotEmpty) out.add(t);
    }
    return out;
  }

  // ----- Individual transforms -----

  /// Removes any standalone occurrence of a filler word (case-
  /// insensitive). "Standalone" means surrounded by word
  /// boundaries — won't touch "Hummingbird" when "hum" is a
  /// filler. Also strips an immediately-following comma so the
  /// remaining text doesn't have a dangling ", , ".
  String removeFillers(String text, Set<String> fillers) {
    if (fillers.isEmpty || text.isEmpty) return text;
    // Sort by length desc so multi-char fillers ("ähm") match
    // before single-char ones ("äh") when both are in the set.
    final sorted = fillers.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final escaped = sorted.map(RegExp.escape).join('|');
    final re = RegExp(r'\b(?:' + escaped + r')\b[,]?\s*',
        caseSensitive: false, unicode: true);
    return text.replaceAll(re, '');
  }

  /// Collapses adjacent identical word tokens (case-insensitive).
  /// "the the cat" → "the cat"; "I I think" → "I think".
  /// Skips numeric tokens to preserve "100 100" deliberately.
  String collapseRepeats(String text) {
    if (text.isEmpty) return text;
    // Word tokens + non-word run between them. Note Dart's
    // `replaceAll(RegExp, String)` does NOT expand $-backrefs;
    // use replaceAllMapped + match[1] to keep the first token's
    // original casing.
    final re = RegExp(r'\b(\w+)(\s+)\1\b',
        caseSensitive: false, unicode: true);
    String once(String s) =>
        s.replaceAllMapped(re, (m) => m[1] ?? '');
    var prev = text;
    var next = once(text);
    // Repeat-replace until stable so "the the the" → "the" not "the the".
    while (next != prev) {
      prev = next;
      next = once(next);
    }
    return next;
  }

  /// Collapse multi-space → single, strip space before
  /// `.,;:!?`, trim ends.
  String normalizeWhitespace(String text) {
    if (text.isEmpty) return text;
    var t = text;
    t = t.replaceAll(RegExp(r'[ \t]+'), ' ');
    t = t.replaceAllMapped(
        RegExp(r'\s+([,.!?;:])'), (m) => m[1] ?? '');
    return t.trim();
  }

  /// Repeated punctuation → single. Trailing comma-before-period
  /// → period. Stray `..` (not three-dot ellipsis) → `.`.
  String fixPunctuation(String text) {
    if (text.isEmpty) return text;
    var t = text;
    t = t.replaceAllMapped(
        RegExp(r'(?<!\.)\.{2}(?!\.)'), (_) => '.');
    t = t.replaceAllMapped(
        RegExp(r',+(\s*[.!?])'), (m) => m[1] ?? '');
    t = t.replaceAllMapped(
        RegExp(r'([,;:])\1+'), (m) => m[1] ?? '');
    return t;
  }

  /// Capitalise the first letter after `.`, `?`, `!`, and at the
  /// very start of the string. Leaves already-capitalised words
  /// alone; preserves the rest of each word verbatim.
  String sentenceCase(String text) {
    if (text.isEmpty) return text;
    final buf = StringBuffer();
    var capNext = true;
    var bracketDepth = 0; // skip annotation contents
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '[' || ch == '(' || ch == '<') bracketDepth++;
      if (bracketDepth > 0) {
        buf.write(ch);
      } else if (capNext && _isLetter(ch)) {
        buf.write(ch.toUpperCase());
        capNext = false;
      } else {
        buf.write(ch);
      }
      if (ch == ']' || ch == ')' || ch == '>') {
        if (bracketDepth > 0) bracketDepth--;
      }
      if (bracketDepth == 0 &&
          (ch == '.' || ch == '?' || ch == '!')) {
        capNext = true;
      }
    }
    return buf.toString();
  }

  bool _isLetter(String ch) => RegExp(r'\p{L}', unicode: true).hasMatch(ch);

  /// Strip annotation tags like `[laughter]`, `(applause)`,
  /// `<noise>`. Leaves the surrounding text intact. Off by
  /// default so accessibility-focused users keep them.
  String stripAnnotations(String text) {
    if (text.isEmpty) return text;
    var t = text;
    t = t.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    t = t.replaceAll(RegExp(r'\([^)]*\)'), '');
    t = t.replaceAll(RegExp(r'<[^>]*>'), '');
    return t;
  }

  // ----- Composed pipeline -----

  /// Runs the configured transforms in a stable order: annotation
  /// strip → fillers → repeats → punctuation → whitespace →
  /// capitalisation. Returns the cleaned text; the caller wraps
  /// it back into a `TranscriptionSegment` via AppState.editSegment.
  String cleanupText(String text, CleanupOptions opts) {
    if (text.isEmpty) return text;
    var t = text;
    if (opts.stripAnnotations) t = stripAnnotations(t);
    if (opts.removeFillers) t = removeFillers(t, resolveFillers(opts));
    if (opts.collapseRepeats) t = collapseRepeats(t);
    if (opts.fixPunctuation) t = fixPunctuation(t);
    if (opts.normalizeWhitespace) t = normalizeWhitespace(t);
    if (opts.sentenceCase) t = sentenceCase(t);
    return t;
  }
}

/// Riverpod singleton; service holds no state so the same
/// instance can be reused across rebuilds.
final transcriptCleanupServiceProvider = Provider<TranscriptCleanupService>(
  (ref) => const TranscriptCleanupService(),
);
