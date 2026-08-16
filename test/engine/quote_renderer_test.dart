import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/engine/quote_renderer.dart';

import '../helpers/load_roboto.dart';
import '../helpers/pixel_snapshot.dart';

const _light = ui.Color(0xFFEEEEEE);
const _medium = ui.Color(0xFF808080);
const _dark = ui.Color(0xFF1B2A41);

String _longText() => List.filled(20, 'essential').join(' ');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRoboto);

  group('QuoteRenderer.textColorFor', () {
    test('returns white on dark backgrounds', () {
      expect(QuoteRenderer.textColorFor(ui.Color(0xFF000000)), const ui.Color(0xFFFFFFFF));
      expect(QuoteRenderer.textColorFor(_dark), const ui.Color(0xFFFFFFFF));
    });

    test('returns black on light backgrounds', () {
      expect(QuoteRenderer.textColorFor(const ui.Color(0xFFFFFFFF)), const ui.Color(0xFF000000));
      expect(QuoteRenderer.textColorFor(_light), const ui.Color(0xFF000000));
    });

    test('picks the color with the higher contrast ratio', () {
      expect(QuoteRenderer.textColorFor(_medium), const ui.Color(0xFF000000));
    });

    test('keeps at least 4.5:1 contrast on the chosen color', () {
      const backgrounds = <ui.Color>[
        ui.Color(0xFF0F0F0F),
        _dark,
        _medium,
        _light,
        ui.Color(0xFFFFD9A0),
        ui.Color(0xFF5B8E7D),
      ];
      for (final background in backgrounds) {
        final text = QuoteRenderer.textColorFor(background);
        expect(
          QuoteRenderer.contrastRatio(text, background),
          greaterThanOrEqualTo(4.5),
          reason: 'background $background',
        );
      }
    });
  });

  group('QuoteRenderer.contrastRatio', () {
    test('computes the WCAG contrast ratio', () {
      expect(
        QuoteRenderer.contrastRatio(const ui.Color(0xFFFFFFFF), const ui.Color(0xFF000000)),
        moreOrLessEquals(21.0, epsilon: 1e-6),
      );
      expect(
        QuoteRenderer.contrastRatio(const ui.Color(0xFF000000), const ui.Color(0xFFFFFFFF)),
        moreOrLessEquals(21.0, epsilon: 1e-6),
      );
      expect(
        QuoteRenderer.contrastRatio(const ui.Color(0xFFFFFFFF), const ui.Color(0xFFFFFFFF)),
        moreOrLessEquals(1.0, epsilon: 1e-6),
      );
    });
  });

  group('QuoteRenderer.buildParagraph', () {
    test('wraps long text at the given width', () {
      final paragraph = QuoteRenderer.buildParagraph(
        _longText(),
        const ui.TextStyle(fontFamily: 'Roboto', fontSize: 45),
        300,
      )..layout(const ui.ParagraphConstraints(width: 300));

      expect(paragraph.width, lessThanOrEqualTo(300));
      expect(paragraph.height, greaterThan(45));
      expect(paragraph.height, greaterThanOrEqualTo(45 * 2));
    });

    test('exposes the paragraph for tests', () {
      final paragraph = QuoteRenderer.buildParagraph(
        'Do the thing',
        const ui.TextStyle(fontFamily: 'Roboto', fontSize: 45),
        1080,
      )..layout(const ui.ParagraphConstraints(width: 1080));

      expect(paragraph.height, greaterThan(45));
      expect(paragraph.height, lessThan(45 * 2));
    });
  });

  group('QuoteRenderer.draw', () {
    const rect = ui.Rect.fromLTWH(150, 110, 100, 80);

    test('renders text centered within the rect', () async {
      final rgba = await renderRgba(400, 300, (canvas) {
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 400, 300),
          ui.Paint()..color = _light,
        );
        QuoteRenderer.draw(
          canvas,
          text: 'Hi',
          rect: rect,
          background: _light,
          fontSize: 30,
        );
      });

      final bounds = inkBounds(rgba, 400, 300, _light);
      expect(bounds, isNotNull);
      expect(bounds!.minX, greaterThanOrEqualTo(rect.left.round()));
      expect(bounds.maxX, lessThanOrEqualTo(rect.right.round()));
      expect(bounds.minY, greaterThanOrEqualTo(rect.top.round()));
      expect(bounds.maxY, lessThanOrEqualTo(rect.bottom.round()));
      final centerX = (bounds.minX + bounds.maxX) / 2;
      final centerY = (bounds.minY + bounds.maxY) / 2;
      expect(centerX, moreOrLessEquals(200, epsilon: 25));
      expect(centerY, moreOrLessEquals(150, epsilon: 25));
    });

    test('draws a soft blurred shadow behind the text', () async {
      const shadowRect = ui.Rect.fromLTWH(150, 120, 100, 60);
      final withShadow = await renderRgba(400, 300, (canvas) {
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 400, 300),
          ui.Paint()..color = const ui.Color(0xFFE8E8E8),
        );
        QuoteRenderer.draw(
          canvas,
          text: 'AB',
          rect: shadowRect,
          background: const ui.Color(0xFFE8E8E8),
          fontSize: 30,
        );
      });
      final withoutShadow = await renderRgba(400, 300, (canvas) {
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 400, 300),
          ui.Paint()..color = const ui.Color(0xFFE8E8E8),
        );
        final paragraph = QuoteRenderer.buildParagraph(
          'AB',
          const ui.TextStyle(fontFamily: 'Roboto', fontSize: 30, color: ui.Color(0xFF000000)),
          shadowRect.width,
        )..layout(ui.ParagraphConstraints(width: shadowRect.width));
        canvas.drawParagraph(
          paragraph,
          ui.Offset(shadowRect.left, shadowRect.top + (shadowRect.height - paragraph.height) / 2),
        );
      });

      const background = ui.Color(0xFFE8E8E8);
      final textInk = countInk(withoutShadow, 400, 300, background);
      final shadowInk = countInk(withShadow, 400, 300, background);
      expect(textInk, greaterThan(0));
      expect(shadowInk, greaterThan(textInk));
    });

    test('defaults to the pinned Roboto font', () async {
      const fontRect = ui.Rect.fromLTWH(100, 130, 600, 60);
      Future<ui.Picture> draw(String? fontFamily) async {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 800, 400),
          ui.Paint()..color = _light,
        );
        QuoteRenderer.draw(
          canvas,
          text: 'Do the thing',
          rect: fontRect,
          background: _light,
          fontSize: 45,
          fontFamily: fontFamily ?? 'Roboto',
        );
        return recorder.endRecording();
      }

      final defaultPng = await draw(null).then(
        (picture) => picture.toImage(800, 400).then((image) => image.toByteData(format: ui.ImageByteFormat.rawRgba)),
      );
      final explicitPng = await draw('Roboto').then(
        (picture) => picture.toImage(800, 400).then((image) => image.toByteData(format: ui.ImageByteFormat.rawRgba)),
      );
      expect(defaultPng!.buffer.asUint8List(), equals(explicitPng!.buffer.asUint8List()));

      final rgba = await renderRgba(800, 400, (canvas) {
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 800, 400),
          ui.Paint()..color = _light,
        );
        QuoteRenderer.draw(
          canvas,
          text: 'Do the thing',
          rect: fontRect,
          background: _light,
          fontSize: 45,
        );
      });
      final bounds = inkBounds(rgba, 800, 400, _light);
      expect(bounds, isNotNull);
      expect(bounds!.maxX - bounds.minX, lessThan(400));
    });

    test('is a no-op for empty text', () async {
      final rgba = await renderRgba(400, 300, (canvas) {
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 400, 300),
          ui.Paint()..color = _light,
        );
        QuoteRenderer.draw(
          canvas,
          text: '',
          rect: rect,
          background: _light,
          fontSize: 30,
        );
      });

      expect(countInk(rgba, 400, 300, _light), 0);
    });

    test('is a no-op for an empty rect', () async {
      final rgba = await renderRgba(400, 300, (canvas) {
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, 400, 300),
          ui.Paint()..color = _light,
        );
        QuoteRenderer.draw(
          canvas,
          text: 'Hi',
          rect: ui.Rect.zero,
          background: _light,
          fontSize: 30,
        );
      });

      expect(countInk(rgba, 400, 300, _light), 0);
    });
  });
}
