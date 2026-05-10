import 'package:crispasr/crispasr.dart' as crispasr;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../main.dart' show transcriptionServiceProvider;
import '../services/model_service.dart';
import '../services/vad_service.dart';

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

  /// Explicit source-language override for translation backends.
  /// Empty means "use the global language dropdown / autodetect".
  /// Non-empty overrides `language:` on the engine call so the user
  /// can pin the source while picking a different target — useful
  /// when whisper's autodetect is unreliable on noisy audio.
  final String sourceLanguage;

  /// Best-of-N decoding. 1 = single decode (historical default).
  /// >1 runs N independent decodes and picks the highest-scoring
  /// result. For Whisper this is internal (`wparams.greedy.best_of`);
  /// for every other backend the CrispASR C side loops externally
  /// and picks the highest-mean-confidence result. Useful when
  /// greedy hallucinates a repetition or the audio is noisy.
  /// Cost: N× the per-call decode time.
  final int bestOf;

  // -------------------------------------------------------------------
  // VAD tunables (CrispASR 0.6 parity — exposed via SessionVadOptions
  // and whisper's TranscribeOptions).
  // -------------------------------------------------------------------

  /// Which VAD GGUF to run when [vad] is on. Silero is bundled (always
  /// available); FireRed / MarbleNet / Whisper-VAD-EncDec require an
  /// explicit download via Model Management.
  final VadBackend vadBackend;

  /// Silero VAD decision threshold (0..1). Higher = fewer / shorter
  /// speech regions. CrispASR ships 0.5.
  final double vadThreshold;

  /// Shortest run of voiced frames (ms) kept as a speech segment.
  final int vadMinSpeechMs;

  /// Shortest silence (ms) needed to split one segment from the next.
  final int vadMinSilenceMs;

  /// Extra context padding (ms) added on each side of every segment.
  final int vadSpeechPadMs;

  // -------------------------------------------------------------------
  // Diarisation method (CrispASR 0.4.5+ shared-lib `diarizeSegments`).
  // -------------------------------------------------------------------

  /// Which diarisation algorithm to run when the user enables
  /// diarisation. Defaults to `vadTurns` because it's mono-friendly
  /// and needs no extra model. Pyannote requires the
  /// `pyannote-v3-seg-*.gguf` GGUF to be on disk.
  final crispasr.DiarizeMethod diarizeMethod;

  // -------------------------------------------------------------------
  // LID method (CrispASR 0.4.6+ `crispasr_detect_language_pcm`).
  // -------------------------------------------------------------------

  /// Which LID classifier to run when the user picks Auto-detect on a
  /// session backend that doesn't have native language identification.
  /// Whisper reuses any multilingual ggml-*.bin already downloaded;
  /// Silero needs its own ~16 MB GGUF.
  final crispasr.LidMethod lidMethod;

  // -------------------------------------------------------------------
  // Whisper-only extras.
  // -------------------------------------------------------------------

  /// tinydiarize speaker-turn markers. Requires a whisper `.en.tdrz`
  /// finetune; output contains `[SPEAKER_TURN]` tokens callers can
  /// split segments on.
  final bool tdrz;

  /// Token-level timestamps (DTW-aligned). Adds per-token timing on
  /// top of per-segment timing; pairs well with `maxLen`.
  final bool tokenTimestamps;

  /// Punctuation post-processor preference: `"firered"` for FireRedPunc
  /// (ZH+EN), `"fullstop"` for fullstop-punc (EN/DE/FR/IT). Honoured
  /// by PuncService when both are downloaded.
  final String puncFamily;

  // -------------------------------------------------------------------
  // LID accelerator + threading. CrispASR's `detect_language_pcm`
  // exposes useGpu / flashAttn / nThreads directly; surface them so
  // users on Metal/CUDA can offload the LID encoder pass.
  // -------------------------------------------------------------------

  /// Route LID inference to the GPU when supported.
  final bool lidUseGpu;

  /// Enable flash-attention on the LID encoder.
  final bool lidFlashAttn;

  /// CPU thread count for LID and other helper passes.
  final int nThreads;

  const AdvancedOptions({
    this.translate = false,
    this.beamSearch = false,
    this.initialPrompt = '',
    this.vad = false,
    this.restorePunctuation = false,
    this.targetLanguage = '',
    this.askPrompt = '',
    this.temperature = 0.0,
    this.sourceLanguage = '',
    this.bestOf = 1,
    this.vadBackend = VadBackend.silero,
    this.vadThreshold = 0.5,
    this.vadMinSpeechMs = 250,
    this.vadMinSilenceMs = 100,
    this.vadSpeechPadMs = 30,
    this.diarizeMethod = crispasr.DiarizeMethod.vadTurns,
    this.lidMethod = crispasr.LidMethod.whisper,
    this.tdrz = false,
    this.tokenTimestamps = false,
    this.puncFamily = 'firered',
    this.lidUseGpu = false,
    this.lidFlashAttn = true,
    this.nThreads = 4,
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
    String? sourceLanguage,
    int? bestOf,
    VadBackend? vadBackend,
    double? vadThreshold,
    int? vadMinSpeechMs,
    int? vadMinSilenceMs,
    int? vadSpeechPadMs,
    crispasr.DiarizeMethod? diarizeMethod,
    crispasr.LidMethod? lidMethod,
    bool? tdrz,
    bool? tokenTimestamps,
    String? puncFamily,
    bool? lidUseGpu,
    bool? lidFlashAttn,
    int? nThreads,
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
        sourceLanguage: sourceLanguage ?? this.sourceLanguage,
        bestOf: bestOf ?? this.bestOf,
        vadBackend: vadBackend ?? this.vadBackend,
        vadThreshold: vadThreshold ?? this.vadThreshold,
        vadMinSpeechMs: vadMinSpeechMs ?? this.vadMinSpeechMs,
        vadMinSilenceMs: vadMinSilenceMs ?? this.vadMinSilenceMs,
        vadSpeechPadMs: vadSpeechPadMs ?? this.vadSpeechPadMs,
        diarizeMethod: diarizeMethod ?? this.diarizeMethod,
        lidMethod: lidMethod ?? this.lidMethod,
        tdrz: tdrz ?? this.tdrz,
        tokenTimestamps: tokenTimestamps ?? this.tokenTimestamps,
        puncFamily: puncFamily ?? this.puncFamily,
        lidUseGpu: lidUseGpu ?? this.lidUseGpu,
        lidFlashAttn: lidFlashAttn ?? this.lidFlashAttn,
        nThreads: nThreads ?? this.nThreads,
      );

  /// Backends that accept a target-language hint different from the
  /// source — i.e. true speech-translation. Used by the UI to show /
  /// hide the target-lang dropdown.
  static const Set<String> translationCapableBackends = {
    'canary',
    'cohere',
    'voxtral',
    'voxtral4b',
    'qwen3',
    'whisper',
    // Granite Speech 4.1 family supports speech-translation too.
    'granite',
    'granite-4.1',
    'granite-4.1-plus',
    'granite-4.1-nar',
  };

  /// Backends that accept a free-form Q&A prompt (instruct-tuned
  /// audio-LLM). Used by the UI to show / hide the ask field.
  static const Set<String> askCapableBackends = {
    'voxtral',
    'voxtral4b',
    'qwen3',
    // Granite + GLM-ASR also expose --ask in the CrispASR CLI.
    'granite',
    'granite-4.1',
    'granite-4.1-plus',
    'glm-asr',
  };

  /// Backends that honour `crispasr_session_set_temperature` per the
  /// CrispASR doc comment. Other session backends silently no-op
  /// (rc=-2) but the slider has nothing to offer them, so hide it.
  /// Whisper isn't in the list — it has its own temperature fallback
  /// inside whisper.cpp's TranscribeOptions.
  static const Set<String> temperatureCapableBackends = {
    'canary',
    'cohere',
    'parakeet',
    'moonshine',
    'kyutai-stt',
    // Granite + Voxtral + Qwen3 + GLM-ASR + Gemma4 all expose
    // `--temperature` in the CrispASR CLI.
    'granite',
    'granite-4.1',
    'granite-4.1-plus',
    'voxtral',
    'voxtral4b',
    'qwen3',
    'glm-asr',
    'gemma4-e2b',
    'omniasr-llm',
    'omniasr-llm-unlimited',
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
        // VAD backend + threshold + duration sliders. Only meaningful
        // when VAD is enabled; collapse otherwise.
        if (opts.vad) _buildVadTuneRows(context, opts),
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
        // Best-of-N slider. Works on every backend per CrispASR
        // §60o: Whisper consumes it as `wparams.greedy.best_of`;
        // other backends run N decodes externally and pick the
        // highest-mean-confidence result. Cost is N× per-call
        // decode time, so the slider is always visible but
        // defaults to 1 (single decode).
        _buildBestOfRow(context, opts),
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
        // LID method picker — visible only when the global language
        // dropdown is "auto" + active backend lacks native LID. We
        // can't see those preconditions here, so always show it; the
        // engine ignores it on backends that already auto-detect.
        _buildLidMethodRow(context, opts),
        // Diarisation method picker — only meaningful when diarisation
        // is enabled (separate toggle on the screen above). Show it
        // unconditionally; the screen-level diarize flag gates whether
        // anything happens.
        _buildDiarizationMethodRow(context, opts),
        // Whisper-only tdrz toggle (tinydiarize). Hidden on session
        // backends because the model file format differs.
        _buildTdrzRow(context, opts),
        // Token-level timestamps (whisper DTW). Useful when subtitle
        // tooling consumes per-token timing instead of segments.
        _buildTokenTimestampsRow(context, opts),
        // Punctuation family picker — only visible when "Restore
        // punctuation" is on AND the user has more than one family on
        // disk. Otherwise PuncService auto-picks whatever it finds.
        if (opts.restorePunctuation) _buildPuncFamilyRow(context, opts),
        // Performance — LID accelerator + thread count. Honoured by
        // crispasr_detect_language_pcm directly. ASR-side perf flags
        // need to be set at session-open time and aren't runtime-
        // tunable, so they aren't surfaced here.
        _buildPerfRows(context, opts),
      ],
    );
  }

  Widget _buildPerfRows(BuildContext context, AdvancedOptions opts) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(l.advancedPerfHeader,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(l.advancedLidUseGpu),
          subtitle: Text(l.advancedLidUseGpuSubtitle,
              style: const TextStyle(fontSize: 11)),
          value: opts.lidUseGpu,
          onChanged: (v) => ref.read(advancedOptionsProvider.notifier).state =
              opts.copyWith(lidUseGpu: v),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(l.advancedLidFlashAttn),
          subtitle: Text(l.advancedLidFlashAttnSubtitle,
              style: const TextStyle(fontSize: 11)),
          value: opts.lidFlashAttn,
          onChanged: (v) => ref.read(advancedOptionsProvider.notifier).state =
              opts.copyWith(lidFlashAttn: v),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.advancedNThreads(opts.nThreads),
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              Slider(
                value: opts.nThreads.toDouble(),
                min: 1,
                max: 16,
                divisions: 15,
                label: opts.nThreads.toString(),
                onChanged: (v) =>
                    ref.read(advancedOptionsProvider.notifier).state =
                        opts.copyWith(nThreads: v.round()),
              ),
              Text(l.advancedNThreadsHelper,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVadTuneRows(BuildContext context, AdvancedOptions opts) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: DropdownButtonFormField<VadBackend>(
            decoration: InputDecoration(
              labelText: l.advancedVadBackend,
              helperText: l.advancedVadBackendHelper,
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            initialValue: opts.vadBackend,
            items: [
              DropdownMenuItem(
                  value: VadBackend.silero, child: Text(l.advancedVadBackendSilero)),
              DropdownMenuItem(
                  value: VadBackend.firered,
                  child: Text(l.advancedVadBackendFirered)),
              DropdownMenuItem(
                  value: VadBackend.marblenet,
                  child: Text(l.advancedVadBackendMarblenet)),
              DropdownMenuItem(
                  value: VadBackend.whisperEncDec,
                  child: Text(l.advancedVadBackendWhisperEncDec)),
            ],
            onChanged: (v) {
              if (v == null) return;
              ref.read(advancedOptionsProvider.notifier).state =
                  opts.copyWith(vadBackend: v);
            },
          ),
        ),
        _sliderRow(
          label: l.advancedVadThreshold(opts.vadThreshold.toStringAsFixed(2)),
          value: opts.vadThreshold,
          min: 0.05,
          max: 0.95,
          divisions: 18,
          onChanged: (v) => ref.read(advancedOptionsProvider.notifier).state =
              opts.copyWith(vadThreshold: v),
          helper: l.advancedVadThresholdHelper,
        ),
        _sliderRow(
          label: l.advancedVadMinSpeech(opts.vadMinSpeechMs),
          value: opts.vadMinSpeechMs.toDouble(),
          min: 50,
          max: 2000,
          divisions: 39,
          onChanged: (v) => ref.read(advancedOptionsProvider.notifier).state =
              opts.copyWith(vadMinSpeechMs: v.round()),
          helper: l.advancedVadMinSpeechHelper,
        ),
        _sliderRow(
          label: l.advancedVadMinSilence(opts.vadMinSilenceMs),
          value: opts.vadMinSilenceMs.toDouble(),
          min: 50,
          max: 2000,
          divisions: 39,
          onChanged: (v) => ref.read(advancedOptionsProvider.notifier).state =
              opts.copyWith(vadMinSilenceMs: v.round()),
          helper: l.advancedVadMinSilenceHelper,
        ),
        _sliderRow(
          label: l.advancedVadSpeechPad(opts.vadSpeechPadMs),
          value: opts.vadSpeechPadMs.toDouble(),
          min: 0,
          max: 500,
          divisions: 50,
          onChanged: (v) => ref.read(advancedOptionsProvider.notifier).state =
              opts.copyWith(vadSpeechPadMs: v.round()),
          helper: l.advancedVadSpeechPadHelper,
        ),
      ],
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: value.toStringAsFixed(2),
            onChanged: onChanged,
          ),
          if (helper != null)
            Text(helper,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLidMethodRow(BuildContext context, AdvancedOptions opts) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DropdownButtonFormField<crispasr.LidMethod>(
        decoration: InputDecoration(
          labelText: l.advancedLidMethod,
          helperText: l.advancedLidMethodHelper,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        initialValue: opts.lidMethod,
        items: [
          DropdownMenuItem(
              value: crispasr.LidMethod.whisper,
              child: Text(l.advancedLidMethodWhisper)),
          DropdownMenuItem(
              value: crispasr.LidMethod.silero,
              child: Text(l.advancedLidMethodSilero)),
        ],
        onChanged: (v) {
          if (v == null) return;
          ref.read(advancedOptionsProvider.notifier).state =
              opts.copyWith(lidMethod: v);
        },
      ),
    );
  }

  Widget _buildDiarizationMethodRow(
      BuildContext context, AdvancedOptions opts) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DropdownButtonFormField<crispasr.DiarizeMethod>(
        decoration: InputDecoration(
          labelText: l.advancedDiarizeMethod,
          helperText: l.advancedDiarizeMethodHelper,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        initialValue: opts.diarizeMethod,
        items: [
          DropdownMenuItem(
              value: crispasr.DiarizeMethod.vadTurns,
              child: Text(l.advancedDiarizeVadTurns)),
          DropdownMenuItem(
              value: crispasr.DiarizeMethod.pyannote,
              child: Text(l.advancedDiarizePyannote)),
          DropdownMenuItem(
              value: crispasr.DiarizeMethod.energy,
              child: Text(l.advancedDiarizeEnergy)),
          DropdownMenuItem(
              value: crispasr.DiarizeMethod.xcorr,
              child: Text(l.advancedDiarizeXcorr)),
        ],
        onChanged: (v) {
          if (v == null) return;
          ref.read(advancedOptionsProvider.notifier).state =
              opts.copyWith(diarizeMethod: v);
        },
      ),
    );
  }

  Widget _buildTdrzRow(BuildContext context, AdvancedOptions opts) {
    final l = AppLocalizations.of(context);
    if (_activeBackend() != 'whisper') return const SizedBox.shrink();
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(l.advancedTdrz),
      subtitle: Text(l.advancedTdrzSubtitle,
          style: const TextStyle(fontSize: 11)),
      value: opts.tdrz,
      onChanged: (v) => ref.read(advancedOptionsProvider.notifier).state =
          opts.copyWith(tdrz: v),
    );
  }

  Widget _buildTokenTimestampsRow(
      BuildContext context, AdvancedOptions opts) {
    final l = AppLocalizations.of(context);
    if (_activeBackend() != 'whisper') return const SizedBox.shrink();
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(l.advancedTokenTimestamps),
      subtitle: Text(l.advancedTokenTimestampsSubtitle,
          style: const TextStyle(fontSize: 11)),
      value: opts.tokenTimestamps,
      onChanged: (v) => ref.read(advancedOptionsProvider.notifier).state =
          opts.copyWith(tokenTimestamps: v),
    );
  }

  Widget _buildPuncFamilyRow(BuildContext context, AdvancedOptions opts) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: l.advancedPuncFamily,
          helperText: l.advancedPuncFamilyHelper,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        initialValue: opts.puncFamily,
        items: [
          DropdownMenuItem(
              value: 'firered',
              child: Text(l.advancedPuncFamilyFirered)),
          DropdownMenuItem(
              value: 'fullstop',
              child: Text(l.advancedPuncFamilyFullstop)),
        ],
        onChanged: (v) {
          if (v == null) return;
          ref.read(advancedOptionsProvider.notifier).state =
              opts.copyWith(puncFamily: v);
        },
      ),
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

  Widget _buildBestOfRow(BuildContext context, AdvancedOptions opts) {
    final l = AppLocalizations.of(context);
    final n = opts.bestOf;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            n <= 1 ? l.advancedBestOfSingle : l.advancedBestOfCurrent(n),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Slider(
            value: n.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: n.toString(),
            onChanged: (v) =>
                ref.read(advancedOptionsProvider.notifier).state =
                    opts.copyWith(bestOf: v.round()),
          ),
          Text(l.advancedBestOfHelper,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
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
    if (!AdvancedOptions.translationCapableBackends
        .contains(_activeBackend())) {
      // Hide the dropdowns for backends that don't translate. Keeps
      // the panel uncluttered for the wav2vec2 / parakeet / mimo-asr
      // common case.
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: l.advancedSourceLanguage,
              helperText: l.advancedSourceLanguageHelper,
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            initialValue: opts.sourceLanguage,
            items: [
              for (final e in _sourceLanguageOptions(context))
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) =>
                ref.read(advancedOptionsProvider.notifier).state =
                    opts.copyWith(sourceLanguage: v ?? ''),
          ),
        ),
        Padding(
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
              for (final e in _targetLanguageOptions(context))
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) =>
                ref.read(advancedOptionsProvider.notifier).state =
                    opts.copyWith(targetLanguage: v ?? ''),
          ),
        ),
      ],
    );
  }

  List<MapEntry<String, String>> _sourceLanguageOptions(
      BuildContext context) {
    final l = AppLocalizations.of(context);
    return [
      // Empty string = "use whatever the global language dropdown
      // says / let whisper autodetect". Pinning a source via this
      // override is only useful when autodetect is unreliable.
      MapEntry('', l.advancedSourceLanguageAuto),
      MapEntry('en', l.languageEn),
      MapEntry('de', l.languageDe),
      MapEntry('es', l.languageEs),
      MapEntry('fr', l.languageFr),
      MapEntry('it', l.languageIt),
      MapEntry('pt', l.languagePt),
      MapEntry('zh', l.languageZh),
      MapEntry('ja', l.languageJa),
      MapEntry('ko', l.languageKo),
    ];
  }

  List<MapEntry<String, String>> _targetLanguageOptions(
      BuildContext context) {
    final l = AppLocalizations.of(context);
    return [
      MapEntry('', l.advancedTargetLanguageNone),
      MapEntry('en', l.languageEn),
      MapEntry('de', l.languageDe),
      MapEntry('es', l.languageEs),
      MapEntry('fr', l.languageFr),
      MapEntry('it', l.languageIt),
      MapEntry('pt', l.languagePt),
      MapEntry('zh', l.languageZh),
      MapEntry('ja', l.languageJa),
      MapEntry('ko', l.languageKo),
      MapEntry('ru', l.languageRu),
    ];
  }
}
