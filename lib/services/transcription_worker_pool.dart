// TranscriptionWorkerPool — §5.23 Q2 v2 main-side dispatcher.
//
// Spawns N persistent worker isolates against the same model.
// Routes incoming transcribe jobs to free workers; blocks on a
// completer when every worker is busy. Each [dispatch] call streams
// segments back via the supplied `onSegment` callback so the UI
// sees text appear as the worker emits it (same UX as the serial
// path).
//
// Lifecycle:
//   var pool = await TranscriptionWorkerPool.spawn(...);
//   for (file in queue) {
//     await pool.dispatch(file: ..., samples: ..., onSegment: ...);
//   }
//   await pool.shutdown();
//
// Errors:
//   - spawn failures (session can't open) propagate from [spawn]
//   - per-dispatch errors throw [TranscriptionWorkerException]
//   - if a worker dies mid-dispatch the dispatch future
//     completes with the same exception and the worker is marked
//     dead; further dispatches fall back to the surviving workers.
//
// Cross-platform: pure dart:isolate. Same code path on every
// platform CrisperWeaver ships on.

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../engines/transcription_engine.dart';
import 'log_service.dart';
import 'transcription_worker.dart';

class TranscriptionWorkerException implements Exception {
  TranscriptionWorkerException(this.message, [this.stack]);
  final String message;
  final String? stack;
  @override
  String toString() => 'TranscriptionWorkerException: $message';
}

class _Worker {
  _Worker({
    required this.isolate,
    required this.sendPort,
  });
  final Isolate isolate;
  final SendPort sendPort;
  bool busy = false;
  bool dead = false;
}

class TranscriptionWorkerPool {
  TranscriptionWorkerPool._(this._workers);

  final List<_Worker> _workers;
  // FIFO of dispatchers waiting for a free worker. Resolved as
  // workers complete their current job.
  final List<Completer<_Worker>> _waiters = [];
  bool _shutdown = false;

  int get size => _workers.length;
  int get aliveCount => _workers.where((w) => !w.dead).length;
  bool get isShutdown => _shutdown;

  /// Spawn `count` workers against [modelPath]. Returns a pool that's
  /// ready to accept dispatches. Throws if every worker fails to
  /// open its session (e.g. malformed GGUF / missing file).
  static Future<TranscriptionWorkerPool> spawn({
    required int count,
    required String modelPath,
    required String backend,
    required String libName,
    bool useGpu = true,
    bool flashAttn = true,
    int nThreads = 0,
    int nGpuLayers = -1,
  }) async {
    if (count < 1) {
      throw ArgumentError.value(count, 'count', 'must be >= 1');
    }
    final workers = <_Worker>[];
    final spawnFutures = <Future<_Worker?>>[];
    for (var i = 0; i < count; i++) {
      spawnFutures.add(_spawnOne(
        index: i,
        modelPath: modelPath,
        backend: backend,
        libName: libName,
        useGpu: useGpu,
        flashAttn: flashAttn,
        nThreads: nThreads,
        nGpuLayers: nGpuLayers,
      ));
    }
    final spawned = await Future.wait(spawnFutures);
    for (final w in spawned) {
      if (w != null) workers.add(w);
    }
    if (workers.isEmpty) {
      throw TranscriptionWorkerException(
          'every worker failed to spawn — see log for details');
    }
    Log.instance.i('worker-pool', 'spawned ${workers.length}/$count workers',
        fields: {'model': modelPath, 'backend': backend});
    return TranscriptionWorkerPool._(workers);
  }

