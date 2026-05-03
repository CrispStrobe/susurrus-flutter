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

  /// Audio Q&A prompt for instruct-tuned audio-LLM backends (voxtral
  /// / voxtral4b / qwen3). When non-empty, the backend ANSWERS the
  /// prompt instead of producing a verbatim transcript ("Summarize",
  /// "What's the speaker's tone?", "What did they say about X?").
  /// Empty means "transcribe normally" — the historical default.
  final String askPrompt;

  /// Decoder temperature for sampling backends (canary, cohere,
  /// parakeet, moonshine — per CrispASR's `setTemperature` contract).
  /// 0.0 = greedy (the historical default; reproducible). > 0.0 =
  /// stochastic sampling, useful when the greedy decode is stuck on a
  /// hallucinated repetition or when paraphrasing is desired. Whisper
  /// has its own temperature fallback ladder inside whisper.cpp; this
  /// field doesn't reach Whisper. Backends that don't support runtime
  /// temperature silently no-op (the C ABI returns rc=-2).
  final double temperature;

  const AdvancedOptions({
    this.translate = false,
    this.beamSearch = false,
    this.initialPrompt = '',
    this.vad = false,
    this.restorePunctuation = false,
    this.targetLanguage = '',
    this.askPrompt = '',
    this.temperature = 0.0,
  });

  AdvancedOptions copyWith({
    bool? translate,
    bool? beamSearch,
    String? initialPrompt,
    bool? vad,
    bool? restorePunctuation,
    String? targetLanguage,
    String? askPrompt,
    double? temperature,
  }) =>
      AdvancedOptions(
        translate: translate ?? this.translate,
        beamSearch: beamSearch ?? this.beamSearch,
        initialPrompt: initialPrompt ?? this.initialPrompt,
        vad: vad ?? this.vad,
        restorePunctuation: restorePunctuation ?? this.restorePunctuation,
        targetLanguage: targetLanguage ?? this.targetLanguage,
        askPrompt: askPrompt ?? this.askPrompt,
        temperature: temperature ?? this.temperature,
      );

  /// Backends that accept a target-language hint different from the
  /// source — i.e. true speech-translation. Used by the UI to show /
  /// hide the target-lang dropdown.
  static const Set<String> translationCapableBackends = {
    'canary', 'cohere', 'voxtral', 'voxtral4b', 'qwen3', 'whisper',
  };

  /// Backends that accept a free-form Q&A prompt (instruct-tuned
  /// audio-LLM). Used by the UI to show / hide the ask field.
  static const Set<String> askCapableBackends = {
    'voxtral', 'voxtral4b', 'qwen3',
  };

  /// Backends that honour `crispasr_session_set_temperature` per the
  /// CrispASR doc comment. Other session backends silently no-op
  /// (rc=-2) but the slider has nothing to offer them, so hide it.
  /// Whisper isn't in the list — it has its own temperature fallback
  /// inside whisper.cpp's TranscribeOptions.
  static const Set<String> temperatureCapableBackends = {
    'canary', 'cohere', 'parakeet', 'moonshine',
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
  late final TextEditingController _askController;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(advancedOptionsProvider);
    _promptController = TextEditingController(text: initial.initialPrompt);
    _askController = TextEditingController(text: initial.askPrompt);
  }

  @override
  void dispose() {
    _promptController.dispose();
    _askController.dispose();
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
        // Decoder temperature slider. Hidden on backends that don't
        // honour `setTemperature` (whisper, mimo-asr, wav2vec2, …) so
        // the panel stays uncluttered for the common case.
        _buildTemperatureRow(context, opts),
        // Target-language picker for translation. Only shown when the
        // currently-loaded model's backend advertises true speech
        // translation (canary, voxtral, qwen3, cohere, whisper). The
        // empty default means "no translation — transcribe verbatim".
        _buildTargetLanguageRow(context, opts),
        // Audio Q&A prompt. Only shown when the currently-loaded
        // model's backend is an instruct-tuned audio-LLM (voxtral,
        // voxtral4b, qwen3-asr). Non-empty answer-mode replaces the
        // verbatim transcription with the LLM's response to the prompt.
        _buildAskRow(context, opts),
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

  String _activeBackend() {
    final svc = ref.read(transcriptionServiceProvider);
    final modelId = svc.currentEngine?.currentModelId;
    if (modelId == null) return '';
    final cached = ModelService.whisperCppModels[modelId] ??
        ModelService.crispasrBackendModels[modelId];
    return cached?.backend ?? '';
  }

  Widget _buildTemperatureRow(BuildContext context, AdvancedOptions opts) {
    final l = AppLocalizations.of(context);
    if (!AdvancedOptions.temperatureCapableBackends
        .contains(_activeBackend())) {
      return const SizedBox.shrink();
    }
    final t = opts.temperature;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t == 0.0
                ? l.advancedTemperatureGreedy
                : l.advancedTemperatureCurrent(t.toStringAsFixed(2)),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Slider(
            value: t,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            label: t.toStringAsFixed(2),
            onChanged: (v) =>
                ref.read(advancedOptionsProvider.notifier).state =
                    opts.copyWith(temperature: v),
          ),
          Text(l.advancedTemperatureHelper,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildAskRow(BuildContext context, AdvancedOptions opts) {
    final l = AppLocalizations.of(context);
    if (!AdvancedOptions.askCapableBackends.contains(_activeBackend())) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: _askController,
        maxLines: 2,
        decoration: InputDecoration(
          labelText: l.advancedAskPrompt,
          hintText: l.advancedAskPromptHint,
          helperText: l.advancedAskPromptHelper,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        onChanged: (v) => ref.read(advancedOptionsProvider.notifier).state =
            opts.copyWith(askPrompt: v),
      ),
    );
  }

  Widget _buildTargetLanguageRow(
      BuildContext context, AdvancedOptions opts) {
    final l = AppLocalizations.of(context);
    if (!AdvancedOptions.translationCapableBackends.contains(_activeBackend())) {
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
