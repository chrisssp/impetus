# Design: Part 2 — Configurator UI

## Technical Approach

A four-page horizontal swipe configurator (background → phrase → character →
font) built on an immutable `ConfiguratorState` held by Riverpod providers,
with a WYSIWYG preview derived from that state through the Part 1
`RenderEngine`. Pure state logic (`ConfiguratorNotifier`) is fully testable
via `ProviderContainer`; a pure `buildRenderConfig(state) → RenderConfig`
mapping and an async `renderPreview(config) → PreviewResult` pipeline (PNG
bytes + per-layer block statuses) give fast widget tests and deterministic
PNG-level goldens. Blocked layers (RE-CF-7) are detected by reusing the
engine's exported pure building blocks (`AlphaBboxDetector`, `ZoneCalculator`,
`LayoutFilter`) — the engine contract is consumed unchanged (RE-CF-11).
The app shell home becomes the configurator; the spike trigger is relocated to
a `kDebugMode`-gated dev entry (RE-AS-2/RE-AS-3).

## Architecture Decisions

| # | Decision | Alternatives | Rationale |
|---|----------|--------------|-----------|
| D1 | `NotifierProvider<ConfiguratorNotifier, ConfiguratorState>`; not `autoDispose`, not `family` | `StateNotifierProvider`, `StateProvider`, `AsyncNotifier`, per-layer families | Riverpod 2's current recommended class; state is an app-lifetime singleton (in-memory only, RE-CF-11); mutations are synchronous; `autoDispose` would drop state when consumers unsubscribe; no family — exactly one configurator. Testable via `ProviderContainer` (RE-CF-1). |
| D2 | Immutable `ConfiguratorState`: `activeLayerIndex`, `modes[4]` (`LayerMode.fixed/dynamic`), `pools[4]` (unmodifiable `List<LayerItem>`), `selectedIds[4]` (`String?`), `frozen[4]`, `clockPosition`. Every mutation returns a new instance via `copyWith` | Mutable `ChangeNotifier`, flat fields + rebuild | RE-CF-1 mandates immutable + observable without a widget tree; one flat object keeps unit tests 1:1 with spec scenarios; index-keyed lists mirror the fixed 4-layer stack (RE-CF-2). |
| D3 | `LayerType` enum (background/phrase/character/font) + typed `LayerItem` subtypes carrying payloads (`BackgroundItem.color`, `PhraseItem.text`, `CharacterItem.bytes`, `FontItem.family`); four const placeholder catalogs; pools hold items by value, selection by `id` | Id-only pools + external resolvers; untyped `dynamic` payloads | Payload-in-item keeps `buildRenderConfig` pure and sync; typed subtypes avoid `dynamic` casting; id-based dedupe gives RE-CF-5 "exactly once". All items are placeholders (RE-CF-5/RE-CF-11). |
| D4 | Placeholder character bytes are embedded PNG literals in `placeholder_assets.dart`, generated once by a throwaway script at apply time | Bundle under `pubspec assets:`, runtime `dart:ui` generation | Follows the existing `kSpikePngBytes` literal precedent (`lib/services/wallpaper_bridge.dart`); keeps the mapping sync/deterministic; zero `pubspec.yaml` change (RE-CF-11). Runtime generation would force async byte resolution into the pure mapping. |
| D5 | Layer stack + swipe: horizontal `PageView` + `PageController`, 4 fixed pages in enum order, default clamp physics (no wrap, RE-CF-3); `onPageChanged` → `notifier.setActiveLayer`; the preview is a persistent panel ABOVE the `PageView`, never inside a page; no `KeepAlive` | Custom gesture recognizer, `IndexedStack`+manual swipe, keepalive pages | `PageView` is the platform-idiomatic horizontal swipe; the preview-outside-pages structure is the *structural* guarantee of RE-CF-3 preview stability (page lifecycle cannot reset it); per-page ephemeral state is nil because modes/pools/selections live in providers (RE-CF-4 mode survives navigation). |
| D6 | Fixed/dynamic and freeze are independent: shuffle re-selects layer `i` iff `modes[i] == dynamic && !frozen[i]`; fixed keeps its pinned selection; `freeze`/`unfreeze` flip the per-layer flag; toggling fixed→dynamic preserves `frozen` | Freeze as a mode value; single combined flag | RE-CF-4 and RE-CF-6 are distinct actions; orthogonal flags are the minimal model and give unit tests 1:1 with spec scenarios (shuffle skips fixed AND frozen; unfreeze restores participation). |
| D7 | `randomProvider = Provider<Random>((_) => Random())`; the notifier reads it inside `shuffle()`; tests override it with a seeded `Random` | Seeded constructor, global `Random`, seed in state | Riverpod-idiomatic DI keeps the notifier arg-less for the default provider; seeded override makes RE-CF-6 shuffle assertions deterministic. |
| D8 | Pool identity (RE-CF-5): `addToPool` dedupes by `id`; `removeFromPool` removes by `id`; if the currently selected item is removed, selection falls back to the pool's first remaining item (or `null`); selecting a pool item pins `selectedIds[i]` | Selection becomes null on remove; forbid removing selected item | Never leaves a stale/unreachable selection; deterministic fallback is testable; preview always renderable from some pool item. |
| D9 | Blocked detection (RE-CF-7): `renderPreview` returns `PreviewResult { Uint8List png, LayerBlockStatuses blocks }`. Block analysis reuses `AlphaBboxDetector.detect`, `ZoneCalculator.compute`, `LayoutFilter.filter`: character blocked when bytes are null/empty or bbox is `Rect.zero`; phrase blocked when `LayoutResult.quoteRect` is empty or no pool item; background/font blocked when their pool is empty (defensive). Suggestion copy lives in `blocking.dart` | Parse PNG output; thread `LayoutResult` out of `RenderEngine` (an engine change) | Layout math is already pure and exported; the bounded ~40-step filter is cheap and deterministic; re-running detection duplicates a decode but keeps the engine contract untouched (RE-CF-11). |
| D10 | `blockStatusProvider` = `Provider<LayerBlockStatuses>` derived from `previewProvider`'s `AsyncValue.data` (all-unblocked while loading); blocked layer pages watch it and render attenuated + a suggestion banner | Blocks inside `ConfiguratorState`; cross-provider writes from the async notifier | Single source of truth (the last render outcome); no side-effecting provider writes; deterministic derivation. |
| D11 | Preview canvas fixed at 540×960 portrait; pipeline split into pure sync `buildRenderConfig(state) → RenderConfig` and async `renderPreview(config) → PreviewResult` | Derive size from widget constraints; one monolithic async pipeline | Fixed canvas decouples the preview from device/layout for deterministic goldens (RE-CF-9); the split yields unit-testable pure mapping + PNG-level goldens without pumping widgets through the engine (part-1 D12 pattern). |
| D12 | `previewProvider` (`AsyncNotifier<PreviewResult>`) watches `previewConfigProvider` via `ref.listen`, debounces 100 ms (`kPreviewDebounce`), renders the latest config, and a generation counter discards stale results; initial build renders immediately; render errors → `AsyncError` → panel shows a fallback placeholder (never crashes, RE-CF-7/RE-CF-9) | Render per change; hard throttle; no debounce | Spec explicitly permits debounce (RE-CF-9); 100 ms collapses burst edits; latest-wins keeps WYSIWYG correct. |
| D13 | `PreviewPanel` = `ConsumerWidget` → `Image.memory(bytes, gaplessPlayback: true, fit: BoxFit.contain)` in `RepaintBoundary` + `AspectRatio(9/16)`; loading/error → static placeholder box | `Image.network`; no gapless playback | `gaplessPlayback` avoids white flash on re-render; `RepaintBoundary` isolates the rasterized image; fixed aspect keeps layout stable during loading. |
| D14 | App shell (RE-AS-2/3): `main.dart` home = `ConfiguratorView` (`Scaffold` + `AppBar('Impetus')`); the spike trigger is relocated to AppBar actions as `SpikeDevTrigger`, rendered only under `kDebugMode`, reusing the untouched `spikeStateProvider`/`wallpaperBridgeProvider` (one-shot via the cached `FutureProvider`). `app_shell.png` regenerated with `--update-goldens` after overriding `previewConfigProvider` so the baseline shows real preview bytes | Keep the FAB; put the spike in a drawer; drop the spike | RE-AS-3 requires "not the primary home-screen action" and dev-only → `kDebugMode` gate; one-shot is already enforced; a seeded preview keeps the shell golden deterministic. |
| D15 | Public naming: branches/commits/PR titles use `feat(configurator):`-style conventional commits with no `part1`/`part2`/`partes` (RE-CF-11); the internal change name stays a planning artifact | `part2/...` prefixed public names | User requirement; matches the established part-0/1 convention (`feat(render-engine): ...`). |

