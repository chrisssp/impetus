// Preview provider (design D12, tasks 4.2/4.4).
//
// The engine futures never complete under the widget-test fake async zone, so
// every test overrides previewRenderProvider with a recording fake. This keeps
// the tests focused on the debounce, the latest-wins generation counter, error
// fallback and the blockStatusProvider projection (D10).

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/configurator/blocking.dart';
import 'package:impetus/configurator/configurator_notifier.dart';
import 'package:impetus/configurator/layer_model.dart';
import 'package:impetus/configurator/preview_pipeline.dart';
import 'package:impetus/configurator/preview_provider.dart';
import 'package:impetus/models/render_config.dart';

const List<int> _pngMagic = [0x89, 0x50, 0x4e, 0x47];

const LayerBlockStatuses _blockedPhrase = LayerBlockStatuses([
  LayerBlockStatus.clear(),
  LayerBlockStatus(
    blocked: true,
    reason: BlockReason.noFreeZone,
    suggestion: 'No room for the quote.',
  ),
  LayerBlockStatus.clear(),
  LayerBlockStatus.clear(),
]);

/// A fake result tagged with [tag] so distinct renders are distinguishable.
PreviewResult _result(String tag, {LayerBlockStatuses? blocks}) {
  return PreviewResult(
    png: Uint8List.fromList(<int>[..._pngMagic, ...tag.codeUnits]),
    blocks: blocks ?? const LayerBlockStatuses.empty(),
  );
}

/// A provider container whose renderer is a recording fake.
(ProviderContainer container, List<RenderConfig> renderedConfigs) _container(
  Future<PreviewResult> Function(RenderConfig config) render, {
  List<Override> overrides = const [],
}) {
  final renderedConfigs = <RenderConfig>[];
  final container = ProviderContainer(
    overrides: [
      previewRenderProvider.overrideWithValue((RenderConfig config) {
        renderedConfigs.add(config);
        return render(config);
      }),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  return (container, renderedConfigs);
}

void main() {
  testWidgets('debounces bursty state changes into one render of the latest '
      'config (D12)', (tester) async {
    final (container, renderedConfigs) = _container(
      (_) async => _result('burst'),
    );
    final notifier = container.read(configuratorStateProvider.notifier);

    container.read(previewProvider);
    notifier.setClockPosition(ClockPosition.topLeft);
    notifier.setClockPosition(ClockPosition.topRight);
    notifier.setClockPosition(ClockPosition.bottomCenter);
    expect(
      renderedConfigs,
      hasLength(1),
      reason: 'the debounce window has not elapsed yet',
    );

    await tester.pump(kPreviewDebounce);

    expect(renderedConfigs, hasLength(2));
    expect(renderedConfigs.last.clockPosition, ClockPosition.bottomCenter);
    expect(
      container.read(previewProvider).value?.blocks,
      const LayerBlockStatuses.empty(),
    );
  });

  testWidgets('only the newest render wins even when an older one finishes '
      'later (D12)', (tester) async {
    final completers = <Completer<PreviewResult>>[];
    final (container, _) = _container((_) {
      final completer = Completer<PreviewResult>();
      completers.add(completer);
      return completer.future;
    });
    final notifier = container.read(configuratorStateProvider.notifier);

    container.read(previewProvider);
    notifier.setClockPosition(ClockPosition.topLeft);
    notifier.setClockPosition(ClockPosition.topRight);
    notifier.setClockPosition(ClockPosition.bottomCenter);
    await tester.pump(kPreviewDebounce);

    expect(completers, hasLength(2));

    final stale = _result('stale');
    final newest = _result('newest');
    completers[1].complete(newest);
    await tester.pump();
    expect(container.read(previewProvider).value?.png, newest.png);

    completers[0].complete(stale);
    await tester.pump();
    expect(
      container.read(previewProvider).value?.png,
      newest.png,
      reason: 'a stale render must not clobber the newest one',
    );
  });

  testWidgets('render errors surface as AsyncError without throwing (D12)', (
    tester,
  ) async {
    final (container, _) = _container(
      (_) async => throw StateError('render failed'),
    );

    container.read(previewProvider);
    await tester.pump(kPreviewDebounce);
    await tester.pump();

    expect(container.read(previewProvider), isA<AsyncError<PreviewResult>>());
  });

  testWidgets('blockStatusProvider is all-unblocked while loading and reports '
      'the render blocks on data (D10)', (tester) async {
    final gate = Completer<PreviewResult>();
    final (container, _) = _container((_) => gate.future);

    container.read(previewProvider);

    var blocks = container.read(blockStatusProvider);
    expect(
      blocks.entries.every((e) => !e.blocked),
      isTrue,
      reason: 'nothing is known yet, so nothing is blocked (D10)',
    );

    gate.complete(_result('data', blocks: _blockedPhrase));
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);

    blocks = container.read(blockStatusProvider);
    expect(blocks.entries[LayerType.phrase.index].blocked, isTrue);
    expect(
      blocks.entries[LayerType.phrase.index].reason,
      BlockReason.noFreeZone,
    );
    expect(blocks.entries[LayerType.background.index].blocked, isFalse);
  });

  testWidgets('layer navigation does not re-render (RE-CF-3)', (tester) async {
    final (container, renderedConfigs) = _container(
      (_) async => _result('swipe'),
    );
    final notifier = container.read(configuratorStateProvider.notifier);

    container.read(previewProvider);
    await tester.pump(kPreviewDebounce);

    notifier.setActiveLayer(1);
    notifier.setActiveLayer(2);
    notifier.setActiveLayer(0);
    await tester.pump(kPreviewDebounce);

    expect(
      renderedConfigs,
      hasLength(1),
      reason: 'activeLayerIndex is not render-relevant (D12)',
    );
  });

  testWidgets('a preview size change re-derives the RenderConfig through the '
      'debounce (RE-CF-9, D16)', (tester) async {
    final size = StateProvider<Size>((ref) => const Size(540, 960));
    final (container, renderedConfigs) = _container(
      (_) async => _result('size'),
      overrides: [previewSizeProvider.overrideWith((ref) => ref.watch(size))],
    );

    container.read(previewProvider);
    await tester.pump(kPreviewDebounce);

    container.read(size.notifier).state = const Size(360, 640);
    await tester.pump(kPreviewDebounce);
    await tester.pump();

    expect(
      renderedConfigs,
      hasLength(2),
      reason:
          'a size change must re-derive the RenderConfig through the '
          'debounced pipeline, not the pinned 540x960 default (D16)',
    );
    expect(renderedConfigs.first.size, const Size(540, 960));
    expect(renderedConfigs.last.size, const Size(360, 640));
  });
}
