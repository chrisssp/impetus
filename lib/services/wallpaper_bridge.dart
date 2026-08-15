import 'package:flutter/services.dart';

/// Spike test payload: a deterministic 1x1 grayscale PNG (67 bytes).
///
/// A fully spec-compliant PNG is used instead of the widely copied 67-byte
/// "red pixel" literal, which relies on a zlib preset-dictionary (FDICT) flag
/// that strict decoders (libpng inside `BitmapFactory.decodeByteArray`) may
/// reject. The spike only needs *any* valid PNG — pixel color is irrelevant.
final kSpikePngBytes = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, //
  0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x00, 0x00, 0x00, 0x00, 0x3a, 0x7e, 0x9b, //
  0x55, 0x00, 0x00, 0x00, 0x0a, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9c, 0x63, 0x60, 0x00, 0x00, 0x00, //
  0x02, 0x00, 0x01, 0x48, 0xaf, 0xa4, 0x71, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, //
  0x42, 0x60, 0x82, //
]);

/// Dart-side bridge to the Kotlin `MainActivity` MethodChannel.
///
/// Channel: `com.impetus.impetus/wallpaper`
/// Method:  `setBitmap(Uint8List) -> bool`
///
/// The channel is static so tests can intercept it with
/// `setMockMethodCallHandler` before calling [setBitmap].
class WallpaperBridge {
  static const _channel = MethodChannel('com.impetus.impetus/wallpaper');

  /// Sends [pngBytes] to the platform and applies them as lock-screen and
  /// system wallpaper. Returns `false` when the platform reports no result.
  static Future<bool> setBitmap(Uint8List pngBytes) async {
    final result = await _channel.invokeMethod<bool>('setBitmap', pngBytes);
    return result ?? false;
  }
}