## Data Flow

```
User gesture (swipe / toggle / pool / shuffle / freeze / preset)
        │
        ▼
ConfiguratorNotifier ──► new immutable ConfiguratorState (configuratorStateProvider)
        │
        ▼
buildRenderConfig(state) ──► RenderConfig (previewConfigProvider)
        │
        ▼
previewProvider (AsyncNotifier) ──ref.listen──► debounce 100ms ──► latest config
        │
        ▼
renderPreview(config): detect bbox → compute zones → layout filter
        │                         │
        │                   RenderEngine.render(config)   BlockAnalyzer.analyze(config, bbox, layout)
        │                         │                                  │
        ▼                         ▼                                  ▼
PreviewResult.png ──► PreviewPanel (Image.memory)        PreviewResult.blocks ──► blockStatusProvider
                                                                                    │
                                        LayerPage(blocked) ──► attenuated + suggestion banner
```

## Block Analysis (RE-CF-7)

`BlockAnalyzer.analyze(RenderConfig, Rect bbox, LayoutResult layout)` returns a
4-entry `LayerBlockStatuses`; each status carries a `bool blocked`, a `reason`
enum and a `suggestion` string (English, RE-CF-11):

- **Background / Font**: blocked only when its pool is empty (defensive
  suggestion: "Add a background color." / "Add a font to the pool.").
