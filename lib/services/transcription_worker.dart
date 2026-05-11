// TranscriptionWorker — §5.23 Q2 v2 worker isolate.
//
// Each spawned isolate holds its own DynamicLibrary + CrispasrSession
// against the same model file. Persistent — opens the session ONCE
// at spawn time then handles N transcribe requests over its
// lifetime, so the session-open cost (seconds for big models)
// amortizes over the whole batch instead of per-file.
//
// Wire-level protocol (all messages are JSON-serializable maps or
// `_FrozenSegment` records — kept simple so the cross-isolate
// boundary doesn't accidentally include closures or live FFI
// handles):
//
//   spawn(args)
//   ↓
//   Worker creates: ReceivePort for commands → sends `.sendPort`
//                   back to main as the first message on the main's
//                   ready ReceivePort. Then opens libcrispasr +
//                   session.
//   ↓
//   Worker sends: { 'type': 'ready', 'backend': '...' }
//                 OR { 'type': 'error', 'message': '...' }
//   ↓
//   Per dispatch, main sends:
//     { 'type': 'transcribe',
//       'jobId': '...',
//       'samples': Float32List (transferable),
//       'language': 'en'?, ..., 'replyPort': SendPort }
//   ↓
//   Worker streams back on replyPort:
//     { 'type': 'segment', 'segment': {...} }
//     ... repeat ...
//     { 'type': 'done', 'segments': [...] }
//   OR on failure:
//     { 'type': 'error', 'message': '...' }
//   ↓
//   To shut down, main sends:
//     { 'type': 'shutdown' }
//   The worker closes the session and the receive port, then exits.
//
// All FFI work happens on the worker isolate — the main isolate's
// CrispASREngine is untouched by this path.
//
// Cross-platform: pure dart:isolate + the existing CrispasrSession
// FFI binding, which lazy-opens libcrispasr per isolate. Identical
// behaviour on macOS / Linux / Windows / Android / iOS.

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crispasr/crispasr.dart' as crispasr;

import '../engines/transcription_engine.dart';

class TranscriptionWorkerArgs {
  const TranscriptionWorkerArgs({
    required this.readySendPort,
    required this.modelPath,
    required this.backend,
    required this.libName,
    this.useGpu = true,
    this.flashAttn = true,
    this.nThreads = 0,
    this.nGpuLayers = 0,
  });

  /// Port the worker uses to hand back its command-receive port
  /// (the "I'm alive, here's where to send work" handshake).
  final SendPort readySendPort;
  final String modelPath;
  final String backend;
  final String libName;
  final bool useGpu;
  final bool flashAttn;
  final int nThreads;
  final int nGpuLayers;
}

/// Top-level isolate entry — must be top-level (not a closure) so
/// `Isolate.spawn` can find it.
Future<void> transcriptionWorkerEntry(TranscriptionWorkerArgs args) async {
  final cmdReceive = ReceivePort();
  args.readySendPort.send(cmdReceive.sendPort);

  crispasr.CrispasrSession? session;
  try {
    // openWithParams (CrispASR 0.6.1+) is the right factory when we
    // want explicit useGpu / flashAttn / nGpuLayers — older runtimes
    // (without `crispasr_session_open_with_params`) fall back to the
    // legacy [open] factory which always uses GPU + flash-attn ON.
    try {
      session = crispasr.CrispasrSession.openWithParams(
        args.modelPath,
        nThreads: args.nThreads,
        useGpu: args.useGpu,
        flashAttn: args.flashAttn,
        nGpuLayers: args.nGpuLayers,
        backend: args.backend,
      );
    } on UnsupportedError {
      session = crispasr.CrispasrSession.open(
        args.modelPath,
        nThreads: args.nThreads,
        backend: args.backend,
      );
    }
    args.readySendPort.send(<String, Object?>{
      'type': 'ready',
      'backend': args.backend,
    });
  } catch (e, st) {
    args.readySendPort.send(<String, Object?>{
      'type': 'error',
      'message': 'session open failed: $e',
      'stack': st.toString(),
    });
    cmdReceive.close();
    return;
  }

  await for (final raw in cmdReceive) {
    if (raw is! Map) continue;
    final type = raw['type'];
    if (type == 'shutdown') {
      try {
        session.close();
      } catch (_) {}
      cmdReceive.close();
      return;
    }
    if (type != 'transcribe') continue;

    final replyPort = raw['replyPort'] as SendPort?;
    if (replyPort == null) continue;
    final samples = raw['samples'] as Float32List?;
    final language = raw['language'] as String?;
    if (samples == null) {
      replyPort.send(<String, Object?>{
        'type': 'error',
        'message': 'transcribe request missing samples',
      });
      continue;
    }

    try {
      // session.transcribe is the bare FFI dispatch — no chunking,
      // no VAD, no resume offsets. The drain loop handles those on
      // the main isolate (chunked whisper has its own offset
      // routing already). For the pool's purposes, the worker just
      // produces segments for the supplied samples. The FFI call is
      // synchronous; wrapping in Future.sync keeps the await loop
      // happy even when transcribe is fast.
      // session.transcribe is synchronous (FFI call returns
      // immediately); no need to await.
      final segs = session.transcribe(samples, language: language);
      // Stream segments first (UI gets them as they arrive), then
      // signal done with the full list (drain loop uses it for
      // final dedupe / history save).
      final outSegs = <Map<String, Object?>>[];
      for (final s in segs) {
        final m = _segmentToMap(s);
        outSegs.add(m);
        replyPort.send(<String, Object?>{'type': 'segment', 'segment': m});
      }
      replyPort.send(<String, Object?>{'type': 'done', 'segments': outSegs});
    } catch (e, st) {
      replyPort.send(<String, Object?>{
        'type': 'error',
        'message': '$e',
        'stack': st.toString(),
      });
    }
  }
}

/// Serialise a SessionSegment for the cross-isolate hop. The
/// canonical SessionSegment lives in `package:crispasr` and is
/// already plain data, but to keep the wire format stable + small
/// we round-trip through a Map.
Map<String, Object?> _segmentToMap(crispasr.SessionSegment s) {
  return <String, Object?>{
    'text': s.text,
    // session segments use `start`/`end`; flatten to the
    // TranscriptionSegment naming the main-isolate consumer expects.
    'startTime': s.start,
    'endTime': s.end,
  };
}

/// Main-side helper to rebuild a [TranscriptionSegment] from the
/// over-the-wire map. The drain loop calls this when it receives a
/// `segment` or `done` message from a worker.
TranscriptionSegment workerSegmentFromMap(Map<String, Object?> m) {
  return TranscriptionSegment(
    text: m['text'] as String? ?? '',
    startTime: (m['startTime'] as num?)?.toDouble() ?? 0.0,
    endTime: (m['endTime'] as num?)?.toDouble() ?? 0.0,
    speaker: m['speaker'] as String?,
    confidence: (m['confidence'] as num?)?.toDouble() ?? 1.0,
  );
}
