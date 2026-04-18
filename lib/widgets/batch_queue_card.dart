import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../l10n/generated/app_localizations.dart';
import '../services/batch_queue_service.dart';

/// Scrollable queue overview, shown on the transcription screen whenever
/// the batch has at least one entry. Per-row status + remove action; header
/// button to clear completed entries.
class BatchQueueCard extends ConsumerWidget {
  const BatchQueueCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(batchQueueProvider);
    if (jobs.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);

    final queued =
        jobs.where((j) => j.status == BatchJobStatus.queued).length;
    final running =
        jobs.where((j) => j.status == BatchJobStatus.running).length;
    final done = jobs.where((j) => j.status == BatchJobStatus.done).length;
    final errored =
        jobs.where((j) => j.status == BatchJobStatus.error).length;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.playlist_play, size: 18),
                const SizedBox(width: 6),
                Text(l.batchQueueTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text(
                  l.batchQueueSummary(queued, running, done, errored),
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade700),
                ),
                const Spacer(),
                if (done > 0)
                  TextButton.icon(
                    icon: const Icon(Icons.cleaning_services_outlined,
                        size: 16),
                    label: Text(l.batchClearCompleted),
                    onPressed: () =>
                        ref.read(batchQueueProvider.notifier).clearCompleted(),
                  ),
              ],
            ),
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
        ),
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
      BatchJobStatus.cancelled =>
        (Icons.block, Colors.grey.shade500),
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
                    style: TextStyle(
                        fontSize: 11, color: Colors.red.shade700),
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
