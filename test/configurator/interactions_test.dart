// Configurator interactions (design D5/D9/D10, RE-CF-4/5/6/7/8/10/12,
// tasks 6.1/6.5 + 4.1-4.7).
//
// The preview renderer is real engine code that never completes under the
// widget-test fake async zone, so every test overrides previewProvider with a
// fake notifier (preview_widget_test precedent). The fake stays pending for
// the pure state-interaction tests and is completed with a crafted block
// status for the blocked-layer test. Shuffle determinism comes from overriding
// randomProvider with a scripted random that always picks the first pool item
// (design D7).
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

import 'dart:async';
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
import 'package:impetus/configurator/preview_panel.dart';
import 'package:impetus/configurator/preview_pipeline.dart';
import 'package:impetus/configurator/preview_provider.dart';
import 'package:impetus/models/render_config.dart';

/// A fake notifier whose build stays pending until the test decides, and that
/// exposes [completeInitial] to drive the block status the pages attenuate by.
class _FakePreviewNotifier extends PreviewNotifier {
  _FakePreviewNotifier() : _initial = Completer<PreviewResult>();

  final Completer<PreviewResult> _initial;

  @override
  Future<PreviewResult> build() => _initial.future;

  void completeInitial(PreviewResult result) {
    _initial.complete(result);
  }
}

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

/// A controllable block-status source so tests can flip a layer between
/// blocked and unblocked and watch the pill appear and disappear (RE-CF-7).
final _blockStatusController = StateProvider<LayerBlockStatuses>(
  (ref) => const LayerBlockStatuses.empty(),
);

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
      previewProvider.overrideWith(_FakePreviewNotifier.new),
      if (scriptedRandom) randomProvider.overrideWithValue(_ScriptedRandom()),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: ConfiguratorView())),
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

/// Flings the shell one page to the left and settles the scroll animation.
Future<void> _flingLeft(WidgetTester tester) async {
  await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
  await tester.pumpAndSettle();
}

/// Opens the controls bottom sheet with a real FAB tap (RE-CF-12, D27).
Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('controls_fab')));
  await tester.pumpAndSettle();
}

