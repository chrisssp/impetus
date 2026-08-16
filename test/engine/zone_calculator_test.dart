// Tests for ZoneCalculator.
//
// Covers design D3 (system zone: full-width strip, round(h * 0.15) tall, top
// for top presets / bottom for bottomCenter) and D5 (free zone = largest
// positive-area split of the band minus the clipped subject; Rect.zero when no
// candidate exists). The free zone must never intersect the system zone or the
// subject bbox.

import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/engine/zone_calculator.dart';
import 'package:impetus/models/render_config.dart';

void main() {
  group('ZoneCalculator.compute', () {
    const size1080x1920 = Size(1080, 1920);

    test(
      'places the system zone full-width at the top for all top presets',
      () {
        const subject = Rect.fromLTRB(340, 900, 740, 1400);
        for (final preset in [
          ClockPosition.topCenter,
          ClockPosition.topLeft,
          ClockPosition.topRight,
        ]) {
          final zones = ZoneCalculator.compute(size1080x1920, preset, subject);

          expect(
            zones.system,
            const Rect.fromLTRB(0, 0, 1080, 288),
            reason: '$preset',
          );
        }
      },
    );

    test(
      'places the system zone full-width at the bottom for bottomCenter',
      () {
        const subject = Rect.fromLTRB(340, 900, 740, 1400);
        final zones = ZoneCalculator.compute(
          size1080x1920,
          ClockPosition.bottomCenter,
          subject,
        );

        expect(zones.system, const Rect.fromLTRB(0, 1632, 1080, 1920));
      },
    );

    test('rounds the system strip height to round(h * 0.15)', () {
      final zones = ZoneCalculator.compute(
        const Size(1000, 999),
        ClockPosition.topCenter,
        Rect.zero,
      );

      expect(zones.system.height, 150.0);
    });

    test('returns the full band as the free zone when there is no subject', () {
      final zones = ZoneCalculator.compute(
        const Size(1000, 1000),
        ClockPosition.topCenter,
        Rect.zero,
      );

      expect(zones.free, const Rect.fromLTRB(0, 150, 1000, 1000));
    });

    test('picks the largest band-split as the free zone (top preset)', () {
      const subject = Rect.fromLTRB(340, 900, 740, 1400);
      final zones = ZoneCalculator.compute(
        size1080x1920,
        ClockPosition.topCenter,
        subject,
      );

      expect(zones.free, const Rect.fromLTRB(0, 288, 1080, 900));
      expect(zones.subject, subject);
    });

    test('picks the largest band-split as the free zone (bottom preset)', () {
      const subject = Rect.fromLTRB(340, 900, 740, 1400);
      final zones = ZoneCalculator.compute(
        size1080x1920,
        ClockPosition.bottomCenter,
        subject,
      );

      expect(zones.free, const Rect.fromLTRB(0, 0, 1080, 900));
    });

    test('clips a subject that overlaps the system zone', () {
      const subject = Rect.fromLTRB(0, 100, 100, 500);
      final zones = ZoneCalculator.compute(
        size1080x1920,
        ClockPosition.topCenter,
        subject,
      );

      expect(zones.subject, subject);
      expect(zones.free, const Rect.fromLTRB(0, 500, 1080, 1920));
    });

    test('returns Rect.zero free zone when the subject fills the band', () {
      final zones = ZoneCalculator.compute(
        const Size(1000, 1000),
        ClockPosition.topCenter,
        const Rect.fromLTRB(0, 150, 1000, 1000),
      );

      expect(zones.free, Rect.zero);
    });

    test('free zone never intersects the system zone or the subject bbox', () {
      final subjects = <Rect>[
        const Rect.fromLTRB(340, 900, 740, 1400),
        const Rect.fromLTRB(0, 100, 100, 500),
        Rect.zero,
      ];
      for (final preset in ClockPosition.values) {
        for (final subject in subjects) {
          final zones = ZoneCalculator.compute(size1080x1920, preset, subject);

          expect(
            zones.free.overlaps(zones.system),
            isFalse,
            reason: '$preset / $subject',
          );
          expect(
            zones.free.overlaps(subject),
            isFalse,
            reason: '$preset / $subject',
          );
        }
      }
    });
  });
}