- **Phrase**: blocked when there is no pool item (`quoteText == ''`) or when
  `layout.quoteRect.isEmpty` ("No room for the quote — shorten it, swap the
  character, or change the clock position.").
- **Character**: blocked when bytes are null/empty or `bbox == Rect.zero`
  ("Add a character to the pool." / "Pick a character with visible art.").

Blocked layers never throw: `RenderEngine.render` already degrades gracefully,
and the panel renders a fallback placeholder on any unexpected error.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/configurator/layer_model.dart` | Create | `LayerType`, `LayerMode`, `LayerItem` + typed subtypes |
| `lib/configurator/catalog.dart` | Create | Four const placeholder catalogs + default pools |
| `lib/configurator/placeholder_assets.dart` | Create | Embedded placeholder character PNG literals (script-generated) |
| `lib/configurator/configurator_state.dart` | Create | Immutable `ConfiguratorState` + `copyWith` |
| `lib/configurator/configurator_notifier.dart` | Create | `randomProvider`, `ConfiguratorNotifier`, `configuratorStateProvider` (D1/D6/D7/D8) |
| `lib/configurator/blocking.dart` | Create | `LayerBlockStatus`/`LayerBlockStatuses` + `BlockAnalyzer` (D9) |
| `lib/configurator/preview_pipeline.dart` | Create | `buildRenderConfig(state)`, `renderPreview(config) → PreviewResult` (D11) |
| `lib/configurator/preview_provider.dart` | Create | `previewConfigProvider`, `previewProvider` (debounced, D12), `blockStatusProvider` (D10) |
| `lib/configurator/preview_panel.dart` | Create | `PreviewPanel` widget (D13) |
| `lib/configurator/configurator_view.dart` | Create | Root: preview + `PageView` + shuffle bar + clock selector (D5) |
| `lib/configurator/layer_page.dart` | Create | Per-layer page: mode toggle, pool add/remove, selection, blocked attenuation |
| `lib/configurator/clock_selector.dart` | Create | 4 `ClockPosition` presets UI (RE-CF-8) |
| `lib/configurator/shuffle_bar.dart` | Create | Shuffle + freeze/unfreeze controls (RE-CF-6) |
| `lib/configurator/spike_dev_trigger.dart` | Create | `kDebugMode`-gated dev-only spike entry (D14) |
| `lib/main.dart` | Modify | Home = `ConfiguratorView`; AppBar dev spike action (D14) |
| `test/configurator/state_test.dart` | Create | Unit: RE-CF-1/4/5/6/8 via `ProviderContainer` |
| `test/configurator/build_config_test.dart` | Create | Unit: `buildRenderConfig` mapping |
| `test/configurator/blocking_test.dart` | Create | Unit: RE-CF-7 detection + suggestions |
| `test/configurator/preview_pipeline_test.dart` | Create | Unit: `renderPreview` degenerate + determinism |
| `test/configurator/swipe_shell_test.dart` | Create | Widget: RE-CF-3 swipe / no-wrap / preview stable |
| `test/configurator/interactions_test.dart` | Create | Widget: RE-CF-4/5/6/7 toggle / pool / shuffle+freeze / blocked UI |
| `test/configurator/preview_widget_test.dart` | Create | Widget: RE-CF-9 state change → re-render (overridden renderer) |
| `test/golden/configurator_preview_golden_test.dart` | Create | PNG-level goldens of `renderPreview` output |
| `test/golden/goldens/configurator_preview/*.png` | Create | 3 baselines (default, no-character, empty-pool phrase) |
| `test/widget_test.dart` | Modify | Home = configurator; dev spike one-shot entry |
| `test/golden/app_shell_golden_test.dart` | Modify | Override `previewConfigProvider` with pre-rendered result (D14) |
| `test/golden/goldens/app_shell.png` | Modify | Regenerated baseline via `--update-goldens` |

## Interfaces / Contracts

```dart
// lib/configurator/layer_model.dart
enum LayerType { background, phrase, character, font }   // fixed order (RE-CF-2)
enum LayerMode { fixed, dynamic }

abstract class LayerItem {
  const LayerItem({required this.id, required this.label});
  final String id;     // stable identity (RE-CF-5 dedupe)
  final String label;
}
class BackgroundItem extends LayerItem { const BackgroundItem(...); final ui.Color color; }
class PhraseItem    extends LayerItem { const PhraseItem(...);    final String text; }
class CharacterItem extends LayerItem { const CharacterItem(...); final Uint8List bytes; }
class FontItem      extends LayerItem { const FontItem(...);      final String family; }

// lib/configurator/configurator_state.dart
@immutable
class ConfiguratorState {
  const ConfiguratorState({...});
  final int activeLayerIndex;              // 0..3
  final List<LayerMode> modes;             // length 4
  final List<List<LayerItem>> pools;       // length 4, unmodifiable
  final List<String?> selectedIds;         // length 4
  final List<bool> frozen;                 // length 4
  final ClockPosition clockPosition;
  ConfiguratorState copyWith({...});
}

// lib/configurator/blocking.dart
enum BlockReason { emptyPool, noFreeZone, noCharacterContent }
class LayerBlockStatus {
  const LayerBlockStatus({required this.blocked, this.reason, this.suggestion});
  final bool blocked; final BlockReason? reason; final String? suggestion;
}
class LayerBlockStatuses { const LayerBlockStatuses(this.entries); final List<LayerBlockStatus> entries; }

// lib/configurator/preview_pipeline.dart
class PreviewResult { const PreviewResult({required this.png, required this.blocks});
  final Uint8List png; final LayerBlockStatuses blocks; }

RenderConfig buildRenderConfig(ConfiguratorState state);                 // pure, sync (D11)
Future<PreviewResult> renderPreview(RenderConfig config);                 // async (D9/D11)

// lib/configurator/configurator_notifier.dart
final randomProvider = Provider<Random>((_) => Random());                 // D7
final configuratorStateProvider =
    NotifierProvider<ConfiguratorNotifier, ConfiguratorState>(ConfiguratorNotifier.new); // D1
class ConfiguratorNotifier extends Notifier<ConfiguratorState> {
  void setActiveLayer(int index);        // clamp 0..3
  void toggleMode(int layer);            // fixed <-> dynamic (RE-CF-4)
  void addToPool(int layer, LayerItem item);      // dedupe by id (RE-CF-5)
  void removeFromPool(int layer, String id);      // + selection fallback (D8)
  void selectItem(int layer, String id);          // pin selection
  void shuffle();                        // dynamic && !frozen only (RE-CF-6, D6/D7)
  void freeze(int layer); void unfreeze(int layer);
  void setClockPosition(ClockPosition preset);    // RE-CF-8
}

// lib/configurator/preview_provider.dart
final previewConfigProvider = Provider<RenderConfig>(
    (ref) => buildRenderConfig(ref.watch(configuratorStateProvider)));   // D11
const kPreviewDebounce = Duration(milliseconds: 100);                     // D12
final previewProvider = AsyncNotifierProvider<PreviewNotifier, PreviewResult>(PreviewNotifier.new);
final blockStatusProvider = Provider<LayerBlockStatuses>(                 // D10
    (ref) => ref.watch(previewProvider).maybeWhen(
        data: (r) => r.blocks, orElse: () => const LayerBlockStatuses.empty()));
```

`RenderEngine.render`, `AlphaBboxDetector.detect`, `ZoneCalculator.compute`,
`LayoutFilter.filter` and `RenderConfig` are consumed unchanged (RE-CF-11).

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit (state) | RE-CF-1 immutability (new instance per mutation) + `ProviderContainer` observability; RE-CF-4 toggle flips mode + persists across navigation; RE-CF-5 add-dedupe/remove/selection fallback; RE-CF-6 shuffle selects dynamic-only, freeze pins, unfreeze restores (seeded `randomProvider`, D7); RE-CF-8 4 presets accepted | `state_test.dart` — `ProviderContainer` with seeded Random override |
| Unit (mapping) | `buildRenderConfig`: mode reflected in config, preset maps to `clockPosition`, selections resolve to quote/character bytes | `build_config_test.dart` |
| Unit (blocking) | RE-CF-7: no-free-zone → phrase blocked + suggestion; null/empty bytes or `Rect.zero` bbox → character blocked; empty pool → blocked; never crashes | `blocking_test.dart` + `preview_pipeline_test.dart` (degenerate config → valid PNG, no throw; determinism ×2 byte-identical) |
| Widget (swipe) | RE-CF-3: swipe advances active layer (provider index), no wrap at font edge, preview config unchanged across swipes (no re-render) | `swipe_shell_test.dart` — `tester.fling` on `PageView` + pumpAndSettle; override preview provider to count re-renders |
| Widget (interactions) | RE-CF-4 toggle flow; RE-CF-5 pool add/remove UI; RE-CF-6 shuffle+freeze UI; RE-CF-7 blocked page attenuated + suggestion visible | `interactions_test.dart` — stable keys (`mode_toggle_$i`, `pool_item_$id`, `shuffle_button`, `blocked_banner_$i`) |
| Widget (preview) | RE-CF-9: state change (toggle/pool/preset) → preview re-renders; AsyncError → fallback placeholder, no crash | `preview_widget_test.dart` — override `previewProvider` with a fake notifier, assert new bytes consumed |
| Golden (preview) | `renderPreview` output for 3 fixed states (default, no-character, empty-pool phrase) byte-identical to baselines | PNG-level `matchesGoldenFile` in plain `test()` + `TestWidgetsFlutterBinding.ensureInitialized` (part-1 D12 pattern) |
| Golden (app shell) | RE-AS-2: home hosts the configurator; baseline regenerated deliberately | `app_shell_golden_test.dart` — override `previewConfigProvider`, `tester.runAsync` to complete image decode, `--update-goldens` once; committed `app_shell.png` passes without the flag |

Strict TDD (config.yaml `apply.tdd: true`): every task writes its RED test
first, then the GREEN implementation, per the part-1 tasks pattern. Commands:
`flutter test test/configurator` (unit+widget),
`flutter test test/golden/configurator_preview_golden_test.dart` (golden),
`flutter analyze --fatal-infos` clean, `flutter test` full suite green.

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file
classification, or process-integration boundary.

## Migration / Rollout

No migration. All new code lands under `lib/configurator/` and
`test/configurator/`; the only existing-code touch is `lib/main.dart`, the two
shell tests and the regenerated `app_shell.png`. Rollback: delete the new
directories + preview goldens and revert `main.dart` (proposal rollback plan).
Delivery per proposal: auto-chain, stacked-to-main, 4 PR slices, public names
without `part` prefixes (D15).

## Open Questions

- [ ] None — every ambiguity is resolved in Architecture Decisions D1–D15.
