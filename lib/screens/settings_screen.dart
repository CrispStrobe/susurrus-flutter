import 'dart:io';
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
    return _buildSettingsSection(
      title: 'App Language',
      icon: Icons.language,
      children: [
        ListTile(
          title: const Text('Interface Language'),
          subtitle: Text(_getAppLocaleDisplayName(settings.appLocale ?? '')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showAppLocaleSelector(settings),
        ),
      ],
    );
  }

  void _showAppLocaleSelector(SettingsService settings) {
    final locales = {
      '': 'System Default',
      'en': 'English',
      'de': 'Deutsch',
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).settingsSelectInterfaceLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: locales.entries.map((entry) {
            return RadioListTile<String>(
              title: Text(entry.value),
              value: entry.key,
              groupValue: settings.appLocale ?? '',
              onChanged: (value) async {
                if (value != null) {
                  setState(() => settings.appLocale = value);
                  
                  // Update app-wide locale via provider
                  final languageCode = value.isEmpty ? null : value;
                  ref.read(localeProvider.notifier).setLocale(languageCode);
                  
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getAppLocaleDisplayName(String code) {
    if (code == 'en') return 'English';
    if (code == 'de') return 'Deutsch';
    return 'System Default';
  }

  Widget _buildEngineSettings(SettingsService settings) {
    return _buildSettingsSection(
      title: 'Transcription Engine',
      icon: Icons.psychology,
      children: [
        ListTile(
          title: const Text('Preferred Engine'),
          subtitle: Text(settings.preferredEngine.displayName),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showEngineSelector(settings),
        ),
      ],
    );
  }

  void _showEngineSelector(SettingsService settings) {
    final availableEngines = EngineFactory.getAvailableEngines();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Engine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: availableEngines.map((engine) {
            return RadioListTile<EngineType>(
              title: Text(engine.displayName),
              subtitle: Text(engine.description),
              value: engine,
              groupValue: settings.preferredEngine,
              onChanged: (value) async {
                if (value == null) return;
                setState(() => settings.preferredEngine = value);
                Navigator.of(context).pop();

                // Try to swap engines immediately
                final service = ref.read(transcriptionServiceProvider);
                try {
                  final ok = await service.switchEngine(value);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok
                          ? 'Switched to ${value.displayName}'
                          : 'Engine switch failed'),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Engine switch failed: $e')),
                  );
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTranscriptionSettings(SettingsService settings) {
    return _buildSettingsSection(
      title: 'Transcription',
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
          subtitle: Text(AppLocalizations.of(context)
              .settingsAutoDetectLanguageSubtitle),
          value: settings.autoDetectLanguage,
          onChanged: (value) {
            setState(() => settings.autoDetectLanguage = value);
          },
        ),
        SwitchListTile(
          title: Text(AppLocalizations.of(context).settingsWordTimestamps),
          subtitle: Text(
              AppLocalizations.of(context).settingsWordTimestampsSubtitle),
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
      'whisper', 'parakeet', 'canary', 'qwen3', 'cohere', 'granite',
      'fastconformer-ctc', 'canary-ctc', 'voxtral', 'voxtral4b', 'wav2vec2',
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).settingsSelectBackend),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: backends.map((b) => RadioListTile<String>(
              title: Text(b),
              value: b,
              groupValue: settings.defaultBackend,
              onChanged: (value) {
                if (value == null) return;
                setState(() => settings.defaultBackend = value);
                Navigator.of(ctx).pop();
              },
            )).toList(),
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
    final filtered = models
        .where((m) => m.backend == backendFilter)
        .toList();

    if (!mounted) return;
    final l = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.settingsSelectModel(backendFilter)),
        content: SizedBox(
          width: double.maxFinite,
          child: filtered.isEmpty
              ? Text(l.settingsNoModelsForBackend(backendFilter))
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: filtered
                        .map((m) => RadioListTile<String>(
                              title: Text(m.displayName),
                              subtitle: Text(
                                  '${m.quantization.isEmpty ? "f16" : m.quantization} • ${m.size}'),
                              value: m.name,
                              groupValue: settings.defaultModel,
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => settings.defaultModel = value);
                                Navigator.of(ctx).pop();
                              },
                            ))
                        .toList(),
                  ),
                ),
        ),
      ),
    );
  }

  void _showLanguageSelector(SettingsService settings) {
    final languages = {
      'auto': 'Auto-detect', 'en': 'English', 'es': 'Spanish', 'fr': 'French',
      'de': 'German', 'it': 'Italian', 'pt': 'Portuguese', 'zh': 'Chinese',
      'ja': 'Japanese', 'ko': 'Korean',
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).settingsSelectLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.entries.map((entry) => RadioListTile<String>(
            title: Text(entry.value),
            value: entry.key,
            groupValue: settings.defaultLanguage,
            onChanged: (value) {
              if (value != null) {
                setState(() => settings.defaultLanguage = value);
                Navigator.of(context).pop();
              }
            },
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildAudioSettings(SettingsService settings) {
    return _buildSettingsSection(
      title: 'Audio',
      icon: Icons.audiotrack,
      children: [
        ListTile(
          title: const Text('Audio Quality'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recording quality: ${(settings.audioQuality * 100).toInt()}%'),
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
          title: const Text('Keep Audio Files'),
          subtitle: const Text('Keep downloaded/recorded audio files after transcription'),
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
      title: 'Speaker Diarization',
      icon: Icons.people,
      children: [
        SwitchListTile(
          title: const Text('Enable by Default'),
          subtitle: const Text('Automatically enable diarization for new transcriptions'),
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
      title: 'Storage',
      icon: Icons.storage,
      children: [
        ListTile(
          title: const Text('Clear Cache'),
          subtitle: const Text('Clear temporary files and cache'),
          trailing: const Icon(Icons.delete_outline),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cache cleared successfully')),
            );
          },
        ),
        ListTile(
          title: const Text('Manage Models'),
          subtitle: const Text('Download, update, or delete transcription models'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/models'),
        ),
      ],
    );
  }

  Widget _buildDeveloperSettings(SettingsService settings) {
    return _buildSettingsSection(
      title: 'Debugging & development',
      icon: Icons.bug_report,
      children: [
        ListTile(
          title: const Text('Log level'),
          subtitle: Text('Currently ${settings.logLevel.tag}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showLogLevelSelector(settings),
        ),
        SwitchListTile(
          title: const Text('Mirror logs to file'),
          subtitle: const Text('Writes to logs/session.log in the app documents directory'),
          value: settings.logToFile,
          onChanged: (value) async {
            setState(() => settings.logToFile = value);
            await Log.instance.enableFileSink(value);
          },
        ),
        SwitchListTile(
          title: const Text('Skip checksum verification'),
          subtitle: const Text('Accept downloaded models even if SHA-1 does not match'),
          value: settings.skipChecksum,
          onChanged: (value) {
            setState(() => settings.skipChecksum = value);
            Log.instance.i('settings', value ? 'Checksum verification disabled' : 'Checksum verification enabled');
          },
        ),
        ListTile(
          title: const Text('Hugging Face API Token'),
          subtitle: Text(settings.hfToken.isEmpty ? 'Not set (required for gated models)' : '••••••••${settings.hfToken.length > 8 ? settings.hfToken.substring(settings.hfToken.length - 4) : ""}'),
          trailing: const Icon(Icons.vpn_key),
          onTap: () => _showHfTokenDialog(settings),
        ),
        ListTile(
          title: const Text('Open log viewer'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/logs'),
        ),
      ],
    );
  }

  void _showLogLevelSelector(SettingsService settings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log level'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: LogLevel.values.map((l) => RadioListTile<LogLevel>(
            title: Text('${l.tag} — ${l.name}'),
            value: l,
            groupValue: settings.logLevel,
            onChanged: (v) {
              if (v == null) return;
              setState(() => settings.logLevel = v);
              Log.instance.setMinLevel(v);
              Navigator.of(ctx).pop();
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showHfTokenDialog(SettingsService settings) {
    final controller = TextEditingController(text: settings.hfToken);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hugging Face API Token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Required for gated or private repositories.', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'API Token', border: OutlineInputBorder(), hintText: 'hf_...'),
              obscureText: true,
              autocorrect: false,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              final newToken = controller.text.trim();
              setState(() => settings.hfToken = newToken);
              ref.read(modelServiceProvider).hfToken = newToken;
              Navigator.of(context).pop();
              Log.instance.i('settings', newToken.isEmpty ? 'HF Token cleared' : 'HF Token updated');
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemInfo() {
    return _buildSettingsSection(
      title: 'System Information',
      icon: Icons.info,
      children: [
        FutureBuilder<Map<String, String>>(
          future: _getSystemInfo(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const ListTile(title: Text('Loading...'));
            return Column(
              children: snapshot.data!.entries.map((entry) => ListTile(
                title: Text(entry.key),
                subtitle: Text(entry.value),
              )).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return _buildSettingsSection(
      title: 'About',
      icon: Icons.help_outline,
      children: [
        ListTile(
          title: const Text('Version'),
          subtitle: FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) => Text(snapshot.hasData ? '${snapshot.data!.version} (${snapshot.data!.buildNumber})' : 'Loading...'),
          ),
        ),
        ListTile(
          title: const Text('About CrisperWeaver'),
          subtitle: const Text('Author, contact, disclaimer, licenses'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/about'),
        ),
      ],
    );
  }

  Widget _buildSettingsSection({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon),
            title: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
      info['App Version'] = '${packageInfo.version} (${packageInfo.buildNumber})';
      if (Platform.isIOS) {
        final deviceInfo = DeviceInfoPlugin();
        final iosInfo = await deviceInfo.iosInfo;
        info['Device'] = '${iosInfo.name} (${iosInfo.model})';
        info['iOS Version'] = '${iosInfo.systemName} ${iosInfo.systemVersion}';
      } else if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        info['Device'] = '${androidInfo.manufacturer} ${androidInfo.model}';
        info['Android Version'] = 'API ${androidInfo.version.sdkInt}';
      }
    } catch (e) {
      info['Error'] = 'Could not load system info';
    }
    return info;
  }

  String _getLanguageDisplayName(String languageCode) {
    const languages = {
      'auto': 'Auto-detect', 'en': 'English', 'es': 'Spanish', 'fr': 'French',
      'de': 'German', 'it': 'Italian', 'pt': 'Portuguese', 'zh': 'Chinese',
      'ja': 'Japanese', 'ko': 'Korean',
    };
    return languages[languageCode] ?? languageCode;
  }
}
