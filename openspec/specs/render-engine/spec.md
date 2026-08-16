# Render Engine Specification

## Purpose

Deterministic `RenderConfig → PNG bytes` rendering engine. Pure function, no widgets, no MethodChannel.

## Requirements

### Requirement: Engine Input Contract

SHALL accept a `RenderConfig` with: dimensions, background color, character PNG bytes (`Uint8List?`), quote text, clock position preset (top-center/top-left/top-right/bottom-center), font family, optional zoom/pan offsets.

#### Scenario: Valid config produces PNG

- GIVEN a valid `RenderConfig`
- WHEN `RenderEngine.render(config)` is called
- THEN a `Uint8List` of valid PNG bytes is returned

#### Scenario: Config without character

- GIVEN a config with null character bytes
- WHEN rendered
- THEN output contains background and clock only — no crash

### Requirement: System Zone Computation

SHALL compute a system zone per clock preset. Top presets produce a full-width strip at the top; bottom-center produces a full-width strip at the bottom. Height is preset-dependent.

#### Scenario: Top preset

- GIVEN 1080×1920 wallpaper with `top-center` clock
- WHEN system zone is computed
- THEN it spans full width at the top with the preset height

#### Scenario: Bottom preset

- GIVEN 1080×1920 wallpaper with `bottom-center` clock
- WHEN system zone is computed
- THEN it spans full width at the bottom with the preset height

### Requirement: Subject Zone Detection

SHALL scan character PNG alpha and compute bounding box for pixels where alpha > 128. All-transparent → `Rect.zero`.

#### Scenario: Opaque character center

- GIVEN PNG with opaque pixels in a centered region
- WHEN alpha-bbox is computed
- THEN bounding box encloses only opaque pixels

#### Scenario: All-transparent character

- GIVEN PNG where all pixels have alpha ≤ 128
- WHEN alpha-bbox is computed
- THEN bounding box is `Rect.zero`, no crash

### Requirement: Free Zone Computation

SHALL compute the free zone as the largest contiguous rectangle after subtracting system and subject zones from the wallpaper.

#### Scenario: Free zone avoids occupied zones

- GIVEN system and subject zones defined
- WHEN free zone is computed
- THEN it does not intersect either zone

### Requirement: Layout Filtering

SHALL verify the free zone fits the quote. If insufficient, SHALL apply zoom/pan to the character to create more free space.

#### Scenario: Sufficient free zone

- GIVEN a free zone large enough for the quote
- WHEN layout filtering runs
- THEN quote is placed without zoom/pan

#### Scenario: Insufficient — zoom/pan fallback

- GIVEN a free zone too small for the quote
- WHEN layout filtering runs
- THEN character is zoomed/panned to enlarge the free zone

### Requirement: Composition Pipeline

SHALL compose layers in order: (1) background, (2) clock, (3) character alpha-composited, (4) quote. Rendered via `dart:ui` `PictureRecorder` + `Canvas` → `toImage` → PNG.

#### Scenario: Full composition

- GIVEN a config with all elements
- WHEN composition runs
- THEN output contains all four layers in z-order with correct alpha compositing

### Requirement: Quote Rendering

SHALL render quote text with line-breaking to fit the free zone and shadow/stroke for contrast. Font family from `RenderConfig` MUST be used.

#### Scenario: Multi-line quote

- GIVEN a quote exceeding free zone width
- WHEN rendered
- THEN text wraps within bounds with contrast shadow

### Requirement: Legibility Guarantees

SHALL ensure quote never overlaps with system or subject zone. SHOULD maintain ≥4.5:1 contrast ratio.

#### Scenario: Quote avoids occupied zones

- GIVEN system and subject zones defined
- WHEN quote is rendered
- THEN quote bounding box does not intersect either zone

### Requirement: Degenerate Config Handling

SHALL handle: empty quote → no text; missing character → background + clock; no free zone → valid output with no quote.

#### Scenario: Empty quote

- GIVEN `quoteText: ""`
- WHEN rendered
- THEN output has background and clock only

### Requirement: Deterministic Output

SHALL produce byte-identical PNG for identical `RenderConfig` inputs.

#### Scenario: Identical configs → identical bytes

- GIVEN the same config rendered twice
- WHEN both outputs are compared
- THEN they are byte-identical
