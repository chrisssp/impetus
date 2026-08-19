// Domain model for the configurator layer stack (design D3).
//
// The stack has exactly four layer kinds in fixed order (RE-CF-2), each with
// its own item payload. Layer items are placeholders only (RE-CF-5 / RE-CF-11):
// the payloads carry no curated content.

import 'dart:typed_data';
import 'dart:ui' show Color;

/// The four layer kinds, in fixed stack order (RE-CF-2).
///
/// The system never reorders, adds or removes layers; this list is the single
/// source of truth for the order.
enum LayerType { background, phrase, character, font }

/// Whether a layer participates in shuffle (RE-CF-4).
///
/// A dynamic layer is re-selected on shuffle; a fixed layer keeps its
/// user-pinned selection (design D6).
enum LayerMode { fixed, dynamic }

/// Base class of every catalog / pool item (design D3).
///
/// [id] is the stable identity used for pool dedupe and selection (RE-CF-5,
/// design D8); [label] is the English UI label.
abstract class LayerItem {
  const LayerItem({required this.id, required this.label});

  final String id;
  final String label;
}

/// A placeholder background color.
class BackgroundItem extends LayerItem {
  const BackgroundItem({
    required super.id,
    required super.label,
    required this.color,
  });

  final Color color;
}

/// A placeholder quote phrase.
class PhraseItem extends LayerItem {
  const PhraseItem({
    required super.id,
    required super.label,
    required this.text,
  });

  final String text;
}

/// A placeholder character, carried as embedded PNG bytes (design D4).
class CharacterItem extends LayerItem {
  const CharacterItem({
    required super.id,
    required super.label,
    required this.bytes,
  });

  final Uint8List bytes;
}

/// A placeholder font family.
class FontItem extends LayerItem {
  const FontItem({
    required super.id,
    required super.label,
    required this.family,
  });

  final String family;
}
