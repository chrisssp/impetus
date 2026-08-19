// Swipe shell (design D5/D12, RE-CF-3, tasks 6.2/6.6) + item-cycle swipe
// gesture (design D17/D18/D19, RE-CF-3, tasks 3.1-3.3).
//
// The shell runs the real previewProvider so the debounce wiring is exercised,
// but previewRenderProvider is replaced with a counting fake renderer: the real
// engine futures never complete under the widget-test fake async zone, and the
// counter proves the preview does NOT re-render while swiping (RE-CF-3, D12 —
// activeLayerIndex is excluded from previewConfigProvider, so navigating the
// pages never changes the rendered config).
//
// Slice 3 adds the immersive-preview swipe surface: a horizontal drag on
// Key('immersive_preview') cycles the ACTIVE layer's item (left = next,
// right = previous, D18), wraps at the pool edges, and is disabled while the
// sheet-open gate is up (D19). Item cycling DOES change the selection, so the
// counter also proves the preview re-renders on every cycle (RE-CF-3).
//
// Slice 4 replaces the state-driven gate helper with REAL FAB taps: tapping
// Key('controls_fab') opens the immersive bottom sheet and raises the gate;
// dismissing the sheet (scrim tap) lowers it again, so the swipe fires again.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/configurator/blocking.dart';
import 'package:impetus/configurator/configurator_notifier.dart';
import 'package:impetus/configurator/configurator_view.dart';
import 'package:impetus/configurator/layer_model.dart';
import 'package:impetus/configurator/placeholder_assets.dart';
import 'package:impetus/configurator/preview_pipeline.dart';
import 'package:impetus/configurator/preview_provider.dart';
import 'package:impetus/models/render_config.dart';

/// A renderer that counts invocations and always succeeds instantly, so the
/// preview resolves without the engine and the counter isolates re-renders.
class _CountingRenderer {
  final PreviewResult _preview = PreviewResult(
    png: kAlphaPngBytes,
    blocks: const LayerBlockStatuses.empty(),
  );

  int calls = 0;

  Future<PreviewResult> call(RenderConfig config) {
    calls++;
    return Future.value(_preview);
  }
}

class _Harness {
  _Harness(this.renderer, this.container);

  final _CountingRenderer renderer;
  final ProviderContainer container;
}

/// Pumps the full shell with the real preview pipeline but a counting fake
/// renderer, and returns the harness for assertions.
Future<_Harness> _pumpShell(WidgetTester tester) async {
  final renderer = _CountingRenderer();
  final container = ProviderContainer(
    overrides: [previewRenderProvider.overrideWithValue(renderer.call)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: ConfiguratorView())),
    ),
  );
  return _Harness(renderer, container);
}

/// Flings the shell one page to the left and settles the scroll animation.
Future<void> _flingLeft(WidgetTester tester) async {
  await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
  await tester.pumpAndSettle();
}

/// Swipes the immersive preview surface horizontally (RE-CF-3, D17) and lets
/// the debounced preview re-render land.
///
/// The 100ms preview debounce ([kPreviewDebounce]) is a plain Timer scheduled
/// from the provider listener that runs on the microtask queue after the
/// notifier mutation. The first pump flushes that microtask so the timer is
/// registered, the second advances past the debounce so the cycle reaches the
/// preview (RE-CF-3), and the last renders the re-render — leaving no pending
/// timer behind.
Future<void> _swipePreview(WidgetTester tester, Offset offset) async {
  await tester.fling(find.byKey(const Key('immersive_preview')), offset, 1000);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
  await tester.pump();
}

/// Opens the immersive bottom sheet with a real FAB tap and settles the
/// sheet animation (RE-CF-12, D27). The FAB tap is the real user path that
/// raises the sheet-open gate (D19).
Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('controls_fab')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('immersive_sheet')), findsOneWidget);
}

/// Dismisses the open sheet by tapping the modal barrier (scrim) and settles
/// the pop animation, lowering the sheet-open gate again (RE-CF-12, D19).
Future<void> _dismissSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(400, 40));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('immersive_sheet')), findsNothing);
}

