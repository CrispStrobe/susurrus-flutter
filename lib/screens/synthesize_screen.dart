import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../l10n/generated/app_localizations.dart';
import '../main.dart' show modelServiceProvider;
import '../services/log_service.dart';
import '../services/model_service.dart';
import '../services/tts_service.dart';

/// Text → speech, using whichever CrispASR TTS backend the user has
/// downloaded. Mirrors the structure of the Transcribe screen but
/// streamlined: there's no language picker (the TTS backend infers from
/// text + voicepack), no diarisation, no advanced decoding knobs.
class SynthesizeScreen extends ConsumerStatefulWidget {
  const SynthesizeScreen({super.key});

  @override
  ConsumerState<SynthesizeScreen> createState() => _SynthesizeScreenState();
}

class _SynthesizeScreenState extends ConsumerState<SynthesizeScreen> {
  final _textController = TextEditingController();
  final _player = AudioPlayer();

  List<ModelInfo> _all = const [];
  bool _loading = true;
  bool _busy = false;

  String? _selectedModel;
  String? _selectedVoice;
  String? _selectedCodec;
  File? _lastWav;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _textController.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final svc = ref.read(modelServiceProvider);
      // Probe the C-side registry so any TTS backend the bundled
      // libcrispasr knows about shows up here without a code change.
      svc.refreshFromCrispasrRegistry();
      _all = await svc.getWhisperCppModels();
      // Auto-select the first downloaded TTS model + matching voice/codec.
      final ttsDownloaded =
          _all.where((m) => m.kind == ModelKind.tts && m.isDownloaded).toList();
      if (ttsDownloaded.isNotEmpty) {
        _selectedModel ??= ttsDownloaded.first.name;
        _autoSelectCompanions();
      }
    } catch (e, st) {
      Log.instance
          .w('synth', 'failed to refresh model list', error: e, stack: st);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Pick the first downloaded voicepack / codec whose backend matches
  /// the selected TTS model. Cheap heuristic — keeps the UX one click
  /// when the user has only one of each.
  void _autoSelectCompanions() {
    final modelDef =
        ref.read(modelServiceProvider).lookupDefinition(_selectedModel ?? '');
    if (modelDef == null) return;
    final voices = _all.where((m) =>
        m.kind == ModelKind.voice &&
        m.backend == modelDef.backend &&
        m.isDownloaded);
    final codecs = _all.where((m) =>
        m.kind == ModelKind.codec &&
        m.backend == modelDef.backend &&
        m.isDownloaded);
    _selectedVoice = voices.isEmpty ? null : voices.first.name;
    _selectedCodec = codecs.isEmpty ? null : codecs.first.name;
  }

  Future<void> _synthesize() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _selectedModel == null) return;
    setState(() {
      _busy = true;
      _lastWav = null;
    });
    final tts = ref.read(ttsServiceProvider);
    try {
      final status = await tts.prepare(
        modelName: _selectedModel!,
        voiceName: _selectedVoice,
        codecName: _selectedCodec,
      );
      if (!status.ready) {
        if (!mounted) return;
        final l = AppLocalizations.of(context);
        final missing = status.missingModelName ??
            status.missingVoiceName ??
            status.missingCodecName ??
            (status.errorMessage ?? '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.synthMissingDependency(missing))),
        );
        return;
      }

      final audio = await tts.synthesize(text);
      if (audio == null) return;
      final wav = await tts.writeWav(audio);
      _lastWav = wav;

      // Auto-play once synthesised so the user gets immediate feedback.
      try {
        await _player.setFilePath(wav.path);
        await _player.play();
      } catch (e, st) {
        Log.instance.w('synth', 'auto-play failed', error: e, stack: st);
      }
    } catch (e, st) {
      Log.instance.e('synth', 'synthesize failed', error: e, stack: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Synthesize failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareWav() async {
    final wav = _lastWav;
    if (wav == null) return;
    try {
      await SharePlus.instance.share(ShareParams(
        files: [XFile(wav.path)],
        subject: 'CrisperWeaver synth',
      ));
    } catch (e, st) {
      Log.instance.w('synth', 'share failed', error: e, stack: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ttsModels =
        _all.where((m) => m.kind == ModelKind.tts).toList(growable: false);
    final downloadedTtsModels =
        ttsModels.where((m) => m.isDownloaded).toList(growable: false);

    final modelDef = _selectedModel == null
        ? null
        : ref.read(modelServiceProvider).lookupDefinition(_selectedModel!);
    final voices = _all
        .where(
            (m) => m.kind == ModelKind.voice && m.backend == modelDef?.backend)
        .toList(growable: false);
    final codecs = _all
        .where(
            (m) => m.kind == ModelKind.codec && m.backend == modelDef?.backend)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(l.synthTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (downloadedTtsModels.isEmpty)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(l.synthNoTtsModelsDownloaded),
                      ),
                    )
                  else ...[
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: l.synthModelLabel),
                      initialValue: _selectedModel,
                      items: downloadedTtsModels
                          .map((m) => DropdownMenuItem(
                                value: m.name,
                                child: Text(m.displayName,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _selectedModel = v;
                        _autoSelectCompanions();
                      }),
                    ),
                    if (voices.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration:
                            InputDecoration(labelText: l.synthVoiceLabel),
                        initialValue: _selectedVoice,
                        items: voices
                            .map((m) => DropdownMenuItem(
                                  value: m.name,
                                  child: Text(
                                    '${m.displayName}'
                                    '${m.isDownloaded ? "" : "  (not downloaded)"}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedVoice = v),
                      ),
                    ],
                    if (codecs.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration:
                            InputDecoration(labelText: l.synthCodecLabel),
                        initialValue: _selectedCodec,
                        items: codecs
                            .map((m) => DropdownMenuItem(
                                  value: m.name,
                                  child: Text(
                                    '${m.displayName}'
                                    '${m.isDownloaded ? "" : "  (not downloaded)"}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedCodec = v),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _textController,
                    minLines: 4,
                    maxLines: 8,
                    decoration: InputDecoration(
                      hintText: l.synthTextHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ||
                                  _selectedModel == null ||
                                  downloadedTtsModels.isEmpty
                              ? null
                              : _synthesize,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.graphic_eq),
                          label: Text(l.synthRunButton),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _lastWav == null ? null : _shareWav,
                        icon: const Icon(Icons.ios_share),
                        label: Text(l.synthShareButton),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_lastWav != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.audiotrack),
                        title: Text(p.basename(_lastWav!.path)),
                        subtitle: StreamBuilder<Duration?>(
                          stream: _player.durationStream,
                          builder: (_, snap) => Text(snap.data == null
                              ? '—'
                              : '${snap.data!.inMilliseconds / 1000.0} s'),
                        ),
                        trailing: StreamBuilder<PlayerState>(
                          stream: _player.playerStateStream,
                          builder: (_, snap) {
                            final playing = snap.data?.playing ?? false;
                            return IconButton(
                              icon: Icon(
                                  playing ? Icons.pause : Icons.play_arrow),
                              onPressed: () async {
                                if (playing) {
                                  await _player.pause();
                                } else {
                                  await _player.seek(Duration.zero);
                                  await _player.play();
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
