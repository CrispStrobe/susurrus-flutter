// HotkeySettingsScreen — phone-form sub-screen for §5.1.11
// global hotkey configuration. Same shape as the Cloud/Local
// LLM sub-screens.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/hotkey_service.dart';
import '../services/settings_service.dart';
import '../widgets/hotkey_settings_form.dart';

class HotkeySettingsScreen extends ConsumerStatefulWidget {
  const HotkeySettingsScreen({super.key});

  @override
  ConsumerState<HotkeySettingsScreen> createState() =>
      _HotkeySettingsScreenState();
}

class _HotkeySettingsScreenState
    extends ConsumerState<HotkeySettingsScreen> {
  final GlobalKey<HotkeySettingsFormState> _formKey =
      GlobalKey<HotkeySettingsFormState>();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = ref.read(settingsServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.settingsHotkey),
        actions: [
          TextButton(
            onPressed: () async {
              final res = _formKey.currentState?.save();
              if (res == null) return;
              if (!res.ok) {
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(SnackBar(
                  content:
                      Text(l.settingsHotkeyInvalid(res.invalidCombo!)),
                ));
                return;
              }
              // Capture Navigator BEFORE the await so we don't
              // re-touch BuildContext across an async gap.
              final nav = Navigator.of(context);
              await ref.read(hotkeyServiceProvider).applyFromSettings();
              if (!mounted) return;
              nav.pop(true);
            },
            child: Text(l.save.toUpperCase(),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: HotkeySettingsForm(
          key: _formKey,
          initialEnabled: settings.hotkeyEnabled,
          initialCombo: settings.hotkeyCombo,
          initialAction: settings.hotkeyAction,
          onCommit: (enabled, combo, action) {
            settings.hotkeyEnabled = enabled;
            settings.hotkeyCombo = combo;
            settings.hotkeyAction = action;
          },
        ),
      ),
    );
  }
}