void main() {
  testWidgets('swiping advances the active layer via the provider (RE-CF-3)', (
    tester,
  ) async {
    final harness = await _pumpShell(tester);

    expect(
      harness.container.read(configuratorStateProvider).activeLayerIndex,
      0,
    );
    expect(harness.renderer.calls, 1);

    await _flingLeft(tester);

    expect(
      harness.container.read(configuratorStateProvider).activeLayerIndex,
      1,
    );
    expect(harness.renderer.calls, 1);
  });

  testWidgets('traversing all four pages never re-renders the preview '
      '(RE-CF-3, D12)', (tester) async {
    final harness = await _pumpShell(tester);

    for (var expected = 1; expected < LayerType.values.length; expected++) {
      await _flingLeft(tester);
      expect(
        harness.container.read(configuratorStateProvider).activeLayerIndex,
        expected,
      );
    }

    expect(harness.renderer.calls, 1);
  });

  testWidgets('the shell does not wrap at the font edge (clamp physics)', (
    tester,
  ) async {
    final harness = await _pumpShell(tester);

    for (var i = 0; i < LayerType.values.length - 1; i++) {
      await _flingLeft(tester);
    }
    expect(
      harness.container.read(configuratorStateProvider).activeLayerIndex,
      3,
    );

    await _flingLeft(tester);

    expect(
      harness.container.read(configuratorStateProvider).activeLayerIndex,
      3,
    );
    expect(harness.renderer.calls, 1);
  });

  testWidgets('swipe left on the preview cycles the active layer to the next '
      'item (RE-CF-3, D17/D18)', (tester) async {
    final harness = await _pumpShell(tester);

    expect(
      harness.container.read(configuratorStateProvider).selectedIds[0],
      isNull,
    );
    expect(harness.renderer.calls, 1);

    await _swipePreview(tester, const Offset(-400, 0));

    // Background pool: bg_navy -> bg_midnight -> bg_forest (D18: left = next).
    expect(
      harness.container.read(configuratorStateProvider).selectedIds[0],
      'bg_midnight',
    );
    // Item cycling changes the selection, so the preview re-renders (RE-CF-3).
    expect(harness.renderer.calls, 2);
  });

  testWidgets('swipe right on the preview cycles the active layer to the '
      'previous item (RE-CF-3, D17/D18)', (tester) async {
    final harness = await _pumpShell(tester);

    await _swipePreview(tester, const Offset(400, 0));

    // An unselected layer resolves to pool index 0; -1 wraps to the last item.
    expect(
      harness.container.read(configuratorStateProvider).selectedIds[0],
      'bg_forest',
    );
  });

  testWidgets('swipe left wraps from the last pool item back to the first '
      '(RE-CF-3)', (tester) async {
    final harness = await _pumpShell(tester);

    for (var i = 0; i < 2; i++) {
      await _swipePreview(tester, const Offset(-400, 0));
    }
    expect(
      harness.container.read(configuratorStateProvider).selectedIds[0],
      'bg_forest',
    );

    // The third next-swipe wraps modulo the pool length.
    await _swipePreview(tester, const Offset(-400, 0));

    expect(
      harness.container.read(configuratorStateProvider).selectedIds[0],
      'bg_navy',
    );
  });

  testWidgets('preview swipe cycles the active layer, not layer zero '
      '(D17/D18)', (tester) async {
    final harness = await _pumpShell(tester);

    // Navigate the shell to the phrase layer (index 1) first.
    await _flingLeft(tester);
    expect(
      harness.container.read(configuratorStateProvider).activeLayerIndex,
      1,
    );

    await _swipePreview(tester, const Offset(-400, 0));

    expect(
      harness.container.read(configuratorStateProvider).selectedIds[1],
      'ph_consistency',
    );
    expect(
      harness.container.read(configuratorStateProvider).selectedIds[0],
      isNull,
    );
  });

  testWidgets('swipe does not fire while the bottom sheet is open '
      '(RE-CF-3, D19)', (tester) async {
    final harness = await _pumpShell(tester);

    await _openSheet(tester);

    await _swipePreview(tester, const Offset(-400, 0));

    expect(
      harness.container.read(configuratorStateProvider).selectedIds[0],
      isNull,
    );
    expect(harness.renderer.calls, 1);
  });

  testWidgets('swipe fires again after the sheet is dismissed '
      '(RE-CF-3, D19)', (tester) async {
    final harness = await _pumpShell(tester);

    await _openSheet(tester);
    await _dismissSheet(tester);

    await _swipePreview(tester, const Offset(-400, 0));

    // Left swipe on the (now ungated) preview advances the background item.
    expect(
      harness.container.read(configuratorStateProvider).selectedIds[0],
      'bg_midnight',
    );
    expect(harness.renderer.calls, 2);
  });

  testWidgets('swipe on an empty active pool is a no-op and never crashes '
      '(RE-CF-3)', (tester) async {
    final harness = await _pumpShell(tester);
    final notifier = harness.container.read(configuratorStateProvider.notifier);
    for (final item in List<LayerItem>.from(
      harness.container.read(configuratorStateProvider).pools[0],
    )) {
      notifier.removeFromPool(0, item.id);
    }
    await tester.pumpAndSettle();
    expect(harness.container.read(configuratorStateProvider).pools[0], isEmpty);

    final callsBefore = harness.renderer.calls;
    await _swipePreview(tester, const Offset(-400, 0));

    expect(
      harness.container.read(configuratorStateProvider).selectedIds[0],
      isNull,
    );
    expect(harness.renderer.calls, callsBefore);
  });
}
