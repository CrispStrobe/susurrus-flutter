// Hermetic tests for HotkeyService — combo parsing,
// serialisation round-trip, edge cases. The native plugin
// registration path can't be unit-tested without a host
// process, but the parser is the only piece that has
// non-trivial logic anyway; the plugin call is a single
// `_platform.register` indirection.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import 'package:crisper_weaver/services/hotkey_service.dart';

void main() {
  group('HotkeyService.parse', () {
    test('simple letter key', () {
      final h = HotkeyService.parse('r');
      expect(h, isNotNull);
      expect(h!.logicalKey, LogicalKeyboardKey.keyR);
      expect(h.modifiers, isNull);
    });

    test('letter with single modifier', () {
      final h = HotkeyService.parse('meta+r');
      expect(h, isNotNull);
      expect(h!.logicalKey, LogicalKeyboardKey.keyR);
      expect(h.modifiers, [HotKeyModifier.meta]);
    });

    test('multiple modifiers', () {
      final h = HotkeyService.parse('control+shift+alt+space');
      expect(h, isNotNull);
      expect(h!.logicalKey, LogicalKeyboardKey.space);
      expect(h.modifiers, containsAll([
        HotKeyModifier.control,
        HotKeyModifier.shift,
        HotKeyModifier.alt,
      ]));
    });

    test('case-insensitive', () {
      final h = HotkeyService.parse('META+SHIFT+A');
      expect(h, isNotNull);
      expect(h!.logicalKey, LogicalKeyboardKey.keyA);
      expect(h.modifiers, containsAll(
          [HotKeyModifier.meta, HotKeyModifier.shift]));
    });

    test('modifier aliases — ctrl, cmd, option, win, super', () {
      // cmd / win / super all map to meta
      for (final s in ['cmd', 'command', 'win', 'super', 'meta']) {
        final h = HotkeyService.parse('$s+a');
        expect(h?.modifiers, [HotKeyModifier.meta], reason: s);
      }
      // ctrl aliases control
      for (final s in ['ctrl', 'control']) {
        final h = HotkeyService.parse('$s+a');
        expect(h?.modifiers, [HotKeyModifier.control], reason: s);
      }
      // option aliases alt
      for (final s in ['alt', 'option']) {
        final h = HotkeyService.parse('$s+a');
        expect(h?.modifiers, [HotKeyModifier.alt], reason: s);
      }
    });

    test('function keys', () {
      for (var i = 1; i <= 12; i++) {
        final h = HotkeyService.parse('meta+f$i');
        expect(h, isNotNull, reason: 'f$i');
      }
    });

    test('digit keys', () {
      final h = HotkeyService.parse('control+0');
      expect(h, isNotNull);
      expect(h!.logicalKey, LogicalKeyboardKey.digit0);
    });

    test('named keys — enter / esc / tab / space / backspace', () {
      expect(HotkeyService.parse('return')?.logicalKey,
          LogicalKeyboardKey.enter);
      expect(HotkeyService.parse('enter')?.logicalKey,
          LogicalKeyboardKey.enter);
      expect(HotkeyService.parse('escape')?.logicalKey,
          LogicalKeyboardKey.escape);
      expect(HotkeyService.parse('esc')?.logicalKey,
          LogicalKeyboardKey.escape);
      expect(HotkeyService.parse('tab')?.logicalKey,
          LogicalKeyboardKey.tab);
      expect(HotkeyService.parse('space')?.logicalKey,
          LogicalKeyboardKey.space);
      expect(HotkeyService.parse('backspace')?.logicalKey,
          LogicalKeyboardKey.backspace);
      expect(HotkeyService.parse('delete')?.logicalKey,
          LogicalKeyboardKey.delete);
    });

    test('empty string returns null', () {
      expect(HotkeyService.parse(''), isNull);
      expect(HotkeyService.parse('   '), isNull);
    });

    test('unknown modifier returns null', () {
      expect(HotkeyService.parse('foo+a'), isNull);
    });

    test('unknown key returns null', () {
      expect(HotkeyService.parse('meta+banana'), isNull);
    });

    test('duplicate modifiers are deduplicated', () {
      final h = HotkeyService.parse('shift+shift+a');
      expect(h?.modifiers, [HotKeyModifier.shift]);
    });
  });

  group('HotkeyService.serialize', () {
    test('round-trips a simple key', () {
      const input = 'r';
      final h = HotkeyService.parse(input)!;
      expect(HotkeyService.serialize(h), input);
    });

    test('round-trips a key with one modifier', () {
      const input = 'meta+r';
      final h = HotkeyService.parse(input)!;
      expect(HotkeyService.serialize(h), input);
    });

    test('canonicalises modifier order on output', () {
      // Input order: meta+control+shift; canonical order:
      // control → alt → shift → meta.
      final h = HotkeyService.parse('meta+control+shift+a')!;
      expect(HotkeyService.serialize(h), 'control+shift+meta+a');
    });

    test('round-trip is idempotent', () {
      // Two parses through the canonicaliser produce the same
      // string — important for SharedPreferences round-trips.
      const input = 'shift+meta+control+space';
      final h1 = HotkeyService.parse(input)!;
      final s1 = HotkeyService.serialize(h1);
      final h2 = HotkeyService.parse(s1)!;
      final s2 = HotkeyService.serialize(h2);
      expect(s1, s2);
    });

    test('lowercases regardless of input case', () {
      final h = HotkeyService.parse('META+R')!;
      expect(HotkeyService.serialize(h), 'meta+r');
    });

    test('f-key round trip', () {
      const input = 'control+alt+f9';
      final h = HotkeyService.parse(input)!;
      expect(HotkeyService.serialize(h), input);
    });
  });
}
