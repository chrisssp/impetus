// Blocked-layer analysis (design D9, RE-CF-7, tasks 3.2/3.4).
//
// BlockAnalyzer decides, for each stack layer, whether the current config can
// render meaningfully. It is deliberately pure and synchronous: the layout
// work (bbox detection, zone computation, layout fitting) is done by the
// engine's exported building blocks and passed in, so the analyzer only
// inspects finished inputs and never touches the engine renderer.
//
// Because analyze() receives a RenderConfig and not the pools, an empty
// background / font pool is encoded as a sentinel produced by
// buildRenderConfig: kEmptyBackgroundColor (transparent) and
// kEmptyFontFamily (empty string). A missing character is simply a null
// characterPng.

import 'dart:ui' show Color, Rect;

import 'package:impetus/models/render_config.dart';
import 'package:impetus/models/zones.dart';

/// Sentinel produced by buildRenderConfig when the background pool is empty.
const Color kEmptyBackgroundColor = Color(0x00000000);

/// Sentinel produced by buildRenderConfig when the font pool is empty.
const String kEmptyFontFamily = '';

/// Why a layer is blocked. Null when the layer renders normally.
enum BlockReason {
  /// The pool has no items (background, phrase, font).
  emptyPool,

  /// The layout leaves no room for the quote (phrase).
  noFreeZone,

  /// The character has no bytes, or no visible art within the canvas (character).
  noCharacterContent,
}

const String _backgroundSuggestion = 'Add a background color.';
const String _phraseSuggestion =
    'No room for the quote — shorten it, swap the character, or change the '
    'clock position.';
const String _addCharacterSuggestion = 'Add a character to the pool.';
const String _pickCharacterSuggestion = 'Pick a character with visible art.';
const String _fontSuggestion = 'Add a font to the pool.';

/// Per-layer blocking result: whether the layer is blocked and why, plus the
/// suggestion shown in the UI to unblock it.
class LayerBlockStatus {
  const LayerBlockStatus({required this.blocked, this.reason, this.suggestion});

  /// A not-blocked status with no reason and no suggestion.
  const LayerBlockStatus.clear()
    : blocked = false,
      reason = null,
      suggestion = null;

  final bool blocked;
  final BlockReason? reason;
  final String? suggestion;
}

/// The four stack-layer statuses in stack order (design D9).
class LayerBlockStatuses {
  const LayerBlockStatuses(this.entries);

  /// All layers unblocked — used by consumers that render without analysis.
  const LayerBlockStatuses.empty()
    : entries = const [
        LayerBlockStatus.clear(),
        LayerBlockStatus.clear(),
        LayerBlockStatus.clear(),
        LayerBlockStatus.clear(),
      ];

  final List<LayerBlockStatus> entries;
}

/// Analyzes [config] and returns one status per stack layer.
class BlockAnalyzer {
  const BlockAnalyzer._();

  static LayerBlockStatuses analyze(
    RenderConfig config,
    Rect bbox,
    LayoutResult layout,
  ) {
    return LayerBlockStatuses([
      _background(config.background),
      _phrase(config.quoteText, layout),
      _character(config.characterPng, bbox),
      _font(config.fontFamily),
    ]);
  }

  static LayerBlockStatus _background(Color background) {
    if (background != kEmptyBackgroundColor) {
      return const LayerBlockStatus.clear();
    }
    return const LayerBlockStatus(
      blocked: true,
      reason: BlockReason.emptyPool,
      suggestion: _backgroundSuggestion,
    );
  }

  static LayerBlockStatus _phrase(String quoteText, LayoutResult layout) {
    if (quoteText.isEmpty) {
      return const LayerBlockStatus(
        blocked: true,
        reason: BlockReason.emptyPool,
        suggestion: _phraseSuggestion,
      );
    }
    if (layout.quoteRect.isEmpty) {
      return const LayerBlockStatus(
        blocked: true,
        reason: BlockReason.noFreeZone,
        suggestion: _phraseSuggestion,
      );
    }
    return const LayerBlockStatus.clear();
  }

  static LayerBlockStatus _character(List<int>? characterPng, Rect bbox) {
    if (characterPng == null) {
      return const LayerBlockStatus(
        blocked: true,
        reason: BlockReason.noCharacterContent,
        suggestion: _addCharacterSuggestion,
      );
    }
    if (bbox.isEmpty) {
      return const LayerBlockStatus(
        blocked: true,
        reason: BlockReason.noCharacterContent,
        suggestion: _pickCharacterSuggestion,
      );
    }
    return const LayerBlockStatus.clear();
  }

  static LayerBlockStatus _font(String fontFamily) {
    if (fontFamily != kEmptyFontFamily) {
      return const LayerBlockStatus.clear();
    }
    return const LayerBlockStatus(
      blocked: true,
      reason: BlockReason.emptyPool,
      suggestion: _fontSuggestion,
    );
  }
}
