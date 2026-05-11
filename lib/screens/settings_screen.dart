import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:go_router/go_router.dart';

import 'package:path/path.dart' as p;

import '../engines/engine_factory.dart';
import '../l10n/generated/app_localizations.dart';
import '../main.dart';
import '../services/hotkey_service.dart';
import '../services/log_service.dart';
import '../services/memory_estimator.dart';
import '../services/model_service.dart';
import '../services/server_service.dart';
import '../services/settings_service.dart';
import '../utils/responsive.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsServiceProvider);
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.settingsTitle),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l.settingsSaved)),
              );
              Navigator.of(context).pop();
            },
            child: Text(l.done.toUpperCase(),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildLocaleSettings(settings),
          _buildEngineSettings(settings),
          _buildTranscriptionSettings(settings),
          _buildAudioSettings(settings),
          _buildDiarizationSettings(settings),
          _buildStorageSettings(),
          _buildServerSettings(),
          _buildDeveloperSettings(settings),
          _buildSystemInfo(),
          _buildAboutSection(),
        ],
      ),
      bottomNavigationBar: isPhoneWidth(context)
          ? const PhoneNavBar(current: PhoneNavDestination.settings)
          : null,
    );
  }

  Widget _buildLocaleSettings(SettingsService settings) {
    final l = AppLocalizations.of(context);
    return _buildSettingsSection(
      title: l.settingsAppLanguage,
      icon: Icons.language,
      children: [
        ListTile(
          title: Text(l.settingsInterfaceLanguage),
          subtitle: Text(_getAppLocaleDisplayName(settings.appLocale ?? '')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showAppLocaleSelector(settings),
        ),
      ],
    );
  }

  void _showAppLocaleSelector(SettingsService settings) {
    final l = AppLocalizations.of(context);
    final locales = {
      '': l.settingsSystemDefault,
      'en': 'English',
      'de': 'Deutsch',
    };

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(AppLocalizations.of(context).settingsSelectInterfaceLanguage),
        content: RadioGroup<String>(
          groupValue: settings.appLocale ?? '',
          onChanged: (value) {
            if (value == null) return;
            setState(() => settings.appLocale = value);
            final languageCode = value.isEmpty ? null : value;
            ref.read(localeProvider.notifier).setLocale(languageCode);
            Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: locales.entries
                .map((entry) => RadioListTile<String>(
                      title: Text(entry.value),
                      value: entry.key,
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  String _getAppLocaleDisplayName(String code) {
    if (code == 'en') return 'English';
    if (code == 'de') return 'Deutsch';
    return AppLocalizations.of(context).settingsSystemDefault;
  }

  Widget _buildEngineSettings(SettingsService settings) {
    final l = AppLocalizations.of(context);
    return _buildSettingsSection(
      title: l.settingsEngineSection,
      icon: Icons.psychology,
      children: [
        ListTile(
          title: Text(l.settingsEnginePreferred),
          subtitle: Text(settings.preferredEngine.displayName),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showEngineSelector(settings),
        ),
      ],
    );
  }

  void _showEngineSelector(SettingsService settings) {
    final availableEngines = EngineFactory.getAvailableEngines();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).settingsSelectEngine),
        content: RadioGroup<EngineType>(
          groupValue: settings.preferredEngine,
          onChanged: (value) async {
            if (value == null) return;
            setState(() => settings.preferredEngine = value);
            Navigator.of(context).pop();

            // Try to swap engines immediately
            final service = ref.read(transcriptionServiceProvider);
            try {
              final ok = await service.switchEngine(value);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? 'Switched to ${value.displayName}'
                      : 'Engine switch failed'),
                ),
              );
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        '${AppLocalizations.of(context).settingsEngineSwitchFailed}: $e')),
              );
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableEngines
                .map((engine) => RadioListTile<EngineType>(
                      title: Text(engine.displayName),
                      subtitle: Text(engine.description),
                      value: engine,
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildTranscriptionSettings(SettingsService settings) {
    return _buildSettingsSection(
      title: AppLocalizations.of(context).settingsTranscription,
      icon: Icons.transcribe,
      children: [
        if (settings.preferredEngine == EngineType.crispasr)
          ListTile(
            title: Text(AppLocalizations.of(context).settingsDefaultBackend),
            subtitle: Text(settings.defaultBackend),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showBackendSelector(settings),
          ),
        ListTile(
          title: Text(AppLocalizations.of(context).settingsDefaultModel),
          subtitle: Text(settings.defaultModel),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showModelSelector(settings),
        ),
        ListTile(
          title: Text(AppLocalizations.of(context).settingsDefaultLanguage),
          subtitle: Text(_getLanguageDisplayName(settings.defaultLanguage)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showLanguageSelector(settings),
        ),
        SwitchListTile(
          title: Text(AppLocalizations.of(context).settingsAutoDetectLanguage),
          subtitle: Text(
              AppLocalizations.of(context).settingsAutoDetectLanguageSubtitle),
          value: settings.autoDetectLanguage,
          onChanged: (value) {
            setState(() => settings.autoDetectLanguage = value);
          },
        ),
        SwitchListTile(
          title: Text(AppLocalizations.of(context).settingsWordTimestamps),
          subtitle:
              Text(AppLocalizations.of(context).settingsWordTimestampsSubtitle),
          value: settings.enableWordTimestamps,
          onChanged: (value) {
            setState(() => settings.enableWordTimestamps = value);
          },
        ),
      ],
    );
  }

  void _showBackendSelector(SettingsService settings) {
    final backends = [
      'whisper',
      'parakeet',
      'canary',
      'qwen3',
      'cohere',
      'granite',
      'fastconformer-ctc',
      'canary-ctc',
      'voxtral',
      'voxtral4b',
      'wav2vec2',
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).settingsSelectBackend),
        content: SingleChildScrollView(
          child: RadioGroup<String>(
            groupValue: settings.defaultBackend,
            onChanged: (value) {
              if (value == null) return;
              setState(() => settings.defaultBackend = value);
              Navigator.of(ctx).pop();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: backends
                  .map((b) => RadioListTile<String>(
                        title: Text(b),
                        value: b,
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _showModelSelector(SettingsService settings) async {
    final backendFilter = settings.defaultBackend;
    List<ModelInfo> models = [];
    try {
      models = await ref.read(modelServiceProvider).getWhisperCppModels();
    } catch (e) {
      Log.instance.w('settings', 'Failed to load models for picker', error: e);
    }
    // Filter by currently-selected backend — user chose "parakeet" as
    // default backend, picker shows parakeet quants only.
    final filtered = models.where((m) => m.backend == backendFilter).toList();

    if (!mounted) return;
    final l = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.settingsSelectModel(backendFilter)),
        content: SizedBox(
          width: double.maxFinite,
          child: filtered.isEmpty
              ? Text(l.settingsNoModelsForBackend(backendFilter))
              : SingleChildScrollView(
                  child: RadioGroup<String>(
                    groupValue: settings.defaultModel,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => settings.defaultModel = value);
                      Navigator.of(ctx).pop();
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: filtered
                          .map((m) => RadioListTile<String>(
                                title: Text(m.displayName),
                                subtitle: Text(
                                    '${m.quantization.isEmpty ? "f16" : m.quantization} • ${m.size}'),
                                value: m.name,
                              ))
                          .toList(),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  void _showLanguageSelector(SettingsService settings) {
    final l = AppLocalizations.of(context);
    final languages = {
      'auto': l.languageAuto,
      'en': l.languageEn,
      'es': l.languageEs,
      'fr': l.languageFr,
      'de': l.languageDe,
      'it': l.languageIt,
      'pt': l.languagePt,
      'zh': l.languageZh,
      'ja': l.languageJa,
      'ko': l.languageKo,
    };

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).settingsSelectLanguage),
        content: RadioGroup<String>(
          groupValue: settings.defaultLanguage,
          onChanged: (value) {
            if (value == null) return;
            setState(() => settings.defaultLanguage = value);
            Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: languages.entries
                .map((entry) => RadioListTile<String>(
                      title: Text(entry.value),
                      value: entry.key,
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioSettings(SettingsService settings) {
    return _buildSettingsSection(
      title: AppLocalizations.of(context).settingsAudio,
      icon: Icons.audiotrack,
      children: [
        ListTile(
          title: Text(AppLocalizations.of(context).settingsAudioQuality),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).settingsAudioQualityCurrent(
                  (settings.audioQuality * 100).toInt())),
              Slider(
                value: settings.audioQuality,
                onChanged: (value) {
                  setState(() => settings.audioQuality = value);
                },
                divisions: 4,
                label: '${(settings.audioQuality * 100).toInt()}%',
              ),
            ],
          ),
        ),
        SwitchListTile(
          title: Text(AppLocalizations.of(context).settingsKeepAudioFiles),
          subtitle:
              Text(AppLocalizations.of(context).settingsKeepAudioFilesSubtitle),
          value: settings.keepAudioFiles,
          onChanged: (value) {
            setState(() => settings.keepAudioFiles = value);
          },
        ),
      ],
    );
  }

  Widget _buildDiarizationSettings(SettingsService settings) {
    return _buildSettingsSection(
      title: AppLocalizations.of(context).settingsDiarization,
      icon: Icons.people,
      children: [
        SwitchListTile(
          title: Text(
              AppLocalizations.of(context).settingsEnableDiarizationByDefault),
          subtitle: Text(AppLocalizations.of(context)
              .settingsEnableDiarizationByDefaultSubtitle),
          value: settings.enableDiarizationByDefault,
          onChanged: (value) {
            setState(() => settings.enableDiarizationByDefault = value);
          },
        ),
      ],
    );
  }

  Widget _buildStorageSettings() {
    return _buildSettingsSection(
      title: AppLocalizations.of(context).settingsStorage,
      icon: Icons.storage,
      children: [
        ListTile(
          title: Text(AppLocalizations.of(context).settingsClearCache),
          subtitle:
              Text(AppLocalizations.of(context).settingsClearCacheSubtitle),
          trailing: const Icon(Icons.delete_outline),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text(AppLocalizations.of(context).settingsCacheCleared)),
            );
          },
        ),
        ListTile(
          title: Text(AppLocalizations.of(context).settingsManageModels),
          subtitle:
              Text(AppLocalizations.of(context).settingsManageModelsSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/models'),
        ),
        ListTile(
          title: Text(AppLocalizations.of(context).settingsStorageBreakdown),
          subtitle: Text(
              AppLocalizations.of(context).settingsStorageBreakdownSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/storage'),
        ),
      ],
    );
  }

  Widget _buildServerSettings() {
    final server = ref.watch(serverServiceProvider);
    final running = server.isRunning;
    final l = AppLocalizations.of(context);
    return _buildSettingsSection(
      title: l.settingsServerSection,
      icon: Icons.cloud,
      children: [
        SwitchListTile(
          title: Text(l.settingsServerEnable),
          subtitle: Text(
            running
                ? l.settingsServerRunningAt(server.boundUrl ?? '')
                : l.settingsServerStopped,
          ),
          value: running,
          onChanged: (v) async {
            if (v) {
              try {
                await server.start();
              } on ServerStartException catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.settingsServerStartFailed(e.message))),
                );
              }
            } else {
              await server.stop();
            }
            if (mounted) setState(() {});
          },
        ),
        ListTile(
          title: Text(l.settingsServerEndpoints),
          subtitle: Text(l.settingsServerEndpointsHelp,
              style: const TextStyle(fontSize: 11)),
          isThreeLine: true,
        ),
      ],
    );
  }

  Widget _buildDeveloperSettings(SettingsService settings) {
    return _buildSettingsSection(
      title: AppLocalizations.of(context).settingsDebugging,
      icon: Icons.bug_report,
      children: [
        ListTile(
          title: Text(AppLocalizations.of(context).settingsLogLevel),
          subtitle: Text(AppLocalizations.of(context)
              .settingsLogLevelCurrent(settings.logLevel.tag)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showLogLevelSelector(settings),
        ),
        SwitchListTile(
          title: Text(AppLocalizations.of(context).settingsMirrorLogs),
          subtitle:
              Text(AppLocalizations.of(context).settingsMirrorLogsSubtitle),
          value: settings.logToFile,
          onChanged: (value) async {
            setState(() => settings.logToFile = value);
            await Log.instance.enableFileSink(value);
          },
        ),
        SwitchListTile(
          title: Text(AppLocalizations.of(context).settingsSkipChecksum),
          subtitle:
              Text(AppLocalizations.of(context).settingsSkipChecksumSubtitle),
          value: settings.skipChecksum,
          onChanged: (value) {
            setState(() => settings.skipChecksum = value);
            Log.instance.i(
                'settings',
                value
                    ? 'Checksum verification disabled'
                    : 'Checksum verification enabled');
          },
        ),
        SwitchListTile(
          title:
              Text(AppLocalizations.of(context).settingsGroupBatchByBackend),
          subtitle: Text(AppLocalizations.of(context)
              .settingsGroupBatchByBackendSubtitle),
          value: settings.groupBatchByBackend,
          onChanged: (value) {
            setState(() => settings.groupBatchByBackend = value);
            Log.instance.i('settings',
                'Group batch by backend: ${value ? "ON" : "OFF"}');
          },
        ),
        // §5.23 Q2 v1 — pipeline parallelism slider. 1 = current
        // serial behaviour, 2..N = pre-decode next file's audio in
        // a worker isolate while the current file's GPU work runs.
        // Cap is platform-specific (2 on iOS, 4 elsewhere).
        Builder(builder: (context) {
          final n = settings.maxConcurrentTranscriptions;
          final cap = settings.maxConcurrentTranscriptionsLimit;
          return ListTile(
            title: Text(AppLocalizations.of(context)
                .settingsMaxConcurrentCurrent(n)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: n.toDouble(),
                  min: 1,
                  max: cap.toDouble(),
                  divisions: cap - 1,
                  label: n.toString(),
                  onChanged: (v) {
                    setState(() =>
                        settings.maxConcurrentTranscriptions = v.round());
                  },
                ),
                Text(AppLocalizations.of(context)
                    .settingsMaxConcurrentSubtitle),
              ],
            ),
          );
        }),
        // §5.23 Q2 v2 — N-way session pool slider. 1 = no pool
        // (existing behaviour). 2+ spawns N worker isolates each
        // holding its own model copy. RAM projection shows
        // realtime estimate against the currently-selected model;
        // pre-flight at batch-start time may clamp lower if the
        // model doesn't fit.
        Builder(builder: (context) {
          final l = AppLocalizations.of(context);
          final n = settings.maxConcurrentSessions;
          final cap = settings.maxConcurrentSessionsLimit;
          final estimator = ref.read(memoryEstimatorProvider);
          final modelPath = _activeModelPath(ref, settings.defaultModel);
          final est = estimator.estimate(
              requested: n, modelPath: modelPath);
          return ListTile(
            title: Text(l.settingsMaxConcurrentSessionsCurrent(n)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: n.toDouble(),
                  min: 1,
                  max: cap.toDouble(),
                  divisions: cap - 1,
                  label: n.toString(),
                  onChanged: (v) {
                    setState(() =>
                        settings.maxConcurrentSessions = v.round());
                  },
                ),
                Text(l.settingsMaxConcurrentSessionsSubtitle),
                const SizedBox(height: 4),
                Text(
                  l.settingsMemoryProjection(
                    est.prettyProjected,
                    est.prettyPhysical,
                    est.prettyPerWorker,
                  ),
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade700),
                ),
                if (est.wasClamped)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l.settingsMemoryProjectionClamped(
                          est.affordableWorkers, est.requestedWorkers),
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          );
        }),
        ListTile(
          title: Text(AppLocalizations.of(context).settingsHfToken),
          subtitle: Text(settings.hfToken.isEmpty
              ? 'Not set (required for gated models)'
              : '••••••••${settings.hfToken.length > 8 ? settings.hfToken.substring(settings.hfToken.length - 4) : ""}'),
          trailing: const Icon(Icons.vpn_key),
          onTap: () => _showHfTokenDialog(settings),
        ),
        // iOS sandboxes apps inside their container; pointing the model
        // store at an arbitrary folder requires security-scoped bookmarks
        // and a different storage flow. Hide the picker on iOS until that
        // exists — the default path inside the app's documents directory
        // is the only sane location there.
        if (!Platform.isIOS)
          ListTile(
            title: Text(AppLocalizations.of(context).settingsModelsDir),
            subtitle: Text(settings.customModelsDir.isEmpty
                ? AppLocalizations.of(context).settingsModelsDirDefault
                : settings.customModelsDir),
            trailing: const Icon(Icons.folder_open),
            onTap: () => _showModelsDirDialog(settings),
          ),
        // §5.1.11 — desktop global hotkey configuration.
        // Hidden on mobile where the OS doesn't expose a
        // system-level shortcut surface.
        if (Platform.isMacOS || Platform.isWindows || Platform.isLinux)
          ListTile(
            title: Text(AppLocalizations.of(context).settingsHotkey),
            subtitle: Text(!settings.hotkeyEnabled ||
                    settings.hotkeyCombo.isEmpty
                ? AppLocalizations.of(context).settingsHotkeyOff
                : '${settings.hotkeyCombo} '
                    '(${settings.hotkeyAction == HotkeyAction.pushToTalk ? AppLocalizations.of(context).settingsHotkeyActionPushToTalk : AppLocalizations.of(context).settingsHotkeyActionToggle})'),
            trailing: const Icon(Icons.keyboard),
            onTap: () => _showHotkeyDialog(settings),
          ),
        // §5.1.6 v2 — BYOK cloud-LLM cleanup settings.
        ListTile(
          title: Text(
              AppLocalizations.of(context).settingsCloudLlmCleanup),
          subtitle: Text(settings.cloudLlmApiUrl.isEmpty ||
                  settings.cloudLlmApiKey.isEmpty
              ? AppLocalizations.of(context)
                  .settingsCloudLlmCleanupOff
              : '${settings.cloudLlmModel} · ${settings.cloudLlmApiUrl}'),
          trailing: const Icon(Icons.cloud_outlined),
          onTap: () => _showCloudLlmDialog(settings),
        ),
        // §5.1.6 v3 — on-device chat-LLM cleanup settings.
        ListTile(
          title: Text(
              AppLocalizations.of(context).settingsLocalLlmCleanup),
          subtitle: Text(settings.localLlmModelPath.isEmpty
              ? AppLocalizations.of(context).settingsLocalLlmCleanupOff
              : _shortGgufLabel(settings.localLlmModelPath)),
          trailing: const Icon(Icons.memory_outlined),
          onTap: () => _showLocalLlmDialog(settings),
        ),
        ListTile(
          title: Text(AppLocalizations.of(context).settingsOpenLogViewer),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/logs'),
        ),
      ],
    );
  }

  /// Pretty-print a model file path for the Settings list tile.
  /// Just the basename plus a parent-dir crumb; the full path
  /// is visible in the picker dialog itself.
  String _shortGgufLabel(String path) {
    final sep = Platform.pathSeparator;
    final parts = path.split(sep).where((p) => p.isNotEmpty).toList();
    if (parts.length <= 1) return path;
    return '${parts[parts.length - 2]}$sep${parts.last}';
  }

  void _showCloudLlmDialog(SettingsService settings) {
    final l = AppLocalizations.of(context);
    final urlCtl = TextEditingController(text: settings.cloudLlmApiUrl);
    final keyCtl = TextEditingController(text: settings.cloudLlmApiKey);
    final modelCtl =
        TextEditingController(text: settings.cloudLlmModel);
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l.settingsCloudLlmCleanup),
          content: SizedBox(
            width: responsiveDialogWidth(ctx, designed: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.settingsCloudLlmHelp,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700)),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtl,
                  decoration: InputDecoration(
                    labelText: l.settingsCloudLlmUrl,
                    hintText:
                        'https://api.openai.com/v1/chat/completions',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: keyCtl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l.settingsCloudLlmKey,
                    hintText: 'sk-…',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: modelCtl,
                  decoration: InputDecoration(
                    labelText: l.settingsCloudLlmModel,
                    hintText: 'gpt-4o-mini',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l.cancel)),
            TextButton(
                onPressed: () {
                  setState(() {
                    settings.cloudLlmApiUrl = '';
                    settings.cloudLlmApiKey = '';
                    settings.cloudLlmModel = 'gpt-4o-mini';
                  });
                  Navigator.of(ctx).pop();
                },
                child: Text(l.settingsCloudLlmClear)),
            FilledButton(
                onPressed: () {
                  setState(() {
                    settings.cloudLlmApiUrl = urlCtl.text.trim();
                    settings.cloudLlmApiKey = keyCtl.text.trim();
                    final m = modelCtl.text.trim();
                    settings.cloudLlmModel =
                        m.isEmpty ? 'gpt-4o-mini' : m;
                  });
                  Navigator.of(ctx).pop();
                },
                child: Text(l.save)),
          ],
        );
      },
    );
  }

  /// §5.1.6 v3 — Local LLM cleanup dialog. File picker for the
  /// GGUF chat model, expandable advanced params. No URL / key
  /// fields — the local path doesn't need them.
  void _showLocalLlmDialog(SettingsService settings) {
    final l = AppLocalizations.of(context);
    // Local working copies of the advanced params so the user
    // can play with sliders without committing until Save.
    var modelPath = settings.localLlmModelPath;
    var nGpuLayers = settings.localLlmNGpuLayers;
    var nCtx = settings.localLlmNCtx;
    var nThreads = settings.localLlmNThreads;
    var maxTokens = settings.localLlmMaxTokens;
    var temperature = settings.localLlmTemperature;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          Future<void> pickModel() async {
            final picked = await FilePicker.pickFiles(
              dialogTitle: l.settingsLocalLlmModelPick,
              type: FileType.custom,
              allowedExtensions: const ['gguf'],
            );
            final p = picked?.files.single.path;
            if (p == null || p.isEmpty) return;
            setLocal(() => modelPath = p);
          }

          return AlertDialog(
            title: Text(l.settingsLocalLlmCleanup),
            content: SizedBox(
              width: responsiveDialogWidth(ctx, designed: 560),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.settingsLocalLlmHelp,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700)),
                    const SizedBox(height: 12),
                    Text(l.settingsLocalLlmModelPath,
                        style:
                            Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            modelPath.isEmpty
                                ? l.settingsLocalLlmModelPathEmpty
                                : modelPath,
                            style: TextStyle(
                              fontSize: 12,
                              color: modelPath.isEmpty
                                  ? Colors.grey.shade600
                                  : null,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: Text(l.settingsLocalLlmModelPick),
                          onPressed: pickModel,
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
                          nGpuLayers == -1
                              ? l.settingsLocalLlmNGpuLayersAll
                              : l.settingsLocalLlmNGpuLayers(nGpuLayers),
                          style:
                              Theme.of(context).textTheme.bodySmall,
                        ),
                        Slider(
                          min: -1,
                          max: 99,
                          divisions: 100,
                          value: nGpuLayers.toDouble().clamp(-1, 99),
                          label: nGpuLayers == -1 ? 'all' : '$nGpuLayers',
                          onChanged: (v) =>
                              setLocal(() => nGpuLayers = v.round()),
                        ),
                        Text(l.settingsLocalLlmNGpuLayersHelp,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700)),
                        const SizedBox(height: 8),
                        Text(
                          nCtx == 0
                              ? l.settingsLocalLlmNCtxDefault
                              : l.settingsLocalLlmNCtx(nCtx),
                          style:
                              Theme.of(context).textTheme.bodySmall,
                        ),
                        Slider(
                          min: 0,
                          max: 32768,
                          divisions: 64,
                          value: nCtx.toDouble().clamp(0, 32768),
                          label: nCtx == 0 ? 'auto' : '$nCtx',
                          onChanged: (v) {
                            // Snap to multiples of 512 for the
                            // common-case context sizes; 0 is
                            // the "model default" anchor.
                            final snapped = (v / 512).round() * 512;
                            setLocal(() => nCtx = snapped);
                          },
                        ),
                        Text(l.settingsLocalLlmNCtxHelp,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700)),
                        const SizedBox(height: 8),
                        Text(
                          nThreads == 0
                              ? l.settingsLocalLlmNThreadsAuto
                              : l.settingsLocalLlmNThreads(nThreads),
                          style:
                              Theme.of(context).textTheme.bodySmall,
                        ),
                        Slider(
                          min: 0,
                          max: 32,
                          divisions: 32,
                          value: nThreads.toDouble().clamp(0, 32),
                          label:
                              nThreads == 0 ? 'auto' : '$nThreads',
                          onChanged: (v) =>
                              setLocal(() => nThreads = v.round()),
                        ),
                        const SizedBox(height: 8),
                        Text(l.settingsLocalLlmMaxTokens(maxTokens),
                            style:
                                Theme.of(context).textTheme.bodySmall),
                        Slider(
                          min: 64,
                          max: 4096,
                          divisions: 63,
                          value: maxTokens.toDouble().clamp(64, 4096),
                          label: '$maxTokens',
                          onChanged: (v) =>
                              setLocal(() => maxTokens = v.round()),
                        ),
                        const SizedBox(height: 8),
                        Text(
                            l.settingsLocalLlmTemperature(
                                temperature.toStringAsFixed(2)),
                            style:
                                Theme.of(context).textTheme.bodySmall),
                        Slider(
                          min: 0.0,
                          max: 2.0,
                          divisions: 40,
                          value: temperature.clamp(0.0, 2.0),
                          label: temperature.toStringAsFixed(2),
                          onChanged: (v) =>
                              setLocal(() => temperature = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l.cancel)),
              TextButton(
                onPressed: () {
                  // Reset to defaults, including clearing the
                  // path so the feature falls back to Off.
                  setState(() {
                    settings.localLlmModelPath = '';
                    settings.localLlmNGpuLayers = -1;
                    settings.localLlmNCtx = 0;
                    settings.localLlmNThreads = 0;
                    settings.localLlmMaxTokens = 512;
                    settings.localLlmTemperature = 0.0;
                  });
                  Navigator.of(ctx).pop();
                },
                child: Text(l.settingsLocalLlmModelClear),
              ),
              FilledButton(
                onPressed: () {
                  setState(() {
                    settings.localLlmModelPath = modelPath.trim();
                    settings.localLlmNGpuLayers = nGpuLayers;
                    settings.localLlmNCtx = nCtx;
                    settings.localLlmNThreads = nThreads;
                    settings.localLlmMaxTokens = maxTokens;
                    settings.localLlmTemperature = temperature;
                  });
                  Navigator.of(ctx).pop();
                },
                child: Text(l.save),
              ),
            ],
          );
        });
      },
    );
  }

  /// §5.1.11 — global-hotkey configuration dialog. Text-input
  /// field for the combo string plus a Radio group for the
  /// push-to-talk / toggle behaviour and an enable switch.
  /// Hotkey-recorder UI is intentionally simple for v1 — a
  /// HotkeyRecorder widget exists in the package but adds a
  /// modal-overlay UX the v1 doesn't need. v2 can swap in the
  /// recorder.
  void _showHotkeyDialog(SettingsService settings) {
    final l = AppLocalizations.of(context);
    final comboCtl = TextEditingController(text: settings.hotkeyCombo);
    bool enabled = settings.hotkeyEnabled;
    HotkeyAction action = settings.hotkeyAction;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialog) {
          return AlertDialog(
            title: Text(l.settingsHotkey),
            content: SizedBox(
              width: responsiveDialogWidth(ctx, designed: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.settingsHotkeyHelp,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700)),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: Text(l.settingsHotkeyEnable),
                    value: enabled,
                    onChanged: (v) => setDialog(() => enabled = v),
                  ),
                  TextField(
                    controller: comboCtl,
                    decoration: InputDecoration(
                      labelText: l.settingsHotkeyCombo,
                      hintText: 'meta+shift+space',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(l.settingsHotkeyBehavior,
                      style:
                          Theme.of(context).textTheme.titleSmall),
                  RadioGroup<HotkeyAction>(
                    groupValue: action,
                    onChanged: (v) {
                      if (v != null) setDialog(() => action = v);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<HotkeyAction>(
                          dense: true,
                          title: Text(
                              l.settingsHotkeyActionPushToTalk),
                          subtitle: Text(
                              l.settingsHotkeyActionPushToTalkHelp,
                              style:
                                  const TextStyle(fontSize: 11)),
                          value: HotkeyAction.pushToTalk,
                        ),
                        RadioListTile<HotkeyAction>(
                          dense: true,
                          title:
                              Text(l.settingsHotkeyActionToggle),
                          subtitle: Text(
                              l.settingsHotkeyActionToggleHelp,
                              style:
                                  const TextStyle(fontSize: 11)),
                          value: HotkeyAction.toggle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l.cancel)),
              FilledButton(
                onPressed: () async {
                  final combo = comboCtl.text.trim();
                  // Validate first — refuse to save garbage
                  // that would silently disable the hotkey on
                  // next start.
                  if (enabled &&
                      combo.isNotEmpty &&
                      HotkeyService.parse(combo) == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(l.settingsHotkeyInvalid(combo)),
                    ));
                    return;
                  }
                  setState(() {
                    settings.hotkeyEnabled = enabled;
                    settings.hotkeyCombo = combo;
                    settings.hotkeyAction = action;
                  });
                  // Re-register with the freshly-saved values.
                  await ref
                      .read(hotkeyServiceProvider)
                      .applyFromSettings();
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: Text(l.save),
              ),
            ],
          );
        });
      },
    );
  }

  void _showLogLevelSelector(SettingsService settings) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).settingsLogLevel),
        content: RadioGroup<LogLevel>(
          groupValue: settings.logLevel,
          onChanged: (v) {
            if (v == null) return;
            setState(() => settings.logLevel = v);
            Log.instance.setMinLevel(v);
            Navigator.of(ctx).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: LogLevel.values
                .map((l) => RadioListTile<LogLevel>(
                      title: Text('${l.tag} — ${l.name}'),
                      value: l,
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  /// Folder-picker for the optional custom models directory. Lets the
  /// user point CrisperWeaver at a shared library on an external disk
  /// (e.g. `/Volumes/backups/ai/crispasr-models`) so existing GGUFs
  /// are reused without re-downloading into the sandbox. The empty
  /// string ("Use default") restores the historical
  /// `<app-docs>/models/whisper_cpp` location.
  Future<void> _showModelsDirDialog(SettingsService settings) async {
    final l = AppLocalizations.of(context);
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.settingsModelsDirPickTitle),
        content: Text(settings.customModelsDir.isEmpty
            ? l.settingsModelsDirCurrentDefault
            : l.settingsModelsDirCurrent(settings.customModelsDir)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: Text(l.cancel),
          ),
          if (settings.customModelsDir.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('reset'),
              child: Text(l.settingsModelsDirReset),
            ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('pick'),
            child: Text(l.settingsModelsDirPick),
          ),
        ],
      ),
    );
    if (action == 'reset') {
      setState(() => settings.customModelsDir = '');
      Log.instance.i('settings', 'customModelsDir cleared (back to sandbox)');
      return;
    }
    if (action != 'pick') return;
    final picked = await FilePicker.getDirectoryPath(
      dialogTitle: l.settingsModelsDirPickTitle,
      initialDirectory:
          settings.customModelsDir.isEmpty ? null : settings.customModelsDir,
    );
    if (picked == null || picked.isEmpty) return;
    setState(() => settings.customModelsDir = picked);
    Log.instance.i('settings', 'customModelsDir set', fields: {'path': picked});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.settingsModelsDirSet(picked))),
    );
  }

  void _showHfTokenDialog(SettingsService settings) {
    final controller = TextEditingController(text: settings.hfToken);
    showDialog<void>(
      context: context,
      builder: (context) {
        final l = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l.settingsHfTokenTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.settingsHfTokenSubtitle,
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                    labelText: l.labelApiToken,
                    border: const OutlineInputBorder(),
                    hintText: 'hf_...'),
                obscureText: true,
                autocorrect: false,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l.settingsHfTokenCancel)),
            ElevatedButton(
              onPressed: () {
                final newToken = controller.text.trim();
                setState(() => settings.hfToken = newToken);
                ref.read(modelServiceProvider).hfToken = newToken;
                Navigator.of(context).pop();
                Log.instance.i(
                    'settings',
                    newToken.isEmpty
                        ? 'HF Token cleared'
                        : 'HF Token updated');
              },
              child: Text(l.settingsHfTokenSave),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSystemInfo() {
    return _buildSettingsSection(
      title: AppLocalizations.of(context).settingsSystemInfo,
      icon: Icons.info,
      children: [
        FutureBuilder<Map<String, String>>(
          future: _getSystemInfo(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return ListTile(
                  title: Text(AppLocalizations.of(context).settingsLoading));
            }
            return Column(
              children: snapshot.data!.entries
                  .map((entry) => ListTile(
                        title: Text(entry.key),
                        subtitle: Text(entry.value),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return _buildSettingsSection(
      title: AppLocalizations.of(context).settingsAbout,
      icon: Icons.help_outline,
      children: [
        ListTile(
          title: Text(AppLocalizations.of(context).settingsVersion),
          subtitle: FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) => Text(snapshot.hasData
                ? '${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                : AppLocalizations.of(context).settingsLoading),
          ),
        ),
        ListTile(
          title: Text(AppLocalizations.of(context).settingsAboutCrisperWeaver),
          subtitle: Text(
              AppLocalizations.of(context).settingsAboutCrisperWeaverSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/about'),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(
      {required String title,
      required IconData icon,
      required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon),
            title: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Future<Map<String, String>> _getSystemInfo() async {
    final info = <String, String>{};
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      info['App Version'] =
          '${packageInfo.version} (${packageInfo.buildNumber})';
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        info['Device'] = '${iosInfo.name} (${iosInfo.model})';
        info['iOS Version'] = '${iosInfo.systemName} ${iosInfo.systemVersion}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        info['Device'] = '${androidInfo.manufacturer} ${androidInfo.model}';
        info['Android Version'] = 'API ${androidInfo.version.sdkInt}';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        info['Device'] = '${macInfo.computerName} (${macInfo.model})';
        info['macOS Version'] = macInfo.osRelease;
      } else if (Platform.isWindows) {
        final winInfo = await deviceInfo.windowsInfo;
        info['Device'] = winInfo.computerName;
        info['Windows Version'] =
            '${winInfo.productName} (build ${winInfo.buildNumber})';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        info['Device'] = linuxInfo.name;
        info['Linux Version'] = linuxInfo.prettyName;
      }
    } catch (e) {
      info['Error'] = 'Could not load system info';
    }
    return info;
  }

  String _getLanguageDisplayName(String languageCode) {
    final l = AppLocalizations.of(context);
    switch (languageCode) {
      case 'auto':
        return l.languageAuto;
      case 'en':
        return l.languageEn;
      case 'es':
        return l.languageEs;
      case 'fr':
        return l.languageFr;
      case 'de':
        return l.languageDe;
      case 'it':
        return l.languageIt;
      case 'pt':
        return l.languagePt;
      case 'zh':
        return l.languageZh;
      case 'ja':
        return l.languageJa;
      case 'ko':
        return l.languageKo;
      default:
        return languageCode;
    }
  }
}

/// Resolve the on-disk path for [modelId] so the §5.23 Q2 v2 memory
/// pre-flight has something to size against. Looks up the model's
/// fileName via [ModelService] catalogs + joins under the
/// configured models dir. Returns null when the model isn't in the
/// catalog yet (covers user-bring-your-own GGUFs) — the memory
/// estimator treats null as "unknown size", refuses to project a
/// pool count.
String? _activeModelPath(WidgetRef ref, String modelId) {
  final def = ModelService.whisperCppModels[modelId] ??
      ModelService.crispasrBackendModels[modelId];
  if (def == null) return null;
  final dir = ref.read(modelServiceProvider).whisperCppDir();
  return p.join(dir, def.fileName);
}
