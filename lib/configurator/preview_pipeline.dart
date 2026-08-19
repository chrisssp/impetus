// Preview pipeline — pure mapping from configurator state to a renderable
// engine config, plus the async render entry point (design D9/D11,
// RE-CF-8/9, tasks 3.1/3.3/4.1/4.3).
//
// buildRenderConfig is deliberately synchronous and side-effect free so it can
// be unit-tested and reused by the preview provider. The canvas size comes in
// as a parameter (design D16, RE-CF-9): the caller — normally
// previewSizeProvider — decides the dimensions, so the mapping stays pure and
// tests can pin any size. An empty pool degrades into a sentinel instead of
// throwing: transparent background, empty quote, null character, empty font
// family — the block analyzer turns those into user-facing guidance (see
// blocking.dart).
//
// renderPreview mirrors the engine's internal layout computation so the block
// analysis reflects the exact layout that was actually drawn.

import 'dart:typed_data' show Uint8List;
import 'dart:ui' show Rect, Size;

import 'package:impetus/configurator/blocking.dart';
import 'package:impetus/configurator/configurator_state.dart';
import 'package:impetus/configurator/layer_model.dart';
import 'package:impetus/engine/alpha_bbox_detector.dart';
import 'package:impetus/engine/layout_filter.dart';
import 'package:impetus/engine/render_engine.dart';
import 'package:impetus/engine/zone_calculator.dart';
import 'package:impetus/models/render_config.dart';

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
///
/// [canvasSize] becomes the render canvas: the device-adaptive preview passes
/// the available body size (D16), while tests and goldens pin 540x960 (D25).
RenderConfig buildRenderConfig(
  ConfiguratorState state, {
  required Size canvasSize,
}) {
  final background = _firstResolved(state.pools[0], state.selectedIds[0]);
  final phrase = _firstResolved(state.pools[1], state.selectedIds[1]);
  final character = _firstResolved(state.pools[2], state.selectedIds[2]);
  final font = _firstResolved(state.pools[3], state.selectedIds[3]);

  return RenderConfig(
    size: canvasSize,
    background: background is BackgroundItem
        ? background.color
        : kEmptyBackgroundColor,
    quoteText: phrase is PhraseItem ? phrase.text : '',
    characterPng: character is CharacterItem ? character.bytes : null,
    clockPosition: state.clockPosition,
    fontFamily: font is FontItem ? font.family : kEmptyFontFamily,
  );
}

/// The preview pipeline output: the rendered PNG plus the per-layer block
/// analysis that says which stack layers can actually be seen (design D9).
class PreviewResult {
  const PreviewResult({required this.png, required this.blocks});

  final Uint8List png;
  final LayerBlockStatuses blocks;
}

/// Renders [config] to PNG bytes and analyzes which layers are blocked.
///
/// Never throws on degenerate input: the engine degrades an empty quote, a
/// missing character and an empty background/font into valid output, and the
/// analyzer reports those layers as blocked (D9, RE-CF-7).
Future<PreviewResult> renderPreview(RenderConfig config) async {
  final subjectBbox = config.characterPng == null
      ? Rect.zero
      : await AlphaBboxDetector.detect(config.characterPng!);

  final zones = ZoneCalculator.compute(
    config.size,
    config.clockPosition,
    subjectBbox,
  );

  final layout = LayoutFilter.filter(
    config.size,
    config.clockPosition,
    zones,
    config.quoteText,
    RenderEngine.baseFontSizeFor(config.size),
    manualZoom: config.manualZoom,
    manualPan: config.manualPan,
  );

  final png = await RenderEngine.render(config);
  return PreviewResult(
    png: png,
    blocks: BlockAnalyzer.analyze(config, subjectBbox, layout),
  );
}
