// LocalLlmSettingsForm — the on-device chat-LLM settings form.
//
// Same shape and contract as CloudLlmSettingsForm: parent holds
// a GlobalKey<LocalLlmSettingsFormState>, calls .save() / .clear()
// from its action buttons, and the form fires onCommit /
// onCleared with the values to persist. Both the wide-layout
// dialog (settings_screen.dart) and the phone sub-screen
// (local_llm_settings_screen.dart) use this widget verbatim.
//
// What lives here: file picker for the GGUF model + the
// advanced-params ExpansionTile (GPU layers / context window /
// CPU threads / max tokens / temperature).

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

class LocalLlmSettingsForm extends StatefulWidget {
  const LocalLlmSettingsForm({
    super.key,
    required this.initialModelPath,
    required this.initialNGpuLayers,
    required this.initialNCtx,
    required this.initialNThreads,
    required this.initialMaxTokens,
    required this.initialTemperature,
    required this.onCommit,
    required this.onCleared,
  });

  final String initialModelPath;
  final int initialNGpuLayers;
  final int initialNCtx;
  final int initialNThreads;
  final int initialMaxTokens;
  final double initialTemperature;

  final void Function(
    String modelPath,
    int nGpuLayers,
    int nCtx,
    int nThreads,
    int maxTokens,
    double temperature,
  ) onCommit;

  final VoidCallback onCleared;

  @override
  State<LocalLlmSettingsForm> createState() => LocalLlmSettingsFormState();
}

class LocalLlmSettingsFormState extends State<LocalLlmSettingsForm> {
  late String _modelPath;
  late int _nGpuLayers;
  late int _nCtx;
  late int _nThreads;
  late int _maxTokens;
  late double _temperature;

  @override
  void initState() {
    super.initState();
    _modelPath = widget.initialModelPath;
    _nGpuLayers = widget.initialNGpuLayers;
    _nCtx = widget.initialNCtx;
    _nThreads = widget.initialNThreads;
    _maxTokens = widget.initialMaxTokens;
    _temperature = widget.initialTemperature;
  }

  /// Open the file picker, store the resulting path. The
  /// parent's Save still has to fire to actually persist;
  /// picking just updates the in-form draft.
  Future<void> _pickModel() async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: AppLocalizations.of(context).settingsLocalLlmModelPick,
      type: FileType.custom,
      allowedExtensions: const ['gguf'],
    );
    final p = picked?.files.single.path;
    if (p == null || p.isEmpty) return;
    setState(() => _modelPath = p);
  }

  /// Commit the in-form draft to the parent via onCommit. Does
  /// not pop / close — the caller chains that.
  void save() {
    widget.onCommit(
      _modelPath.trim(),
      _nGpuLayers,
      _nCtx,
      _nThreads,
      _maxTokens,
      _temperature,
    );
  }

  /// Reset every field to its post-install default and tell the
  /// parent to wipe SettingsService. Same defaults the old
  /// inline dialog wrote — clearing the path is what flips the
  /// feature back to Off.
  void clear() {
    setState(() {
      _modelPath = '';
      _nGpuLayers = -1;
      _nCtx = 0;
      _nThreads = 0;
      _maxTokens = 512;
      _temperature = 0.0;
    });
    widget.onCleared();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.settingsLocalLlmHelp,
            style: TextStyle(
                fontSize: 12, color: Colors.grey.shade700)),
        const SizedBox(height: 12),
        Text(l.settingsLocalLlmModelPath,
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                _modelPath.isEmpty
                    ? l.settingsLocalLlmModelPathEmpty
                    : _modelPath,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      _modelPath.isEmpty ? Colors.grey.shade600 : null,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.folder_open, size: 16),
              label: Text(l.settingsLocalLlmModelPick),
              onPressed: _pickModel,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(l.settingsLocalLlmAdvanced),
          children: [
            const SizedBox(height: 4),
            Text(
              _nGpuLayers == -1
                  ? l.settingsLocalLlmNGpuLayersAll
                  : l.settingsLocalLlmNGpuLayers(_nGpuLayers),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Slider(
              min: -1,
              max: 99,
              divisions: 100,
              value: _nGpuLayers.toDouble().clamp(-1, 99),
              label: _nGpuLayers == -1 ? 'all' : '$_nGpuLayers',
              onChanged: (v) =>
                  setState(() => _nGpuLayers = v.round()),
            ),
            Text(l.settingsLocalLlmNGpuLayersHelp,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Text(
              _nCtx == 0
                  ? l.settingsLocalLlmNCtxDefault
                  : l.settingsLocalLlmNCtx(_nCtx),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Slider(
              min: 0,
              max: 32768,
              divisions: 64,
              value: _nCtx.toDouble().clamp(0, 32768),
              label: _nCtx == 0 ? 'auto' : '$_nCtx',
              onChanged: (v) {
                // Snap to multiples of 512 for common-case
                // context sizes; 0 is the "model default" anchor.
                final snapped = (v / 512).round() * 512;
                setState(() => _nCtx = snapped);
              },
            ),
            Text(l.settingsLocalLlmNCtxHelp,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Text(
              _nThreads == 0
                  ? l.settingsLocalLlmNThreadsAuto
                  : l.settingsLocalLlmNThreads(_nThreads),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Slider(
              min: 0,
              max: 32,
              divisions: 32,
              value: _nThreads.toDouble().clamp(0, 32),
              label: _nThreads == 0 ? 'auto' : '$_nThreads',
              onChanged: (v) =>
                  setState(() => _nThreads = v.round()),
            ),
            const SizedBox(height: 8),
            Text(l.settingsLocalLlmMaxTokens(_maxTokens),
                style: Theme.of(context).textTheme.bodySmall),
            Slider(
              min: 64,
              max: 4096,
              divisions: 63,
              value: _maxTokens.toDouble().clamp(64, 4096),
              label: '$_maxTokens',
              onChanged: (v) =>
                  setState(() => _maxTokens = v.round()),
            ),
            const SizedBox(height: 8),
            Text(
              l.settingsLocalLlmTemperature(
                  _temperature.toStringAsFixed(2)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Slider(
              min: 0.0,
              max: 2.0,
              divisions: 40,
              value: _temperature.clamp(0.0, 2.0),
              label: _temperature.toStringAsFixed(2),
              onChanged: (v) => setState(() => _temperature = v),
            ),
          ],
        ),
      ],
    );
  }
}
