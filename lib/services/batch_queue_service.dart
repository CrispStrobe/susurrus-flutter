import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'batch_persistence_service.dart';
import 'log_service.dart';

enum BatchJobStatus { queued, running, done, error, cancelled }

extension BatchJobStatusX on BatchJobStatus {
  bool get isTerminal =>
      this == BatchJobStatus.done ||
      this == BatchJobStatus.error ||
      this == BatchJobStatus.cancelled;
}

/// Persisted-and-displayed record for one file in a batch queue.
///
/// `backend` / `modelId` / `language` are snapshotted at enqueue time
/// so the drain loop can group jobs by `(backend, modelId, language)`
/// without re-reading global settings (§5.23 Q1 grouping) and so a
/// resumed-from-crash job knows which model to load.
///
/// `resumeOffsetSec` is the float second offset into the audio at which
/// to restart transcription after a crash. Populated by the §5.23 Q3
/// resume-from-checkpoint flow; null for fresh jobs.
class BatchJob {
  final String id;
  final String filePath;
  final DateTime createdAt;
  final BatchJobStatus status;
  final double progress; // 0..1
  final String? errorMessage;
  final String? resultText;
  final String? historyEntryId;
  final String? backend;
  final String? modelId;
  final String? language;
  final double? durationSec;
  final double? resumeOffsetSec;

  const BatchJob({
    required this.id,
    required this.filePath,
    required this.createdAt,
    this.status = BatchJobStatus.queued,
    this.progress = 0.0,
    this.errorMessage,
    this.resultText,
    this.historyEntryId,
    this.backend,
    this.modelId,
    this.language,
    this.durationSec,
    this.resumeOffsetSec,
  });

  BatchJob copyWith({
    BatchJobStatus? status,
    double? progress,
    String? errorMessage,
    String? resultText,
    String? historyEntryId,
    String? backend,
    String? modelId,
    String? language,
    double? durationSec,
    double? resumeOffsetSec,
  }) {
    return BatchJob(
      id: id,
      filePath: filePath,
      createdAt: createdAt,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      resultText: resultText ?? this.resultText,
      historyEntryId: historyEntryId ?? this.historyEntryId,
      backend: backend ?? this.backend,
      modelId: modelId ?? this.modelId,
      language: language ?? this.language,
      durationSec: durationSec ?? this.durationSec,
      resumeOffsetSec: resumeOffsetSec ?? this.resumeOffsetSec,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'filePath': filePath,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'progress': progress,
        if (errorMessage != null) 'errorMessage': errorMessage,
        if (resultText != null) 'resultText': resultText,
        if (historyEntryId != null) 'historyEntryId': historyEntryId,
        if (backend != null) 'backend': backend,
        if (modelId != null) 'modelId': modelId,
        if (language != null) 'language': language,
        if (durationSec != null) 'durationSec': durationSec,
        if (resumeOffsetSec != null) 'resumeOffsetSec': resumeOffsetSec,
      };

  static BatchJob fromJson(Map<String, dynamic> json) => BatchJob(
        id: json['id'] as String,
        filePath: json['filePath'] as String,
        createdAt:
            DateTime.parse(json['createdAt'] as String? ?? '1970-01-01T00:00:00Z'),
        status: BatchJobStatus.values.firstWhere(
          (s) => s.name == (json['status'] as String? ?? 'queued'),
          orElse: () => BatchJobStatus.queued,
        ),
        progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
        errorMessage: json['errorMessage'] as String?,
        resultText: json['resultText'] as String?,
        historyEntryId: json['historyEntryId'] as String?,
        backend: json['backend'] as String?,
        modelId: json['modelId'] as String?,
        language: json['language'] as String?,
        durationSec: (json['durationSec'] as num?)?.toDouble(),
        resumeOffsetSec: (json['resumeOffsetSec'] as num?)?.toDouble(),
      );
}

/// Riverpod-backed serial FIFO of transcription jobs.
///
/// Concurrent FFI calls into the same whisper_context are unsafe, so the
/// queue drains strictly one-at-a-time. The UI (transcription screen)
/// owns the runner — it drives the queue by calling `nextQueued()` in a
/// loop after each job finishes.
///
/// **Persistence (§5.23 Q1).** Every state mutation is mirrored to a
/// per-job JSON file on disk so the queue survives app restarts. The
/// writes are fire-and-forget (the on-disk copy can lag by one frame
/// behind the in-memory state); failures are logged but don't break
/// the in-memory queue. The persistence layer is injectable so unit
/// tests can hand in a `Directory.systemTemp` path.
class BatchQueueNotifier extends StateNotifier<List<BatchJob>> {
  BatchQueueNotifier({BatchPersistenceService? persistence})
      : _persistence = persistence ?? BatchPersistenceService(),
        super(const []);

  final BatchPersistenceService _persistence;
  bool _loaded = false;

