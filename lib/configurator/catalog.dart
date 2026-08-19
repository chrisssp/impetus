// Placeholder catalogs and default pools for the configurator (RE-CF-5,
// design D3).
//
// Every layer kind gets a static catalog of curated placeholders the user can
// pick from. The default pools — the initial pool per layer — reuse the same
// catalog objects. `kCharacterCatalog` and `kDefaultPools` are final, not
// const, because they carry [Uint8List] payloads (see
// lib/configurator/placeholder_assets.dart).

import 'dart:ui' show Color;

import 'package:impetus/configurator/layer_model.dart';
import 'package:impetus/configurator/placeholder_assets.dart';

/// Default background color placeholders.
const List<BackgroundItem> kBackgroundCatalog = [
  BackgroundItem(id: 'bg_navy', label: 'Navy', color: Color(0xFF1A237E)),
  BackgroundItem(
    id: 'bg_midnight',
    label: 'Midnight',
    color: Color(0xFF212121),
  ),
  BackgroundItem(id: 'bg_forest', label: 'Forest', color: Color(0xFF1B5E20)),
];

/// Default phrase placeholders.
const List<PhraseItem> kPhraseCatalog = [
  PhraseItem(
    id: 'ph_strength',
    label: 'Strength',
    text: 'Strength does not come from winning.',
  ),
  PhraseItem(
    id: 'ph_consistency',
    label: 'Consistency',
    text: 'Small daily steps build results.',
  ),
  PhraseItem(
    id: 'ph_discipline',
    label: 'Discipline',
    text: 'Discipline beats motivation.',
  ),
];

/// Default character placeholders (embedded PNG art).
final List<CharacterItem> kCharacterCatalog = [
  CharacterItem(id: 'ch_alpha', label: 'Alpha', bytes: kAlphaPngBytes),
  CharacterItem(id: 'ch_bravo', label: 'Bravo', bytes: kBravoPngBytes),
  CharacterItem(id: 'ch_charlie', label: 'Charlie', bytes: kCharliePngBytes),
  CharacterItem(id: 'ch_delta', label: 'Delta', bytes: kDeltaPngBytes),
];

/// Default font placeholders. The engine pins [FontItem.family] to Roboto, so
/// every placeholder maps to a family the render engine can resolve.
const List<FontItem> kFontCatalog = [
  FontItem(id: 'fo_roboto', label: 'Roboto', family: 'Roboto'),
  FontItem(id: 'fo_roboto_mono', label: 'Roboto Mono', family: 'Roboto'),
];

/// Default pools, indexed by [LayerType.values] order (RE-CF-2).
final List<List<LayerItem>> kDefaultPools = [
  kBackgroundCatalog,
  kPhraseCatalog,
  kCharacterCatalog,
  kFontCatalog,
];
