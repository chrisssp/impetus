// Preview pipeline — pure mapping from configurator state to a renderable
// engine config (design D11, RE-CF-8/9, tasks 3.1/3.3).
//
// buildRenderConfig is deliberately synchronous and side-effect free so it can
// be unit-tested and reused by the preview provider. An empty pool degrades
// into a sentinel instead of throwing: transparent background, empty quote,
// null character, empty font family — the block analyzer turns those into
// user-facing guidance (see blocking.dart).

import 'dart:ui' show Size;

import 'package:impetus/configurator/blocking.dart'
    show kEmptyBackgroundColor, kEmptyFontFamily;
import 'package:impetus/configurator/configurator_state.dart';
import 'package:impetus/configurator/layer_model.dart';
import 'package:impetus/models/render_config.dart';

/// The fixed preview canvas: 540x960 portrait (design D11).
const Size _canvas = Size(540, 960);

/// Resolves the current selection for one layer: the selected item when the
/// id matches a pool entry, otherwise the pool's first item so the WYSIWYG
/// preview always has content, or null when the pool is empty.
LayerItem? _firstResolved(List<LayerItem> pool, String? selectedId) {
  if (pool.isEmpty) {
    return null;
  }
  if (selectedId != null) {
    for (final item in pool) {
      if (item.id == selectedId) {
        return item;
      }
    }
  }
  return pool.first;
}

/// Maps [state] onto the engine's [RenderConfig] for the preview layer.
RenderConfig buildRenderConfig(ConfiguratorState state) {
  final background =
      _firstResolved(state.pools[0], state.selectedIds[0]);
  final phrase = _firstResolved(state.pools[1], state.selectedIds[1]);
  final character = _firstResolved(state.pools[2], state.selectedIds[2]);
  final font = _firstResolved(state.pools[3], state.selectedIds[3]);

  return RenderConfig(
    size: _canvas,
    background: background is BackgroundItem
        ? background.color
        : kEmptyBackgroundColor,
    quoteText: phrase is PhraseItem ? phrase.text : '',
    characterPng: character is CharacterItem ? character.bytes : null,
    clockPosition: state.clockPosition,
    fontFamily: font is FontItem ? font.family : kEmptyFontFamily,
  );
}
