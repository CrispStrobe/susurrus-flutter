import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../engines/transcription_engine.dart'; // Use engine TranscriptionSegment
import '../l10n/generated/app_localizations.dart';
import '../main.dart' show appStateProvider, selectedAudioPathProvider;

class TranscriptionOutputWidget extends ConsumerStatefulWidget {
  final List<TranscriptionSegment> segments;
  final String? currentTranscription;

  const TranscriptionOutputWidget({
    super.key,
    required this.segments,
    this.currentTranscription,
  });

  @override
  ConsumerState<TranscriptionOutputWidget> createState() =>
      _TranscriptionOutputWidgetState();
}

class _TranscriptionOutputWidgetState
    extends ConsumerState<TranscriptionOutputWidget>
    with TickerProviderStateMixin {
  bool _showTimestamps = true;
  bool _showSpeakers = true;
  bool _showConfidence = false;
  String _searchQuery = '';

  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Karaoke playback state. The player is created lazily on the first
  // _playSegment call so unused transcripts don't allocate one. Active
  // position drives the highlighted-word render via positionStream;
  // _karaokePlaying is true while we're actively syncing UI.
  AudioPlayer? _player;
  StreamSubscription<Duration>? _posSub;
  Duration _karaokePos = Duration.zero;
  bool _karaokePlaying = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _posSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Controls
        _buildControls(),

        // Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSegmentView(),
              _buildFullTextView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Text-only tabs to keep the output chrome compact — icons + text
          // tabs pushed the header past ~130px and overflowed short windows.
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Segments'),
              Tab(text: 'Full Text'),
            ],
          ),

          const SizedBox(height: 4),

          // Search and options
          Row(
            children: [
              // Search field
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).searchTranscription,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    border: const OutlineInputBorder(),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),

              const SizedBox(width: 8),

              // Options menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: _handleOption,
                itemBuilder: (context) => [
                  CheckedPopupMenuItem(
                    value: 'timestamps',
                    checked: _showTimestamps,
                    child:
                        Text(AppLocalizations.of(context).outputShowTimestamps),
                  ),
                  CheckedPopupMenuItem(
                    value: 'speakers',
                    checked: _showSpeakers,
                    child:
                        Text(AppLocalizations.of(context).outputShowSpeakers),
                  ),
                  CheckedPopupMenuItem(
                    value: 'confidence',
                    checked: _showConfidence,
                    child:
                        Text(AppLocalizations.of(context).outputShowConfidence),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'copy_all',
                    child: ListTile(
                      leading: const Icon(Icons.copy),
                      title: Text(AppLocalizations.of(context).outputCopyAll),
                      dense: true,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                      leading: const Icon(Icons.download),
                      title: Text(AppLocalizations.of(context).outputExport),
                      dense: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentView() {
    if (widget.segments.isEmpty) {
      return _buildEmptyState();
    }

    final filteredSegments = _searchQuery.isEmpty
        ? widget.segments
        : widget.segments
            .where(
                (segment) => segment.text.toLowerCase().contains(_searchQuery))
            .toList();

    if (filteredSegments.isEmpty) {
      return _buildNoSearchResults();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: filteredSegments.length,
      itemBuilder: (context, index) {
        final segment = filteredSegments[index];
        return _buildSegmentCard(segment, index);
      },
    );
  }

  Widget _buildSegmentCard(TranscriptionSegment segment, int index) {
    final hasSearch = _searchQuery.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _playSegment(segment),
        onLongPress: () => _showSegmentOptions(segment),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with timestamp and speaker
              Row(
                children: [
                  if (_showTimestamps) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        segment.formattedTime,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade800,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  if (_showSpeakers && segment.speaker != null) ...[
                    _buildSpeakerChip(segment.speaker!),
                    const SizedBox(width: 8),
                  ],

                  const Spacer(),

                  // Tiny pencil icon to flag manually-edited segments.
                  // Set in metadata by AppStateNotifier.editSegment.
                  if (segment.metadata['edited'] == true) ...[
                    const Tooltip(
                      message: 'Edited',
                      child: Icon(Icons.edit, size: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 6),
                  ],

                  if (_showConfidence) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getConfidenceColor(segment.confidence),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(segment.confidence * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],

                  // Options menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz, size: 16),
                    onSelected: (action) =>
                        _handleSegmentAction(action, segment),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'play',
                        child: ListTile(
                          leading: const Icon(Icons.play_arrow, size: 16),
                          title: Text(AppLocalizations.of(context).outputPlay),
                          dense: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'copy',
                        child: ListTile(
                          leading: const Icon(Icons.copy, size: 16),
                          title: Text(AppLocalizations.of(context).outputCopy),
                          dense: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: const Icon(Icons.edit, size: 16),
                          title: Text(AppLocalizations.of(context).outputEdit),
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Transcription text. Render priority:
              //   1. Search highlight (yellow background on matches)
              //   2. Karaoke active-word highlight (during playback)
              //   3. Per-word confidence tint
              //   4. Plain SelectableText
              if (hasSearch)
                _buildHighlightedText(segment.text, _searchQuery)
              else if (_karaokePlaying && _karaokeActiveSegment(segment))
                _buildKaraokeText(segment)
              else if (_showConfidence &&
                  segment.words != null &&
                  segment.words!.isNotEmpty)
                _buildConfidenceTintedText(segment)
              else
                SelectableText(
                  segment.text,
                  style: const TextStyle(fontSize: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return SelectableText(text, style: const TextStyle(fontSize: 16));
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    int start = 0;
    int index = lowerText.indexOf(lowerQuery);

    while (index != -1) {
      // Add text before match
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: const TextStyle(
          backgroundColor: Colors.yellow,
          fontWeight: FontWeight.bold,
        ),
      ));

      start = index + query.length;
      index = lowerText.indexOf(lowerQuery, start);
    }

    // Add remaining text
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: const TextStyle(fontSize: 16),
    );
  }

  /// Render `segment.text` with per-word foreground tint based on each
  /// word's `confidence` score. Whisper emits real per-token
  /// probabilities; session backends currently report `1.0` (uniform
  /// green) until the C-ABI extension lands. The original spacing
  /// between words is preserved verbatim — we walk the segment text
  /// linearly and only colour ranges that match a known word.
  /// True when karaoke playback's current position falls inside this
  /// segment's `[startTime, endTime]` range. Used to render the
  /// active-word highlight only on the currently-playing segment so
  /// scrollback doesn't get noisy.
  bool _karaokeActiveSegment(TranscriptionSegment segment) {
    final t = _karaokePos.inMilliseconds / 1000.0;
    return t >= segment.startTime && t <= segment.endTime + 0.1;
  }

  /// Karaoke render: same per-word span layout as confidence-tint, but
  /// the colour scheme is "currently spoken word = filled badge,
  /// already-spoken = subtle grey, upcoming = full opacity". Falls
  /// back to plain text when the segment has no word-level data.
  Widget _buildKaraokeText(TranscriptionSegment segment) {
    final words = segment.words;
    if (words == null || words.isEmpty) {
      // No per-word data — show segment-level highlight so user still
      // sees something during playback.
      return SelectableText(
        segment.text,
        style: TextStyle(
          fontSize: 16,
          backgroundColor: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.15),
        ),
      );
    }
    final tSec = _karaokePos.inMilliseconds / 1000.0;
    final text = segment.text;
    final spans = <TextSpan>[];
    var cursor = 0;
    final accent = Theme.of(context).colorScheme.primary;
    for (final w in words) {
      final hit = text.indexOf(w.word, cursor);
      if (hit < 0) {
        return SelectableText(text, style: const TextStyle(fontSize: 16));
      }
      if (hit > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, hit)));
      }
      final isActive = tSec >= w.startTime && tSec <= w.endTime + 0.05;
      final isPast = tSec > w.endTime;
      spans.add(TextSpan(
        text: w.word,
        style: TextStyle(
          color: isActive
              ? Colors.white
              : (isPast ? Colors.grey : null),
          backgroundColor:
              isActive ? accent : null,
          fontWeight: isActive ? FontWeight.bold : null,
        ),
      ));
      cursor = hit + w.word.length;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return SelectableText.rich(
      TextSpan(children: spans),
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget _buildConfidenceTintedText(TranscriptionSegment segment) {
    final text = segment.text;
    final words = segment.words!;
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final w in words) {
      // Find the next occurrence of this word's text starting at cursor.
      // Tolerates leading punctuation / whitespace that the model
      // attached to the segment text but not the word entry.
      final hit = text.indexOf(w.word, cursor);
      if (hit < 0) {
        // Word doesn't line up with the segment text — bail to plain
        // rendering rather than show garbled colours.
        return SelectableText(text, style: const TextStyle(fontSize: 16));
      }
      if (hit > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, hit)));
      }
      spans.add(TextSpan(
        text: w.word,
        style: TextStyle(
          color: _getConfidenceColor(w.confidence),
          // Underline very-low-confidence words on top of the colour
          // shift — colour alone is insufficient for users with red /
          // green deficiency.
          decoration: w.confidence < 0.5
              ? TextDecoration.underline
              : TextDecoration.none,
        ),
      ));
      cursor = hit + w.word.length;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return SelectableText.rich(
      TextSpan(children: spans),
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget _buildFullTextView() {
    if (widget.currentTranscription == null ||
        widget.currentTranscription!.isEmpty) {
      return _buildEmptyState();
    }

    final text = widget.currentTranscription!;
    final hasSearch = _searchQuery.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: hasSearch
            ? _buildHighlightedText(text, _searchQuery)
            : SelectableText(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.transcribe,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No transcription yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select an audio file and start transcription',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
          ),
        ],
      ),
    );
  }

  Color _getSpeakerColor(String speaker) {
    // Generate consistent colors for speakers
    final colors = [
      Colors.blue.shade600,
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.red.shade600,
      Colors.teal.shade600,
    ];

    final hash = speaker.hashCode;
    return colors[hash.abs() % colors.length];
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }

  /// Speaker chip with rename-on-tap. Display label looks up the user's
  /// custom name in `appState.speakerNames`; falls back to the
  /// diariser's original label (e.g. "Speaker 1"). Colour stays keyed
  /// to the ORIGINAL label so consistent across all segments by that
  /// speaker even after rename.
  Widget _buildSpeakerChip(String original) {
    final renames = ref.watch(appStateProvider).speakerNames;
    final display = renames[original] ?? original;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showRenameSpeakerDialog(original, display),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getSpeakerColor(original),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          display,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showRenameSpeakerDialog(String original, String currentDisplay) {
    final controller = TextEditingController(text: currentDisplay);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx).outputRenameSpeakerTitle),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(ctx)
                  .outputRenameSpeakerOriginal(original),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(ctx).cancel),
          ),
          if (currentDisplay != original)
            TextButton(
              onPressed: () {
                ref.read(appStateProvider.notifier).renameSpeaker(original, '');
                Navigator.of(ctx).pop();
              },
              child:
                  Text(AppLocalizations.of(ctx).outputRenameSpeakerReset),
            ),
          FilledButton(
            onPressed: () {
              ref
                  .read(appStateProvider.notifier)
                  .renameSpeaker(original, controller.text);
              Navigator.of(ctx).pop();
            },
            child: Text(AppLocalizations.of(ctx).ok),
          ),
        ],
      ),
    );
  }

  void _handleOption(String option) {
    switch (option) {
      case 'timestamps':
        setState(() => _showTimestamps = !_showTimestamps);
        break;
      case 'speakers':
        setState(() => _showSpeakers = !_showSpeakers);
        break;
      case 'confidence':
        setState(() => _showConfidence = !_showConfidence);
        break;
      case 'copy_all':
        _copyAllText();
        break;
      case 'export':
        _exportTranscription();
        break;
    }
  }

  void _handleSegmentAction(String action, TranscriptionSegment segment) {
    switch (action) {
      case 'play':
        _playSegment(segment);
        break;
      case 'copy':
        _copySegmentText(segment);
        break;
      case 'edit':
        _editSegment(segment);
        break;
    }
  }

  /// Play the source audio from the segment's start time, with
  /// karaoke-style word highlighting driven by `positionStream`. Falls
  /// back to a stub snackbar when no source path is available
  /// (mic-stream transcripts, history entries that lost their file).
  Future<void> _playSegment(TranscriptionSegment segment) async {
    final audioPath = ref.read(selectedAudioPathProvider);
    if (audioPath == null || audioPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)
              .outputPlayingSegment(segment.formattedTime)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    _player ??= AudioPlayer();
    _posSub ??= _player!.positionStream.listen((p) {
      if (!mounted) return;
      setState(() {
        _karaokePos = p;
        _karaokePlaying = _player!.playing;
      });
    });
    try {
      // Reload only when switching files (cheap no-op when same path).
      if (_player!.audioSource == null) {
        await _player!.setFilePath(audioPath);
      }
      await _player!.seek(Duration(milliseconds: (segment.startTime * 1000).round()));
      await _player!.play();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)
                .playbackFailed(e.toString()))),
      );
    }
  }

  void _copySegmentText(TranscriptionSegment segment) {
    final renames = ref.read(appStateProvider).speakerNames;
    final spk = segment.speaker == null
        ? null
        : (renames[segment.speaker!] ?? segment.speaker!);
    final text =
        _showSpeakers && spk != null ? '$spk: ${segment.text}' : segment.text;

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).outputSegmentCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyAllText() {
    final text = widget.currentTranscription ?? '';
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).outputAllCopied),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _editSegment(TranscriptionSegment segment) {
    final index = widget.segments.indexOf(segment);
    if (index < 0) return;
    final controller = TextEditingController(text: segment.text);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx).outputEditSegment),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: controller,
            maxLines: 6,
            autofocus: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: segment.formattedTime,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(ctx).cancel),
          ),
          FilledButton(
            onPressed: () {
              final next = controller.text.trim();
              if (next.isNotEmpty && next != segment.text) {
                ref
                    .read(appStateProvider.notifier)
                    .editSegment(index, next);
              }
              Navigator.of(ctx).pop();
            },
            child: Text(AppLocalizations.of(ctx).ok),
          ),
        ],
      ),
    );
  }

  void _exportTranscription() {
    // TODO: Implement transcription export
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).outputExport),
        content: Text(AppLocalizations.of(context).outputExportNotImplemented),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).ok),
          ),
        ],
      ),
    );
  }

  void _showSegmentOptions(TranscriptionSegment segment) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: Text(AppLocalizations.of(context).outputPlaySegment),
            onTap: () {
              Navigator.of(context).pop();
              _playSegment(segment);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: Text(AppLocalizations.of(context).outputCopyText),
            onTap: () {
              Navigator.of(context).pop();
              _copySegmentText(segment);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: Text(AppLocalizations.of(context).outputEditSegment),
            onTap: () {
              Navigator.of(context).pop();
              _editSegment(segment);
            },
          ),
        ],
      ),
    );
  }
}
