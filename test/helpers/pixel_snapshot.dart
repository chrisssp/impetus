import 'dart:typed_data';
import 'dart:ui' as ui;

/// Renders [draw] onto a `width` x `height` surface and returns the raw RGBA
/// bytes (one byte per channel, straight alpha, top-left origin).
Future<Uint8List> renderRgba(
  int width,
  int height,
  void Function(ui.Canvas canvas) draw,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  draw(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

bool _differs(
  Uint8List rgba,
  int width,
  int x,
  int y,
  ui.Color background, {
  required int tolerance,
}) {
  final offset = (y * width + x) * 4;
  final r = (background.r * 255).round();
  final g = (background.g * 255).round();
  final b = (background.b * 255).round();
  return (rgba[offset] - r).abs() > tolerance ||
      (rgba[offset + 1] - g).abs() > tolerance ||
      (rgba[offset + 2] - b).abs() > tolerance;
}

/// Number of pixels whose color differs from [background] by more than
/// [tolerance] per channel.
int countInk(Uint8List rgba, int width, int height, ui.Color background, {int tolerance = 8}) {
  var count = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (_differs(rgba, width, x, y, background, tolerance: tolerance)) {
        count++;
      }
    }
  }
  return count;
}

/// Bounding box of pixels that differ from [background]; `null` when the
/// surface is entirely background. Bounds are inclusive-exclusive.
({int minX, int minY, int maxX, int maxY})? inkBounds(
  Uint8List rgba,
  int width,
  int height,
  ui.Color background, {
  int tolerance = 8,
}) {
  int? minX;
  int? minY;
  var maxX = 0;
  var maxY = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (_differs(rgba, width, x, y, background, tolerance: tolerance)) {
        minX ??= x;
        minY ??= y;
        maxX = x + 1;
        maxY = y + 1;
      }
    }
  }
  if (minX == null) {
    return null;
  }
  return (minX: minX, minY: minY!, maxX: maxX, maxY: maxY);
}
