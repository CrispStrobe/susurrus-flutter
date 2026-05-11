// LocalLlmSettingsScreen — phone-form sub-screen for on-device
// chat-LLM settings. Mirror of CloudLlmSettingsScreen with the
// LocalLlmSettingsForm body. See cloud_llm_settings_screen.dart
// for the rationale.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/settings_service.dart';
import '../widgets/local_llm_settings_form.dart';

class LocalLlmSettingsScreen extends ConsumerStatefulWidget {
  const LocalLlmSettingsScreen({super.key});

  @override
  ConsumerState<LocalLlmSettingsScreen> createState() =>
      _LocalLlmSettingsScreenState();
}

class _LocalLlmSettingsScreenState
    extends ConsumerState<LocalLlmSettingsScreen> {
  final GlobalKey<LocalLlmSettingsFormState> _formKey =
      GlobalKey<LocalLlmSettingsFormState>();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = ref.read(settingsServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.settingsLocalLlmCleanup),
        actions: [
          TextButton(
            onPressed: () {
              _formKey.currentState?.clear();
              Navigator.of(context).pop(true);
            },
            child: Text(l.settingsLocalLlmModelClear,
                style: const TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              _formKey.currentState?.save();
              Navigator.of(context).pop(true);
            },
            child: Text(l.save.toUpperCase(),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: LocalLlmSettingsForm(
          key: _formKey,
          initialModelPath: settings.localLlmModelPath,
          initialNGpuLayers: settings.localLlmNGpuLayers,
          initialNCtx: settings.localLlmNCtx,
          initialNThreads: settings.localLlmNThreads,
          initialMaxTokens: settings.localLlmMaxTokens,
          initialTemperature: settings.localLlmTemperature,
          onCommit: (path, gpu, ctx, threads, maxT, temp) {
            settings.localLlmModelPath = path;
            settings.localLlmNGpuLayers = gpu;
            settings.localLlmNCtx = ctx;
            settings.localLlmNThreads = threads;
            settings.localLlmMaxTokens = maxT;
            settings.localLlmTemperature = temp;
          },
          onCleared: () {
            settings.localLlmModelPath = '';
            settings.localLlmNGpuLayers = -1;
            settings.localLlmNCtx = 0;
            settings.localLlmNThreads = 0;
            settings.localLlmMaxTokens = 512;
            settings.localLlmTemperature = 0.0;
          },
        ),
      ),
    );
  }
}
