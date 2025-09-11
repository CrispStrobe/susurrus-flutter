import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import '../services/transcription_service.dart';
import '../widgets/audio_recorder_widget.dart';
import '../widgets/transcription_output_widget.dart';
import '../widgets/diarization_settings_widget.dart';

class TranscriptionScreen extends ConsumerStatefulWidget {
  const TranscriptionScreen({super.key});

  @override
  ConsumerState<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends ConsumerState<TranscriptionScreen> {
  final TextEditingController _urlController = TextEditingController();
  String? _selectedFilePath;
  bool _showAdvancedOptions = false;
  bool _enableDiarization = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final transcriptionService = ref.watch(transcriptionServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Susurrus'),
        subtitle: const Text('Audio Transcription with Speaker Diarization'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => context.push('/models'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Input Section
          Expanded(
            flex: 2,
            child: _buildInputSection(),
          ),

          // Controls Section
          _buildControlsSection(appState, transcriptionService),

          // Output Section
          Expanded(
            flex: 3,
            child: _buildOutputSection(appState),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audio Input',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            // File Selection
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _selectedFilePath?.split('/').last ?? 'No file selected',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Browse'),
                  onPressed: _selectAudioFile,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // URL Input
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Or enter audio URL',
                hintText: 'https://example.com/audio.mp3',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),

            const SizedBox(height: 16),

            // Audio Recorder
            const AudioRecorderWidget(),

            const SizedBox(height: 16),

            // Advanced Options Toggle
            TextButton.icon(
              icon: Icon(_showAdvancedOptions
                ? Icons.expand_less
                : Icons.expand_more
              ),
              label: const Text('Advanced Options'),
              onPressed: () {
                setState(() {
                  _showAdvancedOptions = !_showAdvancedOptions;
                });
              },
            ),

            if (_showAdvancedOptions) ...[
              const SizedBox(height: 16),
              _buildAdvancedOptions(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Speaker Diarization
        DiarizationSettingsWidget(
          enabled: _enableDiarization,
          onChanged: (enabled) {
            setState(() {
              _enableDiarization = enabled;
            });
          },
        ),

        const SizedBox(height: 16),

        // Language Selection
        Row(
          children: [
            const Text('Language: '),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'auto', child: Text('Auto-detect')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'es', child: Text('Spanish')),
                  DropdownMenuItem(value: 'fr', child: Text('French')),
                  DropdownMenuItem(value: 'de', child: Text('German')),
                  DropdownMenuItem(value: 'it', child: Text('Italian')),
                  DropdownMenuItem(value: 'pt', child: Text('Portuguese')),
                  DropdownMenuItem(value: 'zh', child: Text('Chinese')),
                  DropdownMenuItem(value: 'ja', child: Text('Japanese')),
                  DropdownMenuItem(value: 'ko', child: Text('Korean')),
                ],
                value: 'auto',
                onChanged: (value) {},
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Model Selection
        Row(
          children: [
            const Text('Model: '),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'tiny', child: Text('Tiny (fast, less accurate)')),
                  DropdownMenuItem(value: 'base', child: Text('Base (balanced)')),
                  DropdownMenuItem(value: 'small', child: Text('Small (good quality)')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium (high quality)')),
                  DropdownMenuItem(value: 'large', child: Text('Large (best quality)')),
                ],
                value: 'base',
                onChanged: (value) {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControlsSection(AppState appState, TranscriptionService transcriptionService) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Transcribe Button
          ElevatedButton.icon(
            icon: appState.isTranscribing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow),
            label: Text(appState.isTranscribing ? 'Transcribing...' : 'Transcribe'),
            onPressed: appState.isTranscribing ? null : _startTranscription,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),

          // Stop Button
          if (appState.isTranscribing)
            ElevatedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
              onPressed: _stopTranscription,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),

          // Clear Button
          ElevatedButton.icon(
            icon: const Icon(Icons.clear),
            label: const Text('Clear'),
            onPressed: appState.segments.isNotEmpty ? _clearTranscription : null,
          ),

          // Save/Share Button
          if (appState.currentTranscription != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.share),
              onSelected: (action) => _handleShareAction(action, appState),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.share),
                    title: Text('Share'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'copy',
                  child: ListTile(
                    leading: Icon(Icons.copy),
                    title: Text('Copy to Clipboard'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'save',
                  child: ListTile(
                    leading: Icon(Icons.save),
                    title: Text('Save to File'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOutputSection(AppState appState) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Transcription Output',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                if (appState.isTranscribing)
                  Text(
                    '${(appState.progress * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),

          // Progress Bar
          if (appState.isTranscribing)
            LinearProgressIndicator(value: appState.progress),

          // Error Message
          if (appState.errorMessage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Text(
                appState.errorMessage!,
                style: TextStyle(color: Colors.red.shade800),
              ),
            ),

          // Transcription Output
          Expanded(
            child: TranscriptionOutputWidget(
              segments: appState.segments,
              currentTranscription: appState.currentTranscription,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFilePath = result.files.first.path;
      });
    }
  }

  Future<void> _startTranscription() async {
    final transcriptionService = ref.read(transcriptionServiceProvider);
    final appStateNotifier = ref.read(appStateProvider.notifier);

    // Validate input
    if (_selectedFilePath == null && _urlController.text.isEmpty) {
      _showErrorDialog('Please select an audio file or enter a URL');
      return;
    }

    try {
      appStateNotifier.startTranscription();

      if (_selectedFilePath != null) {
        await transcriptionService.transcribeFile(
          File(_selectedFilePath!),
          enableDiarization: _enableDiarization,
          onProgress: (progress) {
            appStateNotifier.updateProgress(progress);
          },
          onSegment: (segment) {
            appStateNotifier.addSegment(segment);
          },
        );
      } else if (_urlController.text.isNotEmpty) {
        await transcriptionService.transcribeUrl(
          _urlController.text,
          enableDiarization: _enableDiarization,
          onProgress: (progress) {
            appStateNotifier.updateProgress(progress);
          },
          onSegment: (segment) {
            appStateNotifier.addSegment(segment);
          },
        );
      }
    } catch (e) {
      appStateNotifier.setError(e.toString());
    }
  }

  void _stopTranscription() {
    final transcriptionService = ref.read(transcriptionServiceProvider);
    transcriptionService.stopTranscription();

    final appStateNotifier = ref.read(appStateProvider.notifier);
    appStateNotifier.setError('Transcription stopped by user');
  }

  void _clearTranscription() {
    final appStateNotifier = ref.read(appStateProvider.notifier);
    appStateNotifier.clearTranscription();
  }

  void _handleShareAction(String action, AppState appState) {
    switch (action) {
      case 'share':
        Share.share(appState.currentTranscription!);
        break;
      case 'copy':
        Clipboard.setData(ClipboardData(text: appState.currentTranscription!));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied to clipboard')),
        );
        break;
      case 'save':
        // TODO: Implement file save functionality
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save functionality coming soon')),
        );
        break;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}