/// Scopes [finder] to the open bottom sheet ([Key('immersive_sheet')]) so the
/// swipe shell's duplicate controls behind the modal never match.
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

    expect(find.text('Mode: Dynamic'), findsOneWidget);
    expect(
      container.read(configuratorStateProvider).modes[0],
      LayerMode.dynamic,
    );

    await _tap(tester, find.byKey(const ValueKey('mode_toggle_0')));

    expect(container.read(configuratorStateProvider).modes[0], LayerMode.fixed);
    expect(find.text('Mode: Fixed'), findsOneWidget);
    expect(find.text('Mode: Dynamic'), findsNothing);

    await _tap(tester, find.byKey(const ValueKey('mode_toggle_0')));

    expect(
      container.read(configuratorStateProvider).modes[0],
      LayerMode.dynamic,
    );
  });

  testWidgets(
    'mode survives swipe navigation because it lives in the state (RE-CF-4)',
    (tester) async {
      final container = await _pumpView(tester);

      await _tap(tester, find.byKey(const ValueKey('mode_toggle_0')));
      expect(
        container.read(configuratorStateProvider).modes[0],
        LayerMode.fixed,
      );

      await _flingLeft(tester);
      expect(container.read(configuratorStateProvider).activeLayerIndex, 1);

      await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();

      expect(container.read(configuratorStateProvider).activeLayerIndex, 0);
      expect(
        container.read(configuratorStateProvider).modes[0],
        LayerMode.fixed,
      );
    },
  );

  testWidgets('pool items are removed and re-added with dedupe (RE-CF-5)', (
    tester,
  ) async {
    final container = await _pumpView(tester);

    await _tap(tester, find.byKey(const ValueKey('pool_remove_bg_navy')));
    var ids = container
        .read(configuratorStateProvider)
        .pools[0]
        .map((item) => item.id);
    expect(ids, isNot(contains('bg_navy')));
    expect(find.byKey(const ValueKey('pool_item_bg_navy')), findsNothing);

    await _tap(tester, find.byKey(const ValueKey('catalog_add_bg_navy')));
    ids = container
        .read(configuratorStateProvider)
        .pools[0]
        .map((item) => item.id);
    expect(ids.where((id) => id == 'bg_navy').length, 1);
    expect(find.byKey(const ValueKey('pool_item_bg_navy')), findsOneWidget);

    await _tap(tester, find.byKey(const ValueKey('catalog_add_bg_navy')));
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

    await _tap(tester, find.byKey(const ValueKey('pool_item_bg_midnight')));
    expect(
      container.read(configuratorStateProvider).selectedIds[0],
      'bg_midnight',
    );

    await _tap(tester, find.byKey(const ValueKey('freeze_button')));
    expect(container.read(configuratorStateProvider).frozen[0], isTrue);

    await _tap(tester, find.byKey(const ValueKey('shuffle_button')));
    expect(
      container.read(configuratorStateProvider).selectedIds[0],
      'bg_midnight',
    );
    expect(
      container.read(configuratorStateProvider).selectedIds[1],
      'ph_strength',
    );

    await _tap(tester, find.byKey(const ValueKey('freeze_button')));
    expect(container.read(configuratorStateProvider).frozen[0], isFalse);

    await _tap(tester, find.byKey(const ValueKey('shuffle_button')));
    expect(container.read(configuratorStateProvider).selectedIds[0], 'bg_navy');
  });

  testWidgets('a blocked layer shows its suggestion in the pill, not an '
      'attenuated page (RE-CF-7, D22)', (tester) async {
    final container = await _pumpView(tester);

    expect(find.byKey(kBlockedPillKey), findsNothing);
    expect(find.byKey(const ValueKey('blocked_banner_0')), findsNothing);
    expect(find.byKey(const ValueKey('layer_attenuation_0')), findsNothing);

    final notifier =
        container.read(previewProvider.notifier) as _FakePreviewNotifier;
    notifier.completeInitial(
      PreviewResult(png: kAlphaPngBytes, blocks: _blockedStatuses()),
    );
    await tester.pump();

    expect(find.byKey(kBlockedPillKey), findsOneWidget);
    expect(find.textContaining('No room for the quote'), findsOneWidget);

    // The old full-page attenuation and per-page banner surfaces are gone
    // (D22): the suggestion lives only in the pill over the preview.
    expect(find.byKey(const ValueKey('blocked_banner_1')), findsNothing);
    expect(find.byKey(const ValueKey('layer_attenuation_1')), findsNothing);
  });

  testWidgets('a blocked layer shows the suggestion pill over the preview '
      'without crashing (RE-CF-7, D22)', (tester) async {
    await _pumpView(
      tester,
      overrides: [blockStatusProvider.overrideWithValue(_blockedStatuses())],
    );

    // The pill overlays the top of the preview (D22) and a valid (degraded)
    // preview placeholder still renders — blocked state never crashes or
    // empties the preview (RE-CF-7).
    final pill = find.byKey(kBlockedPillKey);
    expect(pill, findsOneWidget);
    expect(find.textContaining('No room for the quote'), findsOneWidget);
    expect(find.byKey(kPreviewPlaceholderKey), findsOneWidget);

    final positioned = tester.widget<Positioned>(
      find.ancestor(of: pill, matching: find.byType(Positioned)),
    );
    expect(positioned.top, 12);
    expect(positioned.left, 16);
    expect(positioned.right, 16);
  });

  testWidgets('unblocking the layer hides the pill (RE-CF-7)', (tester) async {
    final container = await _pumpView(
      tester,
      overrides: [
        blockStatusProvider.overrideWith(
          (ref) => ref.watch(_blockStatusController),
        ),
      ],
    );

    expect(find.byKey(kBlockedPillKey), findsNothing);

    container.read(_blockStatusController.notifier).state = _blockedStatuses();
    await tester.pump();
    expect(find.byKey(kBlockedPillKey), findsOneWidget);
    expect(find.textContaining('No room for the quote'), findsOneWidget);

    container.read(_blockStatusController.notifier).state =
        const LayerBlockStatuses.empty();
    await tester.pump();
    expect(find.byKey(kBlockedPillKey), findsNothing);
  });

  testWidgets('the pill shows the first blocked layer in stack order '
      '(RE-CF-7, D22)', (tester) async {
    await _pumpView(
      tester,
      overrides: [
        blockStatusProvider.overrideWithValue(
          const LayerBlockStatuses([
            LayerBlockStatus(
              blocked: true,
              reason: BlockReason.emptyPool,
              suggestion: 'Add a background color.',
            ),
            LayerBlockStatus(
              blocked: true,
              reason: BlockReason.noFreeZone,
              suggestion:
                  'No room for the quote — shorten it, swap the character, or '
                  'change the clock position.',
            ),
            LayerBlockStatus.clear(),
            LayerBlockStatus.clear(),
          ]),
        ),
      ],
    );

    // Background (index 0) is the first blocked layer, so its suggestion wins.
    expect(find.text('Add a background color.'), findsOneWidget);
    expect(find.textContaining('No room for the quote'), findsNothing);
  });

  testWidgets('the pill does not block the item-cycle swipe (RE-CF-7, D22)', (
    tester,
  ) async {
    final container = await _pumpView(
      tester,
      overrides: [blockStatusProvider.overrideWithValue(_blockedStatuses())],
    );

    expect(find.byKey(kBlockedPillKey), findsOneWidget);
    expect(container.read(configuratorStateProvider).selectedIds[0], isNull);

    // The fling STARTS on the pill itself; IgnorePointer lets the gesture fall
    // through to the preview's ItemCycleGesture (D22 non-intrusive).
    await tester.fling(find.byKey(kBlockedPillKey), const Offset(-400, 0), 1000);
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
      overrides: [blockStatusProvider.overrideWithValue(_blockedStatuses())],
    );

    expect(find.byKey(kBlockedPillKey), findsOneWidget);

    await _openSheet(tester);

    expect(find.byKey(const Key('immersive_sheet')), findsOneWidget);
    expect(find.byKey(kBlockedPillKey), findsOneWidget);
  });

  testWidgets('clock presets set the render clock position (RE-CF-8)', (
    tester,
  ) async {
    final container = await _pumpView(tester);

    Future<void> select(ClockPosition preset) async {
      await tester.tap(find.byKey(ValueKey('clock_preset_${preset.name}')));
      await tester.pump();
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
      find.byKey(const ValueKey('clock_preset_bottomCenter')),
    );
    expect(selected.selected, isTrue);
    final unselected = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('clock_preset_topCenter')),
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
}
