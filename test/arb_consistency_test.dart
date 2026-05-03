// Catches translation drift between EN and DE before it ships as a
// silent locale-fallback bug (German user sees English string because
// the DE ARB is missing the key). Adding a string in one ARB and
// forgetting the other now fails CI.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ARB consistency', () {
    final enArb = _readArb('lib/l10n/app_en.arb');
    final deArb = _readArb('lib/l10n/app_de.arb');

    test('EN and DE have the same set of message keys', () {
      final enKeys = _messageKeys(enArb);
      final deKeys = _messageKeys(deArb);

      final missingInDe = enKeys.difference(deKeys);
      final missingInEn = deKeys.difference(enKeys);

      expect(missingInDe, isEmpty,
          reason: 'EN has keys not in DE: ${missingInDe.toList()..sort()}');
      expect(missingInEn, isEmpty,
          reason: 'DE has keys not in EN: ${missingInEn.toList()..sort()}');
    });

    test('every EN message has a non-empty DE value', () {
      for (final key in _messageKeys(enArb)) {
        final deValue = deArb[key];
        expect(deValue, isA<String>(),
            reason: 'DE entry for "$key" is missing or wrong type');
        expect(deValue as String, isNotEmpty,
            reason: 'DE value for "$key" is empty');
      }
    });

    test('placeholders match between EN and DE', () {
      // For every key with @-metadata declaring placeholders, the
      // EN+DE values must reference the same set of {placeholder}
      // names. A typo on the DE side ("{cont}" instead of "{count}")
      // would silently render the literal text without substitution.
      for (final entry in enArb.entries) {
        final key = entry.key;
        if (!key.startsWith('@')) continue;
        final meta = entry.value;
        if (meta is! Map) continue;
        final placeholders = meta['placeholders'];
        if (placeholders is! Map || placeholders.isEmpty) continue;

        final messageKey = key.substring(1);
        final enValue = enArb[messageKey] as String?;
        final deValue = deArb[messageKey] as String?;
        if (enValue == null || deValue == null) continue;

        for (final ph in placeholders.keys) {
          final marker = '{$ph';
          expect(enValue, contains(marker),
              reason:
                  'EN value for "$messageKey" lacks placeholder "$ph"');
          expect(deValue, contains(marker),
              reason:
                  'DE value for "$messageKey" lacks placeholder "$ph"');
        }
      }
    });
  });
}

Map<String, dynamic> _readArb(String relPath) {
  final file = File(relPath);
  if (!file.existsSync()) {
    throw StateError('ARB file not found at $relPath '
        '(cwd=${Directory.current.path})');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// Message keys are the plain string entries — exclude `@key` metadata
/// blocks and ARB-internal keys that start with `@@` (locale, etc.).
Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();
