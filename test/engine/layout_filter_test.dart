import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/engine/layout_filter.dart';
import 'package:impetus/engine/zone_calculator.dart';
import 'package:impetus/models/render_config.dart';
import 'package:impetus/models/zones.dart';

import '../helpers/load_roboto.dart';

const _size = ui.Size(1080, 1920);
const _top = ClockPosition.topCenter;
const _bottom = ClockPosition.bottomCenter;
const _fontSize = 45.0;
const _maxPan = 378.0;
double get _panStep =>
    math.min(_size.width, _size.height) * LayoutFilter.kPanStepFraction;

Zones _zones(
  ui.Rect subject, {
  ui.Size size = _size,
  ClockPosition preset = _top,
}) {
  return ZoneCalculator.compute(size, preset, subject);
}

ui.Paragraph _paragraph(String text, double fontSize, double width) {
  final builder = ui.ParagraphBuilder(
    ui.ParagraphStyle(fontFamily: 'Roboto', fontSize: fontSize),
  )..addText(text);
  return builder.build()..layout(ui.ParagraphConstraints(width: width));
}

bool _fits(String text, double fontSize, ui.Rect free) {
  final paragraph = _paragraph(text, fontSize, free.width);
  return paragraph.width <= free.width && paragraph.height <= free.height;
}

ui.Rect _freeAt(ui.Rect subject, double zoom, ui.Offset pan) {
  final scaled = ui.Rect.fromCenter(
    center: subject.center,
    width: subject.width * zoom,
    height: subject.height * zoom,
  ).shift(pan);
  return _zones(scaled).free;
}

