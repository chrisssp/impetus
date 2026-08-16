# Configurator Specification

## Purpose

Layered swipe configurator: the primary interaction surface for composing a
wallpaper. Four fixed layers (background, phrase, character, font), per-layer
fixed/dynamic mode, placeholder pools, shuffle + freeze, blocked-layer
attenuation with suggestions, four simulated clock presets, and a WYSIWYG
preview driven by the Part 1 `RenderEngine`. Placeholder content only — no
persistence, no curated content, no wallpaper application.

## Requirements

### Requirement: Configurator State Model (RE-CF-1)

Configurator state SHALL be held by Riverpod providers and SHALL be immutable —
every mutation SHALL produce a new state instance, never an in-place change.
State SHALL include: the four-layer stack and active layer, per-layer
fixed/dynamic mode, per-layer catalog and pool, shuffle/freeze status,
blocked-layer status, and the selected clock preset. State changes SHALL be
observable through providers without a widget tree (`ProviderContainer`).

#### Scenario: Mutations produce new state

- GIVEN a configurator provider holding state
- WHEN a mutation is applied (e.g., toggling a layer mode)
- THEN the provider state is a new instance
- AND the previous instance is left unchanged

#### Scenario: State readable without widgets

- GIVEN a `ProviderContainer` with configurator providers
- WHEN provider state is read and mutated
- THEN the observed state matches the applied mutations

### Requirement: Layer Stack and Order (RE-CF-2)

The configurator SHALL present exactly four layers in the fixed order:
background, phrase, character, font. The system SHALL NOT reorder, add, or
remove layers under any user action.

#### Scenario: Fixed four-layer stack

- GIVEN the configurator loads
- WHEN the layer stack is inspected
- THEN exactly four layers exist
- AND their order is background → phrase → character → font

#### Scenario: Order is immutable

- GIVEN the configurator is running
- WHEN the user performs any action (swipe, toggle, shuffle)
- THEN the layer order is unchanged

### Requirement: Active Layer and Horizontal Swipe (RE-CF-3)

The configurator SHALL expose exactly one active layer at a time. The active
layer SHALL change via horizontal swipe (left/right) over the four-layer stack.
Swipe SHALL NOT wrap past the first or last layer. The preview SHALL remain
stable (its config unchanged) across swipes.

#### Scenario: Swipe advances the active layer

- GIVEN the background layer is active
- WHEN the user swipes toward the next layer
- THEN the next layer in stack order becomes active

#### Scenario: No wrap at the stack edges

- GIVEN the font layer is active (last layer)
- WHEN the user swipes in the "next" direction
- THEN the active layer remains the font layer
- AND the stack does not wrap to the background

#### Scenario: Preview stable across swipes

- GIVEN a preview has been rendered
- WHEN the user swipes between layers
- THEN the preview config is unchanged
- AND the preview content does not reset

### Requirement: Fixed/Dynamic Mode Toggle (RE-CF-4)

Each layer SHALL expose a fixed/dynamic mode. A dynamic layer SHALL participate
in shuffle; a fixed layer SHALL be skipped by shuffle and keep its user-pinned
selection. Toggling a layer's mode SHALL be reflected in the derived preview
config and SHALL persist while the user navigates between layers.

#### Scenario: Toggle flips the layer mode

- GIVEN a layer in dynamic mode
- WHEN the user toggles the mode
- THEN the layer is fixed
- AND the derived preview config reflects the change

#### Scenario: Mode survives layer navigation

- GIVEN the phrase layer is fixed
- WHEN the user swipes to another layer and back
- THEN the phrase layer is still fixed

### Requirement: Pool Management (RE-CF-5)

Each layer SHALL own a placeholder catalog and a selected pool. The user SHALL
add items from the catalog to the pool and remove items from the pool. Every
pool and catalog item SHALL be a placeholder — no curated phrase or character
content.

#### Scenario: Add item from catalog

- GIVEN a layer with catalog items and an empty pool
- WHEN the user adds a catalog item to the pool
- THEN the item appears in the pool
- AND it appears exactly once

#### Scenario: Remove item from pool

- GIVEN a pool containing an item
- WHEN the user removes the item
- THEN the item no longer appears in the pool

#### Scenario: Placeholders only

- GIVEN the configurator is populated
- WHEN all pools are inspected
- THEN every item is a placeholder (no curated content)

### Requirement: Shuffle and Freeze (RE-CF-6)

The system SHALL provide a shuffle action that re-selects the current item of
every dynamic layer from its pool. A fixed (or frozen) layer SHALL keep its
current item during shuffle. The system SHALL provide a freeze action that
pins a layer's current item so shuffle skips it, and an unfreeze action that
restores shuffle participation.

