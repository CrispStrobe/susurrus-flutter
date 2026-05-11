// Responsive helpers — small, focused utilities for adapting UI
// to the viewport without rebuilding the layout from scratch.
//
// The app is designed-for-desktop primary, phone-secondary. We
// don't switch to a separate widget tree per form factor; we
// just *clamp / collapse* the existing one when the viewport
// can't fit the designed width. These helpers are the
// vocabulary for "how narrow are we?".

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/generated/app_localizations.dart';

/// Hard breakpoints we use throughout the app. Picked to match
/// what TranscriptionScreen / EditAudioScreen already use, so a
/// new caller's "narrow" matches the existing layouts' "narrow"
/// without bespoke per-screen tuning.
class Breakpoints {
  /// Below this the AppBar should drop subtitles and move
  /// secondary actions into an overflow menu. Roughly "phone in
  /// portrait or split-screen tablet".
  static const double compact = 600;

  /// Below this we treat the viewport as a phone. Dialogs flip
  /// to Dialog.fullscreen, the main screen reflows to a tabbed
  /// layout, and bottom nav replaces top-bar actions.
  static const double phone = 480;
}

/// Width to pass to `SizedBox(width: …)` inside an AlertDialog's
/// `content`. Returns the smaller of [designed] and "viewport
/// minus a 16-px margin on each side", so dialogs never overflow
/// the screen on phones / narrow desktop windows.
///
/// Use everywhere the dialog content currently hardcodes a
/// width — `SizedBox(width: responsiveDialogWidth(context, designed: 560))`.
double responsiveDialogWidth(BuildContext context, {double designed = 560}) {
  final w = MediaQuery.sizeOf(context).width;
  // 32 = 16 px margin per side, matching the Material spec's
  // default dialog insets. Floor at 0 for safety when called
  // under a test pump with a zero-size viewport.
  final available = math.max(0.0, w - 32);
  return math.min(designed, available);
}

/// Height to pass to `SizedBox(height: …)` inside an AlertDialog's
/// `content` when the dialog needs a bounded vertical area
/// (e.g. for an Expanded child like a result list). Returns the
/// smaller of [designed] and "viewport height minus chrome",
/// where chrome covers title + actions + insets — empirically
/// ~200 px is enough on phones in portrait.
double responsiveDialogHeight(BuildContext context,
    {double designed = 560, double chrome = 200}) {
  final h = MediaQuery.sizeOf(context).height;
  final available = math.max(160.0, h - chrome);
  return math.min(designed, available);
}

/// True when the viewport is phone-sized. Dialogs that opt into
/// the [showResponsiveDialog] helper get a Dialog.fullscreen
/// scaffolding here.
bool isPhoneWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width < Breakpoints.phone;

/// True when the viewport is too narrow to comfortably show
/// secondary AppBar actions and 2-line titles. AppBar callers
/// drop subtitle text and push extra actions into an overflow
/// menu here.
bool isCompactWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width < Breakpoints.compact;

/// A pair of (value, label) used by [AdaptiveSegmentedButton] —
/// kept structural rather than depending on the Material
/// [ButtonSegment] type so we can build the dropdown items too
/// without forcing callers to materialise both shapes.
class AdaptiveSegment<T> {
  const AdaptiveSegment({
    required this.value,
    required this.label,
    this.enabled = true,
  });
  final T value;
  final String label;
  final bool enabled;
}

