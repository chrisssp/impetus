// Tests for AlphaBboxDetector.
//
// Synthetic PNGs are built in-test with dart:ui (PictureRecorder → toImage →
// toByteData(png)) so every pixel value is deterministic. Covers design D4:
// threshold alpha > 128 on the rawRgba A channel (offset +3), Rect.zero for
// all-transparent or decode failure.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/engine/alpha_bbox_detector.dart';

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

ui.Paint _hardFill(int a, int r, int g, int b) => ui.Paint()
  ..isAntiAlias = false
  ..color = ui.Color.fromARGB(a, r, g, b);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AlphaBboxDetector.detect', () {
    test(
      'returns the exact bbox of an opaque rect on a transparent canvas',
      () async {
        final png = await _encodePng(40, 40, (canvas) {
          canvas.drawRect(
            const ui.Rect.fromLTRB(5, 9, 27, 30),
            _hardFill(255, 200, 40, 90),
          );
        });

        expect(
          await AlphaBboxDetector.detect(png),
          const ui.Rect.fromLTRB(5, 9, 27, 30),
        );
      },
    );

    test(
      'ignores alpha-128 pixels: bbox covers only the opaque region',
      () async {
        final png = await _encodePng(32, 32, (canvas) {
          canvas.drawRect(
            const ui.Rect.fromLTRB(0, 0, 32, 32),
            _hardFill(128, 255, 255, 255),
          );
          canvas.drawRect(
            const ui.Rect.fromLTRB(6, 5, 18, 17),
            _hardFill(255, 10, 20, 30),
          );
        });

        expect(
          await AlphaBboxDetector.detect(png),
          const ui.Rect.fromLTRB(6, 5, 18, 17),
        );
      },
    );

    test(
      'finds the leftmost opaque pixel even when it is not on the top row',
      () async {
        // An L shape: a top bar whose opaque run starts at x=12 and a lower
        // column that reaches x=4. The topmost row is not the leftmost one.
        final png = await _encodePng(32, 32, (canvas) {
          canvas.drawRect(
            const ui.Rect.fromLTRB(12, 4, 20, 10),
            _hardFill(255, 200, 40, 90),
          );
          canvas.drawRect(
            const ui.Rect.fromLTRB(4, 10, 12, 18),
            _hardFill(255, 200, 40, 90),
          );
        });

        expect(
          await AlphaBboxDetector.detect(png),
          const ui.Rect.fromLTRB(4, 4, 20, 18),
        );
      },
    );

    test('treats alpha 128 as transparent and alpha 129 as opaque', () async {
      final png = await _encodePng(32, 32, (canvas) {
        canvas.drawRect(
          const ui.Rect.fromLTRB(4, 4, 8, 8),
          _hardFill(128, 255, 0, 0),
        );
        canvas.drawRect(
          const ui.Rect.fromLTRB(10, 10, 13, 13),
          _hardFill(129, 0, 0, 255),
        );
      });

      expect(
        await AlphaBboxDetector.detect(png),
        const ui.Rect.fromLTRB(10, 10, 13, 13),
      );
    });

    test('returns Rect.zero for an all-transparent canvas', () async {
      final png = await _encodePng(16, 16, (_) {});

      expect(await AlphaBboxDetector.detect(png), ui.Rect.zero);
    });

    test(
      'returns Rect.zero when every pixel has alpha at or below 128',
      () async {
        final png = await _encodePng(16, 16, (canvas) {
          canvas.drawRect(
            const ui.Rect.fromLTRB(0, 0, 16, 16),
            _hardFill(128, 255, 255, 255),
          );
        });

        expect(await AlphaBboxDetector.detect(png), ui.Rect.zero);
      },
    );

    test('returns Rect.zero for corrupt PNG bytes', () async {
      final corrupt = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

      expect(await AlphaBboxDetector.detect(corrupt), ui.Rect.zero);
    });
  });
}
