import 'dart:ui'
    show
        Canvas,
        Color,
        Offset,
        Paint,
        Paragraph,
        ParagraphBuilder,
        ParagraphConstraints,
        ParagraphStyle,
        Rect,
        Size,
        TextAlign,
        TextDirection,
        TextStyle;

import '../models/render_config.dart';
import 'quote_renderer.dart';

/// Draws the simulated clock text into the system zone (design D9).
///
/// Placement follows the [ClockPosition] preset: top presets pin the text to
/// the top edge (left / center / right), [ClockPosition.bottomCenter] to the
/// bottom edge. The text color is chosen from the background luminance via
/// [QuoteRenderer.textColorFor]. The default font size scales with the system
/// zone height. All measurement uses the pinned 'Roboto' font, so output is
/// deterministic.
class ClockRenderer {
  ClockRenderer._();

  static const double _padding = 8.0;

  /// Top-left offset of a text box of [textSize] inside [systemZone] for the
  /// given [preset].
  static Offset clockOffset(
    Rect systemZone,
    ClockPosition preset,
    Size textSize,
  ) {
    final dx = switch (preset) {
      ClockPosition.topLeft => systemZone.left + _padding,
      ClockPosition.topRight => systemZone.right - _padding - textSize.width,
      ClockPosition.topCenter || ClockPosition.bottomCenter =>
        systemZone.left + (systemZone.width - textSize.width) / 2,
    };
    final dy = switch (preset) {
      ClockPosition.bottomCenter =>
        systemZone.bottom - _padding - textSize.height,
      _ => systemZone.top + _padding,
    };
    return Offset(dx, dy);
  }

  /// Builds a left-aligned, single-line paragraph from [text] that wraps at
  /// [maxWidth]. Callers must call `layout` before drawing or measuring.
  static Paragraph buildParagraph(
    String text,
    String fontFamily,
    double fontSize,
    double maxWidth, {
    Color? color,
    Paint? foreground,
  }) {
    final builder =
        ParagraphBuilder(
            ParagraphStyle(
              fontFamily: fontFamily,
              fontSize: fontSize,
              textAlign: TextAlign.left,
              textDirection: TextDirection.ltr,
            ),
          )
          ..pushStyle(
            TextStyle(
              fontFamily: fontFamily,
              fontSize: fontSize,
              color: color,
              foreground: foreground,
            ),
          )
          ..addText(text);
    return builder.build();
  }

  /// Draws [clockText] inside [systemZone] per [preset], choosing the readable
  /// color against [background]. A no-op for empty text or an empty zone; never
  /// throws on degenerate input.
  static void draw(
    Canvas canvas, {
    required String clockText,
    required Rect systemZone,
    required ClockPosition preset,
    required Color background,
    String fontFamily = 'Roboto',
    double? fontSize,
  }) {
    if (clockText.isEmpty || systemZone.isEmpty) {
      return;
    }

    final size = fontSize ?? systemZone.height * 0.5;
    if (size <= 0) {
      return;
    }

    final paragraph = buildParagraph(
      clockText,
      fontFamily,
      size,
      systemZone.width,
      color: QuoteRenderer.textColorFor(background),
    )..layout(ParagraphConstraints(width: systemZone.width));

    canvas.drawParagraph(
      paragraph,
      clockOffset(
        systemZone,
        preset,
        Size(paragraph.maxIntrinsicWidth, paragraph.height),
      ),
    );
  }
}
