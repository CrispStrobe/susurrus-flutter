// HotkeySettingsForm — the §5.1.11 global-hotkey settings form.
//
// Same contract as CloudLlmSettingsForm /
// LocalLlmSettingsForm: parent holds a
// GlobalKey<HotkeySettingsFormState>, calls .save() from its
// commit button. Validation runs inside save() — when the combo
// is non-empty AND HotkeyService.parse rejects it AND the
// feature is enabled, the form returns an error message instead
// of committing; the parent surfaces that as a SnackBar /
// inline error.

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/hotkey_service.dart' show HotkeyAction, HotkeyService;

/// Result of [HotkeySettingsFormState.save] — either a parsed
/// commit-and-persist or a validation error the caller surfaces.
class HotkeySaveResult {
  const HotkeySaveResult.committed()
      : invalidCombo = null;
  const HotkeySaveResult.invalidCombo(String this.invalidCombo);

  /// When non-null, the form refused to save because the combo
  /// string couldn't be parsed. The string is the rejected
  /// input — usable as a placeholder in the
  /// `settingsHotkeyInvalid({combo})` localised message.
  final String? invalidCombo;

  bool get ok => invalidCombo == null;
}

class HotkeySettingsForm extends StatefulWidget {
  const HotkeySettingsForm({
    super.key,
    required this.initialEnabled,
    required this.initialCombo,
    required this.initialAction,
    required this.onCommit,
  });

  final bool initialEnabled;
  final String initialCombo;
  final HotkeyAction initialAction;

  /// Fires when [HotkeySettingsFormState.save] passes validation.
  /// Trimmed combo string; parent's responsibility to persist
  /// and re-register the hotkey.
  final void Function(bool enabled, String combo, HotkeyAction action)
      onCommit;

  @override
  State<HotkeySettingsForm> createState() => HotkeySettingsFormState();
}

class HotkeySettingsFormState extends State<HotkeySettingsForm> {
  late final TextEditingController _comboCtl;
  late bool _enabled;
  late HotkeyAction _action;

  @override
  void initState() {
    super.initState();
    _comboCtl = TextEditingController(text: widget.initialCombo);
    _enabled = widget.initialEnabled;
    _action = widget.initialAction;
  }

  @override
  void dispose() {
    _comboCtl.dispose();
    super.dispose();
  }

  /// Validate then commit. Returns a result the parent should
  /// inspect — invalid combos must surface to the user (the
  /// hotkey service silently no-ops on bad input at startup, so
  /// catching it at save-time is the only safe gate).
  HotkeySaveResult save() {
    final combo = _comboCtl.text.trim();
    if (_enabled &&
        combo.isNotEmpty &&
        HotkeyService.parse(combo) == null) {
      return HotkeySaveResult.invalidCombo(combo);
    }
    widget.onCommit(_enabled, combo, _action);
    return const HotkeySaveResult.committed();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.settingsHotkeyHelp,
            style: TextStyle(
                fontSize: 12, color: Colors.grey.shade700)),
        const SizedBox(height: 12),
        SwitchListTile(
          title: Text(l.settingsHotkeyEnable),
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
        ),
        TextField(
          controller: _comboCtl,
          decoration: InputDecoration(
            labelText: l.settingsHotkeyCombo,
            hintText: 'meta+shift+space',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Text(l.settingsHotkeyBehavior,
            style: Theme.of(context).textTheme.titleSmall),
        RadioGroup<HotkeyAction>(
          groupValue: _action,
          onChanged: (v) {
            if (v != null) setState(() => _action = v);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<HotkeyAction>(
                dense: true,
                title: Text(l.settingsHotkeyActionPushToTalk),
                subtitle: Text(l.settingsHotkeyActionPushToTalkHelp,
                    style: const TextStyle(fontSize: 11)),
                value: HotkeyAction.pushToTalk,
              ),
              RadioListTile<HotkeyAction>(
                dense: true,
                title: Text(l.settingsHotkeyActionToggle),
                subtitle: Text(l.settingsHotkeyActionToggleHelp,
                    style: const TextStyle(fontSize: 11)),
                value: HotkeyAction.toggle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
