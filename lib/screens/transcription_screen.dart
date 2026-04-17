import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/audio_utils.dart';

import '../main.dart';
import '../engines/engine_factory.dart';
import '../engines/transcription_engine.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/log_service.dart';
import '../services/transcription_service.dart';
import '../services/model_service.dart';
import '../services/settings_service.dart';
import '../utils/file_utils.dart';
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
  late bool _enableDiarization;
  late String _language;
  late String _modelName;
  bool _engineReady = false;
  List<ModelInfo> _availableModels = [];
  bool _loadingModels = false;
  // Memoized init future — the first `_ensureEngineReady()` call kicks it
  // off and any subsequent callers await the same future rather than
  // racing a second init through the service. Without this, tapping
  // "Transcribe" while the first-frame post-callback is still running
  // could spawn a parallel init.
  Future<bool>? _initFuture;
  // Drop-target state — true while a compatible file is hovering over
  // the window so we can paint a tinted overlay.
  bool _dropHover = false;

  @override
  void initState() {
    super.initState();

    // Initialize state from settings
    final settings = ref.read(settingsServiceProvider);
    _enableDiarization = settings.enableDiarizationByDefault;
    _language = settings.defaultLanguage;
    _modelName = settings.defaultModel;

    // Kick off engine initialization after the first frame so the error
    // dialog (if it occurs) has a context to attach to.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureEngineReady());
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _ensureEngineReady() async {
    if (_engineReady) return;
    _initFuture ??= _doInitialize();
    try {
      await _initFuture;
    } catch (e) {
      if (mounted) {
        ref.read(appStateProvider.notifier).setError('Engine init failed: $e');
      }
    }
  }

  Future<bool> _doInitialize() async {
    final service = ref.read(transcriptionServiceProvider);
    final settings = ref.read(settingsServiceProvider);
    
    // Load models list
    _loadModels();

    final ok = await service.initialize(
      preferredEngine: settings.preferredEngine,
    );
    if (ok) {
      try {
        await service.loadModel(_modelName);
      } catch (_) {
        // Non-fatal
      }
    }
    if (mounted) setState(() => _engineReady = ok);
    return ok;
  }

  Future<void> _loadModels() async {
    if (_loadingModels) return;
    Log.instance.d('ui', 'Loading models for advanced options...');
    setState(() => _loadingModels = true);
    try {
      final models = await ref.read(modelServiceProvider).getWhisperCppModels();
      Log.instance.d('ui', 'Fetched ${models.length} models');
      if (mounted) {
        setState(() {
          _availableModels = models;
          _loadingModels = false;
        });
      }
    } catch (e, st) {
      Log.instance.e('ui', 'Failed to load models', error: e, stack: st);
      if (mounted) {
        setState(() => _loadingModels = false);
      }
    }
  }

  Future<void> _downloadModel(ModelInfo model) async {
    final modelService = ref.read(modelServiceProvider);
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Starting download: ${model.displayName}')),
      );
      
      final success = await modelService.downloadWhisperCppModel(
        model.name,
        onProgress: (p) {
          // Optional: update UI with progress
        },
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${model.displayName} downloaded')),
        );
        _loadModels(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Download failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.appName),
            Text(
              l.appTagline,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: l.menuHistory,
            onPressed: () => context.push('/history'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l.menuSettings,
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: l.menuModels,
            onPressed: () => context.push('/models'),
          ),
        ],
      ),
      body: DropTarget(
        onDragEntered: (_) => setState(() => _dropHover = true),
        onDragExited: (_) => setState(() => _dropHover = false),
        onDragDone: _onFilesDropped,
        child: Stack(children: [_buildBody(), if (_dropHover) _buildDropOverlay()]),
      ),
    );
  }

  /// Called when the OS hands us one or more files dropped on the window.
  void _onFilesDropped(DropDoneDetails details) {
    setState(() => _dropHover = false);
    if (details.files.isEmpty) return;

    // Prefer the first file whose extension is an audio format we can
    // plausibly decode. If none match, fall back to the first file and
    // let the audio decoder produce a clear error.
    final first = details.files.firstWhere(
      (f) => AudioUtils.isSupportedAudioFile(f.path),
      orElse: () => details.files.first,
    );
    if (!AudioUtils.isSupportedAudioFile(first.path)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unsupported file type: ${first.name}')),
      );
      return;
    }

    setState(() => _selectedFilePath = first.path);
    ref.read(selectedAudioPathProvider.notifier).state = null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded ${first.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Tinted overlay shown while a file is hovering over the window. The
  /// actual drop handling is on the outer DropTarget — this is purely
  /// visual feedback.
  Widget _buildDropOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Drop audio file to transcribe',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final appState = ref.watch(appStateProvider);
    final transcriptionService = ref.watch(transcriptionServiceProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
          // Narrow (mobile/portrait) layouts flow top-to-bottom with a scroll;
          // wide layouts put input/controls on the left and output on the
          // right so the output isn't crushed by a tall input section.
          final wide = constraints.maxWidth >= 900;
          final input = _buildInputSection();
          final controls =
              _buildControlsSection(appState, transcriptionService);
          final output = _buildOutputSection(appState);

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 420,
                  child: Column(
                    children: [
                      Expanded(child: SingleChildScrollView(child: input)),
                      controls,
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: output),
              ],
            );
          }
          return Column(
            children: [
              Expanded(
                flex: 2,
                child: SingleChildScrollView(child: input),
              ),
              controls,
              Expanded(flex: 3, child: output),
            ],
          );
        },
    );
  }

  Widget _buildInputSection() {
    final l = AppLocalizations.of(context);
    final recordedPath = ref.watch(selectedAudioPathProvider);
    final displayPath = _selectedFilePath ?? recordedPath;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  l.audioInput,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                _EngineStatusChip(ready: _engineReady),
              ],
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
                      displayPath?.split('/').last ?? l.noFileSelected,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: Text(l.browse),
                  onPressed: _selectAudioFile,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // URL Input
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: l.urlInputLabel,
                hintText: l.urlInputHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link),
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
              label: Text(l.advancedOptions),
              onPressed: () {
                setState(() {
                  _showAdvancedOptions = !_showAdvancedOptions;
                  if (_showAdvancedOptions) {
                    _loadModels();
                  }
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
    Log.instance.d('ui', '_buildAdvancedOptions: _loadingModels=$_loadingModels, _availableModels.length=${_availableModels.length}');
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
                value: _language,
                onChanged: (value) {
                  if (value != null) setState(() => _language = value);
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Model Selection
        const Text('Model:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_loadingModels && _availableModels.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_availableModels.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Text('No models found'),
                TextButton.icon(
                  onPressed: () {
                    Log.instance.d('ui', 'Retry tapped in advanced options');
                    _loadModels();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          )
        else
          Container(
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _availableModels.length,
              itemBuilder: (context, index) {
                if (index == 0) Log.instance.t('ui', 'ListView.builder building item 0');
                final model = _availableModels[index];
                final isSelected = _modelName == model.name;
                return ListTile(
                  dense: true,
                  selected: isSelected,
                  title: Text(model.displayName, style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  )),
                  subtitle: Text('${model.size} • ${model.backend}'),
                  trailing: _buildModelAction(model),
                  onTap: model.isDownloaded ? () => _selectModel(model.name) : null,
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildModelAction(ModelInfo model) {
    if (model.isDownloaded) {
      return _modelName == model.name
          ? const Icon(Icons.check_circle, color: Colors.green)
          : const Icon(Icons.check, color: Colors.grey);
    }
    return IconButton(
      icon: const Icon(Icons.download, size: 20),
      onPressed: () => _downloadModel(model),
      tooltip: 'Download model',
    );
  }

  Future<void> _selectModel(String value) async {
    if (value == _modelName) return;
    setState(() => _modelName = value);
    try {
      await ref.read(transcriptionServiceProvider).loadModel(value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loaded $value')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Load failed: $e')),
        );
      }
    }
  }

  Widget _buildControlsSection(AppState appState, TranscriptionService transcriptionService) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        spacing: 16,
        runSpacing: 16,
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
            label: Text(appState.isTranscribing ? l.transcribing : l.transcribe),
            onPressed: appState.isTranscribing ? null : _startTranscription,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),

          // Stop Button
          if (appState.isTranscribing)
            ElevatedButton.icon(
              icon: const Icon(Icons.stop),
              label: Text(l.stop),
              onPressed: _stopTranscription,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),

          // Clear Button
          ElevatedButton.icon(
            icon: const Icon(Icons.clear),
            label: Text(l.clear),
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
                    title: Text('Share plain text'),
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'copy',
                  child: ListTile(
                    leading: Icon(Icons.copy),
                    title: Text('Copy to clipboard'),
                    dense: true,
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'save_txt',
                  child: ListTile(
                    leading: Icon(Icons.description),
                    title: Text('Save as TXT'),
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'save_srt',
                  child: ListTile(
                    leading: Icon(Icons.subtitles),
                    title: Text('Save as SRT'),
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'save_vtt',
                  child: ListTile(
                    leading: Icon(Icons.closed_caption),
                    title: Text('Save as VTT'),
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'save_json',
                  child: ListTile(
                    leading: Icon(Icons.data_object),
                    title: Text('Save as JSON'),
                    dense: true,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOutputSection(AppState appState) {
    final l = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Text(
                  l.transcriptionOutput,
                  style: Theme.of(context).textTheme.titleMedium,
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

          // Performance readout (once a run has completed)
          if (!appState.isTranscribing && appState.performance != null)
            _PerformanceCard(stats: appState.performance!),

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
      // Clear any previously-kept recording so the user's most recent
      // explicit pick wins.
      ref.read(selectedAudioPathProvider.notifier).state = null;
    }
  }

  Future<void> _startTranscription() async {
    final transcriptionService = ref.read(transcriptionServiceProvider);
    final appStateNotifier = ref.read(appStateProvider.notifier);
    final recordedPath = ref.read(selectedAudioPathProvider);
    final filePath = _selectedFilePath ?? recordedPath;

    if (filePath == null && _urlController.text.isEmpty) {
      _showErrorDialog('Please select an audio file, enter a URL, or make a recording.');
      return;
    }

    if (!_engineReady) {
      await _ensureEngineReady();
    }

    // Ensure model is loaded (if not already)
    final currentStatus = transcriptionService.getEngineStatus();
    if (currentStatus.currentModelId != _modelName) {
      try {
        await transcriptionService.loadModel(_modelName);
      } catch (e) {
        _showErrorDialog('Failed to load model $_modelName: $e');
        return;
      }
    }

    try {
      appStateNotifier.startTranscription();

      final started = DateTime.now();
      List<TranscriptionSegment> segments = [];
      final language = _language == 'auto' ? null : _language;

      if (filePath != null) {
        segments = await transcriptionService.transcribeFile(
          File(filePath),
          language: language,
          enableDiarization: _enableDiarization,
          onProgress: appStateNotifier.updateProgress,
          onSegment: appStateNotifier.addSegment,
        );
      } else {
        segments = await transcriptionService.transcribeUrl(
          _urlController.text,
          language: language,
          enableDiarization: _enableDiarization,
          onProgress: appStateNotifier.updateProgress,
          onSegment: appStateNotifier.addSegment,
        );
      }

      final engine = transcriptionService.currentEngine;
      final perf = PerformanceStats.fromMetadata(
        transcriptionService.lastResult?.metadata,
        engineId: engine?.engineId,
        modelId: engine?.currentModelId,
      );
      appStateNotifier.completeTranscription(segments, performance: perf);

      // Persist to history.
      try {
        await ref.read(historyServiceProvider).save(
              engineId: engine?.engineId ?? 'unknown',
              segments: segments,
              sourcePath: filePath,
              sourceUrl: filePath == null ? _urlController.text : null,
              modelId: engine?.currentModelId ?? _modelName,
              language: _language,
              diarizationEnabled: _enableDiarization,
              processingTime: DateTime.now().difference(started),
            );
      } catch (e, st) {
        debugPrint('History save failed: $e\n$st');
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
      case 'save_txt':
        _saveAs(appState, TranscriptFormat.txt);
        break;
      case 'save_srt':
        _saveAs(appState, TranscriptFormat.srt);
        break;
      case 'save_vtt':
        _saveAs(appState, TranscriptFormat.vtt);
        break;
      case 'save_json':
        _saveAs(appState, TranscriptFormat.json);
        break;
    }
  }

  Future<void> _saveAs(AppState state, TranscriptFormat format) async {
    try {
      final baseName =
          'transcription-${DateTime.now().millisecondsSinceEpoch}';
      final file = await FileUtils.saveTranscription(
        state.currentTranscription ?? '',
        baseName,
        format: format,
        segments: state.segments,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved ${file.path}')),
      );
      await FileUtils.shareFile(file.path, subject: baseName);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
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

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.stats});
  final PerformanceStats stats;

  @override
  Widget build(BuildContext context) {
    final rtfGood = stats.rtf >= 1.0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: rtfGood ? Colors.green.shade50 : Colors.orange.shade50,
        border: Border.all(
          color: rtfGood ? Colors.green.shade200 : Colors.orange.shade200,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: 12,
          color: rtfGood ? Colors.green.shade900 : Colors.orange.shade900,
        ),
        child: Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            _metric('RTF', '${stats.rtf.toStringAsFixed(2)}×',
                rtfGood ? 'faster than real-time' : 'slower than real-time'),
            _metric('Audio', '${stats.audioSeconds.toStringAsFixed(1)} s'),
            _metric('Wall', '${stats.wallSeconds.toStringAsFixed(2)} s'),
            _metric('Words', '${stats.wordCount}'),
            _metric('WPS', stats.wordsPerSecond.toStringAsFixed(1)),
            if (stats.engineId != null) _metric('Engine', stats.engineId!),
            if (stats.modelId != null) _metric('Model', stats.modelId!),
          ],
        ),
      ),
    );
  }

  Widget _metric(String key, String value, [String? hint]) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$key: ',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(value),
        if (hint != null)
          Text(' ($hint)',
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 11)),
      ],
    );
  }
}

class _EngineStatusChip extends StatelessWidget {
  const _EngineStatusChip({required this.ready});
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Chip(
      visualDensity: VisualDensity.compact,
      backgroundColor:
          ready ? Colors.green.shade100 : Colors.orange.shade100,
      label: Text(
        ready ? l.engineReady : l.engineStarting,
        style: TextStyle(
          fontSize: 11,
          color: ready ? Colors.green.shade900 : Colors.orange.shade900,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}