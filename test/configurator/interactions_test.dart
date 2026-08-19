// Configurator interactions (design D5/D9/D10, RE-CF-4/5/6/7/8/10/12,
// tasks 6.1/6.5 + 4.1-4.7).
//
// The preview renderer is real engine code that never completes under the
// widget-test fake async zone, so tests inject a fake renderer through
// previewRenderProvider instead of overriding previewProvider: the shell's
// nested ProviderScope isolates the preview pipeline (the device-size override,
// D16), so the renderer — read through that scope — is the controllable seam.
// Pure state-interaction tests run the real pipeline (which stays loading under
// fake async); the blocked-layer tests feed crafted block statuses through the
// renderer so the pill follows the LATEST render's blocks (D10). Shuffle
// determinism comes from overriding randomProvider with a scripted random that
// always picks the first pool item (design D7).
//
// Slice 4 adds the FAB-opened immersive bottom sheet (D20/D21/D27, RE-CF-12):
// a real FAB tap ([_openSheet]) raises the sheet, and every sheet control is
// reached through [_inSheet]-scoped finders — the sheet and the swipe shell
// render the SAME stable keys (mode_toggle_*, shuffle_button, clock_preset_*),
// so an unscoped finder would match both while the sheet is open.
//
// Slice 5 replaces the per-page blocked-layer attenuation with the immersive
// [BlockedPill] overlay (D22, RE-CF-7): a blocked layer shows its suggestion
// in a Chip at the top of the preview instead of dimming a whole page. The
// pill must never crash the preview, must survive sheet open/close, must
// disappear when the layer unblocks, must show the FIRST blocked layer in
// stack order, and must not absorb the preview's item-cycle swipe
// (IgnorePointer passthrough, D22).
//
// Slice 6 removes the PageView shell (RE-CF-9/D23 full-bleed): the sheet is
// the single control surface, so every interaction opens the sheet first.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/configurator/blocked_pill.dart';
import 'package:impetus/configurator/blocking.dart';
import 'package:impetus/configurator/configurator_notifier.dart';
import 'package:impetus/configurator/configurator_view.dart';
import 'package:impetus/configurator/layer_model.dart';
import 'package:impetus/configurator/placeholder_assets.dart';
import 'package:impetus/configurator/preview_pipeline.dart';
import 'package:impetus/configurator/preview_provider.dart';
import 'package:impetus/models/render_config.dart';

/// A random that always returns the first value, so shuffle deterministically
/// re-selects each pool's first item (design D7).
class _ScriptedRandom implements Random {
  @override
  int nextInt(int max) => 0;

  @override
  double nextDouble() => 0.0;

  @override
  bool nextBool() => false;
}

/// A preview renderer whose returned block statuses the test can flip between
/// pumps. Re-renders are triggered by render-relevant state changes (the
/// debounced pipeline, D12), so the pill follows the LATEST render's blocks
/// (D10, RE-CF-7).
class _MutableStatusRenderer {
  LayerBlockStatuses statuses = const LayerBlockStatuses.empty();

  Future<PreviewResult> call(RenderConfig config) async =>
      PreviewResult(png: kAlphaPngBytes, blocks: statuses);
}

/// The statuses used by the blocked-pill tests: the phrase layer (index 1) is
/// blocked with the no-free-zone suggestion (RE-CF-7, D22).
LayerBlockStatuses _blockedStatuses() => const LayerBlockStatuses([
  LayerBlockStatus.clear(),
  LayerBlockStatus(
    blocked: true,
    reason: BlockReason.noFreeZone,
    suggestion:
        'No room for the quote — shorten it, swap the character, or change the '
        'clock position.',
  ),
  LayerBlockStatus.clear(),
  LayerBlockStatus.clear(),
]);

/// Pumps a [ConfiguratorView] inside an isolated provider scope and returns the
/// container so tests can read the state (RE-CF-10: isolated pumps).
Future<ProviderContainer> _pumpView(
  WidgetTester tester, {
  bool scriptedRandom = false,
  List<Override> overrides = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      if (scriptedRandom) randomProvider.overrideWithValue(_ScriptedRandom()),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      // The configurator is the app home (task 7.3): it hosts its own shell
      // Scaffold and AppBar, so no test-level Scaffold wraps it.
      child: const MaterialApp(home: ConfiguratorView()),
    ),
  );
  return container;
}

