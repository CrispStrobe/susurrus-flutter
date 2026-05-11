// EditAudioScreen — PLAN §5.1.5 Phase B.
//
// Dedicated audio editor with a waveform painter, transport
// controls, and three operations: trim, cut middle, split into
// chapters. Output is 16 kHz mono PCM WAV — same format the
// transcription pipeline expects, so a "Crop and transcribe"
// hand-off needs no re-decode.
//
// The collapsible transcript pane (bidirectional sync with the
// transcript editor) lands in Phase C. This commit ships the
// standalone editor — reach it from the transcription screen's
// "more actions" menu with the active audio file path.
//
// Cross-platform: pure Flutter + dart:io + the existing
// crispasr.decodeAudioFile FFI helper. No FFmpeg, no platform
// channels. Works identically on every platform CrisperWeaver
// ships on.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

import '../l10n/generated/app_localizations.dart';
import '../services/audio_edit_service.dart';
import '../services/log_service.dart';
import '../widgets/waveform_painter.dart';

class EditAudioScreen extends ConsumerStatefulWidget {
  const EditAudioScreen({super.key, required this.sourcePath});

  /// Absolute path to the audio file being edited. Required —
  /// the editor has no "open file" picker of its own; the user
  /// reaches this screen from the transcription screen's "more
  /// actions" menu with an audio already loaded.
  final String sourcePath;

  @override
  ConsumerState<EditAudioScreen> createState() => _EditAudioScreenState();
}

class _EditAudioScreenState extends ConsumerState<EditAudioScreen> {
  DecodedSource? _decoded;
  WaveformBars? _bars;
  double _waveformWidth = 0;
  String? _decodeError;

  final _player = AudioPlayer();
  Duration _playerPosition = Duration.zero;
  bool _isPlaying = false;

  /// Active selection on the waveform — set by drag-out on the
  /// painter. Used by Trim (write [start, end] to a new WAV) and
  /// the cut-middle op (delete the selection).
  WaveformSelection? _selection;
  /// Split markers — single-point clicks on the waveform that
  /// the user "drops" via the Add Split button when no
  /// selection is active.
  final List<WaveformCutMarker> _cutMarkers = [];

