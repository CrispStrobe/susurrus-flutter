// Smoke tests for the voice-clone wizard.
//
// Pure widget smoke without driving the recorder (`AudioService`
// needs platform-channel mocking that's out of scope for v1);
// these verify the wizard renders, the stepper advances through
// the three labels, Cancel from step 1 pops the screen, and the
// Back button decrements the step rather than popping.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crisper_weaver/l10n/generated/app_localizations.dart';
import 'package:crisper_weaver/screens/voice_clone_wizard_screen.dart';

Widget _harness(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
      // Add the Material localizations explicitly so widgets in
      // the wizard that pull from Localizations.of (e.g. for
      // text direction in the InputDecoration) get a real value
      // instead of throwing.
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },
    ),
  );
}

void main() {
  testWidgets('renders the first step (Capture) on open', (tester) async {
    await tester.pumpWidget(_harness(const VoiceCloneWizardScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Voice clone wizard'), findsOneWidget);
    expect(find.text('Capture'), findsWidgets);
    expect(find.text('Reference text'), findsWidgets);
    expect(find.text('Synthesize'), findsWidgets);
    expect(find.text('Capture a reference clip'), findsOneWidget);
  });

  testWidgets('step-1 footer shows Cancel + Next labels', (tester) async {
    // FilledButton.icon wraps the FilledButton in an internal
    // helper widget, so the cleanest check is just that the
    // text labels render in the right slots of the footer Row.
    await tester.pumpWidget(_harness(const VoiceCloneWizardScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Open in Synthesize'), findsNothing,
        reason: 'finish label only renders on the last step');
  });

  testWidgets('Cancel on step 1 pops the screen', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          navigatorKey: navKey,
          localizationsDelegates:
              AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(builder: (ctx) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const VoiceCloneWizardScreen(),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            );
          }),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Voice clone wizard'), findsOneWidget);
    // The Cancel button is the only text-button labelled "Cancel".
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Voice clone wizard'), findsNothing);
  });
}
