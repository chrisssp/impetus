# Proposal: Part 2 — Configurator UI

## Intent

Build the layered swipe configurator that lets the user compose a wallpaper
and see it live. This is the product's primary interaction surface: horizontal
swipe between layers (background → phrase → character → font), a fixed/dynamic
mode toggle per layer, a placeholder pool to add/remove items from, a shuffle
button with freeze, blocked-layer attenuation with a suggestion, and the four
simulated clock presets. The WYSIWYG preview wires configurator state into the
Part 1 `RenderEngine.render(config)` so every change re-renders the preview
PNG in real time.

Part 2 is the delivery vehicle for the `configurator` capability declared in
the MVP proposal. It builds strictly on Part 0 (Riverpod shell, golden
harness) and Part 1 (render engine contract, already archived).

## Scope

### In Scope

- **Layered swipe configurator**: horizontal `PageView` over exactly four
  layers in fixed order — background, phrase, character, font. Swiping left /
  right changes the active layer; the preview stays stable across swipes.
- **Fixed/dynamic toggle per layer**: each layer exposes a fixed/dynamic
  choice that feeds the preview state (dynamic = content auto-selects later,
  fixed = user-pinned item; implementation semantics are spec/design scope).
- **Pool management**: each layer owns a catalog of placeholder items and a
  selected pool; add/remove from the catalog updates the pool.
- **Shuffle + freeze**: shuffle button randomizes dynamic layers; freeze pins a
  layer's current item so shuffle skips it.
- **Blocked layers**: a layer whose item conflicts with the current layout
  renders attenuated (visual cue) and shows a suggestion (how to unblock).
- **Simulated clock presets**: UI exposes the four `ClockPosition` presets
  (top-center, top-left, top-right, bottom-center); selection flows to the
  preview.
- **WYSIWYG preview wired to render engine**: derive a `RenderConfig` from
  configurator state and call `RenderEngine.render`; preview re-renders on
  every state change. Placeholder background colors and placeholder character
  bytes drive the preview until real content lands in Part 3.
- **State management**: Riverpod providers holding configurator state —
  layer stack/active layer, per-layer fixed/dynamic mode, per-layer pool,
  shuffle/freeze state, blocked-layer state, clock preset, derived preview
  config. Provider names and shapes are spec/design detail, not fixed here.
- **Widget tests** for the swipe flow, fixed/dynamic toggle flow, pool
  add/remove, shuffle+freeze, and preview refresh on state change.
- `flutter analyze` clean; full `flutter test` suite green (strict TDD, RED
  before GREEN).

### Out of Scope

- **No real content**: placeholder items only — no curated phrase bank, no
  character PNGs (Part 3).
- **No auto-change**: no scheduler, WorkManager, or timed refresh (Part 4).
- **No persistence**: no `shared_preferences` writes; configurator state is
  in-memory only (Part 4).
- **No wallpaper application**: preview is in-app; `WallpaperBridge.setBitmap`
  is not wired to the configurator (Part 4/5).
- **No layer ordering changes**: layer order is fixed to
  background→phrase→character→font.
- **No Spanish/Rioplatense labels**: public UI copy stays English (MVP scope).
- **No engine changes**: the Part 1 `RenderEngine` contract is consumed
  as-is; this part adds no `render-engine` spec delta.

## Capabilities

### New Capabilities

- `configurator`: layered swipe UI (4 fixed layers), per-layer fixed/dynamic
  toggle, pool management against placeholder catalogs, shuffle + freeze,
  blocked-layer attenuation + suggestion, 4 simulated clock presets, and a
  WYSIWYG preview derived from configurator state through the render engine.

### Modified Capabilities

- `app-shell`: the placeholder home screen is replaced by the configurator as
  the app's home; the spike trigger surface is relocated or retained as a
  dev-only entry. Delta spec required.

## Approach

1. **State layer (providers)**: introduce immutable configurator state and the
   Riverpod providers that hold it, fully testable with `ProviderContainer`
   (unit tests, no widgets). This is where swipe index, modes, pools, shuffle/
   freeze, blocking, and clock preset live.
2. **Swipe shell**: a four-page horizontal `PageView` (background → phrase →
   character → font) with a stable preview area; per-layer pages are
   `ConsumerWidget`s. No `setState` for shared state — Riverpod only.
