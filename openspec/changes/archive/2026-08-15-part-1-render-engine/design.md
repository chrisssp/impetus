# Design: Part 1 — Deterministic Rendering Engine

## Technical Approach

A pure, deterministic `RenderConfig → PNG bytes` engine over `dart:ui` only.
`RenderEngine.render(RenderConfig)` orchestrates: alpha-bbox detection of the
subject → 3-zone computation (system / subject / free) → layout filtering
(zoom/pan mutual adaptation per vault decision 14) → `PictureRecorder` +
`Canvas` composition (background → clock → subject → quote) → `toImage` →
PNG `ByteData`. No widgets, no MethodChannel, no new dependencies. The API is
the shared core for Part 2 (configurator preview) and Part 3 (content).
FR-2.4 (blocked-layer attenuation) is explicitly excluded — Part 2 scope.

## Architecture Decisions

| # | Decision | Alternatives | Rationale |
|---|----------|--------------|-----------|
| D1 | `render` returns `Future<Uint8List>` (not sync `Uint8List`) | Sync API | `instantiateImageCodec`/`toImage` are inherently async in `dart:ui`. Still "pure": deterministic, no side effects, no randomness, no IO, no wall-clock. |
| D2 | `ClockPosition` enum: `topCenter`, `topLeft`, `topRight`, `bottomCenter` | Free-form offset | Spec enumerates exactly 4 presets; enum is exhaustively matchable and testable. |
| D3 | System zone = full-width strip, height `round(h * 0.15)`; top presets → top strip, `bottomCenter` → bottom strip | Fixed pixel height, bbox-of-clock height | Spec: "Height is preset-dependent" — preset affects only position; proportional height scales with wallpaper deterministically. System zone always applied (vault decision 12). |
| D4 | Subject bbox: alpha > 128 threshold on `rawRgba` A channel; all-transparent or decode failure → `Rect.zero` | Connected-component segmentation | Spec mandates threshold; simple scan is deterministic. `rawRgba` gives straight RGBA with alpha at offset `+3`. |
| D5 | Free zone = largest of the 4 axis-aligned split rectangles of the band (above/below/left/right of clipped subject) | Maximal empty-rectangle search | Deterministic, O(1) candidates, satisfies "largest contiguous" for the MVP axis-aligned case; quote is a text block. |
| D6 | Layout filter: zoom-out (1.0 → 0.5, step 0.05) → pan (toward the system-opposite edge, up to 0.35× short side, step 0.05) → auto-fit quote font (1.0 → 0.6×, step 0.05) → drop quote | Single-shot scale | Bounded (≤ ~40 cheap Paragraph layouts), fully deterministic, mirrors vault decision 14 (mutual adaptation). |
| D7 | Manual `zoom`/`pan` on `RenderConfig` override auto-adaptation when non-null; auto-fit quote still applies | Manual values always win entirely | Spec: "optional zoom/pan offsets" — caller control with graceful text fallback. |
| D8 | Quote/clock color chosen from background luminance (WCAG contrast); pick white vs black by higher ratio; blurred shadow behind quote | Fixed color, colored stroke | Deterministic contrast mechanism; ≥4.5:1 for non-mid-gray backgrounds (SHOULD level; mid-gray edge documented). |
| D9 | Clock text is an input field `clockText` (default `'12:34'`) rendered by the engine | Pre-rendered clock bitmap | Proposal: engine "receives clock position + rendered clock representation". Text keeps font determinism; real time arrives in Part 2/4. |
| D10 | Fonts: `fontFamily: 'Roboto'` resolved at runtime; tests pin metrics via `FontLoader('Roboto')` from `test/fonts/Roboto-Regular.ttf` (existing Part 0 harness). NO `assets/fonts` bundling in Part 1 | Bundle asset under `assets/fonts` | Android ships Roboto (same metrics); bundling would modify `pubspec.yaml` (app change) and add asset plumbing. Production font choice lands with content (Part 3). |
| D11 | Proposal's "decision 12" for largest-free-zone maps to vault decision 13 (largest free zone) — vault #12 is lock-surface; "decision 14" = vault mutual adaptation | — | Numbering drift between proposal and vault; behavior intent is unambiguous. |
| D12 | Golden comparison via `matchesGoldenFile` on `ByteData.sublistView(pngBytes)` inside plain `test()` + `TestWidgetsFlutterBinding.ensureInitialized()` | `tester.runAsync` in `testWidgets` | Engine has no widgets to pump; `matchesGoldenFile` preserves the `--update-goldens` workflow and the "atomic regeneration" spec. Real async is allowed in plain `test()`. |

## Data Flow

