// CrispASR 0.6 parity catalog — pins the entries added in the May 2026
// sweep so a future model_service refactor doesn't quietly drop them
// from the model picker.
//
// What this catches:
//   * a rename / typo of a CrispASR backend id (gemma4-e2b →
//     gemma-4-e2b) — the affected entry vanishes from the picker;
//   * a missing companion link (qwen3-tts-voicedesign needs the same
//     codec/tokenizer as the base qwen3-tts);
//   * dropping the ModelKind annotation that lets the Model
//     Management filter chips group VAD / LID / diarisation GGUFs.

import 'package:flutter_test/flutter_test.dart';

import 'package:crisper_weaver/services/model_service.dart';

void main() {
  group('CrispASR 0.6 parity catalog', () {
    test('every new backend is in the model catalog', () {
      // New backends added in the parity sweep — each needs at least
      // one ModelDefinition keyed by backend id so the Model Manager
      // can offer a download.
      const expectedNewBackends = [
        'gemma4-e2b',
        'omniasr-llm-unlimited',
        'granite-4.1',
        'granite-4.1-plus',
        'granite-4.1-nar',
        'chatterbox',
        'indextts',
        'fullstop-punc',
        'pyannote',
        'vad',
        'lid',
      ];
      final actualBackends =
          ModelService.crispasrBackendModels.values.map((m) => m.backend).toSet();
      for (final b in expectedNewBackends) {
        expect(actualBackends, contains(b),
            reason: 'parity sweep added the "$b" backend; catalog must keep '
                'at least one entry pointing at it');
      }
    });

    test('each new backend has a BackendRepo for HF auto-probe', () {
      // Repo entries drive the Model Manager's "refresh from HuggingFace"
      // button. Without one, the only model a user sees is the
      // hardcoded q4_k (or whatever the catalog ships) — no quants
      // surface unless they're manually downloaded.
      const expectedRepos = [
        'gemma4-e2b',
        'omniasr-llm-unlimited',
        'granite-4.1',
        'granite-4.1-plus',
        'granite-4.1-nar',
        'chatterbox',
        'indextts',
        'fullstop-punc',
        'pyannote',
      ];
      for (final backend in expectedRepos) {
        expect(ModelService.backendRepos.containsKey(backend), isTrue,
            reason: 'BackendRepo "$backend" missing — HF probe will skip it');
      }
    });

    test('TTS additions are kind=tts so Model Manager filters them', () {
      // Chatterbox / IndexTTS / qwen3-tts VoiceDesign / vibevoice-1.5b
      // are TTS backends — they belong in the TTS filter chip, not
      // the default ASR view.
      for (final id in [
        'chatterbox-en-q8_0',
        'kartoffelbox-de-q8_0',
        'indextts-q8_0',
        'qwen3-tts-12hz-1.7b-voicedesign-q8_0',
        'vibevoice-1.5b-tts-f32-tokenizer',
      ]) {
        final def = ModelService.crispasrBackendModels[id];
        expect(def, isNotNull, reason: '$id missing from catalog');
        expect(def!.kind, ModelKind.tts,
            reason: '$id should be ModelKind.tts (TTS filter chip)');
      }
    });

    test('post-processor + diarize + vad + lid each have the right kind', () {
      // fullstop-punc → punc; pyannote → diarize; firered-vad → vad;
      // silero-lang95 → lid. These bucket assignments drive the new
      // filter chips in Model Management.
      expect(ModelService.crispasrBackendModels['fullstop-punc-multilang-q8_0']
              ?.kind,
          ModelKind.punc);
      expect(
          ModelService.crispasrBackendModels['pyannote-v3-seg-q8_0']?.kind,
          ModelKind.diarize);
      expect(
          ModelService.crispasrBackendModels['firered-vad-q4_k']?.kind,
          ModelKind.vad);
      expect(
          ModelService.crispasrBackendModels['silero-lang95-v1-f16']?.kind,
          ModelKind.lid);
    });

    test('qwen3-tts VoiceDesign keeps the codec/tokenizer companion', () {
      // Synthesize screen looks up `companions` to suggest extra
      // downloads. Drop the link and users see "missing codec" only
      // at first synth, not on the model card.
      final def = ModelService
          .crispasrBackendModels['qwen3-tts-12hz-1.7b-voicedesign-q8_0'];
      expect(def, isNotNull);
      expect(def!.companions, contains('qwen3-tts-tokenizer-12hz'));
    });
  });
}
