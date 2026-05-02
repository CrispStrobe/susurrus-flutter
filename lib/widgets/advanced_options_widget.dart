import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../main.dart' show transcriptionServiceProvider;
import '../services/model_service.dart';

/// Per-run state for the "Advanced decoding" block — translate flag,
/// beam-search strategy, initial prompt. Held as a Riverpod state
/// class so the transcribe path in `transcription_screen.dart` reads
/// the same values the user just edited.
class AdvancedOptions {
  final bool translate;
  final bool beamSearch;
  final String initialPrompt;

  /// Skip silent regions via whisper.cpp's built-in Silero VAD pipeline.
  /// The bundled asset at `assets/vad/silero-v6.2.0-ggml.bin` is extracted
  /// on first use; the engine sets `params.vad = true` +
  /// `params.vad_model_path` and whisper internally restricts decoding
  /// to voiced frames.
  final bool vad;

  /// Run FireRedPunc on the engine output to add capitalisation +
  /// punctuation. No-op when no `fireredpunc-*.gguf` is on disk; useful
  /// for CTC backends (wav2vec2 / fastconformer-ctc / firered-asr) whose
  /// raw output is unpunctuated lowercase.
  final bool restorePunctuation;

  /// Target language for translation backends (canary / voxtral /
  /// voxtral4b / qwen3 / cohere). When equal to source (or empty),
  /// the backend transcribes verbatim. When different, it translates
  /// from source → target. Whisper has its own boolean toggle
  /// ([translate]) that always targets English; this field only takes
  /// effect on session backends that advertise translation support.
  final String targetLanguage;

  const AdvancedOptions({
    this.translate = false,
    this.beamSearch = false,
    this.initialPrompt = '',
    this.vad = false,
    this.restorePunctuation = false,
    this.targetLanguage = '',
  });

  AdvancedOptions copyWith({
    bool? translate,
    bool? beamSearch,
    String? initialPrompt,
    bool? vad,
    bool? restorePunctuation,
    String? targetLanguage,
  }) =>
      AdvancedOptions(
        translate: translate ?? this.translate,
        beamSearch: beamSearch ?? this.beamSearch,
        initialPrompt: initialPrompt ?? this.initialPrompt,
        vad: vad ?? this.vad,
        restorePunctuation: restorePunctuation ?? this.restorePunctuation,
        targetLanguage: targetLanguage ?? this.targetLanguage,
      );

  /// Backends that accept a target-language hint different from the
  /// source — i.e. true speech-translation. Used by the UI to show /
  /// hide the target-lang dropdown.
  static const Set<String> translationCapableBackends = {
    'canary', 'cohere', 'voxtral', 'voxtral4b', 'qwen3', 'whisper',
  };
}

final advancedOptionsProvider =
    StateProvider<AdvancedOptions>((_) => const AdvancedOptions());

/// Collapsible block shown inside Advanced Options on the transcription
/// screen. Visible only when the active engine is CrispASR (the only one
/// that can actually use these knobs).
class AdvancedDecodingSection extends ConsumerStatefulWidget {
  const AdvancedDecodingSection({super.key});

  @override
  ConsumerState<AdvancedDecodingSection> createState() =>
      _AdvancedDecodingSectionState();
}

class _AdvancedDecodingSectionState
    extends ConsumerState<AdvancedDecodingSection> {
  bool _expanded = false;
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(advancedOptionsProvider);
    _promptController = TextEditingController(text: initial.initialPrompt);
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final opts = ref.watch(advancedOptionsProvider);

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 0),
      initiallyExpanded: _expanded,
      onExpansionChanged: (v) => setState(() => _expanded = v),
      title: Row(
        children: [
          const Icon(Icons.tune, size: 18),
          const SizedBox(width: 8),
          Text(l.advancedSection,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
      children: [
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(l.advancedVadTrim),
          subtitle: Text(l.advancedVadTrimSubtitle,
              style: const TextStyle(fontSize: 11)),
          value: opts.vad,
          onChanged: (v) => ref.read(advancedOptionsProvider.notifier).state =
              opts.copyWith(vad: v),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(l.advancedTranslate),
          subtitle: Text(l.advancedTranslateSubtitle,
              style: const TextStyle(fontSize: 11)),
          value: opts.translate,
          onChanged: (v) => ref.read(advancedOptionsProvider.notifier).state =
              opts.copyWith(translate: v),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(l.advancedBeamSearch),
          subtitle: Text(l.advancedBeamSearchSubtitle,
              style: const TextStyle(fontSize: 11)),
          value: opts.beamSearch,
          onChanged: (v) => ref.read(advancedOptionsProvider.notifier).state =
              opts.copyWith(beamSearch: v),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(l.advancedRestorePunctuation),
          subtitle: Text(l.advancedRestorePunctuationSubtitle,
              style: const TextStyle(fontSize: 11)),
          value: opts.restorePunctuation,
          onChanged: (v) => ref.read(advancedOptionsProvider.notifier).state =
              opts.copyWith(restorePunctuation: v),
        ),
        // Target-language picker for translation. Only shown when the
        // currently-loaded model's backend advertises true speech
        // translation (canary, voxtral, qwen3, cohere, whisper). The
        // empty default means "no translation — transcribe verbatim".
        _buildTargetLanguageRow(context, opts),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TextField(
            controller: _promptController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l.advancedInitialPrompt,
              hintText: l.advancedInitialPromptHint,
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onChanged: (v) => ref.read(advancedOptionsProvider.notifier).state =
                opts.copyWith(initialPrompt: v),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetLanguageRow(
      BuildContext context, AdvancedOptions opts) {
    final l = AppLocalizations.of(context);
    // Resolve the active backend from the loaded model id. The engine
    // exposes engineId only, so look the model up in the static
    // catalogs — same source of truth the model picker uses. Misses
    // dynamically-discovered HF quants but the backend name is stable
    // across quants of the same family, so this is good enough.
    final svc = ref.read(transcriptionServiceProvider);
    final modelId = svc.currentEngine?.currentModelId;
    String backend = '';
    if (modelId != null) {
      final cached = ModelService.whisperCppModels[modelId] ??
          ModelService.crispasrBackendModels[modelId];
      backend = cached?.backend ?? '';
    }
    if (!AdvancedOptions.translationCapableBackends.contains(backend)) {
      // Hide the dropdown for backends that don't translate. Keeps
      // the panel uncluttered for the wav2vec2 / parakeet / mimo-asr
      // common case.
      return const SizedBox.shrink();
    }
    const langs = <MapEntry<String, String>>[
      MapEntry('', 'No translation (verbatim)'),
      MapEntry('en', 'English'),
      MapEntry('de', 'German'),
      MapEntry('es', 'Spanish'),
      MapEntry('fr', 'French'),
      MapEntry('it', 'Italian'),
      MapEntry('pt', 'Portuguese'),
      MapEntry('zh', 'Chinese'),
      MapEntry('ja', 'Japanese'),
      MapEntry('ko', 'Korean'),
      MapEntry('ru', 'Russian'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: l.advancedTargetLanguage,
          helperText: l.advancedTargetLanguageHelper,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        initialValue: opts.targetLanguage,
        items: [
          for (final e in langs)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) =>
            ref.read(advancedOptionsProvider.notifier).state =
                opts.copyWith(targetLanguage: v ?? ''),
      ),
    );
  }
}