/// SegmentedButton on wide viewports, DropdownButton on phones.
/// Same value-selection semantics either way — the caller sees
/// `selected: {value}` in and `onSelectionChanged: (newValue)`
/// out, no per-form-factor branching at the call site.
///
/// Why both shapes: SegmentedButton looks great at desktop /
/// tablet widths but its labels expand to text width and start
/// overflowing on narrow viewports once labels are localised
/// (German, Russian, …). Dropdown is the standard phone-form
/// fallback — one tap to open, every option in the menu, no
/// horizontal-space contention with the rest of the dialog.
class AdaptiveSegmentedButton<T> extends StatelessWidget {
  const AdaptiveSegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.compactBreakpoint = Breakpoints.compact,
  });

  final List<AdaptiveSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Viewport width at which we flip to the dropdown form.
  /// Defaults to [Breakpoints.compact]; callers in already-
  /// narrow containers (e.g. a dialog with width < 480) can
  /// pass a higher number to force the dropdown unconditionally.
  final double compactBreakpoint;

  @override
  Widget build(BuildContext context) {
    final narrow =
        MediaQuery.sizeOf(context).width < compactBreakpoint;
    if (!narrow) {
      return SegmentedButton<T>(
        segments: [
          for (final seg in segments)
            ButtonSegment<T>(
              value: seg.value,
              enabled: seg.enabled,
              label: Text(seg.label),
            ),
        ],
        selected: <T>{selected},
        onSelectionChanged: (sel) => onChanged(sel.first),
      );
    }
    // Compact form: a Material InputDecorator-wrapped
    // DropdownButton so the visual weight roughly matches the
    // SegmentedButton it replaces.
    return DropdownButtonFormField<T>(
      initialValue: selected,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding:
            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(),
      ),
      items: [
        for (final seg in segments)
          DropdownMenuItem<T>(
            value: seg.value,
            enabled: seg.enabled,
            child: Text(
              seg.label,
              style: TextStyle(
                color: seg.enabled ? null : Theme.of(context).disabledColor,
              ),
            ),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// Primary navigation destinations that the phone NavigationBar
/// surfaces. Keep this list small — bottom nav is for the
/// destinations users hit constantly, not every route in the app.
/// Secondary destinations (Models / Synthesize / Translate /
/// Logs / About) stay in the AppBar's overflow menu.
enum PhoneNavDestination { transcribe, history, settings }

/// Bottom NavigationBar used only on phone-width viewports.
/// Each primary screen sets it as its Scaffold's
/// `bottomNavigationBar`; the helper picks the correct selected
/// index from the [current] argument and `go()`s to the
/// destination on tap (replace, not push, so the back stack
/// doesn't pile up between primary destinations).
class PhoneNavBar extends StatelessWidget {
  const PhoneNavBar({super.key, required this.current});

  final PhoneNavDestination current;

  static String _routeFor(PhoneNavDestination d) {
    switch (d) {
      case PhoneNavDestination.transcribe:
        return '/';
      case PhoneNavDestination.history:
        return '/history';
      case PhoneNavDestination.settings:
        return '/settings';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return NavigationBar(
      selectedIndex: PhoneNavDestination.values.indexOf(current),
      onDestinationSelected: (i) {
        final dest = PhoneNavDestination.values[i];
        if (dest == current) return;
        // GoRouter's go() replaces the current location, so
        // bouncing between Home / History / Settings doesn't
        // pile up the back stack the way push() would.
        context.go(_routeFor(dest));
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.mic_none_outlined),
          selectedIcon: const Icon(Icons.mic),
          label: l.navHome,
        ),
        NavigationDestination(
          icon: const Icon(Icons.history_outlined),
          selectedIcon: const Icon(Icons.history),
          label: l.menuHistory,
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: l.menuSettings,
        ),
      ],
    );
  }
}

/// One-stop dialog show helper that adapts between AlertDialog
/// and Dialog.fullscreen based on the viewport.
///
/// Designed to absorb the existing pattern:
/// ```dart
/// showDialog(builder: (ctx) => AlertDialog(
///   title: Text(...),
///   content: SizedBox(width: 560, child: ...),
///   actions: [TextButton(...), FilledButton(...)],
/// ));
/// ```
/// → call this as:
/// ```dart
/// showResponsiveDialog(
///   context: context,
///   title: ...,
///   designedWidth: 560,
///   content: ...,
///   actions: [TextButton(...), FilledButton(...)],
/// );
/// ```
/// At phone widths the actions slide into a SafeArea-padded row
/// at the bottom of a fullscreen scaffold; everywhere else it
/// renders as a centred AlertDialog with the width clamped via
/// [responsiveDialogWidth].
Future<T?> showResponsiveDialog<T>({
  required BuildContext context,
  required Widget title,
  required Widget content,
  required List<Widget> actions,
  double designedWidth = 560,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) {
      final phone = isPhoneWidth(ctx);
      if (phone) {
        return Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: title,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(child: content),
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                // OverflowBar handles the case where actions
                // don't fit on one line — they wrap to a column
                // rather than clipping, matching what
                // AlertDialog does internally.
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  overflowSpacing: 4,
                  children: actions,
                ),
              ),
            ),
          ),
        );
      }
      return AlertDialog(
        title: title,
        content: SizedBox(
          width: responsiveDialogWidth(ctx, designed: designedWidth),
          child: content,
        ),
        actions: actions,
      );
    },
  );
}
