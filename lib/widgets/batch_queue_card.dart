import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../l10n/generated/app_localizations.dart';
import '../services/batch_queue_service.dart';
import '../services/log_service.dart';
import '../utils/audio_utils.dart';

/// Always-visible drop target for multi-file transcription queues.
///
/// Two ways to populate it:
///   1. drop files directly on this card → *every* file is enqueued;
///   2. drop more-than-one file on the main window → first file is
///      still picked as the active selection, subsequent files land
///      here (see `_onFilesDropped` in `transcription_screen.dart`).
///
/// Drops on this card set `BatchQueueNotifier._lastReceivedDropAt` so
/// the page-level DropTarget can dedup when the underlying OS delivers
/// the drop to both DropTargets (nested).
class BatchQueueCard extends ConsumerStatefulWidget {
  const BatchQueueCard({super.key});

  @override
  ConsumerState<BatchQueueCard> createState() => _BatchQueueCardState();
}

class _BatchQueueCardState extends ConsumerState<BatchQueueCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(batchQueueProvider);
    final l = AppLocalizations.of(context);

    final queued = jobs.where((j) => j.status == BatchJobStatus.queued).length;
    final running =
        jobs.where((j) => j.status == BatchJobStatus.running).length;
    final done = jobs.where((j) => j.status == BatchJobStatus.done).length;
    final errored = jobs.where((j) => j.status == BatchJobStatus.error).length;

    return DropTarget(
      onDragEntered: (_) => setState(() => _hover = true),
      onDragExited: (_) => setState(() => _hover = false),
      onDragDone: _onDrop,
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        color: _hover ? Theme.of(context).colorScheme.primaryContainer : null,
        shape: _hover
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.playlist_play, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.batchQueueTitle,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          jobs.isEmpty
                              ? l.batchQueueDropHint
                              : l.batchQueueSummary(
                                  queued, running, done, errored),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  if (done > 0)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.cleaning_services_outlined,
                          size: 18),
                      tooltip: l.batchClearCompleted,
                      onPressed: () => ref
                          .read(batchQueueProvider.notifier)
                          .clearCompleted(),
                    ),
                ],
              ),
              if (jobs.isEmpty)
                _EmptyDropHint()
              else ...[
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: jobs.length,
                    itemBuilder: (_, i) => _JobRow(job: jobs[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _onDrop(DropDoneDetails details) {
    setState(() => _hover = false);
    if (details.files.isEmpty) return;
    final supported = details.files
        .where((f) => AudioUtils.isSupportedAudioFile(f.path))
        .toList();
    if (supported.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)
                .transcribeUnsupportedFile(details.files.first.name))),
      );
      return;
    }

    final q = ref.read(batchQueueProvider.notifier);
    for (final f in supported) {
      q.enqueue(f.path);
    }
    q.markDropReceived();

    Log.instance.i('batch', 'drop enqueued', fields: {
      'count': supported.length,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            AppLocalizations.of(context).batchEnqueueAdded(supported.length)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _EmptyDropHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(Icons.cloud_upload_outlined,
              size: 32, color: Colors.grey.shade500),
          const SizedBox(height: 6),
          Text(
            l.batchQueueDropHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _JobRow extends ConsumerWidget {
  const _JobRow({required this.job});
  final BatchJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = p.basename(job.filePath);
    final (icon, color) = switch (job.status) {
      BatchJobStatus.queued => (Icons.schedule, Colors.grey.shade600),
      BatchJobStatus.running => (Icons.refresh, Colors.blue.shade700),
      BatchJobStatus.done => (Icons.check, Colors.green.shade700),
      BatchJobStatus.error => (Icons.error_outline, Colors.red.shade700),
      BatchJobStatus.cancelled => (Icons.block, Colors.grey.shade500),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                if (job.status == BatchJobStatus.running)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 8),
                    child: LinearProgressIndicator(
                      value: job.progress,
                      minHeight: 2,
                    ),
                  )
                else if (job.status == BatchJobStatus.error &&
                    job.errorMessage != null)
                  Text(
                    job.errorMessage!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                  ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 16),
            tooltip: AppLocalizations.of(context).batchRemove,
            onPressed: () =>
                ref.read(batchQueueProvider.notifier).remove(job.id),
          ),
        ],
      ),
    );
  }
}
