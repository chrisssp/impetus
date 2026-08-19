import 'dart:ui' show Offset, Rect;

/// The three layout zones of a wallpaper frame.
///
/// - [system]: full-width clock strip (design D3).
/// - [subject]: alpha-bbox of the character (design D4).
/// - [free]: largest zone available for the quote (design D5); `Rect.zero`
///   when no candidate exists.
class Zones {
  const Zones({
    required this.system,
    required this.subject,
    required this.free,
  });

  final Rect system;
  final Rect subject;
  final Rect free;
}

/// Result of the layout filter: the zoom/pan transform applied to the subject
/// plus the resolved quote metrics.
class LayoutResult {
  const LayoutResult({
    required this.zoom,
    required this.pan,
    required this.quoteFontSize,
    required this.quoteRect,
  });

  /// Scale factor applied to the subject bbox (auto or manual, design D7).
  final double zoom;

  /// Offset applied to the subject position (auto or manual, design D7).
  final Offset pan;

  /// Quote font size that fits the free zone.
  final double quoteFontSize;

  /// Where the quote is drawn, centered in the free zone.
  final Rect quoteRect;
}
