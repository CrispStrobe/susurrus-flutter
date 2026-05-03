// Boundary-test the byte formatter on StorageInfo + BackendStorage.
// Both types' formatters live close together but diverge subtly (GB
// precision: StorageInfo = 1 dp, BackendStorage = 2 dp) — a refactor
// that "unifies" them would silently change the UI.
import 'package:flutter_test/flutter_test.dart';

import 'package:crisper_weaver/services/model_service.dart';

void main() {
  group('StorageInfo.formatted', () {
    StorageInfo at(int b) => StorageInfo(whisperCppBytes: b, totalBytes: b);

    test('< 1 KB → bytes', () {
      expect(at(0).formattedTotal, '0 B');
      expect(at(512).formattedTotal, '512 B');
      expect(at(1023).formattedTotal, '1023 B');
    });

    test('1 KB ≤ x < 1 MB → KB with 1 dp', () {
      expect(at(1024).formattedTotal, '1.0 KB');
      expect(at(1536).formattedTotal, '1.5 KB');
      expect(at(1024 * 1024 - 1).formattedTotal, '1024.0 KB');
    });

    test('1 MB ≤ x < 1 GB → MB with no dp', () {
      expect(at(1024 * 1024).formattedTotal, '1 MB');
      expect(at(150 * 1024 * 1024).formattedTotal, '150 MB');
      expect(at(1024 * 1024 * 1024 - 1).formattedTotal, '1024 MB');
    });

    test('≥ 1 GB → GB with 1 dp', () {
      expect(at(1024 * 1024 * 1024).formattedTotal, '1.0 GB');
      // 4.5 GB exact
      expect(at((4.5 * 1024 * 1024 * 1024).round()).formattedTotal, '4.5 GB');
    });
  });

  group('BackendStorage.formattedSize', () {
    BackendStorage at(int b) =>
        BackendStorage(backend: 'whisper', bytes: b, fileCount: 1);

    test('< 1 KB → bytes', () {
      expect(at(0).formattedSize, '0 B');
      expect(at(999).formattedSize, '999 B');
    });

    test('1 KB ≤ x < 1 MB → KB with 1 dp', () {
      expect(at(2048).formattedSize, '2.0 KB');
      expect(at(2560).formattedSize, '2.5 KB');
    });

    test('1 MB ≤ x < 1 GB → MB with no dp', () {
      expect(at(5 * 1024 * 1024).formattedSize, '5 MB');
      expect(at(750 * 1024 * 1024).formattedSize, '750 MB');
    });

    test('≥ 1 GB → GB with 2 dp (vs StorageInfo which uses 1 dp)', () {
      expect(at(1024 * 1024 * 1024).formattedSize, '1.00 GB');
      expect(at((1.25 * 1024 * 1024 * 1024).round()).formattedSize, '1.25 GB');
      expect(at((4.5 * 1024 * 1024 * 1024).round()).formattedSize, '4.50 GB');
    });
  });
}
