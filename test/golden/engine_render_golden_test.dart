// Golden baseline tests for RenderEngine.render.
//
// Determinism requirements (golden-harness spec):
//   1. Bundled Roboto font loaded into the test environment via FontLoader
//      (test/fonts/Roboto-Regular.ttf is a canonical, Apache 2.0 build).
//   2. The committed fixture test/fixtures/character_alpha.png feeds the
//      character layer, so every run composites the same subject.
//   3. Committed baselines at goldens/engine_render/; each test fails unless
//      the render matches its baseline byte-identically.
//
// The baselines are generated with `flutter test --update-goldens` and then
// must pass without the flag on CI and locally.
//
// Note: the font and the fixture are read from disk via dart:io rather than
// rootBundle. flutter_test only mocks 'flutter/assets' for files declared in
// pubspec (UNIT_TEST_ASSETS), and pubspec changes are out of scope for this
// slice. Reading the same committed bytes with File keeps the render
// deterministic.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/engine/render_engine.dart';
import 'package:impetus/models/render_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final fontBytes = await File('test/fonts/Roboto-Regular.ttf').readAsBytes();
    final fontLoader = FontLoader('Roboto')
      ..addFont(Future.value(ByteData.sublistView(fontBytes)));
    await fontLoader.load();
  });

  final characterPng = File('test/fixtures/character_alpha.png')
      .readAsBytesSync();

  const canvas = ui.Size(540, 960);
  const quote = 'The journey of a thousand miles begins with a single step.';

  const backgrounds = <String, ui.Color>{
    'dark': ui.Color(0xFF2A2A2A),
    'light': ui.Color(0xFFF2EFE9),
  };
  const presets = <String, ClockPosition>{
    'top_center': ClockPosition.topCenter,
    'top_left': ClockPosition.topLeft,
    'top_right': ClockPosition.topRight,
    'bottom_center': ClockPosition.bottomCenter,
  };

  for (final background in backgrounds.entries) {
    for (final preset in presets.entries) {
      final name = '${background.key}_${preset.key}';
      test('renders $name identically to the golden baseline', () async {
        final png = await RenderEngine.render(
          RenderConfig(
            size: canvas,
            background: background.value,
            characterPng: characterPng,
            quoteText: quote,
            clockPosition: preset.value,
          ),
        );

        await expectLater(
          png,
          matchesGoldenFile('goldens/engine_render/$name.png'),
        );
      });
    }
  }

  test(
    'renders without a character identically to the golden baseline',
    () async {
      final png = await RenderEngine.render(
        RenderConfig(
          size: canvas,
          background: const ui.Color(0xFF2A2A2A),
          characterPng: null,
          quoteText: quote,
        ),
      );

      await expectLater(
        png,
        matchesGoldenFile('goldens/engine_render/dark_no_character.png'),
      );
    },
  );

  test('renders without a quote identically to the golden baseline', () async {
    final png = await RenderEngine.render(
      RenderConfig(
        size: canvas,
        background: const ui.Color(0xFF2A2A2A),
        characterPng: characterPng,
        quoteText: '',
      ),
    );

    await expectLater(
      png,
      matchesGoldenFile('goldens/engine_render/dark_empty_quote.png'),
    );
  });
}
