// Speaker-rename behaviour on AppStateNotifier. The mapping is
// applied at render time, so the contract is just: empty inputs are
// no-ops, trimming happens, an empty new-name clears the override,
// and startTranscription wipes the map for the next session.
import 'package:flutter_test/flutter_test.dart';

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
}