String _words(int count) => List.filled(count, 'essential').join(' ');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadRoboto);

  group('LayoutFilter.filter', () {
    test(
      'leaves zoom and pan at defaults when the free zone is sufficient',
      () {
        const subject = ui.Rect.fromLTRB(440, 700, 640, 900);
        final zones = _zones(subject);
        expect(zones.free, const ui.Rect.fromLTRB(0, 900, 1080, 1920));

        final result = LayoutFilter.filter(
          _size,
          _top,
          zones,
          'Do the thing',
          _fontSize,
        );

        expect(result.zoom, 1.0);
        expect(result.pan, ui.Offset.zero);
        expect(result.quoteFontSize, _fontSize);
        expect(result.quoteRect, const ui.Rect.fromLTRB(0, 900, 1080, 1920));
      },
    );

    test(
      'does not zoom for a bottom preset when space suffices below the subject',
      () {
        const subject = ui.Rect.fromLTRB(440, 700, 640, 900);
        final zones = _zones(subject, preset: _bottom);
        expect(zones.free, const ui.Rect.fromLTRB(0, 900, 1080, 1632));

        final result = LayoutFilter.filter(
          _size,
          _bottom,
          zones,
          'Do the thing',
          _fontSize,
        );

        expect(result.zoom, 1.0);
        expect(result.pan, ui.Offset.zero);
        expect(result.quoteRect, const ui.Rect.fromLTRB(0, 900, 1080, 1632));
      },
    );

    test(
      'zooms out in grid steps when the quote does not fit at full scale',
      () {
        const subject = ui.Rect.fromLTRB(0, 520, 1080, 1920);
        final zones = _zones(subject);
        final quote = _words(45);

        expect(_fits(quote, _fontSize, zones.free), isFalse);

        final result = LayoutFilter.filter(
          _size,
          _top,
          zones,
          quote,
          _fontSize,
        );

        expect(result.zoom, lessThan(1.0));
        expect(result.zoom, greaterThanOrEqualTo(LayoutFilter.kMinZoom));
        final zoomGrid = List.generate(
          11,
          (step) => 1.0 - step * LayoutFilter.kZoomStep,
        );
        expect(zoomGrid, contains(result.zoom));
        expect(result.pan, ui.Offset.zero);
        expect(result.quoteFontSize, _fontSize);
        expect(result.quoteRect, _freeAt(subject, result.zoom, result.pan));
        expect(_fits(quote, _fontSize, result.quoteRect), isTrue);
        expect(
          _fits(
            quote,
            _fontSize,
            _freeAt(subject, result.zoom + LayoutFilter.kZoomStep, result.pan),
          ),
          isFalse,
        );
      },
    );

    test('pans toward the system-opposite edge at the floor zoom when zooming is not enough', () {
      const subject = ui.Rect.fromLTRB(440, 900, 640, 1400);
      final zones = _zones(subject);
      final quote = _words(70);

      final result = LayoutFilter.filter(_size, _top, zones, quote, _fontSize);

      expect(result.zoom, LayoutFilter.kMinZoom);
      expect(result.pan.dx, 0);
      expect(result.pan.dy, greaterThan(0));
      expect(result.pan.dy, lessThanOrEqualTo(_maxPan));
      expect(result.pan.dy % _panStep, 0);
      expect(result.quoteFontSize, _fontSize);
      expect(result.quoteRect, _freeAt(subject, result.zoom, result.pan));
      expect(_fits(quote, _fontSize, result.quoteRect), isTrue);
      expect(
        _fits(
          quote,
          _fontSize,
          _freeAt(subject, result.zoom, ui.Offset(0, result.pan.dy - _panStep)),
        ),
        isFalse,
      );
    });

    test('shrinks the quote font at the exhausted zoom and pan when nothing else fits', () {
      const subject = ui.Rect.fromLTRB(0, 520, 1080, 1920);
      final zones = _zones(subject);
      final quote = _words(120);

      expect(_fits(quote, _fontSize, zones.free), isFalse);

      final result = LayoutFilter.filter(_size, _top, zones, quote, _fontSize);

      final fontStep = _fontSize * LayoutFilter.kQuoteScaleStep;
      final fontGrid = List.generate(
        9,
        (step) => _fontSize * (1.0 - step * LayoutFilter.kQuoteScaleStep),
      );
      expect(result.zoom, LayoutFilter.kMinZoom);
      expect(result.pan, const ui.Offset(0, _maxPan));
      expect(result.quoteFontSize, lessThan(_fontSize));
      expect(
        result.quoteFontSize,
        greaterThanOrEqualTo(_fontSize * LayoutFilter.kMinQuoteScale),
      );
      expect(fontGrid, contains(result.quoteFontSize));
      expect(_fits(quote, result.quoteFontSize, result.quoteRect), isTrue);
      expect(
        _fits(quote, result.quoteFontSize + fontStep, result.quoteRect),
        isFalse,
      );
    });

    test(
      'drops the quote when it cannot fit even after shrinking the font',
      () {
        const subject = ui.Rect.fromLTRB(0, 520, 1080, 1920);
        final zones = _zones(subject);
        final quote = _words(260);

        final result = LayoutFilter.filter(
          _size,
          _top,
          zones,
          quote,
          _fontSize,
        );

        expect(result.quoteRect, ui.Rect.zero);
        expect(result.zoom, LayoutFilter.kMinZoom);
        expect(result.pan, const ui.Offset(0, _maxPan));
        expect(result.quoteFontSize, _fontSize);
      },
    );

    test('honors a manual zoom instead of searching', () {
      const subject = ui.Rect.fromLTRB(0, 520, 1080, 1920);
      final zones = _zones(subject);
      final quote = _words(30);

      expect(_fits(quote, _fontSize, zones.free), isFalse);

      final result = LayoutFilter.filter(
        _size,
        _top,
        zones,
        quote,
        _fontSize,
        manualZoom: 0.8,
      );

      expect(result.zoom, 0.8);
      expect(result.pan, ui.Offset.zero);
      expect(result.quoteFontSize, _fontSize);
      expect(_fits(quote, _fontSize, result.quoteRect), isTrue);
    });

    test('honors a manual pan even when the auto layout would not pan', () {
      const subject = ui.Rect.fromLTRB(440, 700, 640, 900);
      final zones = _zones(subject);

      final result = LayoutFilter.filter(
        _size,
        _top,
        zones,
        'Do the thing',
        _fontSize,
        manualPan: const ui.Offset(0, 100),
      );

      expect(result.zoom, 1.0);
      expect(result.pan, const ui.Offset(0, 100));
      expect(result.quoteFontSize, _fontSize);
    });

    test('honors manual zoom and pan together', () {
      const subject = ui.Rect.fromLTRB(440, 700, 640, 900);
      final zones = _zones(subject);

      final result = LayoutFilter.filter(
        _size,
        _top,
        zones,
        'Do the thing',
        _fontSize,
        manualZoom: 0.9,
        manualPan: const ui.Offset(0, 50),
      );

      expect(result.zoom, 0.9);
      expect(result.pan, const ui.Offset(0, 50));
      expect(result.quoteFontSize, _fontSize);
    });

    test('reports an empty quote rect for an empty quote text', () {
      const subject = ui.Rect.fromLTRB(440, 700, 640, 900);
      final zones = _zones(subject);

      final result = LayoutFilter.filter(_size, _top, zones, '', _fontSize);

      expect(result.quoteRect, ui.Rect.zero);
      expect(result.zoom, 1.0);
      expect(result.pan, ui.Offset.zero);
      expect(result.quoteFontSize, _fontSize);
    });

    test('applies manual zoom to an empty quote', () {
      const subject = ui.Rect.fromLTRB(440, 700, 640, 900);
      final zones = _zones(subject);

      final result = LayoutFilter.filter(
        _size,
        _top,
        zones,
        '',
        _fontSize,
        manualZoom: 0.7,
      );

      expect(result.quoteRect, ui.Rect.zero);
      expect(result.zoom, 0.7);
      expect(result.pan, ui.Offset.zero);
    });

    test('reports an empty quote rect when no free zone exists', () {
      const subject = ui.Rect.fromLTRB(0, 288, 1080, 1920);
      final zones = _zones(subject);
      expect(zones.free, ui.Rect.zero);

      final result = LayoutFilter.filter(
        _size,
        _top,
        zones,
        _words(220),
        _fontSize,
      );

      expect(result.quoteRect, ui.Rect.zero);
      expect(result.zoom, LayoutFilter.kMinZoom);
      expect(result.pan, const ui.Offset(0, _maxPan));
    });
  });
}
