import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'log_service.dart';

/// Register licenses for the *native* dependencies CrisperWeaver bundles —
/// `showLicensePage` only surfaces pub/Dart packages by default, so CrispASR,
/// whisper.cpp, and the ggml runtime would otherwise be invisible.
///
/// The license text is shipped as an asset under `assets/licenses/` and
/// registered via Flutter's built-in `LicenseRegistry`. That keeps everything
/// in one place — the same in-app screen that lists pub deps now lists the
/// FFI runtime too, no separate searchable JSON to maintain.
Future<void> registerNativeLicenses() async {
  LicenseRegistry.addLicense(() async* {
    try {
      final crispasr =
          await rootBundle.loadString('assets/licenses/CrispASR.txt');
      yield LicenseEntryWithLineBreaks(
        const ['CrispASR', 'whisper.cpp', 'ggml'],
        crispasr,
      );
    } catch (e, st) {
      Log.instance.w('licenses',
          'Failed to load CrispASR/whisper.cpp/ggml license',
          error: e, stack: st);
    }

    // Short in-line attributions for upstream model weights.
    yield const LicenseEntryWithLineBreaks(
      ['Whisper model weights (OpenAI)'],
      '''Whisper model weights are distributed by OpenAI under the MIT License.
See: https://github.com/openai/whisper/blob/main/LICENSE

CrisperWeaver downloads Whisper GGML conversions hosted on HuggingFace
(ggerganov/whisper.cpp, cstr/whisper-ggml-quants). The weights remain under
their original licenses; only the on-disk GGML re-packing is attributable to
the respective HuggingFace repo maintainers.''',
    );
  });
}
