# Proposal: Part 1 — Rendering Engine

## Intent

Build a deterministic rendering engine that composes wallpaper images from configuration input. The engine is the core of the product: it takes background color, character PNG, quote text, clock position, and wallpaper geometry, then outputs a single composed PNG. This is the foundation for Part 2 (WYSIWYG configurator) and Part 3 (content selection).

## Scope

### In Scope

- **3-zone computation**: system zone (status bar + clock), subject zone (character bbox from alpha channel), free zone (largest remaining → quote placement).
- **Alpha-channel bbox detection**: scan character PNG alpha channel to derive subject bounding box.
- **Simulated clock rendering**: clock position presets (top-center, top-left, top-right, bottom-center) — engine receives clock position + rendered clock representation.
- **Layout filtering**: fixed-layout filter that checks whether a character's free zone fits the required quote area; fallback to character zoom/pan when no zone fits (decision 14).
- **Composition pipeline**: `dart:ui PictureRecorder` + `Canvas` → `toImage` → PNG bytes. Renders background, clock, character (alpha-composited), quote (with contrast/legibility checks — text never hidden, never overlapping subject).
- **Engine API**: pure function `RenderEngine.render(config) → Uint8List` — testable in isolation, no widgets, no MethodChannel.
- **Golden tests**: engine render goldens using bundled Roboto, pinned fontFamily, same harness pattern as Part 0.
- **Unit tests**: zone computation, alpha-bbox detection, layout filtering logic.

### Out of Scope

- Configurator UI (Part 2), content/phrases/characters (Part 3), scheduler (Part 4).
- MethodChannel changes (bridge frozen).
- Wallpaper application (production apply wiring is later).
- Shuffle/deterministic phrase selection (Part 2/3 concern).
- Any design/branding asset changes.

## Capabilities

### New Capabilities

- `render-engine`: 3-zone computation, alpha-bbox detection, deterministic composition pipeline, layout filtering, simulated clock integration, engine API contract.

### Modified Capabilities

- `golden-harness`: extend existing harness with engine-specific golden tests (same Roboto/pinned-font pattern, new golden baseline for engine output).

## Approach

**Engine architecture**: single `RenderEngine` class with static `render(RenderConfig) → Uint8List` method. `RenderConfig` is an immutable data class holding all inputs (wallpaper size, background color, character PNG bytes, quote text, clock position, font family). Pure function — no side effects, no state.

**Zone computation**: given wallpaper geometry + clock position, compute system zone (status bar height + clock bounding box), then scan character alpha channel for subject bbox. Free zone = wallpaper minus system minus subject; pick largest contiguous rectangle.

**Alpha-bbox strategy**: decode PNG to `dart:ui.Image`, iterate pixels row-by-row, find min/max x/y where alpha > threshold (e.g. 128). Returns `Rect` of the character's opaque region.

**Deterministic render pipeline**: `PictureRecorder` → `Canvas` → draw background fill → draw clock at position → draw character (alpha compositing) → draw quote (with line-breaking, contrast shadow/stroke for legibility) → `picture.toImage(w, h)` → `ByteData` → PNG bytes via `ui.imageByteFormat`.

**Golden strategy**: same pattern as Part 0 — load bundled Roboto via `FontLoader`, pin `fontFamily`, compare engine output PNG against baseline. Engine goldens test composition correctness, not widget rendering.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/engine/` (new) | New | Engine API, zone computation, render pipeline |
| `lib/models/` (new) | New | `RenderConfig` and related data classes |
| `test/engine/` (new) | New | Unit tests + golden tests for engine |
| `openspec/specs/render-engine/` (new) | New | Spec for the render engine capability |
| `openspec/specs/golden-harness/` | Modified | Add engine golden test scenarios |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Alpha-bbox accuracy on edge-case PNGs (low contrast, noisy alpha) | Medium | Threshold tuning + golden tests with representative character PNGs |
| Render performance >1s on mid-range devices | Low | Profile early; `dart:ui` canvas is hardware-accelerated; no widget tree overhead |
| Clock rendering complexity (simulated time display) | Low | Keep clock as simple text + icon; reuse Roboto font |
| Golden test fragility across Flutter versions | Medium | Pin Flutter channel; regenerate goldens on upgrade; use `golden_tool` tolerance if needed |

## Rollback Plan

All new code lives under `lib/engine/` and `lib/models/`. No existing files are modified except extending the golden-harness spec. To rollback: remove `lib/engine/`, `lib/models/`, `test/engine/`, and `openspec/specs/render-engine/`. The app shell and bridge remain untouched.

## Dependencies

- Part 0 complete (golden harness with bundled Roboto, Riverpod shell).
- Bundled `Roboto-Regular.ttf` in `test/fonts/` (already exists).
- No new external dependencies — uses only `dart:ui`, `dart:typed_data`, and `dart:io` for PNG encoding.

## Success Criteria

- [ ] `RenderEngine.render(config)` returns deterministic PNG bytes (same config → same output).
- [ ] Golden test passes with bundled Roboto on CI.
- [ ] 3-zone computation correctly handles all 4 clock position presets.
- [ ] Alpha-bbox detection produces correct bounding box for test character PNGs.
- [ ] Quote never overlaps subject or system zone in any golden output.
- [ ] Unit tests cover zone computation, bbox detection, and layout filtering.
- [ ] Engine API is a pure function — testable without Flutter widget framework or MethodChannel.
