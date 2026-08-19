// Tests for RenderEngine.render (design D1, render-engine spec).
//
// Degenerate-config scenarios from the spec: valid config → PNG bytes,
// null character → background + clock only, empty quote → no quote layer,
// no free zone → valid output without a quote. Renders are compared at the
// byte level; a valid PNG is detected via its 8-byte magic signature. The
// synthetic character PNGs are built in-test with dart:ui so every input is
// deterministic.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/engine/render_engine.dart';
import 'package:impetus/models/render_config.dart';

import '../helpers/load_roboto.dart';

const _background = ui.Color(0xFF2A2A2A);
const _size = ui.Size(400, 300);

/// Encodes a [width]x[height] PNG whose pixels come from [paint].
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

/// Opaque rect centered in the free band (below the 45px top system strip).
Future<Uint8List> _centeredPng() => _encodePng(400, 300, (canvas) {
  canvas.drawRect(
    const ui.Rect.fromLTRB(140, 110, 260, 230),
    ui.Paint()
      ..isAntiAlias = false
      ..color = const ui.Color(0xFFFFB03A),
  );
});

/// Opaque rect covering the whole free band, so the free zone is empty at
/// zoom 1.0 and stays too small for a huge quote even after full adaptation.
Future<Uint8List> _bandFillingPng() => _encodePng(400, 300, (canvas) {
  canvas.drawRect(
    const ui.Rect.fromLTRB(0, 45, 400, 300),
    ui.Paint()
      ..isAntiAlias = false
      ..color = const ui.Color(0xFFFFB03A),
  );
});

Future<Uint8List> _transparentPng() => _encodePng(400, 300, (_) {});

RenderConfig _config({
  Uint8List? characterPng,
  String quoteText = 'Do the thing',
}) {
  return RenderConfig(
    size: _size,
    background: _background,
    characterPng: characterPng,
    quoteText: quoteText,
  );
}

/// Pins the subject transform (design D7) so the only variable between two
/// renders is the quote. 0.5 = kMinZoom; (0, 105) = kMaxPanFraction × short
/// side. The pinned transform is what the auto-filter would end on after
/// exhausting zoom and pan for a band-filling subject.
RenderConfig _pinned({
  required Uint8List characterPng,
  String quoteText = 'Do the thing',
}) {
  return RenderConfig(
    size: _size,
    background: _background,
    characterPng: characterPng,
    quoteText: quoteText,
    manualZoom: 0.5,
    manualPan: const ui.Offset(0, 105),
  );
}

/// Long enough that it cannot fit the free zone even at the minimum font.
String _hugeQuote() => List.filled(200, 'essential').join(' ');

bool _isPng(Uint8List bytes) {
  const magic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (bytes.length < magic.length) {
    return false;
  }
  for (var i = 0; i < magic.length; i++) {
    if (bytes[i] != magic[i]) {
      return false;
    }
  }
  return true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRoboto);

  group('RenderEngine.render', () {
    test('produces PNG bytes for a valid config with all layers', () async {
      final withCharacter = await RenderEngine.render(
        _config(characterPng: await _centeredPng()),
      );
      final withoutCharacter = await RenderEngine.render(_config());

      expect(_isPng(withCharacter), isTrue);
      expect(withCharacter, isNot(equals(withoutCharacter)));
    });

    test('renders background and clock only for a null character', () async {
      final withoutCharacter = await RenderEngine.render(
        _config(characterPng: null),
      );
      final withTransparent = await RenderEngine.render(
        _config(characterPng: await _transparentPng()),
      );

      expect(_isPng(withoutCharacter), isTrue);
      expect(withoutCharacter, equals(withTransparent));
    });

    test('renders background and clock only for an empty quote', () async {
      final empty = await RenderEngine.render(
        _config(characterPng: await _centeredPng(), quoteText: ''),
      );
      final withQuote = await RenderEngine.render(
        _config(characterPng: await _centeredPng()),
      );

      expect(_isPng(empty), isTrue);
      expect(empty, isNot(equals(withQuote)));
    });

    test('drops the quote when no free zone can fit it', () async {
      final noFreeZone = await RenderEngine.render(
        _pinned(characterPng: await _bandFillingPng(), quoteText: _hugeQuote()),
      );
      final noQuote = await RenderEngine.render(
        _pinned(characterPng: await _bandFillingPng(), quoteText: ''),
      );

      expect(_isPng(noFreeZone), isTrue);
      expect(noFreeZone, equals(noQuote));
    });
  });
}
