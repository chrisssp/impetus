// Tests for device-adaptive preview sizing (design D16/D25, RE-CF-9,
// tasks 1.1-1.3).
//
// Strict TDD: this file is the RED test for tasks 1.1-1.3 (PR 1 of the
// immersive-shell chain). Coverage:
//   - buildRenderConfig accepts a canvasSize parameter and propagates it into
//     RenderConfig.size (RE-CF-9) — the hardcoded 540x960 canvas becomes a
//     caller-supplied size with the provider defaulting to 540x960 (D16).
//   - Different canvas sizes produce different RenderConfig instances.
//   - previewSizeProvider defaults to 540x960 and, when overridden in a
//     ProviderContainer, changes the canvas derived by previewConfigProvider
//     (D16/D25).

import 'dart:ui' show Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/configurator/catalog.dart';
import 'package:impetus/configurator/configurator_state.dart';
import 'package:impetus/configurator/layer_model.dart';
import 'package:impetus/configurator/preview_pipeline.dart';
import 'package:impetus/configurator/preview_provider.dart';

/// The pinned default canvas (design D11/D16).
const Size _defaultCanvas = Size(540, 960);

/// A state over the placeholder catalogs with every layer unselected.
ConfiguratorState _state({List<List<LayerItem>>? pools}) {
  return ConfiguratorState(
    pools:
        pools ??
        [kBackgroundCatalog, kPhraseCatalog, kCharacterCatalog, kFontCatalog],
  );
}

void main() {
  group('buildRenderConfig canvasSize (D16, RE-CF-9)', () {
    test('propagates the given canvas size into RenderConfig.size', () {
      const canvas = Size(360, 640);
      expect(buildRenderConfig(_state(), canvasSize: canvas).size, canvas);
    });

    test('honors the default 540x960 canvas when that size is supplied', () {
      final config = buildRenderConfig(_state(), canvasSize: _defaultCanvas);
      expect(config.size, _defaultCanvas);
    });

    test('different canvas sizes yield different RenderConfig instances', () {
      final small = buildRenderConfig(
        _state(),
        canvasSize: const Size(360, 640),
      );
      final large = buildRenderConfig(
        _state(),
        canvasSize: const Size(1080, 1920),
      );
      expect(small.size, isNot(large.size));
    });
  });

  group('previewSizeProvider (D16/D25)', () {
    test('defaults to the pinned 540x960 canvas', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(previewSizeProvider), _defaultCanvas);
    });

    test('override is respected by previewConfigProvider', () {
      final container = ProviderContainer(
        overrides: [
          previewSizeProvider.overrideWithValue(const Size(360, 640)),
        ],
      );
      addTearDown(container.dispose);
      expect(
        container.read(previewConfigProvider).size,
        const Size(360, 640),
      );
    });
  });
}