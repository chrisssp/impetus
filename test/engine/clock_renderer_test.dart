import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:impetus/engine/clock_renderer.dart';
import 'package:impetus/models/render_config.dart';

import '../helpers/load_roboto.dart';
import '../helpers/pixel_snapshot.dart';

const _bg = ui.Color(0xFFE8E8E8);
const _zoneTop = ui.Rect.fromLTWH(0, 0, 400, 45);
const _zoneBottom = ui.Rect.fromLTWH(0, 255, 400, 45);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadRoboto();
  });

  Future<Uint8List> render(String text, ui.Rect zone, ClockPosition preset) {
    return renderRgba(400, 300, (canvas) {
      canvas.drawColor(_bg, ui.BlendMode.src);
      ClockRenderer.draw(
        canvas,
        clockText: text,
        systemZone: zone,
        preset: preset,
        background: _bg,
      );
    });
  }

  Future<Uint8List> renderExplicitRoboto(
    String text,
    ui.Rect zone,
    ClockPosition preset,
  ) {
    return renderRgba(400, 300, (canvas) {
      canvas.drawColor(_bg, ui.BlendMode.src);
      ClockRenderer.draw(
        canvas,
        clockText: text,
        systemZone: zone,
        preset: preset,
        background: _bg,
        fontFamily: 'Roboto',
      );
    });
  }

  group('ClockRenderer.draw', () {
    test('renders the clock text centered in the top system zone', () async {
      final bounds = inkBounds(
        await render('12:34', _zoneTop, ClockPosition.topCenter),
        400,
        300,
        _bg,
      )!;

      expect(bounds.minY, lessThan(45));
      expect(bounds.minX + bounds.maxX, closeTo(400, 24));
      expect(bounds.maxX - bounds.minX, greaterThan(30));
    });

    test('aligns the clock to the left edge (topLeft)', () async {
      final bounds = inkBounds(
        await render('12:34', _zoneTop, ClockPosition.topLeft),
        400,
        300,
        _bg,
      )!;

      expect(bounds.minX, lessThan(24));
      expect(bounds.minY, lessThan(45));
    });

    test('aligns the clock to the right edge (topRight)', () async {
      final bounds = inkBounds(
        await render('12:34', _zoneTop, ClockPosition.topRight),
        400,
        300,
        _bg,
      )!;

      expect(bounds.maxX, greaterThan(400 - 24));
      expect(bounds.minY, lessThan(45));
    });

    test(
      'renders the clock in the bottom system zone (bottomCenter)',
      () async {
        final bounds = inkBounds(
          await render('12:34', _zoneBottom, ClockPosition.bottomCenter),
          400,
          300,
          _bg,
        )!;

        expect(bounds.maxY, greaterThan(255));
        expect(bounds.minX + bounds.maxX, closeTo(400, 24));
      },
    );

    test('defaults to the pinned Roboto font', () async {
      expect(
        await render('12:34', _zoneTop, ClockPosition.topCenter),
        equals(
          await renderExplicitRoboto(
            '12:34',
            _zoneTop,
            ClockPosition.topCenter,
          ),
        ),
      );
    });

    test('is a no-op for empty clock text', () async {
      final bounds = inkBounds(
        await render('', _zoneTop, ClockPosition.topCenter),
        400,
        300,
        _bg,
      );

      expect(bounds, isNull);
    });

    test('is a no-op for an empty system zone', () async {
      final bounds = inkBounds(
        await render('12:34', ui.Rect.zero, ClockPosition.topCenter),
        400,
        300,
        _bg,
      );

      expect(bounds, isNull);
    });
  });

  group('ClockRenderer.clockOffset', () {
    const size = ui.Size(60, 22);

    test('centers the text horizontally for topCenter', () {
      const zone = ui.Rect.fromLTWH(0, 0, 400, 45);
      final offset = ClockRenderer.clockOffset(
        zone,
        ClockPosition.topCenter,
        size,
      );

      expect(offset.dx, closeTo((400 - 60) / 2, 1e-6));
      expect(offset.dy, closeTo(8, 1e-6));
    });

    test('hugs the left edge for topLeft', () {
      const zone = ui.Rect.fromLTWH(0, 0, 400, 45);
      final offset = ClockRenderer.clockOffset(
        zone,
        ClockPosition.topLeft,
        size,
      );

      expect(offset.dx, closeTo(8, 1e-6));
    });

    test('hugs the right edge for topRight', () {
      const zone = ui.Rect.fromLTWH(0, 0, 400, 45);
      final offset = ClockRenderer.clockOffset(
        zone,
        ClockPosition.topRight,
        size,
      );

      expect(offset.dx, closeTo(400 - 8 - 60, 1e-6));
    });

    test('hugs the bottom edge for bottomCenter', () {
      const zone = ui.Rect.fromLTWH(0, 255, 400, 45);
      final offset = ClockRenderer.clockOffset(
        zone,
        ClockPosition.bottomCenter,
        size,
      );

      expect(offset.dx, closeTo((400 - 60) / 2, 1e-6));
      expect(offset.dy, closeTo(255 + 45 - 8 - 22, 1e-6));
    });
  });
}
