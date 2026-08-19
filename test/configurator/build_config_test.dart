// Tests for buildRenderConfig — the pure, synchronous mapping from
// configurator state to the engine's RenderConfig (design D11, tasks 3.1/3.3).
//
// Strict TDD: this file is the RED test for tasks 3.1 + 3.3. Coverage:
//   - The canvas size is caller-supplied; tests pin the default 540x960
//     portrait canvas (D16/D25).
//   - Selected background / phrase / character / font items resolve into the
//     RenderConfig fields they own (RE-CF-9).
//   - A null selection falls back to the pool's first item so the WYSIWYG
//     preview always has content when the pool is populated.
//   - Every clock preset maps into config.clockPosition (RE-CF-8).
//   - Empty pools produce a degenerate config (empty quoteText, null
//     characterPng) that never throws (RE-CF-9).

import 'dart:ui' show Color, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/configurator/blocking.dart'
    show kEmptyBackgroundColor, kEmptyFontFamily;
import 'package:impetus/configurator/catalog.dart';
import 'package:impetus/configurator/configurator_state.dart';
import 'package:impetus/configurator/layer_model.dart';
import 'package:impetus/configurator/placeholder_assets.dart';
import 'package:impetus/configurator/preview_pipeline.dart';
import 'package:impetus/models/render_config.dart';

const _canvas = Size(540, 960);

/// A state over the placeholder catalogs with every layer unselected.
ConfiguratorState _state({
  List<LayerItem>? backgroundPool,
  List<LayerItem>? phrasePool,
  List<LayerItem>? characterPool,
  List<LayerItem>? fontPool,
  List<String?>? selectedIds,
  ClockPosition clockPosition = ClockPosition.topCenter,
}) {
  return ConfiguratorState(
    pools: [
      backgroundPool ?? kBackgroundCatalog,
      phrasePool ?? kPhraseCatalog,
      characterPool ?? kCharacterCatalog,
      fontPool ?? kFontCatalog,
    ],
    selectedIds: selectedIds ?? const [null, null, null, null],
    clockPosition: clockPosition,
  );
}

void main() {
  group('buildRenderConfig (D11)', () {
    test('maps the given canvas size into RenderConfig.size (D16)', () {
      expect(buildRenderConfig(_state(), canvasSize: _canvas).size, _canvas);
    });

    test('resolves the selected background item into config.background', () {
      final state = _state(selectedIds: const ['bg_forest', null, null, null]);
      expect(
        buildRenderConfig(state, canvasSize: _canvas).background,
        const Color(0xFF1B5E20),
      );
    });

    test('resolves the selected phrase item into config.quoteText', () {
      final state = _state(
        selectedIds: const [null, 'ph_discipline', null, null],
      );
      expect(
        buildRenderConfig(state, canvasSize: _canvas).quoteText,
        'Discipline beats motivation.',
      );
    });

    test('resolves the selected character item into config.characterPng', () {
      final state = _state(selectedIds: const [null, null, 'ch_bravo', null]);
      expect(
        buildRenderConfig(state, canvasSize: _canvas).characterPng,
        kBravoPngBytes,
      );
    });

    test('resolves the selected font item into config.fontFamily', () {
      final state = _state(selectedIds: const [null, null, null, 'fo_roboto']);
      expect(
        buildRenderConfig(state, canvasSize: _canvas).fontFamily,
        'Roboto',
      );
    });

    test('falls back to the pool first item when nothing is selected', () {
      final config = buildRenderConfig(_state(), canvasSize: _canvas);
      expect(config.background, const Color(0xFF1A237E)); // bg_navy
      expect(config.quoteText, 'Strength does not come from winning.');
      expect(config.characterPng, kAlphaPngBytes);
      expect(config.fontFamily, 'Roboto');
    });

    test('maps every clock preset into config.clockPosition (RE-CF-8)', () {
      for (final preset in ClockPosition.values) {
        final config = buildRenderConfig(
          _state(clockPosition: preset),
          canvasSize: _canvas,
        );
        expect(config.clockPosition, preset);
      }
    });

    test('empty pools produce a degenerate config that never throws '
        '(RE-CF-9)', () {
      final state = _state(
        backgroundPool: const [],
        phrasePool: const [],
        characterPool: const [],
        fontPool: const [],
      );
      final config = buildRenderConfig(state, canvasSize: _canvas);
      expect(config.quoteText, '');
      expect(config.characterPng, isNull);
      expect(config.background, kEmptyBackgroundColor);
      expect(config.fontFamily, kEmptyFontFamily);
    });
  });
}
