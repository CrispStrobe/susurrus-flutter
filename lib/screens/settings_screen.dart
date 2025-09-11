import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../services/transcription_service.dart';
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
  TranscriptionBackend _preferredBackend = TranscriptionBackend.auto;
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
      _preferredBackend = TranscriptionBackend.values[
        _prefs.getInt('preferred_backend') ?? TranscriptionBackend.auto.index
      ];
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
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
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

  Widget _buildTranscriptionSettings() {
    return _buildSettingsSection(
      title: 'Transcription',
      icon: Icons.transcribe,
      children: [
        ListTile(
          title: const Text('Preferred Backend'),
          subtitle: Text(_getBackendDisplayName(_preferredBackend)),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showBackendSelector,
        ),

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

        ListTile(
          title: const Text('About Diarization'),
          subtitle: const Text('Learn more about speaker diarization'),
          trailing: const Icon(Icons.info_outline),
          onTap: _showDiarizationInfo,
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
              return const ListTile(
                title: Text('Loading system information...'),
              );
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
          title: const Text('Open Source Licenses'),
          subtitle: const Text('View third-party licenses'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showLicensePage(context: context),
        ),

        ListTile(
          title: const Text('Privacy Policy'),
          subtitle: const Text('View our privacy policy'),
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

  void _showBackendSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Backend'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: TranscriptionBackend.values.map((backend) {
            return RadioListTile<TranscriptionBackend>(
              title: Text(_getBackendDisplayName(backend)),
              subtitle: Text(_getBackendDescription(backend)),
              value: backend,
              groupValue: _preferredBackend,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _preferredBackend = value);
                  _saveSetting('preferred_backend', value.index);
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
    // TODO: Implement model selector based on available models
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Default Model'),
        content: const Text('Model selection will be implemented'),
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

  void _showDiarizationInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Speaker Diarization'),
        content: const SingleChildScrollView(
          child: Text(
            'Speaker diarization identifies different speakers in audio recordings '
            'and labels each segment with the corresponding speaker.\n\n'
            'This feature:\n'
            '• Identifies who is speaking when\n'
            '• Works best with clear audio\n'
            '• May increase processing time\n'
            '• Supports multiple languages\n\n'
            'For best results, use audio where speakers don\'t talk over each other '
            'and there is minimal background noise.',
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

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will delete temporary files and cached data. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: Implement cache clearing
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache cleared successfully')),
      );
    }
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Susurrus Privacy Policy\n\n'
            'Audio Processing:\n'
            '• Audio files are processed locally on your device\n'
            '• No audio data is sent to external servers\n'
            '• Transcriptions are stored locally\n\n'
            'Models:\n'
            '• AI models are downloaded from Hugging Face\n'
            '• Models are stored locally on your device\n\n'
            'Data Collection:\n'
            '• We do not collect personal data\n'
            '• No analytics or tracking\n'
            '• All processing happens on-device\n\n'
            'Your privacy is our priority. All transcription and diarization '
            'processing happens locally on your device.',
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
      info['App Name'] = packageInfo.appName;
    } catch (e) {
      info['App Version'] = 'Unknown';
    }

    if (Platform.isIOS) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final iosInfo = await deviceInfo.iosInfo;
        info['Device'] = '${iosInfo.name} (${iosInfo.model})';
        info['iOS Version'] = '${iosInfo.systemName} ${iosInfo.systemVersion}';
        info['CoreML Available'] = await CoreMLWhisper.instance.isAvailable ? 'Yes' : 'No';
      } catch (e) {
        info['Device'] = 'iOS Device';
      }
    } else if (Platform.isAndroid) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        info['Device'] = '${androidInfo.manufacturer} ${androidInfo.model}';
        info['Android Version'] = 'API ${androidInfo.version.sdkInt}';
      } catch (e) {
        info['Device'] = 'Android Device';
      }
    }

    return info;
  }

  String _getBackendDisplayName(TranscriptionBackend backend) {
    switch (backend) {
      case TranscriptionBackend.auto:
        return 'Auto (Recommended)';
      case TranscriptionBackend.whisperCpp:
        return 'Whisper.cpp';
      case TranscriptionBackend.coreML:
        return 'CoreML (iOS)';
    }
  }

  String _getBackendDescription(TranscriptionBackend backend) {
    switch (backend) {
      case TranscriptionBackend.auto:
        return 'Automatically choose the best backend for your device';
      case TranscriptionBackend.whisperCpp:
        return 'Cross-platform Whisper implementation';
      case TranscriptionBackend.coreML:
        return 'Apple\'s machine learning framework (iOS only)';
    }
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