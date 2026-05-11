// Widget tests for CloudLlmSettingsForm — the BYOK cloud-LLM
// settings form body. Pins the controller-style API contract
// the two callers (dialog + sub-screen) depend on:
//   • initial values render into the TextFields
//   • save() commits trimmed values; empty model falls back to
//     the historical default
//   • clear() wipes fields AND fires onCleared

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crisper_weaver/l10n/generated/app_localizations.dart';
import 'package:crisper_weaver/widgets/cloud_llm_settings_form.dart';

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('renders initial values in the TextFields',
      (tester) async {
    await tester.pumpWidget(_host(
      CloudLlmSettingsForm(
        initialApiUrl: 'https://x.test/api',
        initialApiKey: 'sk-abc',
        initialModel: 'my-model',
        onCommit: (_, __, ___) {},
        onCleared: () {},
      ),
    ));
    expect(find.text('https://x.test/api'), findsOneWidget);
    // The key field uses obscureText, so the rendered glyphs
    // are bullet chars — assert on the controller value instead.
    final keyFieldFinder = find.byType(TextField).at(1);
    final keyField = tester.widget<TextField>(keyFieldFinder);
    expect(keyField.controller?.text, 'sk-abc');
    expect(find.text('my-model'), findsOneWidget);
  });

  testWidgets('save() trims values and commits via onCommit',
      (tester) async {
    final key = GlobalKey<CloudLlmSettingsFormState>();
    String? committedUrl;
    String? committedKey;
    String? committedModel;
    await tester.pumpWidget(_host(
      CloudLlmSettingsForm(
        key: key,
        initialApiUrl: '',
        initialApiKey: '',
        initialModel: '',
        onCommit: (u, k, m) {
          committedUrl = u;
          committedKey = k;
          committedModel = m;
        },
        onCleared: () {},
      ),
    ));
    // Enter values with leading / trailing whitespace and confirm
    // they're trimmed at commit time.
    await tester.enterText(
        find.byType(TextField).at(0), '  https://x.test/api  ');
    await tester.enterText(find.byType(TextField).at(1), '  sk-zzz  ');
    await tester.enterText(
        find.byType(TextField).at(2), '   gpt-x   ');
    key.currentState!.save();
    expect(committedUrl, 'https://x.test/api');
    expect(committedKey, 'sk-zzz');
    expect(committedModel, 'gpt-x');
  });

  testWidgets('empty model falls back to gpt-4o-mini on save',
      (tester) async {
    final key = GlobalKey<CloudLlmSettingsFormState>();
    String? committedModel;
    await tester.pumpWidget(_host(
      CloudLlmSettingsForm(
        key: key,
        initialApiUrl: 'https://x.test',
        initialApiKey: 'k',
        initialModel: '   ',
        onCommit: (_, __, m) => committedModel = m,
        onCleared: () {},
      ),
    ));
    key.currentState!.save();
    expect(committedModel, 'gpt-4o-mini',
        reason: 'whitespace-only model must fall back, matching '
            'the historical dialog behaviour');
  });

  testWidgets('clear() wipes the fields and fires onCleared',
      (tester) async {
    final key = GlobalKey<CloudLlmSettingsFormState>();
    var cleared = 0;
    await tester.pumpWidget(_host(
      CloudLlmSettingsForm(
        key: key,
        initialApiUrl: 'https://x.test/api',
        initialApiKey: 'sk-abc',
        initialModel: 'my-model',
        onCommit: (_, __, ___) {},
        onCleared: () => cleared++,
      ),
    ));
    key.currentState!.clear();
    await tester.pump();
    // URL + model TextFields show empty / default text; the key
    // field is obscured but its controller is empty.
    final urlField = tester.widget<TextField>(find.byType(TextField).at(0));
    expect(urlField.controller?.text, '');
    final keyField = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(keyField.controller?.text, '');
    final modelField =
        tester.widget<TextField>(find.byType(TextField).at(2));
    expect(modelField.controller?.text, 'gpt-4o-mini');
    expect(cleared, 1);
  });
}
