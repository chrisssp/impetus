// Golden baseline tests for renderPreview output (design D11, RE-CF-9,
// tasks 5.3-5.5).
//
// PNG-level goldens of the preview pipeline, following the part-1 D12 pattern
// (see engine_render_golden_test.dart):
//   1. Bundled Roboto loaded into the test environment via loadRoboto
//      (test/fonts/Roboto-Regular.ttf is a canonical, Apache 2.0 build), so
//      every rendered quote uses the same glyphs.
//   2. Three fixed configurator states feed renderPreview through the real
//      engine: the default pools, a no-character state (empty character pool)
//      and an empty-pool phrase state (empty phrase pool) — the degenerate
//      states from RE-CF-9.
//   3. Committed baselines at goldens/configurator_preview/; each test fails
//      unless the render matches its baseline byte-identically.
//
// The baselines are generated with `flutter test --update-goldens` and then
// must pass without the flag on CI and locally.

import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/configurator/catalog.dart';
import 'package:impetus/configurator/configurator_state.dart';
import 'package:impetus/configurator/layer_model.dart';
import 'package:impetus/configurator/preview_pipeline.dart';

import '../helpers/load_roboto.dart';

/// The pinned 540x960 canvas the goldens render at (design D25).
const Size _canvas = Size(540, 960);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(loadRoboto);

  ConfiguratorState state({List<List<LayerItem>>? pools}) {
    return ConfiguratorState(
      pools:
          pools ??
          [kBackgroundCatalog, kPhraseCatalog, kCharacterCatalog, kFontCatalog],
    );
  }

  test('default state renders identically to the golden baseline', () async {
    final result = await renderPreview(
      buildRenderConfig(state(), canvasSize: _canvas),
    );

    await expectLater(
      result.png,
      matchesGoldenFile('goldens/configurator_preview/default.png'),
    );
  });

  test(
    'no-character state renders identically to the golden baseline',
    () async {
      final result = await renderPreview(
        buildRenderConfig(
          state(
            pools: [
              kBackgroundCatalog,
              kPhraseCatalog,
              const <LayerItem>[],
              kFontCatalog,
            ],
          ),
          canvasSize: _canvas,
        ),
      );

      await expectLater(
        result.png,
        matchesGoldenFile('goldens/configurator_preview/no_character.png'),
      );
    },
  );

  test(
    'empty-pool phrase state renders identically to the golden baseline',
    () async {
      final result = await renderPreview(
        buildRenderConfig(
          state(
            pools: [
              kBackgroundCatalog,
              const <LayerItem>[],
              kCharacterCatalog,
              kFontCatalog,
            ],
          ),
          canvasSize: _canvas,
        ),
      );

      await expectLater(
        result.png,
        matchesGoldenFile('goldens/configurator_preview/empty_pool_phrase.png'),
      );
    },
  );
}
