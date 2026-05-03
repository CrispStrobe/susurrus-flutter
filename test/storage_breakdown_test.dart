// Storage breakdown — file-walk + grouping logic. Drops fake files
// into a temp dir under known backend names and asserts the
// per-backend totals match. Catches regressions in the .tmp
// stripping and "(other)" bucketing.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:crisper_weaver/services/model_service.dart';

void main() {
  late Directory tmp;

  // Catalog filenames mirroring real ModelService entries — keeps the
  // shape honest. We pretend whisper has two quants, parakeet one,
  // kokoro a voicepack.
  const byFilename = <String, String>{
    'ggml-tiny.bin': 'whisper',
    'ggml-base.bin': 'whisper',
    'parakeet-v3-q4_k.gguf': 'parakeet',
    'kokoro-voice-en_US-amy-q8_0.gguf': 'kokoro',
  };

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('crisper_storage_test_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<File> drop(String name, int bytes) async {
    final f = File(p.join(tmp.path, name));
    await f.writeAsBytes(List<int>.filled(bytes, 0));
    return f;
  }

  group('groupDirByBackend', () {
    test('empty dir → empty list', () async {
      final out = await ModelService.groupDirByBackend(tmp, byFilename);
      expect(out, isEmpty);
    });

    test('groups files by their catalogued backend', () async {
      await drop('ggml-tiny.bin', 1000);
      await drop('ggml-base.bin', 5000);
      await drop('parakeet-v3-q4_k.gguf', 2000);

      final out = await ModelService.groupDirByBackend(tmp, byFilename);

      final whisper =
          out.firstWhere((g) => g.backend == 'whisper');
      expect(whisper.bytes, 6000);
      expect(whisper.fileCount, 2);

      final parakeet = out.firstWhere((g) => g.backend == 'parakeet');
      expect(parakeet.bytes, 2000);
      expect(parakeet.fileCount, 1);
    });

    test('uncatalogued files land in the (other) bucket', () async {
      await drop('ggml-tiny.bin', 1000);
      await drop('mystery-file.bin', 500);
      await drop('leftover.txt', 250);

      final out = await ModelService.groupDirByBackend(tmp, byFilename);

      final other = out.firstWhere((g) => g.backend == '(other)');
      expect(other.bytes, 750);
      expect(other.fileCount, 2);
    });

    test('strips trailing .tmp before backend lookup', () async {
      // An in-progress download — file ends in .tmp but logically
      // belongs to its target backend.
      await drop('ggml-tiny.bin.tmp', 1234);

      final out = await ModelService.groupDirByBackend(tmp, byFilename);
      final whisper = out.firstWhere((g) => g.backend == 'whisper');
      expect(whisper.bytes, 1234);
      expect(whisper.fileCount, 1);
      // No "(other)" bucket because .tmp stripped to a known name.
      expect(out.where((g) => g.backend == '(other)'), isEmpty);
    });

    test('result is sorted by descending bytes', () async {
      await drop('ggml-tiny.bin', 100);
      await drop('parakeet-v3-q4_k.gguf', 5000);
      await drop('mystery.bin', 1000);

      final out = await ModelService.groupDirByBackend(tmp, byFilename);
      // Order: parakeet (5000) > (other) (1000) > whisper (100)
      expect(out.map((g) => g.backend).toList(),
          ['parakeet', '(other)', 'whisper']);
    });

    test('walks recursively into nested dirs', () async {
      // Real downloads sometimes land in subdirs (CoreML .mlmodelc
      // expansions, model variant subfolders).
      final sub = Directory(p.join(tmp.path, 'subdir'));
      await sub.create();
      await File(p.join(sub.path, 'ggml-tiny.bin'))
          .writeAsBytes(List<int>.filled(2048, 0));

      final out = await ModelService.groupDirByBackend(tmp, byFilename);
      final whisper = out.firstWhere((g) => g.backend == 'whisper');
      expect(whisper.bytes, 2048);
    });
  });

  group('deleteBackendFilesIn', () {
    test('deletes only files matching the requested backend', () async {
      final keep = await drop('parakeet-v3-q4_k.gguf', 100);
      final go1 = await drop('ggml-tiny.bin', 500);
      final go2 = await drop('ggml-base.bin', 1500);
      final other = await drop('mystery.bin', 250);

      final freed = await ModelService.deleteBackendFilesIn(
          tmp, byFilename, 'whisper');

      expect(freed, 2000);
      expect(await keep.exists(), isTrue);
      expect(await go1.exists(), isFalse);
      expect(await go2.exists(), isFalse);
      expect(await other.exists(), isTrue,
          reason: '(other) bucket not deleted by backend sweep');
    });

    test('also deletes in-progress .tmp files for the backend', () async {
      final tmpfile = await drop('ggml-tiny.bin.tmp', 4096);
      final freed = await ModelService.deleteBackendFilesIn(
          tmp, byFilename, 'whisper');
      expect(freed, 4096);
      expect(await tmpfile.exists(), isFalse);
    });

    test('returns 0 when no files match', () async {
      await drop('parakeet-v3-q4_k.gguf', 100);
      final freed = await ModelService.deleteBackendFilesIn(
          tmp, byFilename, 'voxtral');
      expect(freed, 0);
    });
  });
}
