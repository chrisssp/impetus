// Determinism test for RenderEngine (render-engine spec: Deterministic Output).
//
// The same RenderConfig rendered twice must produce byte-identical PNG bytes.
// Roboto is pinned via loadRoboto and the character PNG is built in-test, so
// the whole pipeline is deterministic. A companion case with a different
// background proves the identity is not vacuous.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/engine/render_engine.dart';
import 'package:impetus/models/render_config.dart';

import '../helpers/load_roboto.dart';

Future<Uint8List> _encodePng(
  int width,
  int height,
  void Function(ui.Canvas canvas) paint,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  paint(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRoboto);

  test('renders byte-identical PNGs for the same config twice', () async {
    final character = await _encodePng(256, 256, (canvas) {
      canvas.drawRect(
        const ui.Rect.fromLTRB(64, 64, 192, 192),
        ui.Paint()
          ..isAntiAlias = false
          ..color = const ui.Color(0xFFFFB03A),
      );
    });
    final config = RenderConfig(
      size: const ui.Size(540, 960),
      background: const ui.Color(0xFF1B2A41),
      characterPng: character,
      quoteText: 'Push beyond your limits. Stay hungry. Stay focused.',
    );

    final first = await RenderEngine.render(config);
    final second = await RenderEngine.render(config);

    expect(first, equals(second));
  });

  test('renders different bytes for different configs', () async {
    final character = await _encodePng(256, 256, (canvas) {
      canvas.drawRect(
        const ui.Rect.fromLTRB(64, 64, 192, 192),
        ui.Paint()
          ..isAntiAlias = false
          ..color = const ui.Color(0xFFFFB03A),
      );
    });

    RenderConfig make(ui.Color background) => RenderConfig(
      size: const ui.Size(540, 960),
      background: background,
      characterPng: character,
      quoteText: 'Push beyond your limits. Stay hungry. Stay focused.',
    );

    final dark = await RenderEngine.render(make(const ui.Color(0xFF1B2A41)));
    final light = await RenderEngine.render(make(const ui.Color(0xFFF5EEDC)));

    expect(dark, isNot(equals(light)));
  });
}