/// Scrolls the target into view (the layer content lives in a scrollable) and
/// taps it.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

/// Opens the controls bottom sheet with a real FAB tap (RE-CF-12, D27).
Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('controls_fab')));
  await tester.pumpAndSettle();
}

/// Scopes [finder] to the open bottom sheet ([Key('immersive_sheet')]) so
/// sheet finders never match controls rendered elsewhere in the tree.
Finder _inSheet(Finder finder) => find.descendant(
  of: find.byKey(const Key('immersive_sheet')),
  matching: finder,
);

/// Taps a control INSIDE the open sheet, scrolling it into view first.
Future<void> _tapInSheet(WidgetTester tester, Finder finder) async {
  await _tap(tester, _inSheet(finder));
}

void main() {
  testWidgets('mode toggle flips a layer between dynamic and fixed (RE-CF-4)', (
    tester,
  ) async {
    final container = await _pumpView(tester);

    expect(
      container.read(configuratorStateProvider).modes[0],
      LayerMode.dynamic,
    );

    // The sheet is the single control surface (RE-CF-12): the toggle lives
    // there, not in a shell page.
    await _openSheet(tester);
    expect(_inSheet(find.text('Mode: Dynamic')), findsOneWidget);

    await _tapInSheet(tester, find.byKey(const ValueKey('mode_toggle_0')));

    expect(container.read(configuratorStateProvider).modes[0], LayerMode.fixed);
    expect(_inSheet(find.text('Mode: Fixed')), findsOneWidget);
    expect(_inSheet(find.text('Mode: Dynamic')), findsNothing);

    await _tapInSheet(tester, find.byKey(const ValueKey('mode_toggle_0')));

    expect(
      container.read(configuratorStateProvider).modes[0],
      LayerMode.dynamic,
    );
  });

  testWidgets('mode survives layer switching because it lives in the state '
      '(RE-CF-4)', (tester) async {
    final container = await _pumpView(tester);

    await _openSheet(tester);
    await _tapInSheet(tester, find.byKey(const ValueKey('mode_toggle_0')));
    expect(container.read(configuratorStateProvider).modes[0], LayerMode.fixed);

    // The active layer changes in the sheet's selector, not by swipe
    // (RE-CF-3); the mode survives the switch.
    await _tapInSheet(tester, find.text(LayerType.character.name));
    expect(container.read(configuratorStateProvider).activeLayerIndex, 2);
    expect(container.read(configuratorStateProvider).modes[0], LayerMode.fixed);

    await _tapInSheet(tester, find.text(LayerType.background.name));
    expect(container.read(configuratorStateProvider).activeLayerIndex, 0);
    expect(_inSheet(find.text('Mode: Fixed')), findsOneWidget);
  });

  testWidgets('pool items are removed and re-added with dedupe (RE-CF-5)', (
    tester,
  ) async {
    final container = await _pumpView(tester);

    await _openSheet(tester);
    await _tapInSheet(
      tester,
      find.byKey(const ValueKey('pool_remove_bg_navy')),
    );
    var ids = container
        .read(configuratorStateProvider)
        .pools[0]
        .map((item) => item.id);
    expect(ids, isNot(contains('bg_navy')));
    expect(find.byKey(const ValueKey('pool_item_bg_navy')), findsNothing);

    await _tapInSheet(
      tester,
      find.byKey(const ValueKey('catalog_add_bg_navy')),
    );
    ids = container
        .read(configuratorStateProvider)
        .pools[0]
        .map((item) => item.id);
    expect(ids.where((id) => id == 'bg_navy').length, 1);
    expect(find.byKey(const ValueKey('pool_item_bg_navy')), findsOneWidget);

    await _tapInSheet(
      tester,
      find.byKey(const ValueKey('catalog_add_bg_navy')),
    );
    ids = container
        .read(configuratorStateProvider)
        .pools[0]
        .map((item) => item.id);
    expect(ids.where((id) => id == 'bg_navy').length, 1);
    expect(find.byKey(const ValueKey('pool_item_bg_navy')), findsOneWidget);
  });

  testWidgets('freeze pins the active layer while shuffle re-selects the rest '
      '(RE-CF-6, D6)', (tester) async {
    final container = await _pumpView(tester, scriptedRandom: true);

    await _openSheet(tester);
    await _tapInSheet(
      tester,
      find.byKey(const ValueKey('pool_item_bg_midnight')),
    );
    expect(
      container.read(configuratorStateProvider).selectedIds[0],
      'bg_midnight',
    );

    await _tapInSheet(tester, find.byKey(const ValueKey('freeze_button')));
    expect(container.read(configuratorStateProvider).frozen[0], isTrue);

    await _tapInSheet(tester, find.byKey(const ValueKey('shuffle_button')));
    expect(
      container.read(configuratorStateProvider).selectedIds[0],
      'bg_midnight',
    );
    expect(
      container.read(configuratorStateProvider).selectedIds[1],
      'ph_strength',
    );

    await _tapInSheet(tester, find.byKey(const ValueKey('freeze_button')));
    expect(container.read(configuratorStateProvider).frozen[0], isFalse);

    await _tapInSheet(tester, find.byKey(const ValueKey('shuffle_button')));
    expect(container.read(configuratorStateProvider).selectedIds[0], 'bg_navy');
  });

  testWidgets('a blocked layer shows its suggestion in the pill, not an '
      'attenuated page (RE-CF-7, D22)', (tester) async {
    await _pumpView(
      tester,
      overrides: [
        previewRenderProvider.overrideWithValue(
          (_) async =>
              PreviewResult(png: kAlphaPngBytes, blocks: _blockedStatuses()),
        ),
      ],
    );
    await tester.pump();

    // The old full-page attenuation and per-page banner surfaces are gone
    // (D22): the suggestion lives only in the pill over the preview.
    expect(find.byKey(const ValueKey('blocked_banner_0')), findsNothing);
    expect(find.byKey(const ValueKey('layer_attenuation_0')), findsNothing);
    expect(find.byKey(const ValueKey('blocked_banner_1')), findsNothing);
    expect(find.byKey(const ValueKey('layer_attenuation_1')), findsNothing);
    expect(find.byKey(kBlockedPillKey), findsOneWidget);
    expect(find.textContaining('No room for the quote'), findsOneWidget);
  });

  testWidgets('a blocked layer shows the suggestion pill over the preview '
      'without crashing (RE-CF-7, D22)', (tester) async {
    await _pumpView(
      tester,
      overrides: [
        previewRenderProvider.overrideWithValue(
          (_) async =>
              PreviewResult(png: kAlphaPngBytes, blocks: _blockedStatuses()),
        ),
      ],
    );
    await tester.pump();

    // The pill overlays the top of the preview (D22) and a valid preview
    // still renders — blocked state never crashes or empties the preview
    // (RE-CF-7).
    final pill = find.byKey(kBlockedPillKey);
    expect(pill, findsOneWidget);
    expect(find.textContaining('No room for the quote'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    final positioned = tester.widget<Positioned>(
      find.ancestor(of: pill, matching: find.byType(Positioned)),
    );
    expect(positioned.top, 12);
    expect(positioned.left, 16);
    expect(positioned.right, 16);
  });

  testWidgets('unblocking the layer hides the pill (RE-CF-7)', (tester) async {
    final renderer = _MutableStatusRenderer();
    final container = await _pumpView(
      tester,
      overrides: [previewRenderProvider.overrideWithValue(renderer.call)],
    );
    await tester.pump();

    expect(find.byKey(kBlockedPillKey), findsNothing);

    // The pill follows the LATEST render's blocks (D10): a render-relevant
    // change re-renders through the debounced pipeline, and the new statuses
    // flip the pill.
    renderer.statuses = _blockedStatuses();
    container.read(configuratorStateProvider.notifier).selectItem(0, 'bg_navy');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(find.byKey(kBlockedPillKey), findsOneWidget);
    expect(find.textContaining('No room for the quote'), findsOneWidget);

    renderer.statuses = const LayerBlockStatuses.empty();
    container
        .read(configuratorStateProvider.notifier)
        .selectItem(0, 'bg_midnight');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(find.byKey(kBlockedPillKey), findsNothing);
  });

  testWidgets('the pill shows the first blocked layer in stack order '
      '(RE-CF-7, D22)', (tester) async {
    await _pumpView(
      tester,
      overrides: [
        previewRenderProvider.overrideWithValue(
          (_) async => PreviewResult(
            png: kAlphaPngBytes,
            blocks: const LayerBlockStatuses([
              LayerBlockStatus(
                blocked: true,
                reason: BlockReason.emptyPool,
                suggestion: 'Add a background color.',
              ),
              LayerBlockStatus(
                blocked: true,
                reason: BlockReason.noFreeZone,
                suggestion:
                    'No room for the quote — shorten it, swap the character, '
                    'or change the clock position.',
              ),
              LayerBlockStatus.clear(),
              LayerBlockStatus.clear(),
            ]),
          ),
        ),
      ],
    );
    await tester.pump();

    // Background (index 0) is the first blocked layer, so its suggestion wins.
    expect(find.text('Add a background color.'), findsOneWidget);
    expect(find.textContaining('No room for the quote'), findsNothing);
  });

  testWidgets('the pill does not block the item-cycle swipe (RE-CF-7, D22)', (
    tester,
  ) async {
    final container = await _pumpView(
      tester,
      overrides: [
        previewRenderProvider.overrideWithValue(
          (_) async =>
              PreviewResult(png: kAlphaPngBytes, blocks: _blockedStatuses()),
        ),
      ],
    );
    await tester.pump();

    expect(find.byKey(kBlockedPillKey), findsOneWidget);
    expect(container.read(configuratorStateProvider).selectedIds[0], isNull);

    // The fling STARTS on the pill itself; IgnorePointer lets the gesture fall
    // through to the preview's ItemCycleGesture (D22 non-intrusive).
    // warnIfMissed: false — the "miss" is the point: the pill deliberately
    // never receives pointer events, so fling() warns that its center does not
    // hit the Chip. The assertion below proves the swipe still cycles.
    await tester.fling(
      find.byKey(kBlockedPillKey),
      const Offset(-400, 0),
      1000,
      warnIfMissed: false,
    );
    await tester.pump();

    expect(
      container.read(configuratorStateProvider).selectedIds[0],
      'bg_midnight',
    );
  });

  testWidgets('opening the sheet does not hide the pill (RE-CF-7)', (
    tester,
  ) async {
    await _pumpView(
      tester,
      overrides: [
        previewRenderProvider.overrideWithValue(
          (_) async =>
              PreviewResult(png: kAlphaPngBytes, blocks: _blockedStatuses()),
        ),
      ],
    );
    await tester.pump();

    expect(find.byKey(kBlockedPillKey), findsOneWidget);

    await _openSheet(tester);

    expect(find.byKey(const Key('immersive_sheet')), findsOneWidget);
    expect(find.byKey(kBlockedPillKey), findsOneWidget);
  });

  testWidgets('clock presets set the render clock position (RE-CF-8)', (
    tester,
  ) async {
    final container = await _pumpView(tester);

    await _openSheet(tester);
    Future<void> select(ClockPosition preset) async {
      await _tapInSheet(
        tester,
        find.byKey(ValueKey('clock_preset_${preset.name}')),
      );
    }

    await select(ClockPosition.topLeft);
    expect(
      container.read(configuratorStateProvider).clockPosition,
      ClockPosition.topLeft,
    );

    await select(ClockPosition.topRight);
    expect(
      container.read(configuratorStateProvider).clockPosition,
      ClockPosition.topRight,
    );

    await select(ClockPosition.bottomCenter);
    expect(
      container.read(configuratorStateProvider).clockPosition,
      ClockPosition.bottomCenter,
    );

    final selected = tester.widget<ChoiceChip>(
      _inSheet(find.byKey(const ValueKey('clock_preset_bottomCenter'))),
    );
    expect(selected.selected, isTrue);
    final unselected = tester.widget<ChoiceChip>(
      _inSheet(find.byKey(const ValueKey('clock_preset_topCenter'))),
    );
    expect(unselected.selected, isFalse);
  });

  testWidgets('FAB opens the controls sheet with every control (RE-CF-12)', (
    tester,
  ) async {
    await _pumpView(tester);

    expect(find.byKey(const Key('immersive_sheet')), findsNothing);
    expect(find.byKey(const ValueKey('controls_fab')), findsOneWidget);

    await _openSheet(tester);

    expect(find.byKey(const Key('immersive_sheet')), findsOneWidget);

    // Layer selector: a SegmentedButton with one segment per layer (D21).
    final selector = tester.widget<SegmentedButton<int>>(
      _inSheet(find.byKey(const ValueKey('layer_selector'))),
    );
    expect(selector.segments.length, LayerType.values.length);

    // Per-layer controls for the active layer, shuffle/freeze, pool
    // management and the clock presets are all present (RE-CF-12).
    expect(
      _inSheet(find.byKey(const ValueKey('mode_toggle_0'))),
      findsOneWidget,
    );
    expect(
      _inSheet(find.byKey(const ValueKey('shuffle_controls'))),
      findsOneWidget,
    );
    expect(
      _inSheet(find.byKey(const ValueKey('pool_management_0'))),
      findsOneWidget,
    );
    expect(
      _inSheet(find.byKey(const ValueKey('clock_presets'))),
      findsOneWidget,
    );
  });

  testWidgets('sheet layer selector switches the active layer (RE-CF-3, D21)', (
    tester,
  ) async {
    final container = await _pumpView(tester);
    expect(container.read(configuratorStateProvider).activeLayerIndex, 0);

    await _openSheet(tester);

    await tester.tap(_inSheet(find.text(LayerType.character.name)));
    await tester.pumpAndSettle();

    expect(container.read(configuratorStateProvider).activeLayerIndex, 2);
    // The sheet now shows layer 2's controls.
    expect(
      _inSheet(find.byKey(const ValueKey('mode_toggle_2'))),
      findsOneWidget,
    );
    expect(
      _inSheet(find.byKey(const ValueKey('pool_management_2'))),
      findsOneWidget,
    );
  });

  testWidgets('mode toggle works from the sheet (RE-CF-4)', (tester) async {
    final container = await _pumpView(tester);

    await _openSheet(tester);

    await _tapInSheet(tester, find.byKey(const ValueKey('mode_toggle_0')));
    expect(container.read(configuratorStateProvider).modes[0], LayerMode.fixed);
    expect(_inSheet(find.text('Mode: Fixed')), findsOneWidget);

    await _tapInSheet(tester, find.byKey(const ValueKey('mode_toggle_0')));
    expect(
      container.read(configuratorStateProvider).modes[0],
      LayerMode.dynamic,
    );
  });

  testWidgets('shuffle and freeze work from the sheet (RE-CF-6)', (
    tester,
  ) async {
    final container = await _pumpView(tester, scriptedRandom: true);

    await _openSheet(tester);

    await _tapInSheet(
      tester,
      find.byKey(const ValueKey('pool_item_bg_midnight')),
    );
    expect(
      container.read(configuratorStateProvider).selectedIds[0],
      'bg_midnight',
    );

    await _tapInSheet(tester, find.byKey(const ValueKey('freeze_button')));
    expect(container.read(configuratorStateProvider).frozen[0], isTrue);

    await _tapInSheet(tester, find.byKey(const ValueKey('shuffle_button')));
    // The frozen layer keeps its selection; the phrase layer shuffles to its
    // first pool item (scripted random, D7).
    expect(
      container.read(configuratorStateProvider).selectedIds[0],
      'bg_midnight',
    );
    expect(
      container.read(configuratorStateProvider).selectedIds[1],
      'ph_strength',
    );

    await _tapInSheet(tester, find.byKey(const ValueKey('freeze_button')));
    expect(container.read(configuratorStateProvider).frozen[0], isFalse);
  });

  testWidgets('catalog add and pool remove work from the sheet (RE-CF-5)', (
    tester,
  ) async {
    final container = await _pumpView(tester);

    await _openSheet(tester);

    await _tapInSheet(
      tester,
      find.byKey(const ValueKey('pool_remove_bg_forest')),
    );
    var ids = container
        .read(configuratorStateProvider)
        .pools[0]
        .map((item) => item.id);
    expect(ids, isNot(contains('bg_forest')));

    await _tapInSheet(
      tester,
      find.byKey(const ValueKey('catalog_add_bg_forest')),
    );
    ids = container
        .read(configuratorStateProvider)
        .pools[0]
        .map((item) => item.id);
    expect(ids.where((id) => id == 'bg_forest').length, 1);

    // Adding again dedupes by id (RE-CF-5).
    await _tapInSheet(
      tester,
      find.byKey(const ValueKey('catalog_add_bg_forest')),
    );
    ids = container
        .read(configuratorStateProvider)
        .pools[0]
        .map((item) => item.id);
    expect(ids.where((id) => id == 'bg_forest').length, 1);
  });

  testWidgets('clock presets work from the sheet (RE-CF-8)', (tester) async {
    final container = await _pumpView(tester);

    await _openSheet(tester);

    await _tapInSheet(
      tester,
      find.byKey(const ValueKey('clock_preset_topLeft')),
    );
    expect(
      container.read(configuratorStateProvider).clockPosition,
      ClockPosition.topLeft,
    );

    await _tapInSheet(
      tester,
      find.byKey(const ValueKey('clock_preset_bottomCenter')),
    );
    expect(
      container.read(configuratorStateProvider).clockPosition,
      ClockPosition.bottomCenter,
    );

    final selected = tester.widget<ChoiceChip>(
      _inSheet(find.byKey(const ValueKey('clock_preset_bottomCenter'))),
    );
    expect(selected.selected, isTrue);
  });

  testWidgets('tapping the scrim dismisses the sheet (RE-CF-12)', (
    tester,
  ) async {
    await _pumpView(tester);

    await _openSheet(tester);
    expect(find.byKey(const Key('immersive_sheet')), findsOneWidget);

    // Tap the modal barrier above the sheet.
    await tester.tapAt(const Offset(400, 40));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('immersive_sheet')), findsNothing);
  });

  testWidgets('dragging the sheet down dismisses it (RE-CF-12)', (
    tester,
  ) async {
    await _pumpView(tester);

    await _openSheet(tester);
    expect(find.byKey(const Key('immersive_sheet')), findsOneWidget);

    // Drag the sheet's drag handle far down; the modal sheet pops on release.
    await tester.drag(
      find.byKey(const ValueKey('sheet_drag_handle')),
      const Offset(0, 400),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('immersive_sheet')), findsNothing);
  });

  testWidgets('the whole body is the preview: no shell pages or bottom bars; '
      'controls live only in the sheet (RE-CF-9/12, D23)', (tester) async {
    await _pumpView(
      tester,
      overrides: [
        previewRenderProvider.overrideWithValue(
          (_) async => PreviewResult(
            png: kAlphaPngBytes,
            blocks: const LayerBlockStatuses.empty(),
          ),
        ),
      ],
    );
    await tester.pump();

    // The PageView shell is gone: no pages, no fixed bottom bars compete for
    // body space (RE-CF-9, D23).
    expect(find.byType(PageView), findsNothing);

    // Full-bleed: the rendered preview spans the configurator body — full
    // width and down to the bottom edge; only the slim shell AppBar (kept
    // for the title, D27) sits above it (RE-CF-9).
    final imageRect = tester.getRect(find.byType(Image));
    final viewRect = tester.getRect(find.byType(ConfiguratorView));
    expect(imageRect.width, viewRect.width);
    expect(imageRect.bottom, viewRect.bottom);

    // The bottom sheet is the single control surface: after opening it, every
    // control key exists exactly once — the shell's duplicates are gone
    // (RE-CF-12).
    await _openSheet(tester);
    expect(find.byKey(const ValueKey('mode_toggle_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('shuffle_controls')), findsOneWidget);
    expect(find.byKey(const ValueKey('clock_presets')), findsOneWidget);
  });
}
