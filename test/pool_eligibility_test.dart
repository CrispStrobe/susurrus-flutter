// Tests for [poolEligible] — the §5.23 Q2 v2 pool gatekeeper.
//
// After the Q2 v2.1 polish round, the worker isolate carries every
// sticky session-state setter (translate / targetLanguage /
// askPrompt / temperature / bestOf) and supports VAD via
// `transcribeVad`. Diarization + punctuation now run as a main-
// isolate post-process. So the eligibility check has only THREE
// genuine blockers left, and these tests pin them.

import 'package:crisper_weaver/services/batch_queue_service.dart';
import 'package:crisper_weaver/services/transcription_worker_pool.dart';
import 'package:crisper_weaver/widgets/advanced_options_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('poolEligible', () {
    final freshJob = BatchJob(
      id: 'j1',
      filePath: '/p/foo.wav',
      createdAt: DateTime.utc(2026, 5, 11),
    );

    test('vanilla job + default options → eligible', () {
      expect(
          poolEligible(freshJob, const AdvancedOptions(),
              enableDiarization: false),
          isTrue);
    });

    test('resume offset > 0 → ineligible (chunked-whisper only)', () {
      final resumed = freshJob.copyWith(resumeOffsetSec: 12.5);
      expect(
          poolEligible(resumed, const AdvancedOptions(),
              enableDiarization: false),
          isFalse);
    });

    test('resume offset == 0 or null → eligible', () {
      expect(
          poolEligible(freshJob.copyWith(resumeOffsetSec: 0),
              const AdvancedOptions(),
              enableDiarization: false),
          isTrue);
      expect(
          poolEligible(freshJob, const AdvancedOptions(),
              enableDiarization: false),
          isTrue,
          reason: 'null resumeOffsetSec equals "no resume"');
    });

    test('beamSearch ON → ineligible (whisper-only feature)', () {
      expect(
          poolEligible(freshJob, const AdvancedOptions(beamSearch: true),
              enableDiarization: false),
          isFalse);
    });

    test('tdrz ON → ineligible (whisper-only feature)', () {
      expect(
          poolEligible(freshJob, const AdvancedOptions(tdrz: true),
              enableDiarization: false),
          isFalse);
    });

    test('VAD ON → eligible (worker calls transcribeVad)', () {
      expect(
          poolEligible(freshJob, const AdvancedOptions(vad: true),
              enableDiarization: false),
          isTrue);
    });

    test('translate / targetLanguage / askPrompt → eligible (sticky '
        'setters in worker protocol)', () {
      expect(
          poolEligible(freshJob, const AdvancedOptions(translate: true),
              enableDiarization: false),
          isTrue);
      expect(
          poolEligible(
              freshJob, const AdvancedOptions(targetLanguage: 'de'),
              enableDiarization: false),
          isTrue);
      expect(
          poolEligible(
              freshJob, const AdvancedOptions(askPrompt: 'summarise'),
              enableDiarization: false),
          isTrue);
    });

    test('temperature > 0 / bestOf > 1 → eligible (sticky setters)', () {
      expect(
          poolEligible(
              freshJob, const AdvancedOptions(temperature: 0.5),
              enableDiarization: false),
          isTrue);
      expect(
          poolEligible(freshJob, const AdvancedOptions(bestOf: 5),
              enableDiarization: false),
          isTrue);
    });

    test('diarization enabled → eligible (post-process on main thread)',
        () {
      expect(
          poolEligible(freshJob, const AdvancedOptions(),
              enableDiarization: true),
          isTrue);
    });

    test(
        'restorePunctuation ON → eligible (post-process on main thread)',
        () {
      expect(
          poolEligible(
              freshJob, const AdvancedOptions(restorePunctuation: true),
              enableDiarization: false),
          isTrue);
    });

    test(
        'mixed advanced job (translate + temperature + bestOf + VAD '
        '+ diarize + punc) is still eligible — none of those are '
        'genuine blockers any more',
        () {
      expect(
          poolEligible(
            freshJob,
            const AdvancedOptions(
              translate: true,
              targetLanguage: 'en',
              temperature: 0.3,
              bestOf: 3,
              vad: true,
              restorePunctuation: true,
            ),
            enableDiarization: true,
          ),
          isTrue);
    });

    test(
        'beamSearch + everything else → still ineligible — beamSearch '
        'is the disqualifier and order of checks does not matter',
        () {
      expect(
          poolEligible(
            freshJob,
            const AdvancedOptions(
              beamSearch: true,
              translate: true,
              vad: true,
            ),
            enableDiarization: true,
          ),
          isFalse);
    });
  });
}
