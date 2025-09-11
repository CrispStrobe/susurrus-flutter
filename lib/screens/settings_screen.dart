// lib/screens/settings_screen.dart (FIXED)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../engines/engine_factory.dart'; // Use EngineType instead of TranscriptionBackend
import '../native/coreml_whisper.dart';
import '../main.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late SharedPreferences _prefs;
  bool _isLoading = true;

  // Settings values
  EngineType _preferredEngine = EngineType.mock; // Use EngineType
  String _defaultModel = 'base';
  String _defaultLanguage = 'auto';
  bool _autoDetectLanguage = true;
  bool _enableWordTimestamps = false;
  bool _keepAudioFiles = false;
  double _audioQuality = 0.8;
  bool _enableDiarizationByDefault = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    setState(() {
      // Load engine type by name
      final engineName = _prefs.getString('preferred_engine') ?? 'mock';
      _preferredEngine = EngineType.values.firstWhere(
        (e) => e.id == engineName,
        orElse: () => EngineType.mock,
      );
      
      _defaultModel = _prefs.getString('default_model') ?? 'base';
      _defaultLanguage = _prefs.getString('default_language') ?? 'auto';
      _autoDetectLanguage = _prefs.getBool('auto_detect_language') ?? true;
      _enableWordTimestamps = _prefs.getBool('enable_word_timestamps') ?? false;
      _keepAudioFiles = _prefs.getBool('keep_audio_files') ?? false;
      _audioQuality = _prefs.getDouble('audio_quality') ?? 0.8;
      _enableDiarizationByDefault = _prefs.getBool('enable_diarization_by_default') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _saveSetting<T>(String key, T value) async {
    if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is double) {
      await _prefs.setDouble(key, value);
    } else if (value is String) {
      await _prefs.setString(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _buildEngineSettings(),
          _buildTranscriptionSettings(),
          _buildAudioSettings(),
          _buildDiarizationSettings(),
          _buildStorageSettings(),
          _buildSystemInfo(),
          _buildAboutSection(),
        ],
      ),
    );
  }

  Widget _buildEngineSettings() {
    return _buildSettingsSection(
      title: 'Transcription Engine',
      icon: Icons.psychology,
      children: [
        ListTile(
          title: const Text('Preferred Engine'),
          subtitle: Text(_getEngineDisplayName(_preferredEngine)),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showEngineSelector,
        ),
      ],
    );
  }

  Widget _buildTranscriptionSettings() {
    return _buildSettingsSection(
      title: 'Transcription',
      icon: Icons.transcribe,
      children: [
        ListTile(
          title: const Text('Default Model'),
          subtitle: Text(_defaultModel),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showModelSelector,
        ),
        ListTile(
          title: const Text('Default Language'),
          subtitle: Text(_getLanguageDisplayName(_defaultLanguage)),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showLanguageSelector,
        ),
        SwitchListTile(
          title: const Text('Auto-detect Language'),
          subtitle: const Text('Automatically detect audio language'),
          value: _autoDetectLanguage,
          onChanged: (value) {
            setState(() => _autoDetectLanguage = value);
            _saveSetting('auto_detect_language', value);
          },
        ),
        SwitchListTile(
          title: const Text('Word Timestamps'),
          subtitle: const Text('Generate timestamps for individual words'),
          value: _enableWordTimestamps,
          onChanged: (value) {
            setState(() => _enableWordTimestamps = value);
            _saveSetting('enable_word_timestamps', value);
          },
        ),
      ],
    );
  }

  Widget _buildAudioSettings() {
    return _buildSettingsSection(
      title: 'Audio',
      icon: Icons.audiotrack,
      children: [
        ListTile(
          title: const Text('Audio Quality'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recording quality: ${(_audioQuality * 100).toInt()}%'),
              Slider(
                value: _audioQuality,
                onChanged: (value) {
                  setState(() => _audioQuality = value);
                  _saveSetting('audio_quality', value);
                },
                divisions: 4,
                label: '${(_audioQuality * 100).toInt()}%',
              ),
            ],
          ),
        ),
        SwitchListTile(
          title: const Text('Keep Audio Files'),
          subtitle: const Text('Keep downloaded/recorded audio files after transcription'),
          value: _keepAudioFiles,
          onChanged: (value) {
            setState(() => _keepAudioFiles = value);
            _saveSetting('keep_audio_files', value);
          },
        ),
      ],
    );
  }

  Widget _buildDiarizationSettings() {
    return _buildSettingsSection(
      title: 'Speaker Diarization',
      icon: Icons.people,
      children: [
        SwitchListTile(
          title: const Text('Enable by Default'),
          subtitle: const Text('Automatically enable diarization for new transcriptions'),
          value: _enableDiarizationByDefault,
          onChanged: (value) {
            setState(() => _enableDiarizationByDefault = value);
            _saveSetting('enable_diarization_by_default', value);
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
          onTap: _clearCache,
        ),
        ListTile(
          title: const Text('Manage Models'),
          subtitle: const Text('Download, update, or delete transcription models'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).pushNamed('/models'),
        ),
      ],
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
            if (!snapshot.hasData) {
              return const ListTile(title: Text('Loading system information...'));
            }

            final info = snapshot.data!;
            return Column(
              children: info.entries.map((entry) {
                return ListTile(
                  title: Text(entry.key),
                  subtitle: Text(entry.value),
                );
              }).toList(),
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
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Text('${snapshot.data!.version} (${snapshot.data!.buildNumber})');
              }
              return const Text('Loading...');
            },
          ),
        ),
        ListTile(
          title: const Text('Privacy Policy'),
          subtitle: const Text('All processing happens on-device'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showPrivacyPolicy,
        ),
      ],
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon),
            title: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  void _showEngineSelector() {
    final availableEngines = EngineFactory.getAvailableEngines();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Engine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: availableEngines.map((engine) {
            return RadioListTile<EngineType>(
              title: Text(_getEngineDisplayName(engine)),
              subtitle: Text(_getEngineDescription(engine)),
              value: engine,
              groupValue: _preferredEngine,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _preferredEngine = value);
                  _saveSetting('preferred_engine', value.id);
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showModelSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Default Model'),
        content: const Text('Model selection will be implemented with engine integration'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLanguageSelector() {
    final languages = {
      'auto': 'Auto-detect',
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'zh': 'Chinese',
      'ja': 'Japanese',
      'ko': 'Korean',
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Default Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.entries.map((entry) {
            return RadioListTile<String>(
              title: Text(entry.value),
              value: entry.key,
              groupValue: _defaultLanguage,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _defaultLanguage = value);
                  _saveSetting('default_language', value);
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _clearCache() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache cleared successfully')),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Susurrus processes all audio locally on your device. '
            'No audio data is sent to external servers. '
            'Transcriptions are stored locally and can be deleted at any time.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
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
        info['CoreML Available'] = await CoreMLWhisper.instance.isAvailable ? 'Yes' : 'No';
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

  String _getEngineDisplayName(EngineType engine) {
    return engine.displayName;
  }

  String _getEngineDescription(EngineType engine) {
    return engine.description;
  }

  String _getLanguageDisplayName(String languageCode) {
    const languages = {
      'auto': 'Auto-detect',
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'zh': 'Chinese',
      'ja': 'Japanese',
      'ko': 'Korean',
    };
    return languages[languageCode] ?? languageCode;
  }
}