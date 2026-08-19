import 'dart:typed_data';
import 'dart:ui' show Color, Offset, Size;

/// Placement of the system zone (clock strip) on the wallpaper.
///
/// Top presets pin the strip to the top edge; [bottomCenter] pins it to the
/// bottom edge (design D2).
enum ClockPosition { topCenter, topLeft, topRight, bottomCenter }

/// Immutable input contract for the deterministic rendering engine.
///
/// Everything the engine needs to produce a PNG is captured here; all fields
/// are `final` and the constructor is `const`, so instances can be shared
/// freely across renders without mutation.
class RenderConfig {
  const RenderConfig({
    required this.size,
    required this.background,
    required this.quoteText,
    this.characterPng,
    this.clockPosition = ClockPosition.topCenter,
    this.clockText = '12:34',
    this.fontFamily = 'Roboto',
    this.manualZoom,
    this.manualPan,
  });

  /// Output wallpaper dimensions.
  final Size size;

  /// Wallpaper background color.
  final Color background;

  /// Character PNG bytes; `null` means no character layer (design D9).
  final Uint8List? characterPng;

  /// Motivational quote text; empty means no quote layer.
  final String quoteText;

  /// System zone preset.
  final ClockPosition clockPosition;

  /// Simulated clock text rendered into the system zone (design D9).
  final String clockText;

  /// Font family resolved at render time; production renderers pin it to
  /// 'Roboto' (design D10).
  final String fontFamily;

  /// Manual zoom override; when non-null it wins over auto-adaptation (D7).
  final double? manualZoom;

  /// Manual pan override; when non-null it wins over auto-adaptation (D7).
  final Offset? manualPan;
}
