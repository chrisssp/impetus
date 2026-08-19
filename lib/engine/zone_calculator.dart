import 'dart:ui' show Rect, Size;

import '../models/render_config.dart';
import '../models/zones.dart';

/// Computes the three layout zones of a wallpaper frame (design D3/D5).
///
/// Pure, deterministic, synchronous geometry:
///   - System zone: full-width strip, `round(h * 0.15)` tall, pinned to the
///     top for top presets and to the bottom for [ClockPosition.bottomCenter].
///   - Free zone: the largest positive-area rectangle among the four splits of
///     the band (wallpaper minus system strip) around the subject bbox clipped
///     into that band. When the subject contributes no occupied area to the
///     band the whole band is free; when no split has positive area the free
///     zone is `Rect.zero`.
class ZoneCalculator {
  static const double _systemHeightRatio = 0.15;

  static Zones compute(Size size, ClockPosition preset, Rect subjectBbox) {
    final systemHeight = (size.height * _systemHeightRatio).roundToDouble();
    final isBottom = preset == ClockPosition.bottomCenter;
    final system = isBottom
        ? Rect.fromLTWH(0, size.height - systemHeight, size.width, systemHeight)
        : Rect.fromLTWH(0, 0, size.width, systemHeight);

    final band = isBottom
        ? Rect.fromLTRB(0, 0, size.width, system.top)
        : Rect.fromLTRB(0, system.bottom, size.width, size.height);

    final clipped = subjectBbox.intersect(band);
    final Rect free;
    if (clipped.isEmpty) {
      free = band;
    } else {
      free = _largestSplit(clipped, band, size.width);
    }

    return Zones(system: system, subject: subjectBbox, free: free);
  }

  /// The four axis-aligned splits of [band] around [clipped], keeping only
  /// those with positive width and height and returning the largest by area.
  static Rect _largestSplit(Rect clipped, Rect band, double width) {
    final candidates = <Rect>[
      Rect.fromLTRB(0, band.top, width, clipped.top),
      Rect.fromLTRB(0, clipped.bottom, width, band.bottom),
      Rect.fromLTRB(0, clipped.top, clipped.left, clipped.bottom),
      Rect.fromLTRB(clipped.right, clipped.top, width, clipped.bottom),
    ];

    var best = Rect.zero;
    var bestArea = 0.0;
    for (final candidate in candidates) {
      if (candidate.width <= 0 || candidate.height <= 0) {
        continue;
      }
      final area = candidate.width * candidate.height;
      if (area > bestArea) {
        bestArea = area;
        best = candidate;
      }
    }
    return best;
  }
}
