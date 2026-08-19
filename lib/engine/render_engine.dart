import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models/render_config.dart';
import 'alpha_bbox_detector.dart';
import 'clock_renderer.dart';
import 'layout_filter.dart';
import 'quote_renderer.dart';
import 'zone_calculator.dart';

/// Deterministic `RenderConfig → PNG bytes` renderer (design D1).
///
/// Orchestrates the full composition pipeline: alpha-bbox detection of the
/// character → 3-zone computation → layout filtering (zoom/pan/text-fit) →
/// `PictureRecorder` + `Canvas` drawing in fixed z-order (background → clock →
/// subject → quote) → `toImage` → PNG `ByteData`. No widgets, no
/// MethodChannel, no randomness, no IO — only `dart:ui`.
///
/// Never throws on degenerate input: a null character, an all-transparent (or
/// undecodable) PNG, an empty quote and a free zone too small for the quote all
/// produce valid output.
class RenderEngine {
  RenderEngine._();

  /// The wall-clock font size of the quote before auto-fit.
  static double baseFontSizeFor(ui.Size size) {
    return (size.height * 0.045).roundToDouble();
  }

  /// Renders [config] to PNG bytes.
  static Future<Uint8List> render(RenderConfig config) async {
    final subjectBbox = config.characterPng == null
        ? ui.Rect.zero
        : await AlphaBboxDetector.detect(config.characterPng!);

    final zones = ZoneCalculator.compute(
      config.size,
      config.clockPosition,
      subjectBbox,
    );

    final layout = LayoutFilter.filter(
      config.size,
      config.clockPosition,
      zones,
      config.quoteText,
      baseFontSizeFor(config.size),
      manualZoom: config.manualZoom,
      manualPan: config.manualPan,
    );

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    canvas.drawColor(config.background, ui.BlendMode.src);

    ClockRenderer.draw(
      canvas,
      clockText: config.clockText,
      systemZone: zones.system,
      preset: config.clockPosition,
      background: config.background,
      fontFamily: config.fontFamily,
    );

    if (config.characterPng != null && !subjectBbox.isEmpty) {
      await _drawSubject(
        canvas,
        config.characterPng!,
        subjectBbox,
        layout.zoom,
        layout.pan,
      );
    }

    QuoteRenderer.draw(
      canvas,
      text: config.quoteText,
      rect: layout.quoteRect,
      background: config.background,
      fontSize: layout.quoteFontSize,
      fontFamily: config.fontFamily,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      config.size.width.toInt(),
      config.size.height.toInt(),
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  }

  /// Alpha-composites the character PNG onto [canvas] with the subject bbox
  /// mapped to its zoom/pan-transformed destination (design D7). A decode
  /// failure is treated as "no subject" and is a no-op.
  static Future<void> _drawSubject(
    ui.Canvas canvas,
    Uint8List pngBytes,
    ui.Rect bbox,
    double zoom,
    ui.Offset pan,
  ) async {
    final ui.Image? image;
    try {
      final codec = await ui.instantiateImageCodec(pngBytes);
      final frame = await codec.getNextFrame();
      image = frame.image;
    } catch (_) {
      return;
    }

    try {
      final destination = ui.Rect.fromCenter(
        center: bbox.center,
        width: bbox.width * zoom,
        height: bbox.height * zoom,
      ).shift(pan);
      canvas.drawImageRect(image, bbox, destination, ui.Paint());
    } finally {
      image.dispose();
    }
  }
}
