# Delta for Golden Harness

## ADDED Requirements

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
