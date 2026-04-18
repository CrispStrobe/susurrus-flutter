import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BatchJobStatus { queued, running, done, error, cancelled }

extension BatchJobStatusX on BatchJobStatus {
  bool get isTerminal =>
      this == BatchJobStatus.done ||
      this == BatchJobStatus.error ||
      this == BatchJobStatus.cancelled;
}

class BatchJob {
  final String id;
  final String filePath;
  final DateTime createdAt;
  final BatchJobStatus status;
  final double progress; // 0..1
  final String? errorMessage;
  final String? resultText;
  final String? historyEntryId;

  const BatchJob({
    required this.id,
    required this.filePath,
    required this.createdAt,
    this.status = BatchJobStatus.queued,
    this.progress = 0.0,
    this.errorMessage,
    this.resultText,
    this.historyEntryId,
  });

  BatchJob copyWith({
    BatchJobStatus? status,
    double? progress,
    String? errorMessage,
    String? resultText,
    String? historyEntryId,
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
    );
  }
}

/// Riverpod-backed serial FIFO of transcription jobs.
///
/// Concurrent FFI calls into the same whisper_context are unsafe, so the
/// queue drains strictly one-at-a-time. The UI (transcription screen)
/// owns the runner — it drives the queue by calling `takeNext()` in a
/// loop after each job finishes.
class BatchQueueNotifier extends StateNotifier<List<BatchJob>> {
  BatchQueueNotifier() : super(const []);

  String enqueue(String filePath) {
    // Dedup by path — already-queued or in-flight jobs stay in place.
    for (final j in state) {
      if (j.filePath == filePath && !j.status.isTerminal) return j.id;
    }

    final job = BatchJob(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      filePath: filePath,
      createdAt: DateTime.now(),
    );
    state = [...state, job];
    return job.id;
  }

  void remove(String id) {
    state = state.where((j) => j.id != id).toList(growable: false);
  }

  void clearCompleted() {
    state = state
        .where((j) =>
            j.status != BatchJobStatus.done &&
            j.status != BatchJobStatus.cancelled)
        .toList(growable: false);
  }

  void clearAll() => state = const [];

  void _update(String id, BatchJob Function(BatchJob) fn) {
    state = state
        .map((j) => j.id == id ? fn(j) : j)
        .toList(growable: false);
  }

  void setRunning(String id) =>
      _update(id, (j) => j.copyWith(status: BatchJobStatus.running, progress: 0));

  void setProgress(String id, double p) =>
      _update(id, (j) => j.copyWith(progress: p));

  void setDone(String id, {String? resultText, String? historyEntryId}) =>
      _update(
          id,
          (j) => j.copyWith(
                status: BatchJobStatus.done,
                progress: 1.0,
                resultText: resultText,
                historyEntryId: historyEntryId,
              ));

  void setError(String id, String message) =>
      _update(
          id,
          (j) => j.copyWith(
                status: BatchJobStatus.error,
                errorMessage: message,
              ));

  void setCancelled(String id) =>
      _update(id, (j) => j.copyWith(status: BatchJobStatus.cancelled));

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
}

final batchQueueProvider =
    StateNotifierProvider<BatchQueueNotifier, List<BatchJob>>(
        (ref) => BatchQueueNotifier());
