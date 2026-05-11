// Widget tests for HotkeySettingsForm — pins the validate-then-
// commit contract that the dialog + sub-screen both lean on.
//
// In particular: an invalid combo with `enabled = true` must
// NOT silently commit (the hotkey service no-ops on bad combos
// at startup, so catching at save-time is the only safe gate).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crisper_weaver/l10n/generated/app_localizations.dart';
import 'package:crisper_weaver/services/hotkey_service.dart'
    show HotkeyAction;
import 'package:crisper_weaver/widgets/hotkey_settings_form.dart';

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('valid combo commits via onCommit and returns ok',
      (tester) async {
    final key = GlobalKey<HotkeySettingsFormState>();
    bool? committedEnabled;
    String? committedCombo;
    HotkeyAction? committedAction;
    await tester.pumpWidget(_host(
      HotkeySettingsForm(
        key: key,
        initialEnabled: true,
        initialCombo: 'meta+shift+space',
        initialAction: HotkeyAction.pushToTalk,
        onCommit: (e, c, a) {
          committedEnabled = e;
          committedCombo = c;
          committedAction = a;
        },
      ),
    ));
    final res = key.currentState!.save();
    expect(res.ok, isTrue);
    expect(res.invalidCombo, isNull);
    expect(committedEnabled, isTrue);
    expect(committedCombo, 'meta+shift+space');
    expect(committedAction, HotkeyAction.pushToTalk);
  });

  testWidgets(
      'invalid combo refuses to commit and returns the rejected input',
      (tester) async {
    final key = GlobalKey<HotkeySettingsFormState>();
    var commits = 0;
    await tester.pumpWidget(_host(
      HotkeySettingsForm(
        key: key,
        initialEnabled: true,
        initialCombo: 'bogus+nope',
        initialAction: HotkeyAction.toggle,
        onCommit: (_, __, ___) => commits++,
      ),
    ));
    final res = key.currentState!.save();
    expect(res.ok, isFalse);
    expect(res.invalidCombo, 'bogus+nope');
    expect(commits, 0,
        reason: 'invalid combos must not slip through to settings');
  });

  testWidgets(
      'invalid combo is tolerated when the feature is disabled',
      (tester) async {
    // The hotkey service ignores the combo when enabled=false, so
    // a user can pre-disable + leave an in-progress combo without
    // being yelled at.
    final key = GlobalKey<HotkeySettingsFormState>();
    var commits = 0;
    await tester.pumpWidget(_host(
      HotkeySettingsForm(
        key: key,
        initialEnabled: false,
        initialCombo: 'bogus+nope',
        initialAction: HotkeyAction.toggle,
        onCommit: (_, __, ___) => commits++,
      ),
    ));
    final res = key.currentState!.save();
    expect(res.ok, isTrue);
    expect(commits, 1);
  });

  testWidgets('empty combo passes validation regardless of enabled',
      (tester) async {
    final key = GlobalKey<HotkeySettingsFormState>();
    var commits = 0;
    await tester.pumpWidget(_host(
      HotkeySettingsForm(
        key: key,
        initialEnabled: true,
        initialCombo: '   ',
        initialAction: HotkeyAction.pushToTalk,
        onCommit: (_, __, ___) => commits++,
      ),
    ));
    final res = key.currentState!.save();
    expect(res.ok, isTrue);
    expect(commits, 1);
  });
}
