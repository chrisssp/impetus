# Tasks: Part 2 — Configurator UI

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~2,200 (excl. goldens + binary) |
| 400-line budget risk | High (per-slice: PR1 ~340, PR2 ~190, PR3 ~330, PR4 ~390, PR5 ~220, PR6 ~550, PR7 ~110) |
| Chained PRs recommended | Yes |
| Suggested split | PR1 state → PR2 notifier → PR3 mapping+blocking → PR4 pipeline+providers → PR5 preview UI+goldens → PR6 shell+layers+interactions → PR7 shell wiring+verify |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

> Estimate note: part-1 estimated ~900 but committed ~2,450 lines of .dart —
> ~2.7× understatement. Applying that ratio to this part's ~700-line projection
> gives the ~2,200 figure above. Slicing is finer than design's "4 PR slices"
> to honor the per-slice 400-line budget; slices are the operative delivery plan.

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | State model + catalogs + immutable state (RE-CF-1/2) | PR 1 | `flutter test test/configurator/state_test.dart` | N/A — pure data types; `ProviderContainer` immutability tests are the runtime proof | delete `lib/configurator/{layer_model,catalog,placeholder_assets,configurator_state}.dart` + `test/configurator/state_test.dart` |
| 2 | Notifier actions (RE-CF-4/5/6/8) | PR 2 | `flutter test test/configurator/state_test.dart` | N/A — seeded `randomProvider` override in `ProviderContainer` is the runtime proof | delete `lib/configurator/configurator_notifier.dart` (state_test Part B rows revert) |
| 3 | `buildRenderConfig` + `BlockAnalyzer` (RE-CF-7/8) | PR 3 | `flutter test test/configurator/build_config_test.dart test/configurator/blocking_test.dart` | N/A — pure mapping + layout math on committed fixture `character_alpha.png` | delete `lib/configurator/{blocking,preview_pipeline}.dart` + both tests |
| 4 | `renderPreview` + preview providers (RE-CF-9) | PR 4 | `flutter test test/configurator/preview_pipeline_test.dart test/configurator/preview_provider_test.dart` | determinism test double-render = runtime proof of engine wiring | delete `lib/configurator/preview_provider.dart` + renderPreview in pipeline + both tests |
| 5 | `PreviewPanel` + preview goldens (RE-CF-9) | PR 5 | `flutter test test/configurator/preview_widget_test.dart test/golden/configurator_preview_golden_test.dart` | `flutter test --update-goldens` generates/validates the 3 committed preview baselines (visual output) | delete `preview_panel.dart` + `preview_widget_test.dart` + golden test + `goldens/configurator_preview/` |
| 6 | Swipe shell + layer pages + interactions (RE-CF-3/4/5/6/7/10) | PR 6 | `flutter test test/configurator/swipe_shell_test.dart test/configurator/interactions_test.dart` | widget tests pump `ConfiguratorView` — real gesture path | delete `lib/configurator/{configurator_view,clock_selector,shuffle_bar,layer_page}.dart` + both tests |
| 7 | App-shell wiring + final verification (RE-AS-2/3) | PR 7 | `flutter test test/widget_test.dart test/golden/app_shell_golden_test.dart && flutter analyze --fatal-infos && flutter test` | `flutter test --update-goldens` regenerates `app_shell.png` (visual proof of new home) | delete `spike_dev_trigger.dart`; revert `main.dart`, `widget_test.dart`, `app_shell_golden_test.dart`, `app_shell.png` |

Delivery: auto-chain, stacked-to-main (design D15 — public commits/PRs use
`feat(configurator): ...`, no `part` prefixes).

## Phase 1: Configurator State Foundation (Strict TDD) — PR 1

- [x] 1.1 **RED** Create `test/configurator/state_test.dart` (Part A, `ProviderContainer`, no widgets): RE-CF-1 `copyWith` yields new instance and leaves previous unchanged; RE-CF-2 exactly 4 layers in fixed order background→phrase→character→font and order immutable under any `copyWith`
- [x] 1.2 **GREEN** Create `lib/configurator/layer_model.dart`: `LayerType` (4 values, D3), `LayerMode` (fixed/dynamic), abstract `LayerItem` + `BackgroundItem`/`PhraseItem`/`CharacterItem`/`FontItem` subtypes (D3)
- [x] 1.3 **GREEN** Generate `lib/configurator/placeholder_assets.dart`: 4 embedded character PNG literals via a throwaway script (not committed), `kSpikePngBytes` precedent (D4)
- [x] 1.4 **GREEN** Create `lib/configurator/catalog.dart`: 4 const placeholder catalogs + default pools; every item a placeholder (RE-CF-5/11)
- [x] 1.5 **GREEN** Create `lib/configurator/configurator_state.dart`: immutable `ConfiguratorState` (activeLayerIndex, modes, pools, selectedIds, frozen, clockPosition) + `copyWith` with unmodifiable index-keyed lists (D2)
- Verify: `flutter test test/configurator/state_test.dart && flutter analyze --fatal-infos`