  @override
  void initState() {
    super.initState();
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _playerPosition = p);
    });
    _player.playingStream.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
    _loadAudio();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadAudio() async {
    final svc = ref.read(audioEditServiceProvider);
    try {
      // Kick off the player + decode in parallel — decoding the
      // raw PCM for the waveform is the slow step; player setup
      // is just header-reading.
      final decodeFuture = svc.decode(widget.sourcePath);
      await _player.setFilePath(widget.sourcePath);
      final decoded = await decodeFuture;
      if (!mounted) return;
      setState(() => _decoded = decoded);
    } catch (e, st) {
      Log.instance.e('audio-edit', 'decode failed',
          fields: {'path': widget.sourcePath}, error: e, stack: st);
      if (mounted) setState(() => _decodeError = e.toString());
    }
  }

  /// Lazily downsample the source to `width` columns whenever
  /// the widget gets a new layout size. Cached so a window
  /// resize doesn't re-traverse all samples on every frame.
  void _ensureBars(double width) {
    final w = width.floor();
    if (w <= 0 || _decoded == null) return;
    if (_bars != null && _waveformWidth == w.toDouble()) return;
    setState(() {
      _waveformWidth = w.toDouble();
      _bars = WaveformBars.fromSamples(
        samples: _decoded!.samples,
        targetWidth: w,
      );
    });
  }

  double _xToSec(double x, double w) {
    if (_decoded == null || _decoded!.durationSec <= 0 || w <= 0) return 0;
    return (x / w).clamp(0.0, 1.0) * _decoded!.durationSec;
  }

  void _seekTo(double sec) {
    _player.seek(Duration(milliseconds: (sec * 1000).round()));
  }

  // ----- Pointer interaction -----

  // Drag state — we treat the gesture's onPanStart as the
  // selection's left edge, onPanUpdate as the right edge. A
  // pure-tap (no drag) sets the playhead via _seekTo.
  Offset? _dragStart;

  void _onPanStart(DragStartDetails d, double width) {
    _dragStart = d.localPosition;
    final sec = _xToSec(d.localPosition.dx, width);
    setState(() => _selection = WaveformSelection(
          startSec: sec,
          endSec: sec,
        ));
  }

  void _onPanUpdate(DragUpdateDetails d, double width) {
    final start = _dragStart;
    if (start == null) return;
    final secStart = _xToSec(start.dx, width);
    final secEnd = _xToSec(d.localPosition.dx, width);
    setState(() {
      final lo = secStart < secEnd ? secStart : secEnd;
      final hi = secEnd > secStart ? secEnd : secStart;
      _selection = WaveformSelection(startSec: lo, endSec: hi);
    });
  }

  void _onTap(TapUpDetails d, double width) {
    final sec = _xToSec(d.localPosition.dx, width);
    _seekTo(sec);
  }

  // ----- Operations -----

  Future<void> _trim() async {
    final sel = _selection;
    if (sel == null || sel.endSec <= sel.startSec) {
      _toast(AppLocalizations.of(context).editAudioNeedSelection);
      return;
    }
    await _runOp(
      label: 'trim',
      op: (svc, dest) => svc.trim(
        sourcePath: widget.sourcePath,
        startSec: sel.startSec,
        endSec: sel.endSec,
        destinationPath: dest,
      ),
      defaultSuffix: 'trimmed',
    );
  }

  Future<void> _cut() async {
    final sel = _selection;
    if (sel == null || sel.endSec <= sel.startSec) {
      _toast(AppLocalizations.of(context).editAudioNeedSelection);
      return;
    }
    await _runOp(
      label: 'cut',
      op: (svc, dest) => svc.cut(
        sourcePath: widget.sourcePath,
        regions: [AudioCutRegion(sel.startSec, sel.endSec)],
        destinationPath: dest,
      ),
      defaultSuffix: 'cut',
    );
  }

  Future<void> _addSplit() async {
    if (_decoded == null) return;
    setState(() => _cutMarkers.add(WaveformCutMarker(
          startSec: _playerPosition.inMilliseconds / 1000.0,
          endSec: _playerPosition.inMilliseconds / 1000.0,
        )));
  }

  Future<void> _runSplit() async {
    if (_cutMarkers.isEmpty) {
      _toast(AppLocalizations.of(context).editAudioNeedSplitMarks);
      return;
    }
    final svc = ref.read(audioEditServiceProvider);
    final base = await _chooseSaveLocation('split');
    if (base == null) return;
    try {
      final files = await svc.split(
        sourcePath: widget.sourcePath,
        splitPoints: _cutMarkers.map((c) => c.startSec).toList(),
        destinationBuilder: (i) {
          final dir = p.dirname(base);
          final stem = p.basenameWithoutExtension(base);
          return p.join(dir, '$stem-part-${(i + 1).toString().padLeft(3, "0")}.wav');
        },
      );
      if (!mounted) return;
      _toast(AppLocalizations.of(context).editAudioSplitSaved(files.length));
    } catch (e, st) {
      Log.instance.e('audio-edit', 'split failed', error: e, stack: st);
      if (mounted) _toast(e.toString());
    }
  }

  Future<void> _runOp({
    required String label,
    required Future<File> Function(AudioEditService svc, String dest) op,
    required String defaultSuffix,
  }) async {
    final l = AppLocalizations.of(context);
    final svc = ref.read(audioEditServiceProvider);
    final dest = await _chooseSaveLocation(defaultSuffix);
    if (dest == null) return;
    try {
      final out = await op(svc, dest);
      if (!mounted) return;
      _toast(l.editAudioSavedTo(out.path));
    } catch (e, st) {
      Log.instance.e('audio-edit', '$label failed', error: e, stack: st);
      if (mounted) _toast(e.toString());
    }
  }

  Future<String?> _chooseSaveLocation(String suffix) async {
    final dir = p.dirname(widget.sourcePath);
    final stem = p.basenameWithoutExtension(widget.sourcePath);
    final defaultName = '$stem-$suffix.wav';
    final path = await FilePicker.saveFile(
      dialogTitle: AppLocalizations.of(context).editAudioSaveAs,
      initialDirectory: dir,
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: const ['wav'],
    );
    return path;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  // ----- UI -----

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.editAudioTitle)),
      body: _decodeError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.editAudioLoadFailed(_decodeError!)),
              ),
            )
          : _decoded == null
              ? const Center(child: CircularProgressIndicator())
              : _buildEditor(l),
    );
  }

  Widget _buildEditor(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Waveform + interaction layer.
        SizedBox(
          height: 180,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(builder: (context, constraints) {
              _ensureBars(constraints.maxWidth);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _onTap(d, constraints.maxWidth),
                onPanStart: (d) => _onPanStart(d, constraints.maxWidth),
                onPanUpdate: (d) => _onPanUpdate(d, constraints.maxWidth),
                onPanEnd: (_) => _dragStart = null,
                child: CustomPaint(
                  size: Size(constraints.maxWidth, 180),
                  painter: WaveformPainter(
                    bars: _bars ?? WaveformBars(peaks: const []),
                    durationSec: _decoded!.durationSec,
                    playheadSec:
                        _playerPosition.inMilliseconds / 1000.0,
                    selection: _selection,
                    cutMarkers: _cutMarkers,
                  ),
                ),
              );
            }),
          ),
        ),

        // Transport row.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                iconSize: 32,
                onPressed: () =>
                    _isPlaying ? _player.pause() : _player.play(),
              ),
              IconButton(
                icon: const Icon(Icons.stop),
                iconSize: 32,
                onPressed: () {
                  _player.pause();
                  _player.seek(Duration.zero);
                },
              ),
              const SizedBox(width: 16),
              Text(
                '${_formatDuration(_playerPosition)} / '
                '${_formatDuration(Duration(milliseconds: ((_decoded?.durationSec ?? 0) * 1000).round()))}',
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 14),
              ),
              const Spacer(),
              if (_selection != null) ...[
                Text(
                  l.editAudioSelectionLabel(
                    _formatSeconds(_selection!.startSec),
                    _formatSeconds(_selection!.endSec),
                  ),
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade700),
                ),
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: l.editAudioClearSelection,
                  onPressed: () =>
                      setState(() => _selection = null),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 8),
        // Op-button toolbar.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                icon: const Icon(Icons.content_cut, size: 18),
                label: Text(l.editAudioTrim),
                onPressed: _selection == null ? null : _trim,
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.cut, size: 18),
                label: Text(l.editAudioCut),
                onPressed: _selection == null ? null : _cut,
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add_location, size: 18),
                label: Text(l.editAudioAddSplitMark),
                onPressed: _addSplit,
              ),
              FilledButton.icon(
                icon: const Icon(Icons.call_split, size: 18),
                label: Text(l.editAudioRunSplit(_cutMarkers.length)),
                onPressed:
                    _cutMarkers.isEmpty ? null : _runSplit,
              ),
              if (_cutMarkers.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: Text(l.editAudioClearMarks),
                  onPressed: () =>
                      setState(() => _cutMarkers.clear()),
                ),
            ],
          ),
        ),

        const Divider(height: 24),
        // Help text — collapsible "How to use" so the screen
        // self-documents without bloating the toolbar.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l.editAudioHowto,
            style: TextStyle(
                fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _formatSeconds(double s) {
    final d = Duration(milliseconds: (s * 1000).round());
    return _formatDuration(d);
  }
}
