// Preview provider — debounced, latest-wins rendering of the configurator
// state (design D12, RE-CF-9, tasks 4.2/4.4).
//
// The canvas is device-adaptive: previewSizeProvider supplies the render size
// (defaulting to the pinned 540x960 used by tests and goldens, design D16/D25)
// and previewConfigProvider watches it together with the render-relevant slice
// of the state, so a size change re-derives the RenderConfig (D16).
//
// previewConfigProvider exposes only the render-relevant slice of the state
// (pools, selections, clock position). Layer navigation, mode toggles and the
// frozen flags never change the rendered output, so they are excluded: an
// equal snapshot keeps the preview from flickering while swiping (RE-CF-3).
//
// previewProvider renders immediately on first read and then debounces bursty
// edits. A generation counter makes the debounce latest-wins: a render that
// started earlier but finishes later is discarded, so the preview always shows
// the newest config (D12).

import 'dart:async';
import 'dart:ui' show Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impetus/configurator/blocking.dart';
import 'package:impetus/configurator/configurator_notifier.dart';
import 'package:impetus/configurator/configurator_state.dart';
import 'package:impetus/configurator/preview_pipeline.dart';
import 'package:impetus/models/render_config.dart';

/// Debounce window for preview re-renders (design D12).
const Duration kPreviewDebounce = Duration(milliseconds: 100);

/// The canvas the preview renders at (design D16, RE-CF-9).
///
/// Defaults to the pinned 540x960 portrait canvas so tests and goldens stay
/// deterministic (D25); the immersive shell overrides it with the device's
/// available body size.
final previewSizeProvider = Provider<Size>((ref) => const Size(540, 960));

/// The render-relevant slice of the configurator state, mapped to the engine's
/// [RenderConfig].
///
/// [ConfiguratorState]'s equality is content-based, so constructing a snapshot
/// only changes when pools, selections or the clock actually change. Raw lists
/// would break this: they compare by identity, so every state change would
/// look different even when the render output is identical.
final previewConfigProvider = Provider<RenderConfig>((ref) {
  final size = ref.watch(previewSizeProvider);
  final state = ref.watch(
    configuratorStateProvider.select(
      (s) => ConfiguratorState(
        pools: s.pools,
        selectedIds: s.selectedIds,
        clockPosition: s.clockPosition,
      ),
    ),
  );
  return buildRenderConfig(state, canvasSize: size);
});

/// The render entry point, injectable so tests can substitute a fake renderer
/// (the real engine futures never complete under the widget-test fake async
/// zone).
final previewRenderProvider =
    Provider<Future<PreviewResult> Function(RenderConfig)>(
      (ref) => renderPreview,
    );

/// The debounced, latest-wins preview (design D12).
final previewProvider = AsyncNotifierProvider<PreviewNotifier, PreviewResult>(
  PreviewNotifier.new,
);

class PreviewNotifier extends AsyncNotifier<PreviewResult> {
  Timer? _debounce;
  int _generation = 0;
  bool _disposed = false;

  @override
  Future<PreviewResult> build() {
    ref.onDispose(() {
      _debounce?.cancel();
      _disposed = true;
    });
    ref.listen(previewConfigProvider, (_, _) => _scheduleDebouncedRender());
    return _renderInitial();
  }

  /// Renders the current config immediately and gates the returned future on
  /// the generation counter, so the framework never applies a stale initial
  /// result once a debounced render has taken over (latest-wins, D12).
  Future<PreviewResult> _renderInitial() {
    final gate = Completer<PreviewResult>();
    final generation = _nextGeneration();
    _startRender(
      generation,
      onValue: (result) {
        if (generation == _generation) {
          gate.complete(result);
        }
      },
      onError: (error, stackTrace) {
        if (generation == _generation) {
          gate.completeError(error, stackTrace);
        }
      },
    );
    return gate.future;
  }

  void _scheduleDebouncedRender() {
    _debounce?.cancel();
    _debounce = Timer(kPreviewDebounce, () {
      final generation = _nextGeneration();
      _startRender(
        generation,
        onValue: (result) => _apply(generation, AsyncData(result)),
        onError: (error, stackTrace) =>
            _apply(generation, AsyncError(error, stackTrace)),
      );
    });
  }

  int _nextGeneration() => ++_generation;

  void _startRender(
    int generation, {
    required void Function(PreviewResult) onValue,
    required void Function(Object, StackTrace) onError,
  }) {
    final config = ref.read(previewConfigProvider);
    final render = ref.read(previewRenderProvider);
    render(config).then(onValue, onError: onError);
  }

  void _apply(int generation, AsyncValue<PreviewResult> next) {
    if (_disposed || generation != _generation) {
      return;
    }
    state = next;
  }
}

/// Projection of the latest render's blocks. While the preview is loading or
/// errored, nothing is known, so every layer reports unblocked (design D10).
final blockStatusProvider = Provider<LayerBlockStatuses>((ref) {
  return ref
      .watch(previewProvider)
      .maybeWhen(
        data: (result) => result.blocks,
        orElse: () => const LayerBlockStatuses.empty(),
      );
});
