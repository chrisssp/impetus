import 'dart:math' as math;
import 'dart:ui'
    show
        Offset,
        Paragraph,
        ParagraphBuilder,
        ParagraphConstraints,
        ParagraphStyle,
        Rect,
        Size;

import '../models/render_config.dart';
import '../models/zones.dart';
import 'zone_calculator.dart';

/// Resolves the final layout of the clock subject and quote: the zoom and
/// pan applied to the subject plus the font size and free-zone rect where
/// the quote will be drawn.
///
/// The search is bounded and deterministic (design D6):
///   1. zoom from 1.0 down to [kMinZoom] in [kZoomStep] steps,
///   2. pan toward the system-opposite edge in [kPanStepFraction] steps up
///      to [kMaxPanFraction] of the short side, pinned at the resolved zoom,
///   3. quote font auto-fit from [baseFontSize] down to
///      [kMinQuoteScale] * [baseFontSize] in [kQuoteScaleStep] steps,
///   4. otherwise the quote is dropped (quote rect is empty).
///
/// Manual zoom and pan override steps 1 and 2 respectively. Text is measured
/// with the pinned 'Roboto' font so results are deterministic and independent
/// of the runtime font.
class LayoutFilter {
  LayoutFilter._();

  static const double kMinZoom = 0.5;
  static const double kZoomStep = 0.05;
  static const double kMaxPanFraction = 0.35;
  static const double kPanStepFraction = 0.05;
  static const double kMinQuoteScale = 0.6;
  static const double kQuoteScaleStep = 0.05;

  static const String _fontFamily = 'Roboto';

  static LayoutResult filter(
    Size size,
    ClockPosition preset,
    Zones zones,
    String quoteText,
    double baseFontSize, {
    double? manualZoom,
    Offset? manualPan,
  }) {
    final panDirection = preset == ClockPosition.bottomCenter ? -1.0 : 1.0;
    final shortSide = math.min(size.width, size.height);
    final panStep = shortSide * kPanStepFraction;
    final zoomSteps = ((1.0 - kMinZoom) / kZoomStep).round();
    final panSteps = (kMaxPanFraction / kPanStepFraction).round();
    final fontSteps = ((1.0 - kMinQuoteScale) / kQuoteScaleStep).round();

    var zoom = manualZoom ?? 1.0;
    var pan = manualPan ?? Offset.zero;

    LayoutResult emit(double z, Offset p, double fontSize) {
      return LayoutResult(
        zoom: z,
        pan: p,
        quoteFontSize: fontSize,
        quoteRect: _freeZone(size, preset, zones, z, p),
      );
    }

    bool fits(double z, Offset p, double fontSize) {
      final free = _freeZone(size, preset, zones, z, p);
      return _fitsQuote(quoteText, fontSize, free);
    }

    if (quoteText.isEmpty) {
      return LayoutResult(
        zoom: zoom,
        pan: pan,
        quoteFontSize: baseFontSize,
        quoteRect: Rect.zero,
      );
    }

    if (manualZoom == null) {
      for (var step = 0; step <= zoomSteps; step++) {
        zoom = 1.0 - step * kZoomStep;
        if (fits(zoom, pan, baseFontSize)) {
          return emit(zoom, pan, baseFontSize);
        }
      }
    } else if (fits(zoom, pan, baseFontSize)) {
      return emit(zoom, pan, baseFontSize);
    }

    if (manualPan == null) {
      for (var step = 1; step <= panSteps; step++) {
        pan = Offset(0, panDirection * step * panStep);
        if (fits(zoom, pan, baseFontSize)) {
          return emit(zoom, pan, baseFontSize);
        }
      }
    }

    for (var step = 1; step <= fontSteps; step++) {
      final fontSize = baseFontSize * (1.0 - step * kQuoteScaleStep);
      if (fits(zoom, pan, fontSize)) {
        return emit(zoom, pan, fontSize);
      }
    }

    return LayoutResult(
      zoom: zoom,
      pan: pan,
      quoteFontSize: baseFontSize,
      quoteRect: Rect.zero,
    );
  }

  static Rect _freeZone(
    Size size,
    ClockPosition preset,
    Zones zones,
    double zoom,
    Offset pan,
  ) {
    if (zoom == 1.0 && pan == Offset.zero) {
      return zones.free;
    }
    final scaled = Rect.fromCenter(
      center: zones.subject.center,
      width: zones.subject.width * zoom,
      height: zones.subject.height * zoom,
    ).shift(pan);
    return ZoneCalculator.compute(size, preset, scaled).free;
  }

  static bool _fitsQuote(String quoteText, double fontSize, Rect free) {
    final builder = ParagraphBuilder(
      ParagraphStyle(fontFamily: _fontFamily, fontSize: fontSize),
    )..addText(quoteText);
    final paragraph = builder.build()
      ..layout(ParagraphConstraints(width: free.width));
    return paragraph.width <= free.width && paragraph.height <= free.height;
  }
}