## Phase 2: ConfiguratorNotifier Actions (Strict TDD) — PR 2

- [x] 2.1 **RED** Append to `test/configurator/state_test.dart` (Part B): RE-CF-4 `toggleMode` flips fixed/dynamic and survives `setActiveLayer` navigation; RE-CF-5 `addToPool` dedupes by id (appears exactly once), `removeFromPool` removes + selection falls back to first remaining or null (D8); RE-CF-6 `shuffle` with seeded `randomProvider` re-selects only dynamic && !frozen, `freeze` pins, `unfreeze` restores (D6/D7); RE-CF-8 all 4 `ClockPosition` presets accepted via `setClockPosition`
- [x] 2.2 **GREEN** Create `lib/configurator/configurator_notifier.dart`: `randomProvider = Provider<Random>` (D7) + `ConfiguratorNotifier extends Notifier<ConfiguratorState>` (D1) implementing `setActiveLayer` (clamp 0..3), `toggleMode`, `addToPool`, `removeFromPool`, `selectItem`, `shuffle`, `freeze`/`unfreeze`, `setClockPosition`; export `configuratorStateProvider`
- Verify: `flutter test test/configurator/state_test.dart`

## Phase 3: RenderConfig Mapping + Block Analysis (Strict TDD) — PR 3

- [x] 3.1 **RED** Create `test/configurator/build_config_test.dart`: canvas 540×960 (D11); selected background/quote/character/font items resolve into `RenderConfig` fields; preset maps to `clockPosition` (RE-CF-8); empty pools → degenerate config (empty `quoteText`, null `characterPng`) that never throws (RE-CF-9)
- [x] 3.2 **RED** Create `test/configurator/blocking_test.dart` (RE-CF-7): phrase blocked when pool empty/quoteRect empty (suggestion "No room for the quote…"); character blocked when bytes null/empty or `Rect.zero` bbox ("Add a character…"/"Pick a character…"); background/font blocked when pool empty (defensive suggestions); never throws — using `AlphaBboxDetector.detect` + `ZoneCalculator.compute` + `LayoutFilter.filter` on `test/fixtures/character_alpha.png` (D9)
- [x] 3.3 **GREEN** Add pure `buildRenderConfig(ConfiguratorState) → RenderConfig` to `lib/configurator/preview_pipeline.dart` (D11)
- [x] 3.4 **GREEN** Create `lib/configurator/blocking.dart`: `BlockReason`/`LayerBlockStatus`/`LayerBlockStatuses` + `BlockAnalyzer.analyze` per D9 (English suggestions, RE-CF-11)
- Verify: `flutter test test/configurator/build_config_test.dart test/configurator/blocking_test.dart`

## Phase 4: Preview Pipeline + Providers (Strict TDD) — PR 4

- [x] 4.1 **RED** Create `test/configurator/preview_pipeline_test.dart`: `renderPreview` valid config → PNG magic bytes (`0x89 0x50 0x4E 0x47`) + block statuses; degenerate configs (empty quote, null character) → valid PNG without throwing; same config twice → byte-identical (RE-CF-9 determinism)
- [x] 4.2 **RED** Create `test/configurator/preview_provider_test.dart` (added beyond design file table — covers D12 mechanisms): `previewProvider` debounces burst edits for `kPreviewDebounce` (100 ms) into a single render; generation counter discards a stale late result (latest-wins); render error surfaces as `AsyncError` without throwing; `blockStatusProvider` = all-unblocked while loading, `r.blocks` on data (D10)
- [x] 4.3 **GREEN** Add async `renderPreview(RenderConfig) → Future<PreviewResult>` (png + `LayerBlockStatuses`) to `lib/configurator/preview_pipeline.dart` (D9/D11): `RenderEngine.render` + `BlockAnalyzer.analyze`
- [x] 4.4 **GREEN** Create `lib/configurator/preview_provider.dart`: `previewConfigProvider` watching only render-relevant state (so swipe does not re-render, RE-CF-3), `kPreviewDebounce`, `previewProvider` (`AsyncNotifier`, `ref.listen` debounce + generation counter + error fallback + immediate initial render, D12), `blockStatusProvider` (D10)
- Verify: `flutter test test/configurator/preview_pipeline_test.dart test/configurator/preview_provider_test.dart`

## Phase 5: PreviewPanel + Preview Goldens (Strict TDD) — PR 5