```
RenderConfig ──► AlphaBboxDetector.detect(pngBytes) ──► Rect subjectBbox
     │                                                        │
     └────────► ZoneCalculator.compute(size, preset, bbox) ──► Zones
                                                                 │
     ┌──────────────────────────────────────────────────────────┘
     ▼
LayoutFilter.filter(zones, quote, zoom?, pan?) ──► LayoutResult
     │                        (zoom, pan, quoteFontSize, quoteRect)
     ▼
RenderEngine.render: PictureRecorder → Canvas
     drawColor(background) → ClockRenderer.draw(clockText)
     → drawImageRect(subject, src: bbox, dst: zoomPan-transformed)
     → QuoteRenderer.draw(quote, contrastColor, shadow) → picture
     → toImage(w, h) → toByteData(png) → Uint8List
```

## Zone Computation Algorithm

- **System zone** (D3): `Rect.fromLTWH(0, 0, w, sysH)` for top presets;
  `Rect.fromLTWH(0, h - sysH, w, sysH)` for `bottomCenter`; `sysH = (h * 0.15).roundToDouble()`.
- **Subject zone** (D4): alpha-bbox; returned directly. If `Rect.zero`, subject
  contributes no occupied area.
- **Free zone** (D5): working band = wallpaper minus system strip
  (`topBand = Rect(0, sysBottom, w, h)` for top presets; `bottomBand =
  Rect(0, 0, w, sysTop)` for bottom). `clipped = subjectBbox.intersect(band)`.
  Candidates: above `(0, band.top, w, clipped.top)`, below
  `(0, clipped.bottom, w, band.bottom)`, left `(0, clipped.top, clipped.left,
  clipped.bottom)`, right `(clipped.right, clipped.top, w, clipped.bottom)`.
  Keep candidates with positive width AND height; pick max area. None → `Rect.zero`.

## Layout Filtering Algorithm

Input: `zones`, `quoteText`, base font size `fs = (h * 0.045).roundToDouble()`, optional manual `zoom`/`pan` (D7).

1. Set `zoom = 1.0`, `pan = Offset.zero` (or manual values).
2. Scale subject bbox about its center by `zoom`; re-run free-zone with the
   transformed bbox + `pan`.
3. Layout quote via `Paragraph` at `fs`, width = free zone width.
   `fits` ⟺ `paragraph.width ≤ freeZone.width && paragraph.height ≤ freeZone.height`.
4. If `fits` → emit `LayoutResult`.
5. **Zoom phase**: `zoom` from 1.0 down to `kMinZoom = 0.5`, step `kZoomStep = 0.05`;
   first step where `fits` wins.
6. **Pan phase**: at `zoom = kMinZoom`, pan subject toward the system-opposite
   edge (down for top presets, up for bottom) up to `kMaxPan = shortSide * 0.35`,
   step `0.05 * shortSide`; first `fits` wins.
7. **Text auto-fit**: keep current zoom/pan; reduce `fs` to `0.6 × fs` in
   `0.05 × fs` steps; first `fits` wins.
8. Else → empty quote (`quoteText = ''`) — background + clock + subject only
   (spec: "no free zone → valid output with no quote").

## Composition Pipeline