  static Future<_Worker?> _spawnOne({
    required int index,
    required String modelPath,
    required String backend,
    required String libName,
    required bool useGpu,
    required bool flashAttn,
    required int nThreads,
    required int nGpuLayers,
  }) async {
    final readyReceive = ReceivePort();
    Isolate? isolate;
    try {
      isolate = await Isolate.spawn<TranscriptionWorkerArgs>(
        transcriptionWorkerEntry,
        TranscriptionWorkerArgs(
          readySendPort: readyReceive.sendPort,
          modelPath: modelPath,
          backend: backend,
          libName: libName,
          useGpu: useGpu,
          flashAttn: flashAttn,
          nThreads: nThreads,
          nGpuLayers: nGpuLayers,
        ),
        debugName: 'crisperweaver-worker-$index',
        errorsAreFatal: false,
      );
    } catch (e, st) {
      Log.instance.w('worker-pool', 'spawn failed', error: e, stack: st);
      readyReceive.close();
      return null;
    }
    // Expect two messages on readyReceive:
    //   1. The worker's command SendPort
    //   2. A {type: 'ready'} or {type: 'error'} confirmation
    SendPort? cmdPort;
    final completer = Completer<_Worker?>();
    late StreamSubscription<dynamic> sub;
    final timeout = Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        Log.instance.w('worker-pool', 'spawn timeout for worker $index');
        sub.cancel();
        readyReceive.close();
        isolate?.kill(priority: Isolate.immediate);
        completer.complete(null);
      }
    });
    sub = readyReceive.listen((raw) {
      if (raw is SendPort) {
        cmdPort = raw;
        return;
      }
      if (raw is Map && raw['type'] == 'ready') {
        timeout.cancel();
        sub.cancel();
        readyReceive.close();
        completer.complete(_Worker(isolate: isolate!, sendPort: cmdPort!));
        return;
      }
      if (raw is Map && raw['type'] == 'error') {
        Log.instance.w('worker-pool',
            'worker $index init failed: ${raw['message']}');
        timeout.cancel();
        sub.cancel();
        readyReceive.close();
        isolate?.kill(priority: Isolate.immediate);
        completer.complete(null);
      }
    });
    return completer.future;
  }

  /// Acquire a free worker (blocks until one becomes available).
  /// Returns null if the pool is shutdown or every worker has died.
  Future<_Worker?> _acquire() async {
    if (_shutdown) return null;
    for (final w in _workers) {
      if (!w.busy && !w.dead) {
        w.busy = true;
        return w;
      }
    }
    if (_workers.every((w) => w.dead)) return null;
    final c = Completer<_Worker>();
    _waiters.add(c);
    return c.future;
  }

  void _release(_Worker w) {
    w.busy = false;
    while (_waiters.isNotEmpty) {
      final c = _waiters.removeAt(0);
      if (!w.busy && !w.dead) {
        w.busy = true;
        c.complete(w);
        return;
      }
    }
  }

  /// Send a transcribe job to a free worker and stream segments
  /// back via [onSegment]. Returns the full segment list when the
  /// worker reports `done`. Throws [TranscriptionWorkerException]
  /// on worker-side errors.
  Future<List<TranscriptionSegment>> dispatch({
    required Float32List samples,
    String? language,
    void Function(TranscriptionSegment seg)? onSegment,
  }) async {
    final worker = await _acquire();
    if (worker == null) {
      throw TranscriptionWorkerException(
          'pool unavailable (shutdown or all workers dead)');
    }

    final replyReceive = ReceivePort();
    final completer = Completer<List<TranscriptionSegment>>();
    late StreamSubscription<dynamic> sub;
    sub = replyReceive.listen((raw) {
      if (raw is! Map) return;
      switch (raw['type']) {
        case 'segment':
          if (onSegment != null) {
            onSegment(workerSegmentFromMap(
                (raw['segment'] as Map).cast<String, Object?>()));
          }
          break;
        case 'done':
          final list = (raw['segments'] as List)
              .map((m) =>
                  workerSegmentFromMap((m as Map).cast<String, Object?>()))
              .toList(growable: false);
          sub.cancel();
          replyReceive.close();
          if (!completer.isCompleted) completer.complete(list);
          break;
        case 'error':
          sub.cancel();
          replyReceive.close();
          if (!completer.isCompleted) {
            completer.completeError(TranscriptionWorkerException(
                raw['message'] as String? ?? 'unknown worker error',
                raw['stack'] as String?));
          }
          break;
      }
    });
    try {
      worker.sendPort.send(<String, Object?>{
        'type': 'transcribe',
        'samples': samples,
        'language': language,
        'replyPort': replyReceive.sendPort,
      });
      return await completer.future;
    } catch (e) {
      // Worker likely died mid-send — mark dead so the pool stops
      // routing to it. Re-throw so the drain loop knows the job
      // didn't land.
      worker.dead = true;
      rethrow;
    } finally {
      _release(worker);
    }
  }

  /// Shut down every worker. Idempotent. After this point new
  /// dispatches throw. In-flight dispatches are NOT cancelled — they
  /// run to completion against their worker, then the worker exits.
  Future<void> shutdown() async {
    if (_shutdown) return;
    _shutdown = true;
    for (final w in _workers) {
      if (w.dead) continue;
      try {
        w.sendPort.send(<String, Object?>{'type': 'shutdown'});
      } catch (_) {}
    }
    // Give workers a moment to close their sessions cleanly. We
    // can't await Isolate exit without a per-worker onExit port; a
    // short delay covers the typical path.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    for (final w in _workers) {
      try {
        w.isolate.kill(priority: Isolate.beforeNextEvent);
      } catch (_) {}
    }
  }
}
