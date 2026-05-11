// Tests for MemoryEstimator — §5.23 Q2 v2 OOM pre-flight guard.
//
// The estimator's math has two paths that need pinning:
//   1. `physicalMemoryBytes` reads the platform's total RAM. We
//      can't reliably exercise the live read in a unit test (would
//      need to shell out and the value varies per host), so we
//      use the `physicalMemoryBytesForTest` injection and verify
//      the projection math is correct for known inputs.
//   2. `estimate(...)` returns affordable workers + projection. We
//      cover: requested fits, requested clamped, unknown-mem
//      fallback, missing-model fallback.
//
// Cross-platform: only uses dart:io File for the size probe (we
// write a real file under Directory.systemTemp). Same as the rest
// of the batch-tier hermetic tests.

import 'dart:io';

import 'package:crisper_weaver/services/memory_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MemoryEstimator', () {
    late Directory tempDir;
    late File modelFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mem-est-test-');
      modelFile = File('${tempDir.path}/fake-model.gguf');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<void> writeSparse(int sizeBytes) async {
      // Cheap: write a sparse-ish file of the requested size.
      // RandomAccessFile.setSize is platform-portable.
      final raf = await modelFile.open(mode: FileMode.write);
      await raf.setPosition(sizeBytes - 1);
      await raf.writeByte(0);
      await raf.close();
    }

    test('modelFileSizeBytes returns 0 for null/missing paths', () {
      expect(MemoryEstimator.modelFileSizeBytes(null), 0);
      expect(MemoryEstimator.modelFileSizeBytes(''), 0);
      expect(
          MemoryEstimator.modelFileSizeBytes('/does/not/exist.gguf'), 0);
    });

    test('modelFileSizeBytes returns the real on-disk size', () async {
      const size = 200 * 1024 * 1024; // 200 MB
      await writeSparse(size);
      expect(MemoryEstimator.modelFileSizeBytes(modelFile.path), size);
    });

    test('estimate: requested 1 fits trivially', () async {
      const size = 100 * 1024 * 1024; // 100 MB
      await writeSparse(size);
      final est = MemoryEstimator()
        ..physicalMemoryBytesForTest = 16 * 1024 * 1024 * 1024; // 16 GB
      final r = est.estimate(requested: 1, modelPath: modelFile.path);
      expect(r.requestedWorkers, 1);
      expect(r.affordableWorkers, 1);
      expect(r.reason, 'fits');
      expect(r.wasClamped, isFalse);
    });

    test('estimate: tiny model fits 4 workers on a 16 GB host', () async {
      // 100 MB × 1.6 overhead × 4 workers = 640 MB; plus 400 MB
      // base = 1.04 GB; budget = 16 GB × 50% − 400 MB = 7.6 GB.
      // → 4 fit comfortably.
      const size = 100 * 1024 * 1024;
      await writeSparse(size);
      final est = MemoryEstimator()
        ..physicalMemoryBytesForTest = 16 * 1024 * 1024 * 1024;
      final r = est.estimate(requested: 4, modelPath: modelFile.path);
      expect(r.affordableWorkers, 4);
      expect(r.reason, 'fits');
    });

    test('estimate: huge model is clamped down on a 16 GB host',
        () async {
      // 3 GB on disk × 1.6 = 4.8 GB per worker; budget = 7.6 GB.
      // → only 1 worker fits.
      const size = 3 * 1024 * 1024 * 1024;
      await writeSparse(size);
      final est = MemoryEstimator()
        ..physicalMemoryBytesForTest = 16 * 1024 * 1024 * 1024;
      final r = est.estimate(requested: 4, modelPath: modelFile.path);
      expect(r.affordableWorkers, 1);
      expect(r.requestedWorkers, 4);
      expect(r.reason, 'clamped');
      expect(r.wasClamped, isTrue);
    });

    test(
        'estimate: medium model fits 2 of requested 4 on a tight host',
        () async {
      // 500 MB × 1.6 = 800 MB per worker.
      // On an 8 GB host: budget = 8 GB × 50% − 400 MB ≈ 3.6 GB.
      // 3.6 GB / 800 MB ≈ 4 → fits 4. Use a 3 GB host to get 2:
      // budget = 3 GB × 50% − 400 MB ≈ 1.1 GB. 1.1 GB / 800 MB = 1.
      // Calibrate up: 4 GB host → budget = 1.6 GB. 1.6 / 0.8 = 2.
      const size = 500 * 1024 * 1024;
      await writeSparse(size);
      final est = MemoryEstimator()
        ..physicalMemoryBytesForTest = 4 * 1024 * 1024 * 1024;
      final r = est.estimate(requested: 4, modelPath: modelFile.path);
      expect(r.affordableWorkers, 2,
          reason:
              'on a 4 GB host the budget is ~1.6 GB; 2× 800 MB workers fit');
      expect(r.reason, 'clamped');
    });

    test('estimate: missing model returns unknown-mem and 1 worker',
        () async {
      final est = MemoryEstimator()
        ..physicalMemoryBytesForTest = 16 * 1024 * 1024 * 1024;
      final r = est.estimate(requested: 4, modelPath: '/missing/x.gguf');
      expect(r.affordableWorkers, 1);
      expect(r.reason, 'unknown-mem');
    });

    test('estimate: null physical memory returns unknown-mem', () async {
      const size = 100 * 1024 * 1024;
      await writeSparse(size);
      final est = MemoryEstimator()..physicalMemoryBytesForTest = null;
      final r = est.estimate(requested: 4, modelPath: modelFile.path);
      expect(r.affordableWorkers, 1);
      expect(r.reason, 'unknown-mem');
    });

    test('estimate: pretty strings are non-empty and reasonable',
        () async {
      const size = 200 * 1024 * 1024;
      await writeSparse(size);
      final est = MemoryEstimator()
        ..physicalMemoryBytesForTest = 16 * 1024 * 1024 * 1024;
      final r = est.estimate(requested: 2, modelPath: modelFile.path);
      // 200 MB × 1.6 = 320 MB per worker. UI shows in MB.
      expect(r.prettyPerWorker, '320 MB');
      // physical = 16 GB (formatted with 1 decimal place).
      expect(r.prettyPhysical, '16.0 GB');
      // projection = 400 MB base + 2 × 320 MB = 1.04 GB.
      expect(r.prettyProjected, contains('GB'));
    });
  });
}
