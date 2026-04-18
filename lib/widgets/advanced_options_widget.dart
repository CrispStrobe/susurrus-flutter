import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';

/// Per-run state for the "Advanced decoding" block — translate flag,
/// beam-search strategy, initial prompt. Held as a Riverpod state
/// class so the transcribe path in `transcription_screen.dart` reads
/// the same values the user just edited.
class AdvancedOptions {
  final bool translate;
  final bool beamSearch;
  final String initialPrompt;

  const AdvancedOptions({
    this.translate = false,
    this.beamSearch = false,
    this.initialPrompt = '',
  });

  AdvancedOptions copyWith({
    bool? translate,
    bool? beamSearch,
    String? initialPrompt,
  }) =>
      AdvancedOptions(
        translate: translate ?? this.translate,
        beamSearch: beamSearch ?? this.beamSearch,
        initialPrompt: initialPrompt ?? this.initialPrompt,
      );
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
          title: Text(l.advancedTranslate),
          subtitle: Text(l.advancedTranslateSubtitle,
              style: const TextStyle(fontSize: 11)),
          value: opts.translate,
          onChanged: (v) => ref
              .read(advancedOptionsProvider.notifier)
              .state = opts.copyWith(translate: v),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(l.advancedBeamSearch),
          subtitle: Text(l.advancedBeamSearchSubtitle,
              style: const TextStyle(fontSize: 11)),
          value: opts.beamSearch,
          onChanged: (v) => ref
              .read(advancedOptionsProvider.notifier)
              .state = opts.copyWith(beamSearch: v),
        ),
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
            onChanged: (v) => ref
                .read(advancedOptionsProvider.notifier)
                .state = opts.copyWith(initialPrompt: v),
          ),
        ),
      ],
    );
  }
}
