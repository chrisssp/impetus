// Tests for the render-engine domain models.
//
// Covers the design.md contracts:
//   - D2: ClockPosition has exactly the four spec presets.
//   - D9: RenderConfig defaults (clockText '12:34', fontFamily 'Roboto') and
//     const immutability.
//   - Zones/LayoutResult data-carrying construction.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/models/render_config.dart';
import 'package:impetus/models/zones.dart';

void main() {
  group('ClockPosition', () {
    test('has exactly the four spec presets in order', () {
      expect(ClockPosition.values, [
        ClockPosition.topCenter,
        ClockPosition.topLeft,
        ClockPosition.topRight,
        ClockPosition.bottomCenter,
      ]);
    });
  });

  group('RenderConfig', () {
    test('applies spec defaults for optional fields', () {
      const config = RenderConfig(
        size: Size(1080, 1920),
        background: Color(0xFF000000),
        quoteText: 'Do the thing',
      );

      expect(config.size, const Size(1080, 1920));
      expect(config.background, const Color(0xFF000000));
      expect(config.quoteText, 'Do the thing');
      expect(config.clockPosition, ClockPosition.topCenter);
      expect(config.clockText, '12:34');
      expect(config.fontFamily, 'Roboto');
      expect(config.characterPng, isNull);
      expect(config.manualZoom, isNull);
      expect(config.manualPan, isNull);
    });

    test('carries every field when fully specified', () {
      final png = Uint8List.fromList([1, 2, 3]);
      final config = RenderConfig(
        size: const Size(1000, 1500),
        background: const Color(0xFF123456),
        quoteText: 'quote',
        characterPng: png,
        clockPosition: ClockPosition.bottomCenter,
        clockText: '08:15',
        fontFamily: 'Roboto',
        manualZoom: 1.5,
        manualPan: const Offset(10, 20),
      );

      expect(config.size, const Size(1000, 1500));
      expect(config.background, const Color(0xFF123456));
      expect(config.quoteText, 'quote');
      expect(identical(config.characterPng, png), isTrue);
      expect(config.clockPosition, ClockPosition.bottomCenter);
      expect(config.clockText, '08:15');
      expect(config.fontFamily, 'Roboto');
      expect(config.manualZoom, 1.5);
      expect(config.manualPan, const Offset(10, 20));
    });

    test('is const-constructible with canonical constant instances', () {
      const a = RenderConfig(
        size: Size(100, 200),
        background: Color(0xFF000000),
        quoteText: 'x',
      );
      const b = RenderConfig(
        size: Size(100, 200),
        background: Color(0xFF000000),
        quoteText: 'x',
      );

      expect(identical(a, b), isTrue);
    });
  });

  group('Zones', () {
    test('exposes system, subject and free rects', () {
      const zones = Zones(
        system: Rect.fromLTWH(0, 0, 100, 20),
        subject: Rect.fromLTWH(10, 10, 50, 50),
        free: Rect.fromLTWH(0, 20, 100, 80),
      );

      expect(zones.system, const Rect.fromLTWH(0, 0, 100, 20));
      expect(zones.subject, const Rect.fromLTWH(10, 10, 50, 50));
      expect(zones.free, const Rect.fromLTWH(0, 20, 100, 80));
    });
  });

  group('LayoutResult', () {
    test('exposes zoom, pan, quoteFontSize and quoteRect', () {
      const result = LayoutResult(
        zoom: 0.8,
        pan: Offset(0, 42),
        quoteFontSize: 24.0,
        quoteRect: Rect.fromLTWH(0, 20, 100, 80),
      );

      expect(result.zoom, 0.8);
      expect(result.pan, const Offset(0, 42));
      expect(result.quoteFontSize, 24.0);
      expect(result.quoteRect, const Rect.fromLTWH(0, 20, 100, 80));
    });
  });
}