Draw order is fixed (spec Requirement: Composition Pipeline): background fill →
clock (in system zone, centered/left/right per preset) → subject
(`canvas.drawImageRect(img, src: bbox, dst: dstRect)` — alpha-composited by
the canvas) → quote (centered in free zone). Contrast (D8): relative luminance
of background; text color = white if `contrast(bg, white) ≥ contrast(bg, black)`
else black; quote drawn twice — blurred dark shadow (separation) then text.
Quote uses `ParagraphBuilder` with `TextStyle(fontFamily, fs, color)`; wrapping
is automatic via `ParagraphConstraints(width: freeZone.width)` (spec: multi-line
quote). PNG: `picture.toImage(w, h)` → `toByteData(ImageByteFormat.png)` →
`ByteData.buffer.asUint8List(offsetInBytes, lengthInBytes)`.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/models/render_config.dart` | Create | `RenderConfig` (immutable, const), `ClockPosition`, default `clockText` |
| `lib/models/zones.dart` | Create | `Zones` (system/subject/free Rects) and `LayoutResult` (zoom, pan, quoteFontSize, quoteRect) |
| `lib/engine/alpha_bbox_detector.dart` | Create | PNG bytes → alpha-bbox `Rect` (threshold 128, `rawRgba`) |
| `lib/engine/zone_calculator.dart` | Create | Pure sync `compute(Size, ClockPosition, Rect subject) → Zones` |
| `lib/engine/layout_filter.dart` | Create | Bounded zoom/pan/text-fit search → `LayoutResult` |
| `lib/engine/quote_renderer.dart` | Create | Contrast color + shadow + Paragraph draw |
| `lib/engine/clock_renderer.dart` | Create | Clock text draw in system zone per preset |
| `lib/engine/render_engine.dart` | Create | `RenderEngine.render` orchestration + PictureRecorder pipeline |
| `test/helpers/load_roboto.dart` | Create | Shared `FontLoader('Roboto')` from `test/fonts/Roboto-Regular.ttf` (dedupe Part 0 setup) |
| `test/fixtures/character_alpha.png` | Create | ~256×256 transparent PNG, centered opaque subject (golden + bbox fixture) |
| `test/engine/zone_calculator_test.dart` | Create | Top/bottom presets, sizes, no-intersection |
| `test/engine/alpha_bbox_detector_test.dart` | Create | Opaque center, all-transparent → `Rect.zero`, alpha 128 vs 129 |
| `test/engine/layout_filter_test.dart` | Create | Sufficient → no zoom; insufficient → zoom; floor → pan; never-fits → drop quote |
| `test/engine/render_engine_test.dart` | Create | Degenerate configs: null character, empty quote, no free zone |
| `test/engine/render_engine_determinism_test.dart` | Create | Same config ×2 → byte-identical PNG |
| `test/golden/engine_render_golden_test.dart` | Create | Golden suite + `--update-goldens` workflow |
| `test/golden/goldens/engine_render/*.png` | Create | Baselines: 2 bg × 4 presets (8), + no-character, empty-quote (2) |

No existing `lib/` or `test/` file is modified in this phase (design only).

## Interfaces / Contracts

```dart
// lib/models/render_config.dart
enum ClockPosition { topCenter, topLeft, topRight, bottomCenter }

class RenderConfig {
  const RenderConfig({
    required this.size,            // dart:ui Size
    required this.background,      // dart:ui Color
    required this.quoteText,
    this.characterPng,             // Uint8List?, null = no character
    this.clockPosition = ClockPosition.topCenter,
    this.clockText = '12:34',      // simulated clock (D9)
    this.fontFamily = 'Roboto',
    this.manualZoom,               // double?, override auto-zoom (D7)
    this.manualPan,                // Offset?, override auto-pan (D7)
  });
  final Size size;
  final Color background;
  final Uint8List? characterPng;
  final String quoteText;
  final ClockPosition clockPosition;
  final String clockText;
  final String fontFamily;
  final double? manualZoom;
  final Offset? manualPan;
}

// lib/engine/alpha_bbox_detector.dart
class AlphaBboxDetector {
  /// Rect.zero when all-transparent or decode fails (spec D4).
  static Future<Rect> detect(Uint8List pngBytes); // async: image decode
}

// lib/engine/zone_calculator.dart
class ZoneCalculator {
  static Zones compute(Size size, ClockPosition preset, Rect subjectBbox);
}

// lib/engine/layout_filter.dart
class LayoutFilter {
  static LayoutResult filter(Zones zones, String quoteText, double baseFontSize);
}

// lib/engine/render_engine.dart
class RenderEngine {
  static Future<Uint8List> render(RenderConfig config); // PNG bytes
}
```

Edge behavior: empty `quoteText` → no quote layer; `characterPng == null` or
`Rect.zero` bbox → background + clock only; no free zone after adaptation →
background + clock + subject, no quote. Never throws on degenerate input —
decode failure is `Rect.zero`, and the layout filter always terminates.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | Zone computation (4 presets, sizes, subject/system clipping, no-intersection) | Pure sync asserts on `ZoneCalculator` |
| Unit | Alpha-bbox: opaque center, all-transparent, threshold boundary (alpha 128 excluded, 129 included), corrupt bytes → `Rect.zero` | Synthetic PNGs built with `dart:ui` in-test (deterministic) |
| Unit | Layout filter: sufficient→no zoom; tight→zoom; floor→pan; impossible→empty quote; manual zoom/pan honored | Paragraph layout with pinned Roboto |
| Unit | Degenerate renders: null character, empty quote, no free zone — valid PNG, no crash | `render` + PNG magic-byte assert |
| Unit | Determinism: same config twice → identical bytes | Full byte compare |
| Golden | Composition across 2 bg × 4 presets + no-character + empty-quote baselines | `matchesGoldenFile` on PNG bytes, `flutter test --update-goldens` to regenerate; committed `goldens/engine_render/` |

Golden workflow: plain `test()` + `TestWidgetsFlutterBinding.ensureInitialized()`
(D12). `--update-goldens` regenerates all baselines in one run (spec: atomic —
no partial regeneration; a failure stops at the failing file and CI re-runs).
Regression → `flutter test` fails with a diff report. Commands:
`flutter test test/engine` (unit), `flutter test test/golden/engine_render_golden_test.dart`
(golden), `flutter analyze --fatal-infos` clean.

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file
classification, or process-integration boundary.

## Migration / Rollout

No migration. Greenfield `lib/engine/`, `lib/models/`, `test/engine/`. No app
entry points, MethodChannel, or `pubspec.yaml` changes. Rollback = delete the
new directories (proposal rollback plan).

## Open Questions

- [ ] None — every ambiguity is resolved in Architecture Decisions D1–D12.
