// Tests for BlockAnalyzer — blocked-layer detection (RE-CF-7, design D9,
// tasks 3.2/3.4).
//
// Strict TDD: this file is the RED test for tasks 3.2 + 3.4. The layout math
// is measured with the engine's exported pure building blocks — AlphaBboxDetector,
// ZoneCalculator, LayoutFilter — over the committed fixture
// test/fixtures/character_alpha.png (D9). Every analyze call returns statuses;
// none may throw (RE-CF-7).

import 'dart:io';
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/configurator/blocking.dart';
import 'package:impetus/configurator/catalog.dart';
import 'package:impetus/configurator/configurator_state.dart';
import 'package:impetus/configurator/layer_model.dart';
import 'package:impetus/configurator/preview_pipeline.dart';
import 'package:impetus/engine/alpha_bbox_detector.dart';
import 'package:impetus/engine/layout_filter.dart';
import 'package:impetus/engine/render_engine.dart';
import 'package:impetus/engine/zone_calculator.dart';
import 'package:impetus/models/render_config.dart';
import 'package:impetus/models/zones.dart';

import '../helpers/load_roboto.dart';

const _canvas = Size(540, 960);

final _fixturePng = File('test/fixtures/character_alpha.png').readAsBytesSync();

const _phraseSuggestion =
    'No room for the quote — shorten it, swap the character, or change the '
    'clock position.';
const _addCharacterSuggestion = 'Add a character to the pool.';
const _pickCharacterSuggestion = 'Pick a character with visible art.';
const _addBackgroundSuggestion = 'Add a background color.';
const _addFontSuggestion = 'Add a font to the pool.';

/// The committed fixture as a [CharacterItem], so the detection path runs over
/// real visible art (design D9).
List<CharacterItem> _fixtureCharacter() => [
      CharacterItem(id: 'ch_fixture', label: 'Fixture', bytes: _fixturePng),
    ];

/// Measures the character bbox and resolved layout for [config] through the
/// exported engine pipeline: detect -> compute -> filter (design D9).
Future<({Rect bbox, LayoutResult layout})> _measure(
  RenderConfig config,
) async {
  final bbox = config.characterPng == null
      ? Rect.zero
      : await AlphaBboxDetector.detect(config.characterPng!);
  final zones = ZoneCalculator.compute(
    config.size,
    config.clockPosition,
    bbox,
  );
  final layout = LayoutFilter.filter(
    config.size,
    config.clockPosition,
    zones,
    config.quoteText,
    RenderEngine.baseFontSizeFor(config.size),
  );
  return (bbox: bbox, layout: layout);
}

/// Builds the config from [state], measures it, then analyzes it.
Future<LayerBlockStatuses> _statuses(ConfiguratorState state) async {
  final config = buildRenderConfig(state);
  final measured = await _measure(config);
  return BlockAnalyzer.analyze(config, measured.bbox, measured.layout);
}

ConfiguratorState _state({
  List<LayerItem>? backgroundPool,
  List<LayerItem>? phrasePool,
  List<LayerItem>? characterPool,
  List<LayerItem>? fontPool,
  List<String?>? selectedIds,
}) {
  return ConfiguratorState(
    pools: [
      backgroundPool ?? kBackgroundCatalog,
      phrasePool ?? kPhraseCatalog,
      characterPool ?? _fixtureCharacter(),
      fontPool ?? kFontCatalog,
    ],
    selectedIds: selectedIds ?? const [null, null, null, null],
  );
}

/// A layout where the quote has room, so only character analysis is isolated.
const LayoutResult _roomyLayout = LayoutResult(
  zoom: 1,
  pan: Offset.zero,
  quoteFontSize: 43,
  quoteRect: Rect.fromLTWH(0, 208, 540, 752),
);

