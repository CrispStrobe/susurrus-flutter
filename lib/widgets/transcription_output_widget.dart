import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engines/transcription_engine.dart'; // Use engine TranscriptionSegment
import '../l10n/generated/app_localizations.dart';

class TranscriptionOutputWidget extends StatefulWidget {
  final List<TranscriptionSegment> segments;
  final String? currentTranscription;

  const TranscriptionOutputWidget({
    super.key,
    required this.segments,
    this.currentTranscription,
  });

  @override
  State<TranscriptionOutputWidget> createState() => _TranscriptionOutputWidgetState();
}

class _TranscriptionOutputWidgetState extends State<TranscriptionOutputWidget>
    with TickerProviderStateMixin {
  bool _showTimestamps = true;
  bool _showSpeakers = true;
  bool _showConfidence = false;
  String _searchQuery = '';

  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                    child: Text(AppLocalizations.of(context).outputShowTimestamps),
                  ),
                  CheckedPopupMenuItem(
                    value: 'speakers',
                    checked: _showSpeakers,
                    child: Text(AppLocalizations.of(context).outputShowSpeakers),
                  ),
                  CheckedPopupMenuItem(
                    value: 'confidence',
                    checked: _showConfidence,
                    child: Text(AppLocalizations.of(context).outputShowConfidence),
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
        : widget.segments.where((segment) =>
            segment.text.toLowerCase().contains(_searchQuery)).toList();

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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getSpeakerColor(segment.speaker!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        segment.speaker!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  const Spacer(),

                  if (_showConfidence) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    onSelected: (action) => _handleSegmentAction(action, segment),
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

              // Transcription text
              hasSearch
                  ? _buildHighlightedText(segment.text, _searchQuery)
                  : SelectableText(
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

  Widget _buildFullTextView() {
    if (widget.currentTranscription == null || widget.currentTranscription!.isEmpty) {
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

  void _playSegment(TranscriptionSegment segment) {
    // TODO: Implement audio playback for specific segment
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).outputPlayingSegment(segment.formattedTime)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copySegmentText(TranscriptionSegment segment) {
    final text = _showSpeakers && segment.speaker != null
        ? '${segment.speaker}: ${segment.text}'
        : segment.text;

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
    // TODO: Implement segment editing
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).outputEditSegment),
        content: Text(AppLocalizations.of(context).outputEditNotImplemented),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).ok),
          ),
        ],
      ),
    );
  }

  void _exportTranscription() {
    // TODO: Implement transcription export
    showDialog(
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
    showModalBottomSheet(
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