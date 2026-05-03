// AppStateNotifier — speaker rename + transcription lifecycle. Pure
// state machine, easy to drive directly without a ProviderContainer.
import 'package:flutter_test/flutter_test.dart';

import 'package:crisper_weaver/engines/transcription_engine.dart';
import 'package:crisper_weaver/main.dart' show AppStateNotifier;

void main() {
  group('AppStateNotifier.renameSpeaker', () {
    test('starts with no overrides', () {
      final n = AppStateNotifier();
      expect(n.state.speakerNames, isEmpty);
    });

    test('sets and overrides a name', () {
      final n = AppStateNotifier();
      n.renameSpeaker('Speaker 1', 'Alice');
      expect(n.state.speakerNames, {'Speaker 1': 'Alice'});

      n.renameSpeaker('Speaker 1', 'Alicia');
      expect(n.state.speakerNames, {'Speaker 1': 'Alicia'});
    });

    test('keeps multiple overrides in parallel', () {
      final n = AppStateNotifier();
      n.renameSpeaker('Speaker 1', 'Alice');
      n.renameSpeaker('Speaker 2', 'Bob');
      expect(n.state.speakerNames, {
        'Speaker 1': 'Alice',
        'Speaker 2': 'Bob',
      });
    });

    test('trims surrounding whitespace from the new name', () {
      final n = AppStateNotifier();
      n.renameSpeaker('Speaker 1', '   Alice   ');
      expect(n.state.speakerNames['Speaker 1'], 'Alice');
    });

    test('whitespace-only new name removes the override', () {
      final n = AppStateNotifier();
      n.renameSpeaker('Speaker 1', 'Alice');
      n.renameSpeaker('Speaker 1', '   ');
      expect(n.state.speakerNames.containsKey('Speaker 1'), isFalse);
    });

    test('empty new name removes the override (reset)', () {
      final n = AppStateNotifier();
      n.renameSpeaker('Speaker 1', 'Alice');
      n.renameSpeaker('Speaker 1', '');
      expect(n.state.speakerNames.containsKey('Speaker 1'), isFalse);
    });

    test('empty original is a no-op', () {
      final n = AppStateNotifier();
      n.renameSpeaker('Speaker 1', 'Alice');
      n.renameSpeaker('', 'Charlie');
      expect(n.state.speakerNames, {'Speaker 1': 'Alice'});
    });

    test('startTranscription wipes the rename map', () {
      final n = AppStateNotifier();
      n.renameSpeaker('Speaker 1', 'Alice');
      n.startTranscription();
      expect(n.state.speakerNames, isEmpty);
      expect(n.state.isTranscribing, isTrue);
      expect(n.state.segments, isEmpty);
    });
  });

  group('AppStateNotifier transcription lifecycle', () {
    TranscriptionSegment seg(String t, double start, double end) =>
        TranscriptionSegment(
            text: t, startTime: start, endTime: end, confidence: 1.0);

    test('updateProgress clamps to [0, 1]', () {
      final n = AppStateNotifier();
      n.updateProgress(0.5);
      expect(n.state.progress, 0.5);
      n.updateProgress(1.5);
      expect(n.state.progress, 1.0);
      n.updateProgress(-0.2);
      expect(n.state.progress, 0.0);
    });

    test('addSegment appends and rebuilds the joined transcription text',
        () {
      final n = AppStateNotifier();
      n.addSegment(seg('Hello.', 0.0, 1.0));
      expect(n.state.segments.length, 1);
      expect(n.state.currentTranscription, 'Hello.');

      n.addSegment(seg('World.', 1.0, 2.0));
      expect(n.state.segments.length, 2);
      expect(n.state.currentTranscription, 'Hello. World.');
    });

    test('completeTranscription sets isTranscribing=false + progress=1', () {
      final n = AppStateNotifier();
      n.startTranscription();
      n.completeTranscription([seg('a', 0, 1), seg('b', 1, 2)]);
      expect(n.state.isTranscribing, isFalse);
      expect(n.state.progress, 1.0);
      expect(n.state.currentTranscription, 'a b');
      expect(n.state.errorMessage, isNull);
    });

    test('setError clears isTranscribing and stores the message', () {
      final n = AppStateNotifier();
      n.startTranscription();
      n.setError('boom');
      expect(n.state.isTranscribing, isFalse);
      expect(n.state.errorMessage, 'boom');
    });

    test('clearTranscription resets to a fresh AppState', () {
      final n = AppStateNotifier();
      n.addSegment(seg('a', 0, 1));
      n.renameSpeaker('Speaker 1', 'Alice');
      n.clearTranscription();
      expect(n.state.segments, isEmpty);
      expect(n.state.currentTranscription, isNull);
      expect(n.state.speakerNames, isEmpty);
    });

    test('replaceLiveStreamingText overwrites without touching segments',
        () {
      final n = AppStateNotifier();
      n.addSegment(seg('frozen', 0, 1));
      n.replaceLiveStreamingText('rolling decode latest');
      expect(n.state.currentTranscription, 'rolling decode latest');
      expect(n.state.segments.length, 1);
      expect(n.state.segments[0].text, 'frozen');
    });

    test('editSegment replaces text + flags edited in metadata', () {
      final n = AppStateNotifier();
      n.addSegment(seg('original text', 0, 1));
      n.editSegment(0, 'corrected text');
      expect(n.state.segments[0].text, 'corrected text');
      expect(n.state.segments[0].metadata['edited'], isTrue);
      expect(n.state.currentTranscription, 'corrected text');
    });

    test('editSegment with out-of-range index is a no-op', () {
      final n = AppStateNotifier();
      n.addSegment(seg('original', 0, 1));
      n.editSegment(5, 'should not happen');
      expect(n.state.segments[0].text, 'original');
      n.editSegment(-1, 'should not happen');
      expect(n.state.segments[0].text, 'original');
    });
  });
}
