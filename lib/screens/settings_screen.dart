import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:go_router/go_router.dart';

import '../engines/engine_factory.dart';
import '../l10n/generated/app_localizations.dart';
import '../main.dart';
import '../services/log_service.dart';
import '../services/model_service.dart';
import '../services/settings_service.dart';

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
          _buildDeveloperSettings(settings),
          _buildSystemInfo(),
          _buildAboutSection(),
        ],
      ),
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
        title: const Text('Select Engine'),
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
        ListTile(
          title: Text(AppLocalizations.of(context).settingsHfToken),
          subtitle: Text(settings.hfToken.isEmpty
              ? 'Not set (required for gated models)'
              : '••••••••${settings.hfToken.length > 8 ? settings.hfToken.substring(settings.hfToken.length - 4) : ""}'),
          trailing: const Icon(Icons.vpn_key),
          onTap: () => _showHfTokenDialog(settings),
        ),
        ListTile(
          title: Text(AppLocalizations.of(context).settingsModelsDir),
          subtitle: Text(settings.customModelsDir.isEmpty
              ? AppLocalizations.of(context).settingsModelsDirDefault
              : settings.customModelsDir),
          trailing: const Icon(Icons.folder_open),
          onTap: () => _showModelsDirDialog(settings),
        ),
        ListTile(
          title: Text(AppLocalizations.of(context).settingsOpenLogViewer),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/logs'),
        ),
      ],
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
      builder: (context) => AlertDialog(
        title: const Text('Hugging Face API Token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Required for gated or private repositories.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                  labelText: 'API Token',
                  border: OutlineInputBorder(),
                  hintText: 'hf_...'),
              obscureText: true,
              autocorrect: false,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              final newToken = controller.text.trim();
              setState(() => settings.hfToken = newToken);
              ref.read(modelServiceProvider).hfToken = newToken;
              Navigator.of(context).pop();
              Log.instance.i('settings',
                  newToken.isEmpty ? 'HF Token cleared' : 'HF Token updated');
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
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
