// Swipe shell (design D5/D12, RE-CF-3, tasks 6.2/6.6).
//
// The shell runs the real previewProvider so the debounce wiring is exercised,
// but previewRenderProvider is replaced with a counting fake renderer: the real
// engine futures never complete under the widget-test fake async zone, and the
// counter proves the preview does NOT re-render while swiping (RE-CF-3, D12 —
// activeLayerIndex is excluded from previewConfigProvider, so navigating the
// pages never changes the rendered config).

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
}