- [x] 5.1 **RED** Create `test/configurator/preview_widget_test.dart` (RE-CF-9): state change (toggle/pool/preset) → preview re-renders — override `previewProvider` with a fake notifier, assert new bytes consumed via `Image.memory`; `AsyncError` → fallback placeholder shown, no crash (RE-CF-7)
- [x] 5.2 **GREEN** Create `lib/configurator/preview_panel.dart`: `PreviewPanel` = `ConsumerWidget` → `Image.memory(gaplessPlayback: true, fit: BoxFit.contain)` in `RepaintBoundary` + `AspectRatio(9/16)`; loading/error → static placeholder box (D13)
- [x] 5.3 **RED** Create `test/golden/configurator_preview_golden_test.dart`: `loadRoboto` (test/helpers/load_roboto.dart) + `TestWidgetsFlutterBinding.ensureInitialized`, `matchesGoldenFile` on `renderPreview` output for 3 fixed states (default / no-character / empty-pool phrase) — part-1 D12 pattern
- [x] 5.4 **GENERATE** `flutter test --update-goldens` → 3 baselines `test/golden/goldens/configurator_preview/{default,no_character,empty_pool_phrase}.png`
- [x] 5.5 Verify committed baselines pass without the flag (byte-identical, pinned Roboto)
- Verify: `flutter test test/configurator/preview_widget_test.dart test/golden/configurator_preview_golden_test.dart`

## Phase 6: Swipe Shell + Layer Pages + Interactions (Strict TDD) — PR 6

- [x] 6.1 **RED** Create `test/configurator/interactions_test.dart` (RE-CF-4/5/6/7/10): toggle flow (`mode_toggle_$i`), pool add/remove (`pool_item_$id`), shuffle+freeze UI (`shuffle_button`), blocked page attenuated + suggestion banner visible (`blocked_banner_$i`), stable keys, isolated pumps
- [x] 6.2 **RED** Create `test/configurator/swipe_shell_test.dart` (RE-CF-3): `tester.fling` on `PageView` → active layer advances via provider index; no wrap at font edge (clamp physics); preview config unchanged across swipes (override preview provider, re-render counter stays 0); `pumpAndSettle` after animations
- [x] 6.3 **GREEN** Create `lib/configurator/clock_selector.dart`: 4 `ClockPosition` presets UI → `setClockPosition` (RE-CF-8)
- [x] 6.4 **GREEN** Create `lib/configurator/shuffle_bar.dart`: shuffle + freeze/unfreeze controls (RE-CF-6)
- [x] 6.5 **GREEN** Create `lib/configurator/layer_page.dart`: mode toggle, catalog add / pool remove, item selection, blocked attenuation + suggestion banner (D9/D10, RE-CF-7)
- [x] 6.6 **GREEN** Create `lib/configurator/configurator_view.dart`: persistent `PreviewPanel` above a 4-fixed-page `PageView` + shuffle bar + clock selector; `PageController` default clamp physics, `onPageChanged` → `setActiveLayer` (D5)
- Verify: `flutter test test/configurator/interactions_test.dart test/configurator/swipe_shell_test.dart`

## Phase 7: App-Shell Integration (Strict TDD) — PR 7

- [x] 7.1 **RED** Update `test/widget_test.dart`: home = `ConfiguratorView` (AppBar 'Impetus'), no placeholder FAB; spike entry in AppBar actions, one-shot (RE-AS-2/3)
- [x] 7.2 **RED** Update `test/golden/app_shell_golden_test.dart`: override `previewConfigProvider` with pre-rendered result; `tester.runAsync` to complete image decode (D14)
- [x] 7.3 **GREEN** Create `lib/configurator/spike_dev_trigger.dart`: `SpikeDevTrigger` rendered only under `kDebugMode`, reuses untouched `spikeStateProvider`/`wallpaperBridgeProvider` (D14)
- [x] 7.4 **GREEN** Update `lib/main.dart`: home = `ConfiguratorView` (`Scaffold` + `AppBar('Impetus')`); remove `HomeShell` + FAB; AppBar action hosts `SpikeDevTrigger` (D14)
- [x] 7.5 **GENERATE** `flutter test --update-goldens` → regenerated `test/golden/goldens/app_shell.png`
- [x] 7.6 Verify committed `app_shell.png` passes without the flag (RE-AS-2)
- Verify: `flutter test test/widget_test.dart test/golden/app_shell_golden_test.dart`

## Phase 8: Final Verification — PR 7

- [x] 8.1 Run `flutter analyze --fatal-infos` — zero issues required
- [x] 8.2 Run `flutter test` — full suite green (unit + widget + golden; RE-CF-10)
- [x] 8.3 Re-run `flutter test --update-goldens` → no diff (all baselines byte-identical, including regenerated `app_shell.png`)
- [x] 8.4 Confirm `test/widget_test.dart` references the new home deliberately (RE-AS-2) and scope constraints hold (RE-CF-11: no persistence, no setBitmap wiring, no engine change)