3. **Interaction widgets**: per-layer toggle, pool add/remove against
   placeholder catalogs, shuffle + freeze controls, blocked-layer visual
   attenuation + suggestion chip, clock-preset selector.
4. **Preview wiring**: a derived preview-config provider maps configurator
   state → `RenderConfig` and calls `RenderEngine.render`; results feed an
   `Image` in the preview area, re-rendering on state change.
5. **Strict TDD**: widget tests first for each user flow (RED), then
   implementation (GREEN). Preview tests assert state change → re-render with
   the pinned-Roboto golden harness from Part 0/1.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/configurator/` | New | State, providers, swipe shell, per-layer widgets, preview |
| `lib/main.dart` | Modified | Home becomes the configurator |
| `test/configurator/` | New | Unit + widget tests for all configurator flows |
| `test/golden/` | New | Configurator preview goldens (pinned Roboto) |
| `openspec/specs/configurator/` | New | Configurator capability spec |
| `openspec/specs/app-shell/` | Modified | Home-screen delta spec |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Preview re-render latency on state change (engine runs per change) | Medium | Throttle/debounce re-render; only changed layers rebuild; golden proves determinism |
| Swipe + toggle interactions conflict in widget tests | Medium | Test each flow in isolation with stable finder keys; `pumpAndSettle` only after animations settle |
| `PageView` golden flakiness | Low | Reuse pinned-Roboto harness; fixed surface size; no time-based content |
| Feature creep toward content/persistence | Medium | Explicit scope-out list; PR slices bound the work |

## Rollback Plan

All new code lives under `lib/configurator/` and `test/configurator/`. The
`lib/main.dart` change is the only touch to existing code. Rollback: remove
`lib/configurator/`, `test/configurator/`, and the preview goldens, and revert
`lib/main.dart` to the Part 0 placeholder shell. No engine, bridge, or
persistence code is modified, so no migration risk.

## Dependencies

- Part 0 delivered (Riverpod `ProviderScope`, golden harness, pinned Roboto).
- Part 1 delivered and merged (immutable `RenderConfig`, `RenderEngine.render`
  → PNG bytes).
- No new external dependencies.

## Success Criteria (Exit Criteria)

- [ ] User can swipe horizontally between the four layers (bg → phrase →
      character → font) and the active layer is visually identified.
- [ ] User can toggle fixed/dynamic per layer and the toggle is reflected in
      preview state.
- [ ] User can add/remove pool items from the placeholder catalog per layer.
- [ ] User can shuffle dynamic layers and freeze a layer so shuffle skips it.
- [ ] Blocked layers render attenuated with a suggestion visible.
- [ ] User can select each of the four simulated clock presets and the preview
      updates.
- [ ] The WYSIWYG preview updates in real time on every state change (wired to
      `RenderEngine.render`).
- [ ] Widget tests pass for swipe, toggle, shuffle+freeze, and preview-refresh
      flows; `flutter analyze` clean; full `flutter test` green.

## PR Slice Strategy

Estimated ~700 changed lines (UI + widget tests; goldens excluded from
authored-risk count). Delivery: auto-chain, stacked-to-main, review budget 800
for the part — each slice well under 400.

| Slice | Work unit | Est. lines | Focused test command |
|-------|-----------|-----------|----------------------|
| PR 1 | Configurator state + providers (layers, modes, pools, shuffle/freeze, blocking, clock preset) | ~180 | `flutter test test/configurator/state_test.dart` |
| PR 2 | Swipe shell + per-layer pages + clock-preset selector | ~180 | `flutter test test/configurator/swipe_shell_test.dart` |
| PR 3 | Toggle, pool add/remove, shuffle+freeze, blocked-layer attenuation + suggestion | ~200 | `flutter test test/configurator/interactions_test.dart` |
| PR 4 | WYSIWYG preview wired to render engine + goldens + `main.dart` swap + full verification | ~160 | `flutter test && flutter analyze --fatal-infos` |

Each PR targets the previous PR's branch; the final PR lands on `main` after
the earlier three merge. Every slice keeps its own autonomous scope, focused
tests, and rollback boundary (delete its files + revert `main.dart`).

**Public naming**: branches, commits, and PR titles use no `part1`/`part2`
prefixes — e.g. `feat(configurator): add swipe shell`. The internal change
name `part-2-configurator-ui` is a planning artifact only.
