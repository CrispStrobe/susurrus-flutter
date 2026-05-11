// WaveformPainter — PLAN §5.1.5 Phase B.
//
// Renders a downsampled audio waveform as vertical bars, plus
// overlays for: the current playhead position, a selection band
// (start / end markers for trim & cut), and zero or more cut
// markers (for split & cut-middle ops).
//
// Design choices:
//   • Per-pixel-column reduction = max(|sample|) over the N/M
//     samples it covers. Cheap (O(samples)), no FFT, no
//     SoundCloud-style logarithmic compression. Visually
//     consistent across short and long files.
//   • Pre-compute the column peaks ONCE per source + width,
//     cache in [WaveformBars]. Callers re-create the bars only
//     when the underlying samples or the widget width change;
//     marker/playhead/selection updates skip the recompute.
//   • Painter is dumb: takes already-precomputed peaks +
//     overlay state and draws. Interaction (drag-to-set-marker,
//     tap-to-seek) lives in the enclosing widget — the painter
//     is shouldRepaint-cheap because all inputs are immutable
//     value-types.

import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Pre-computed per-column peaks for a given (samples, width)
/// pair. Construction is O(samples); painting is O(width).
class WaveformBars {
  WaveformBars({required this.peaks});

  /// One value in [0, 1] per pixel column — the maximum
  /// absolute sample magnitude within that column's span.
  final List<double> peaks;

  /// Convenience ctor that downsamples a Float32 PCM buffer
  /// into `targetWidth` columns. `samples` may exceed
  /// [int] range on platforms with 32-bit Dart? No — Float32List
  /// length is int, fine.
  factory WaveformBars.fromSamples({
    required Float32List samples,
    required int targetWidth,
  }) {
    if (targetWidth <= 0 || samples.isEmpty) {
      return WaveformBars(peaks: const []);
    }
    final stride = samples.length / targetWidth;
    final out = List<double>.filled(targetWidth, 0.0);
    for (var col = 0; col < targetWidth; col++) {
      final lo = (col * stride).floor();
      final hi = ((col + 1) * stride).floor().clamp(lo + 1, samples.length);
      double peak = 0.0;
      for (var i = lo; i < hi; i++) {
        final m = samples[i].abs();
        if (m > peak) peak = m;
      }
      if (peak > 1.0) peak = 1.0; // defensive clip — same as the WAV encoder
      out[col] = peak;
    }
    return WaveformBars(peaks: out);
  }
}

/// Active selection on the waveform (e.g. drag-out a band, or
/// segment-pasted from the transcript pane). Both bounds in
/// seconds; null means "no selection".
class WaveformSelection {
  const WaveformSelection({required this.startSec, required this.endSec});
  final double startSec;
  final double endSec;
}

/// Cut markers — drawn as red vertical bands at each [a, b]
/// pair. Used by the cut-middle op (the user marks regions
/// in the transcript or directly on the waveform) and by the
/// split op (a degenerate cut where a == b draws a single
/// vertical line).
class WaveformCutMarker {
  const WaveformCutMarker({required this.startSec, required this.endSec});
  final double startSec;
  final double endSec;
  bool get isSplitMark => startSec == endSec;
}

class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.bars,
    required this.durationSec,
    required this.playheadSec,
    this.selection,
    this.cutMarkers = const [],
    this.waveColor = const Color(0xFF5B6BCA),
    this.playheadColor = const Color(0xFFFF5252),
    this.selectionFill = const Color(0x3300C853), // green @ 20%
    this.cutFill = const Color(0x33FF5252),       // red @ 20%
    this.backgroundColor = const Color(0xFFF5F5F5),
  });

  final WaveformBars bars;
  final double durationSec;
  final double playheadSec;
  final WaveformSelection? selection;
  final List<WaveformCutMarker> cutMarkers;
  final Color waveColor;
  final Color playheadColor;
  final Color selectionFill;
  final Color cutFill;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final mid = h / 2;

    // Background fill.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = backgroundColor,
    );

    // Selection band — drawn BEHIND the waveform so the bars
    // stay readable on top.
    if (selection != null && durationSec > 0) {
      final x0 = (selection!.startSec / durationSec).clamp(0.0, 1.0) * w;
      final x1 = (selection!.endSec / durationSec).clamp(0.0, 1.0) * w;
      final lo = x0 < x1 ? x0 : x1;
      final hi = x1 > x0 ? x1 : x0;
      canvas.drawRect(
        Rect.fromLTRB(lo, 0, hi, h),
        Paint()..color = selectionFill,
      );
    }

    // Cut markers — drawn behind the waveform too, in red.
    if (durationSec > 0) {
      for (final c in cutMarkers) {
        final x0 = (c.startSec / durationSec).clamp(0.0, 1.0) * w;
        final x1 = (c.endSec / durationSec).clamp(0.0, 1.0) * w;
        if (c.isSplitMark) {
          // 2-pixel vertical line.
          canvas.drawRect(
            Rect.fromLTWH(x0 - 1, 0, 2, h),
            Paint()..color = cutFill.withAlpha(0xCC),
          );
        } else {
          canvas.drawRect(
            Rect.fromLTRB(x0, 0, x1, h),
            Paint()..color = cutFill,
          );
        }
      }
    }

    // Waveform bars — one column per pixel. Use a thin stroke
    // so adjacent columns visually merge into a continuous
    // amplitude envelope.
    final wavePaint = Paint()
      ..color = waveColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final cols = bars.peaks.length;
    if (cols > 0) {
      final colWidth = w / cols;
      for (var i = 0; i < cols; i++) {
        final p = bars.peaks[i];
        final half = p * (h * 0.45);
        final x = (i + 0.5) * colWidth;
        canvas.drawLine(
          Offset(x, mid - half),
          Offset(x, mid + half),
          wavePaint,
        );
      }
    }

    // Playhead — drawn ON TOP of everything else so it's always
    // visible regardless of selection / cut overlap.
    if (durationSec > 0 && playheadSec >= 0) {
      final x = (playheadSec / durationSec).clamp(0.0, 1.0) * w;
      canvas.drawRect(
        Rect.fromLTWH(x - 1, 0, 2, h),
        Paint()..color = playheadColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter old) {
    return old.bars != bars ||
        old.durationSec != durationSec ||
        old.playheadSec != playheadSec ||
        old.selection != selection ||
        old.cutMarkers != cutMarkers ||
        old.waveColor != waveColor ||
        old.playheadColor != playheadColor ||
        old.selectionFill != selectionFill ||
        old.cutFill != cutFill ||
        old.backgroundColor != backgroundColor;
  }
}
