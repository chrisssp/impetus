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

## Verification

- **Font bundling**: `flutter test` — test asserts font file exists and loads
- **FontFamily pinning**: `flutter test` — golden output matches expected Roboto metrics
- **CI determinism**: CI workflow runs `flutter test` twice, golden files are identical
- **Baseline test**: `flutter test` passes including the golden test