  /// Hydrate in-memory state from the on-disk queue. Idempotent —
  /// safe to call multiple times. Used by the app-startup wiring in
  /// `main.dart` and by the resume-from-crash UI in
  /// `transcription_screen.dart`.
  ///
  /// Running-when-killed jobs are demoted back to `queued` on load so
  /// the next drain pass picks them up. A separate §5.23 Q3 path will
  /// look for matching `.ckpt.jsonl` files and stamp `resumeOffsetSec`
  /// onto the BatchJob before re-running — that lives in commit 2 of
  /// this slice.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final loaded = await _persistence.loadAllJobs();
      // Anything that was 'running' when the app died can't still be
      // running — demote to queued so the drain loop will retry it.
      final demoted = loaded
          .map((j) => j.status == BatchJobStatus.running
              ? j.copyWith(
                  status: BatchJobStatus.queued,
                  progress: 0.0,
                )
              : j)
          .toList(growable: false);
      state = demoted;
      // Push the demotion back to disk so subsequent loads see the
      // same state.
      for (final j in demoted) {
        if (j.status == BatchJobStatus.queued) {
          unawaited(_persist(j));
        }
      }
      Log.instance.i('batch-queue',
          'hydrated ${demoted.length} job(s) from disk', fields: {
        'queued': demoted.where((j) => j.status == BatchJobStatus.queued).length,
        'done': demoted.where((j) => j.status == BatchJobStatus.done).length,
      });
    } catch (e, st) {
      Log.instance.w('batch-queue', 'load failed; starting empty',
          error: e, stack: st);
    }
  }

  Future<void> _persist(BatchJob job) async {
    try {
      await _persistence.saveJob(job);
    } catch (e, st) {
      Log.instance.w('batch-queue', 'saveJob failed for ${job.id}',
          error: e, stack: st);
    }
  }

  String enqueue(String filePath,
      {String? backend, String? modelId, String? language}) {
    // Dedup by path — already-queued or in-flight jobs stay in place.
    for (final j in state) {
      if (j.filePath == filePath && !j.status.isTerminal) return j.id;
    }

    final job = BatchJob(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      filePath: filePath,
      createdAt: DateTime.now(),
      backend: backend,
      modelId: modelId,
      language: language,
    );
    state = [...state, job];
    unawaited(_persist(job));
    return job.id;
  }

  void remove(String id) {
    state = state.where((j) => j.id != id).toList(growable: false);
    unawaited(_persistence.deleteJob(id));
  }

  void clearCompleted() {
    final toRemove = state
        .where((j) =>
            j.status == BatchJobStatus.done ||
            j.status == BatchJobStatus.cancelled)
        .map((j) => j.id)
        .toList();
    state = state
        .where((j) =>
            j.status != BatchJobStatus.done &&
            j.status != BatchJobStatus.cancelled)
        .toList(growable: false);
    for (final id in toRemove) {
      unawaited(_persistence.deleteJob(id));
    }
  }

  void clearAll() {
    state = const [];
    unawaited(_persistence.clearAll());
  }

  void _update(String id, BatchJob Function(BatchJob) fn) {
    BatchJob? updated;
    state = state.map((j) {
      if (j.id != id) return j;
      updated = fn(j);
      return updated!;
    }).toList(growable: false);
    if (updated != null) unawaited(_persist(updated!));
  }

  void setRunning(String id) => _update(
      id, (j) => j.copyWith(status: BatchJobStatus.running, progress: 0));

  void setProgress(String id, double p) =>
      _update(id, (j) => j.copyWith(progress: p));

  void setDone(String id, {String? resultText, String? historyEntryId}) {
    _update(
        id,
        (j) => j.copyWith(
              status: BatchJobStatus.done,
              progress: 1.0,
              resultText: resultText,
              historyEntryId: historyEntryId,
            ));
    // Clean up any leftover checkpoint file — the job finished cleanly
    // and the result is in the history entry now.
    unawaited(_persistence.deleteCheckpoint(id));
  }

  void setError(String id, String message) => _update(
      id,
      (j) => j.copyWith(
            status: BatchJobStatus.error,
            errorMessage: message,
          ));

  void setCancelled(String id) {
    _update(id, (j) => j.copyWith(status: BatchJobStatus.cancelled));
    unawaited(_persistence.deleteCheckpoint(id));
  }

  /// Next still-queued job (or null if queue is empty / all terminal).
  BatchJob? nextQueued() {
    for (final j in state) {
      if (j.status == BatchJobStatus.queued) return j;
    }
    return null;
  }

  bool get hasQueued => state.any((j) => j.status == BatchJobStatus.queued);
  bool get hasRunning => state.any((j) => j.status == BatchJobStatus.running);
  int get queuedCount =>
      state.where((j) => j.status == BatchJobStatus.queued).length;
  int get doneCount =>
      state.where((j) => j.status == BatchJobStatus.done).length;

  /// Expose the persistence service for the §5.23 Q3 resume flow
  /// (transcription_screen reads/writes checkpoint segments directly
  /// during the drain loop).
  BatchPersistenceService get persistence => _persistence;

  // desktop_drop DropTargets fire even when nested. When the batch card's
  // own DropTarget consumes a drop, it calls markDropReceived(); the outer
  // page-level DropTarget peeks at `recentlyConsumedDrop` to avoid
  // re-handling the same event.
  DateTime? _lastDropAt;
  void markDropReceived() {
    _lastDropAt = DateTime.now();
  }

  bool get recentlyConsumedDrop {
    final t = _lastDropAt;
    if (t == null) return false;
    return DateTime.now().difference(t) < const Duration(milliseconds: 400);
  }
}

final batchQueueProvider =
    StateNotifierProvider<BatchQueueNotifier, List<BatchJob>>(
        (ref) => BatchQueueNotifier());
