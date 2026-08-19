import 'dart:typed_data';
import 'dart:ui' as ui;

/// Bounding-box detector for the character PNG's opaque pixels.
///
/// Decodes the PNG and scans the `rawRgba` buffer's A channel (alpha lives at
/// byte offset +3 of every pixel) keeping pixels with `alpha > 128` (design
/// D4). Returns [ui.Rect.zero] when the image is fully transparent (or every
/// pixel is at or below the threshold) and when decoding fails.
class AlphaBboxDetector {
  /// The smallest [ui.Rect] enclosing every pixel with `alpha > 128`.
  ///
  /// The rect uses half-open bounds (right/bottom exclusive), matching how the
  /// pixels are laid out in the buffer.
  static Future<ui.Rect> detect(Uint8List pngBytes) async {
    final ui.Image? image;
    try {
      final codec = await ui.instantiateImageCodec(pngBytes);
      final frame = await codec.getNextFrame();
      image = frame.image;
    } catch (_) {
      return ui.Rect.zero;
    }

    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) {
        return ui.Rect.zero;
      }
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      var minX = image.width;
      var minY = image.height;
      var maxX = 0;
      var maxY = 0;
      var found = false;
      for (var y = 0; y < image.height; y++) {
        var offset = y * image.width * 4 + 3;
        for (var x = 0; x < image.width; x++, offset += 4) {
          if (bytes[offset] > 128) {
            found = true;
            if (x < minX) {
              minX = x;
            }
            if (y < minY) {
              minY = y;
            }
            if (x > maxX) {
              maxX = x;
            }
            if (y > maxY) {
              maxY = y;
            }
          }
        }
      }

      if (!found) {
        return ui.Rect.zero;
      }
      return ui.Rect.fromLTRB(
        minX.toDouble(),
        minY.toDouble(),
        (maxX + 1).toDouble(),
        (maxY + 1).toDouble(),
      );
    } finally {
      image.dispose();
    }
  }
}
