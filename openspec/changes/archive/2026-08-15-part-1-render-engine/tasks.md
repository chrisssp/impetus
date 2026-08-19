# Tasks: Part 1 — Rendering Engine

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~900 (excl. goldens + binary fixture) |
| 400-line budget risk | High (per-slice: P1 ~355, P2 ~335, P3 ~235) |
| Chained PRs recommended | Yes |
| Suggested split | PR 1: models + bbox + zones | PR 2: layout + renderers | PR 3: render + goldens + verify |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Models + shared font harness + AlphaBboxDetector + ZoneCalculator (all 4 presets) | PR 1 | `flutter test test/engine/models_test.dart test/engine/alpha_bbox_detector_test.dart test/engine/zone_calculator_test.dart` | N/A — pure geometry, no render path exists yet | delete `lib/models/`, `lib/engine/alpha_bbox_detector.dart`, `lib/engine/zone_calculator.dart`, `test/helpers/`, and their tests |
| 2 | LayoutFilter (zoom/pan/text-fit) + QuoteRenderer + ClockRenderer | PR 2 | `flutter test test/engine/layout_filter_test.dart test/engine/quote_renderer_test.dart test/engine/clock_renderer_test.dart` | N/A — renderers have no standalone runtime; visual proof lands with PR 3 goldens | delete `lib/engine/layout_filter.dart`, `lib/engine/quote_renderer.dart`, `lib/engine/clock_renderer.dart`, and their tests |
| 3 | RenderEngine.render + degenerate/determinism tests + fixture + 10 goldens + final verification | PR 3 | `flutter test test/golden/engine_render_golden_test.dart && flutter analyze --fatal-infos && flutter test` | `flutter test --update-goldens` generates/validates the 10 committed baselines (visual output) | delete `lib/engine/render_engine.dart`, `test/engine/render_engine*`, `test/fixtures/`, `test/golden/engine*` |

## Phase 1: Foundation — Models + Test Harness (Strict TDD)

- [x] 1.1 Create `test/helpers/load_roboto.dart`: shared `FontLoader('Roboto')` from `File('test/fonts/Roboto-Regular.ttf')` — dedupes Part 0 `setUpAll` pattern
- [x] 1.2 **RED** Create `test/engine/models_test.dart`: `ClockPosition` 4 values; `RenderConfig` fields + defaults (`clockText '12:34'`, `fontFamily 'Roboto'`, null `manualZoom`/`manualPan`); `Zones`/`LayoutResult` construction
- [x] 1.3 **GREEN** Create `lib/models/render_config.dart`: const immutable `RenderConfig` + `ClockPosition` enum per design contract
- [x] 1.4 **GREEN** Create `lib/models/zones.dart`: `Zones` (system/subject/free) + `LayoutResult` (zoom/pan/quoteFontSize/quoteRect)

## Phase 2: AlphaBboxDetector (Strict TDD)

- [x] 2.1 **RED** Create `test/engine/alpha_bbox_detector_test.dart` with synthetic PNGs built via `dart:ui` in-test: opaque center → exact bbox; all-transparent → `Rect.zero`; alpha 128 excluded / 129 included; corrupt bytes → `Rect.zero`
- [x] 2.2 **GREEN** Create `lib/engine/alpha_bbox_detector.dart`: decode PNG, scan `rawRgba` A channel (offset +3), threshold `alpha > 128` (D4)

## Phase 3: ZoneCalculator (Strict TDD)

- [x] 3.1 **RED** Create `test/engine/zone_calculator_test.dart`: 4 presets; system strip `round(h*0.15)` top (top presets) / bottom (`bottomCenter`); band minus clipped subject → 4 candidates (above/below/left/right); positive w&h only, max area; no candidate → `Rect.zero`; free zone never intersects system/subject
- [x] 3.2 **GREEN** Create `lib/engine/zone_calculator.dart`: pure sync `compute(Size, ClockPosition, Rect) → Zones` per D3/D5

## Phase 4: LayoutFilter (Strict TDD)

- [x] 4.1 **RED** Create `test/engine/layout_filter_test.dart` (Paragraph + `load_roboto`): sufficient → no zoom/pan; tight → zoom 1.0→0.5 step 0.05; floor → pan toward system-opposite edge ≤0.35× short side step 0.05; text auto-fit 1.0→0.6× step 0.05; never-fits → empty quote; manual `zoom`/`pan` override (D7)
- [x] 4.2 **GREEN** Create `lib/engine/layout_filter.dart`: bounded search per D6/D7 → `LayoutResult`; always terminates

## Phase 5: QuoteRenderer (Strict TDD)

- [x] 5.1 **RED** Create `test/engine/quote_renderer_test.dart`: contrast color from background luminance (D8) — white on dark, black on light; multi-line wrap within `ParagraphConstraints` width; blurred shadow applied; pinned Roboto
- [x] 5.2 **GREEN** Create `lib/engine/quote_renderer.dart`: WCAG relative-luminance color pick + blurred shadow + `ParagraphBuilder` wrap

## Phase 6: ClockRenderer (Strict TDD)

- [x] 6.1 **RED** Create `test/engine/clock_renderer_test.dart`: `clockText` paragraph laid out inside system zone per preset (top-center/left/right, bottom-center), pinned Roboto, no throw
- [x] 6.2 **GREEN** Create `lib/engine/clock_renderer.dart`: draw clock text in system zone per preset (D2/D9)

## Phase 7: RenderEngine.render (Strict TDD)

- [x] 7.1 **RED** Create `test/engine/render_engine_test.dart`: valid config → PNG magic bytes (`0x89 0x50 0x4E 0x47`); null `characterPng` → background + clock, no crash; empty `quoteText` → background + clock only; no free zone → valid PNG without quote
- [x] 7.2 **RED** Create `test/engine/render_engine_determinism_test.dart`: same config rendered twice → byte-identical
- [x] 7.3 **GREEN** Create `lib/engine/render_engine.dart`: `PictureRecorder` → `drawColor(bg)` → `ClockRenderer` → `drawImageRect(bbox → zoomPan dst)` → `QuoteRenderer` → `toImage` → `toByteData(png)` → `asUint8List`

## Phase 8: Golden Suite + Fixture

- [x] 8.1 Create `test/fixtures/character_alpha.png`: ~256×256 transparent PNG with centered opaque subject (golden + bbox fixture)
- [x] 8.2 **RED** Create `test/golden/engine_render_golden_test.dart`: `load_roboto` + `TestWidgetsFlutterBinding.ensureInitialized`, `matchesGoldenFile(pngBytes)` in plain `test()` (D12) for 10 cases
- [x] 8.3 **GENERATE** `flutter test --update-goldens` → 10 baselines `test/golden/goldens/engine_render/*.png` (2 bg × 4 presets + no-character + empty-quote), atomic regeneration
- [x] 8.4 Verify committed baselines pass without the flag (byte-identical, pinned Roboto)

## Phase 9: Final Verification

- [x] 9.1 Run `flutter analyze --fatal-infos` — zero issues required
- [x] 9.2 Run `flutter test` — full suite green (unit + golden)
- [x] 9.3 Re-run `flutter test --update-goldens` → no diff (baselines byte-identical)
- [x] 9.4 Confirm determinism test passes in the full run (byte-identical ×2)
