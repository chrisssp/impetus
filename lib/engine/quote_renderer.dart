import 'dart:math' as math;
import 'dart:ui'
    show
        BlurStyle,
        Canvas,
        Color,
        MaskFilter,
        Offset,
        Paint,
        Paragraph,
        ParagraphBuilder,
        ParagraphConstraints,
        ParagraphStyle,
        Rect,
        TextAlign,
        TextDirection,
        TextStyle;

/// Draws the motivational quote layer over a background (design D9).
///
/// The quote color is picked per the WCAG relative-luminance contrast ratio so
/// the text stays readable on any background. A soft blurred shadow is drawn
/// behind the text to separate it from busy wallpaper areas. Text is centered
/// inside the given free-zone rect and wraps at its width. All measurement
/// uses the pinned 'Roboto' font, so output is deterministic.
class QuoteRenderer {
  QuoteRenderer._();

  static const Color _shadowColor = Color(0xB3000000);
  static const double _shadowSigma = 6.0;

  /// Black or white, whichever has the higher WCAG contrast ratio against
  /// [background].
  static Color textColorFor(Color background) {
    const white = Color(0xFFFFFFFF);
    const black = Color(0xFF000000);
    return contrastRatio(white, background) >= contrastRatio(black, background)
        ? white
        : black;
  }

  /// WCAG contrast ratio between two opaque colors (0.05..21.0).
  static double contrastRatio(Color a, Color b) {
    final luminanceA = _relativeLuminance(a);
    final luminanceB = _relativeLuminance(b);
    final lighter = math.max(luminanceA, luminanceB);
    final darker = math.min(luminanceA, luminanceB);
    return (lighter + 0.05) / (darker + 0.05);
  }

  static double _relativeLuminance(Color color) {
    double channel(double value) {
      return value <= 0.03928
          ? value / 12.92
          : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * channel(color.r) +
        0.7152 * channel(color.g) +
        0.0722 * channel(color.b);
  }

  /// Builds a centered, left-to-right paragraph from [text] that wraps at
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
              textAlign: TextAlign.center,
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

  /// Draws [text] centered inside [rect], choosing the readable color against
  /// [background] and laying a blurred shadow behind it. A no-op for empty
  /// text or an empty rect.
  static void draw(
    Canvas canvas, {
    required String text,
    required Rect rect,
    required Color background,
    required double fontSize,
    String fontFamily = 'Roboto',
  }) {
    if (text.isEmpty || rect.isEmpty) {
      return;
    }

    final paragraph = buildParagraph(
      text,
      fontFamily,
      fontSize,
      rect.width,
      color: textColorFor(background),
    )..layout(ParagraphConstraints(width: rect.width));

    final shadowPaint = Paint()
      ..color = _shadowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _shadowSigma);
    final shadow = buildParagraph(
      text,
      fontFamily,
      fontSize,
      rect.width,
      foreground: shadowPaint,
    )..layout(ParagraphConstraints(width: rect.width));

    final offset = Offset(
      rect.left,
      rect.top + (rect.height - paragraph.height) / 2,
    );
    canvas.drawParagraph(shadow, offset);
    canvas.drawParagraph(paragraph, offset);
  }
}
