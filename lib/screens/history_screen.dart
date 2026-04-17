import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../services/history_service.dart';
import '../utils/file_utils.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late Future<List<HistoryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final service = ref.read(historyServiceProvider);
    _future = service.list();
  }

  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all history?'),
        content: const Text(
          'Remove every saved transcription from this device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(historyServiceProvider).clear();
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcription History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(_reload),
          ),
          IconButton(
            tooltip: 'Clear all',
            icon: const Icon(Icons.delete_sweep),
            onPressed: _deleteAll,
          ),
        ],
      ),
      body: FutureBuilder<List<HistoryEntry>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Failed to load history: ${snap.error}'));
          }
          final items = snap.data ?? const <HistoryEntry>[];
          if (items.isEmpty) {
            return const _EmptyHistory();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, i) => _HistoryTile(
              entry: items[i],
              onDelete: () async {
                await ref.read(historyServiceProvider).delete(items[i].id);
                setState(_reload);
              },
            ),
          );
        },
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No transcriptions yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Run a transcription and it will show up here.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.onDelete});

  final HistoryEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd().add_Hm();
    return Card(
      child: ExpansionTile(
        title: Text(
          entry.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${fmt.format(entry.createdAt)} · ${entry.engineId}'
          '${entry.modelId != null ? ' · ${entry.modelId}' : ''}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(entry.fullText),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: entry.fullText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied')),
                        );
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.save_alt, size: 16),
                      label: const Text('Export SRT'),
                      onPressed: () => _exportAs(context, TranscriptFormat.srt),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.save_alt, size: 16),
                      label: const Text('Export TXT'),
                      onPressed: () => _exportAs(context, TranscriptFormat.txt),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.save_alt, size: 16),
                      label: const Text('Export JSON'),
                      onPressed: () => _exportAs(context, TranscriptFormat.json),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 16),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      label: const Text('Delete'),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAs(BuildContext context, TranscriptFormat fmt) async {
    try {
      final file = await FileUtils.saveTranscription(
        entry.fullText,
        entry.title,
        format: fmt,
        segments: entry.segments,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved ${file.path}')),
      );
      await FileUtils.shareFile(file.path, subject: entry.title);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }
}