#### Scenario: Shuffle re-selects dynamic layers only

- GIVEN at least one dynamic layer and one fixed layer
- WHEN the user shuffles
- THEN every dynamic layer's selection is drawn from its pool
- AND the fixed layer's selection is unchanged

#### Scenario: Freeze pins the current item

- GIVEN a layer with a current selection
- WHEN the user freezes it and then shuffles
- THEN the layer's selection does not change

#### Scenario: Unfreeze restores participation

- GIVEN a frozen layer
- WHEN the user unfreezes and then shuffles
- THEN the layer's selection may change again

### Requirement: Blocked Layer Handling (RE-CF-7)

The system SHALL detect a layer whose item cannot reach the preview (e.g., no
free zone for the quote, or no character content) and SHALL render that layer
attenuated with a visible suggestion for unblocking. Blocked state SHALL NOT
cause a crash or an empty preview.

#### Scenario: Blocked layer shows attenuation and suggestion

- GIVEN a layer whose item conflicts with the current layout
- WHEN the configurator renders that layer
- THEN the layer appears attenuated
- AND a suggestion is visible

#### Scenario: Blocked layer never crashes the preview

- GIVEN a blocked layer (no free zone or null character)
- WHEN the preview re-renders
- THEN a valid (degraded) preview is produced
- AND no exception is thrown

### Requirement: Clock Preset Selection (RE-CF-8)

The system SHALL expose the four simulated clock presets — top-center,
top-left, top-right, bottom-center — for selection. The selected preset SHALL
map to `RenderConfig.clockPosition` in the preview.

#### Scenario: All four presets selectable

- GIVEN the clock preset selector
- WHEN the user selects each of the four presets in turn
- THEN each selection is accepted
- AND the derived preview config carries the selected preset

#### Scenario: Preset reaches the preview config

- GIVEN a preset is selected
- WHEN the preview `RenderConfig` is derived
- THEN `clockPosition` equals the selected preset

### Requirement: WYSIWYG Preview Wiring (RE-CF-9)

The system SHALL derive a `RenderConfig` from the current configurator state
and SHALL render it through `RenderEngine.render(config)` as the live preview.
The preview SHALL update on every configurator state change, with re-renders
throttled or debounced so rapid changes do not render per frame. Degenerate
configs (empty quote, null character) SHALL produce a valid preview without
crashing. Preview goldens SHALL use the pinned-Roboto golden harness and SHALL
be byte-deterministic.

#### Scenario: State change re-renders the preview

- GIVEN the preview shows a rendered config
- WHEN configurator state changes (toggle, pool change, preset)
- THEN the preview re-renders from the updated config

#### Scenario: Degenerate config does not crash

- GIVEN a config with an empty quote or null character bytes
- WHEN the preview renders
- THEN a valid preview image is produced
- AND no exception is thrown

#### Scenario: Preview is deterministic

- GIVEN identical configurator state
- WHEN the preview renders twice under the pinned-Roboto harness
- THEN both preview images are byte-identical

### Requirement: Configurator Widget Test Coverage (RE-CF-10)

The project SHALL include widget tests covering: horizontal swipe between
layers, fixed/dynamic toggle, pool add/remove, shuffle + freeze, blocked-layer
attenuation + suggestion, and preview refresh on state change. Each flow SHALL
be testable in isolation using stable widget keys, and `flutter test` SHALL
pass with the full suite green.

#### Scenario: Flow tests exist and pass

- GIVEN the configurator test suite
- WHEN `flutter test` runs
- THEN swipe, toggle, pool, shuffle+freeze, blocked-layer, and
  preview-refresh tests pass
- AND `flutter analyze` reports no issues

### Requirement: Scope Constraints (RE-CF-11)

Part 2 SHALL NOT add real curated content (placeholder items only), SHALL NOT
persist configurator state, SHALL NOT auto-change wallpapers, and SHALL NOT
wire `WallpaperBridge.setBitmap` to the configurator. The `RenderEngine`
contract SHALL be consumed unchanged. Public UI copy and public artifact names
SHALL be English and SHALL NOT use `part1`/`part2`/`partes` prefixes.

#### Scenario: No persistence

- GIVEN the configurator is running
- WHEN the app restarts
- THEN configurator state is reset to defaults (in-memory only)

#### Scenario: No wallpaper application

- GIVEN the preview has rendered
- WHEN the user adjusts layers
- THEN no `setBitmap` call is made

#### Scenario: Engine contract unchanged

- GIVEN the render-engine base spec
- WHEN this part is delivered
- THEN the render-engine spec is not modified
