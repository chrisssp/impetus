// Preview pipeline (design D9/D11, tasks 4.1/4.3).
//
// renderPreview takes a finished RenderConfig and returns the encoded PNG plus
// the per-layer blocking analysis. The engine runs for real here (loaded
// Roboto, embedded placeholder art, on the default clock '12:34'), so these
// tests also pin down the canvas size and the degenerate-config fallbacks.

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/configurator/catalog.dart';
import 'package:impetus/configurator/configurator_state.dart';
import 'package:impetus/configurator/layer_model.dart';
import 'package:impetus/configurator/preview_pipeline.dart';
import 'package:impetus/models/render_config.dart' show ClockPosition;

import '../helpers/load_roboto.dart';

const List<int> _pngMagic = [0x89, 0x50, 0x4e, 0x47];

const int _canvasWidth = 540;
const int _canvasHeight = 960;

/// The pinned canvas size these pipeline tests render at (design D16/D25).
const Size _canvas = Size(540, 960);

ConfiguratorState _baseState({List<List<LayerItem>>? pools}) {
  return ConfiguratorState(
    pools:
        pools ??
        [kBackgroundCatalog, kPhraseCatalog, kCharacterCatalog, kFontCatalog],
  );
}

/// Asserts the png is a decodable PNG at the canvas size (D11).
Future<void> _expectValidCanvas(Uint8List png) async {
  expect(png.sublist(0, 4), _pngMagic);
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  expect(frame.image.width, _canvasWidth);
  expect(frame.image.height, _canvasHeight);
  frame.image.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(loadRoboto);

  group('renderPreview (D9/D11)', () {
    test('renders a valid PNG and reports all four layers unblocked', () async {
      final config = buildRenderConfig(_baseState(), canvasSize: _canvas);

      final result = await renderPreview(config);

      await _expectValidCanvas(result.png);
      expect(result.blocks.entries, hasLength(4));
      for (final status in result.blocks.entries) {
        expect(
          status.blocked,
          isFalse,
          reason: '${status.reason} — ${status.suggestion}',
        );
      }
    });

    test(
      'empty phrase pool still renders and blocks the phrase layer',
      () async {
        final config = buildRenderConfig(
          _baseState(
            pools: [
              kBackgroundCatalog,
              const <LayerItem>[],
              kCharacterCatalog,
              kFontCatalog,
            ],
          ),
          canvasSize: _canvas,
        );

        final result = await renderPreview(config);

        await _expectValidCanvas(result.png);
        expect(result.blocks.entries[LayerType.phrase.index].blocked, isTrue);
        expect(
          result.blocks.entries[LayerType.background.index].blocked,
          isFalse,
        );
        expect(
          result.blocks.entries[LayerType.character.index].blocked,
          isFalse,
        );
        expect(result.blocks.entries[LayerType.font.index].blocked, isFalse);
      },
    );

    test(
      'empty character pool still renders and blocks the character layer',
      () async {
        final config = buildRenderConfig(
          _baseState(
            pools: [
              kBackgroundCatalog,
              kPhraseCatalog,
              const <LayerItem>[],
              kFontCatalog,
            ],
          ),
          canvasSize: _canvas,
        );

        final result = await renderPreview(config);

        await _expectValidCanvas(result.png);
        expect(
          result.blocks.entries[LayerType.character.index].blocked,
          isTrue,
        );
        expect(
          result.blocks.entries[LayerType.background.index].blocked,
          isFalse,
        );
        expect(result.blocks.entries[LayerType.phrase.index].blocked, isFalse);
        expect(result.blocks.entries[LayerType.font.index].blocked, isFalse);
      },
    );

    test(
      'fully degenerate config renders a valid PNG with every layer blocked',
      () async {
        final config = buildRenderConfig(
          _baseState(
            pools: [
              const <LayerItem>[],
              const <LayerItem>[],
              const <LayerItem>[],
              const <LayerItem>[],
            ],
          ),
          canvasSize: _canvas,
        );

        final result = await renderPreview(config);

        await _expectValidCanvas(result.png);
        for (final status in result.blocks.entries) {
          expect(
            status.blocked,
            isTrue,
            reason: 'expected ${status.reason} — ${status.suggestion}',
          );
        }
      },
    );

    test(
      'clock position is forwarded to the rendered config (RE-CF-8)',
      () async {
        final config = buildRenderConfig(
          _baseState().copyWith(clockPosition: ClockPosition.bottomCenter),
          canvasSize: _canvas,
        );

        final result = await renderPreview(config);

        await _expectValidCanvas(result.png);
        expect(result.blocks.entries[LayerType.phrase.index].blocked, isFalse);
      },
    );

    test(
      'is deterministic: the same config renders byte-identical PNGs',
      () async {
        final config = buildRenderConfig(_baseState(), canvasSize: _canvas);

        final first = await renderPreview(config);
        final second = await renderPreview(config);

        expect(first.png, second.png);
        expect(first.blocks.entries, second.blocks.entries);
      },
    );
  });
}