String _hugeQuote() => List.filled(200, 'essential').join(' ');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRoboto);

  group('BlockAnalyzer.analyze (RE-CF-7)', () {
    test('exposes exactly four statuses in the fixed stack order', () async {
      final statuses = await _statuses(_state());
      expect(statuses.entries, hasLength(LayerType.values.length));
    });

    test('fully resolved default state has no blocked layer', () async {
      final statuses = await _statuses(_state());
      for (final status in statuses.entries) {
        expect(status.blocked, isFalse, reason: status.suggestion);
        expect(status.reason, isNull);
        expect(status.suggestion, isNull);
      }
    });

    test('phrase is blocked when the pool is empty (no pool item)', () async {
      final statuses = await _statuses(_state(phrasePool: const []));
      final phrase = statuses.entries[LayerType.phrase.index];
      expect(phrase.blocked, isTrue);
      expect(phrase.reason, BlockReason.emptyPool);
      expect(phrase.suggestion, _phraseSuggestion);
      expect(statuses.entries[LayerType.background.index].blocked, isFalse);
      expect(statuses.entries[LayerType.character.index].blocked, isFalse);
      expect(statuses.entries[LayerType.font.index].blocked, isFalse);
    });

    test('phrase is blocked when the layout leaves no room for the quote',
        () async {
      final state = _state(
        phrasePool: [
          PhraseItem(id: 'ph_huge', label: 'Huge', text: _hugeQuote()),
        ],
        selectedIds: const [null, 'ph_huge', null, null],
      );
      final config = buildRenderConfig(state);
      final measured = await _measure(config);
      expect(measured.layout.quoteRect, Rect.zero); // precondition

      final phrase =
          BlockAnalyzer.analyze(config, measured.bbox, measured.layout)
              .entries[LayerType.phrase.index];
      expect(phrase.blocked, isTrue);
      expect(phrase.reason, BlockReason.noFreeZone);
      expect(phrase.suggestion, _phraseSuggestion);
    });

    test('character is blocked when bytes are missing', () async {
      final statuses = await _statuses(_state(characterPool: const []));
      final character = statuses.entries[LayerType.character.index];
      expect(character.blocked, isTrue);
      expect(character.reason, BlockReason.noCharacterContent);
      expect(character.suggestion, _addCharacterSuggestion);
      expect(statuses.entries[LayerType.phrase.index].blocked, isFalse);
    });

    test('character is blocked when its bbox is empty (no visible art)',
        () async {
      final config = buildRenderConfig(_state());
      // Real fixture bytes, but a zero bbox: bytes exist, art does not.
      final statuses = BlockAnalyzer.analyze(config, Rect.zero, _roomyLayout);
      final character = statuses.entries[LayerType.character.index];
      expect(character.blocked, isTrue);
      expect(character.reason, BlockReason.noCharacterContent);
      expect(character.suggestion, _pickCharacterSuggestion);
      expect(statuses.entries[LayerType.phrase.index].blocked, isFalse);
    });

    test('character is unblocked when the fixture art is measured', () async {
      final config = buildRenderConfig(_state());
      final measured = await _measure(config);
      expect(measured.bbox, isNot(Rect.zero)); // precondition
      final character =
          BlockAnalyzer.analyze(config, measured.bbox, measured.layout)
              .entries[LayerType.character.index];
      expect(character.blocked, isFalse);
    });

    test('background is blocked when its pool is empty', () async {
      final statuses = await _statuses(_state(backgroundPool: const []));
      final background = statuses.entries[LayerType.background.index];
      expect(background.blocked, isTrue);
      expect(background.reason, BlockReason.emptyPool);
      expect(background.suggestion, _addBackgroundSuggestion);
      expect(statuses.entries[LayerType.phrase.index].blocked, isFalse);
      expect(statuses.entries[LayerType.character.index].blocked, isFalse);
    });

    test('font is blocked when its pool is empty', () async {
      final statuses = await _statuses(_state(fontPool: const []));
      final font = statuses.entries[LayerType.font.index];
      expect(font.blocked, isTrue);
      expect(font.reason, BlockReason.emptyPool);
      expect(font.suggestion, _addFontSuggestion);
      expect(statuses.entries[LayerType.phrase.index].blocked, isFalse);
      expect(statuses.entries[LayerType.background.index].blocked, isFalse);
    });

    test('never throws on a fully degenerate config', () async {
      final state = _state(
        backgroundPool: const [],
        phrasePool: const [],
        characterPool: const [],
        fontPool: const [],
      );
      final config = buildRenderConfig(state);
      final measured = await _measure(config);
      final statuses =
          BlockAnalyzer.analyze(config, measured.bbox, measured.layout);
      expect(statuses.entries, hasLength(4));
      expect(statuses.entries[LayerType.background.index].blocked, isTrue);
      expect(statuses.entries[LayerType.phrase.index].blocked, isTrue);
      expect(statuses.entries[LayerType.character.index].blocked, isTrue);
      expect(statuses.entries[LayerType.font.index].blocked, isTrue);
    });
  });
}
