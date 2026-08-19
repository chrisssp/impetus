// Golden baseline test for the app shell.
//
// Determinism requirements (golden-harness spec, design D14):
//   1. Bundled Roboto font loaded into the test environment via loadRoboto
//      (test/fonts/Roboto-Regular.ttf is a canonical, Apache 2.0 build).
//   2. MainApp's theme pins fontFamily: 'Roboto' so rendered text uses the
//      bundled font — never the Ahem placeholder or host-system fonts.
//   3. The preview is seeded deterministically: the default state's
//      RenderConfig is pre-rendered through the REAL engine inside
//      tester.runAsync (the engine's futures never complete under the
//      widget-test fake async zone), then previewRenderProvider is overridden
//      with that pre-rendered result, so the baseline shows real preview
//      bytes (D14). The previewConfigProvider override is deliberately NOT
//      pinned here: slice 6 (D16) makes the immersive shell render the
//      preview at the device size through its nested ProviderScope, which
//      re-creates the provider with the scoped size — the renderer override
//      is what keeps the pixels deterministic (it ignores the config).
//   4. The Image.memory decode completes on the real event loop via
//      tester.runAsync + precacheImage before the frame is captured.
//   5. A committed baseline at goldens/app_shell.png; the test fails unless
//      the render matches it byte-identically.
//
// The baseline is generated with `flutter test --update-goldens` and then
// must pass without the flag on CI and locally.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/configurator/catalog.dart';
import 'package:impetus/configurator/configurator_state.dart';
import 'package:impetus/configurator/preview_pipeline.dart';
import 'package:impetus/configurator/preview_provider.dart';
import 'package:impetus/main.dart';

import '../helpers/load_roboto.dart';

/// The device-size canvas the shell renders the preview at (design D16): the
/// golden's default test surface is 800x600 logical, and the shell's nested
/// scope feeds that size into the preview pipeline, so the pre-render must
/// match it aspect-for-aspect (BoxFit.cover, D23).
const Size _canvas = Size(800, 600);

void main() {
  setUpAll(loadRoboto);

  testWidgets('app shell renders identically to the golden baseline', (
    WidgetTester tester,
  ) async {
    final defaultState = ConfiguratorState(
      pools: [
        kBackgroundCatalog,
        kPhraseCatalog,
        kCharacterCatalog,
        kFontCatalog,
      ],
    );
    final defaultConfig = buildRenderConfig(defaultState, canvasSize: _canvas);

    // Pre-render the default config through the real engine on the real event
    // loop, so the golden baseline contains actual preview pixels (D14).
    final preview = await tester.runAsync<PreviewResult>(
      () => renderPreview(defaultConfig),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          previewRenderProvider.overrideWithValue((_) async => preview!),
        ],
        child: const MainApp(),
      ),
    );
    await tester.pump();

    // Complete the Image.memory decode on the real event loop, then repaint
    // with the decoded frame before capturing the golden (D14).
    final image = tester.widget<Image>(find.byType(Image));
    await tester.runAsync(
      () => precacheImage(image.image, tester.element(find.byType(Image))),
    );
    await tester.pump();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/app_shell.png'),
    );
  });
}
