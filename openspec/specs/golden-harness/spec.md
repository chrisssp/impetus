# Golden Harness Specification

## Purpose

Deterministic golden-test infrastructure: bundled Roboto font, pinned `fontFamily` in test setup, and a baseline golden test that renders identically across CI runs regardless of host font configuration.

## Requirements

### Requirement: Roboto Font Bundling

The system SHALL bundle `Roboto-Regular.ttf` as a test asset so golden tests never fall back to the Ahem placeholder font.

#### Scenario: Font file present in test assets

- GIVEN the golden harness is configured
- WHEN `flutter test` runs
- THEN `test/fonts/Roboto-Regular.ttf` exists and is loadable
- AND the font file matches the canonical Roboto Regular metrics

### Requirement: Pinned FontFamily in Test Setup

The system SHALL configure `golden_tool` or test setup to pin `fontFamily: 'Roboto'` for all golden tests.

#### Scenario: Test environment uses bundled Roboto

- GIVEN a golden test renders a widget with text
- WHEN the test runs in CI (Ubuntu) or local development
- THEN the rendered text uses the bundled Roboto font
- AND NOT the Ahem placeholder or any host-system font

#### Scenario: CI consistency

- GIVEN the same golden test runs on two different CI runs
- WHEN both runs complete
- THEN the golden output files are byte-identical
- AND no font substitution warnings appear in test output

### Requirement: Deterministic Golden Baseline

The system SHALL include one golden baseline test that passes consistently across CI runs.

#### Scenario: Baseline golden test passes

- GIVEN the golden harness is configured with pinned Roboto
- WHEN `flutter test` runs the golden baseline test
- THEN the test passes on first run (golden generated)
- AND the test passes on subsequent runs (golden matches)

#### Scenario: Baseline golden test detects regressions

- GIVEN a golden baseline exists
- WHEN a widget change alters the rendered output
- THEN `flutter test --update-goldens` regenerates the baseline
- AND the test passes with the updated golden

### Requirement: Engine Golden Test Fixtures

The system SHALL include engine golden test fixtures covering: at least two background colors (dark, light), at least one quote text, at least one character PNG with alpha channel, and all four clock position presets (top-center, top-left, top-right, bottom-center). Fixtures MUST be bundled as test assets.

#### Scenario: Engine fixtures present

- GIVEN the golden harness is configured for engine tests
- WHEN `flutter test` runs
- THEN engine golden fixtures exist for all four clock presets
- AND fixtures include at least one character PNG with alpha transparency

#### Scenario: Engine golden test passes

- GIVEN engine golden fixtures are bundled
- WHEN `RenderEngine.render` is called with a fixture config
- THEN the output matches the baseline golden PNG
- AND the test passes using the same pinned Roboto font

### Requirement: Engine Golden Baseline Regeneration

The system SHALL support baseline regeneration for engine golden tests via `flutter test --update-goldens`. Regeneration MUST update all engine golden files atomically — partial regeneration is not permitted.

#### Scenario: Regenerate engine goldens after intentional change

- GIVEN engine golden baselines exist
- WHEN the render engine output changes intentionally
- THEN `flutter test --update-goldens` regenerates all engine golden files
- AND subsequent `flutter test` passes with updated baselines

#### Scenario: Engine golden detects regression

- GIVEN engine golden baselines exist
- WHEN a code change alters engine output unintentionally
- THEN `flutter test` fails on the engine golden test
- AND the failure output shows the diff between actual and expected

## Verification

- **Font bundling**: `flutter test` — test asserts font file exists and loads
- **FontFamily pinning**: `flutter test` — golden output matches expected Roboto metrics
- **CI determinism**: CI workflow runs `flutter test` twice, golden files are identical
- **Baseline test**: `flutter test` passes including the golden test
