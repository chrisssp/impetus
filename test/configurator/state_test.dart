// Tests for the configurator state foundation (PR 1).
//
// Strict TDD (openspec/config.yaml apply.tdd: true): this file is the RED test
// for Phase 1 tasks 1.1-1.5. It covers:
//   - RE-CF-1: copyWith yields a new instance and leaves the previous state
//     unchanged.
//   - RE-CF-2: exactly four layers in fixed order background -> phrase ->
//     character -> font, and the order is immutable under any copyWith.
//   - RE-CF-5 / RE-CF-11: placeholder catalogs and default pools (foundation).
//
// Part A only — provider-free, no widget tree. Part B (ProviderContainer
// tests) arrives with the ConfiguratorNotifier in Phase 2.

import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/configurator/catalog.dart';
import 'package:impetus/configurator/configurator_state.dart';
import 'package:impetus/configurator/layer_model.dart';
import 'package:impetus/models/render_config.dart' show ClockPosition;

const _layerOrder = [
  LayerType.background,
  LayerType.phrase,
  LayerType.character,
  LayerType.font,
];

/// A minimal PNG header for test-only [CharacterItem] instances.
Uint8List _tinyPng() => Uint8List.fromList(
    const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

/// A fresh state built from the placeholder catalogs and dynamic modes.
ConfiguratorState _baseState() {
  return ConfiguratorState(
    activeLayerIndex: 0,
    modes: const [
      LayerMode.dynamic,
      LayerMode.dynamic,
      LayerMode.dynamic,
      LayerMode.dynamic,
    ],
    pools: [
      kBackgroundCatalog,
      kPhraseCatalog,
      kCharacterCatalog,
      kFontCatalog,
    ],
    selectedIds: const [null, null, null, null],
    frozen: const [false, false, false, false],
    clockPosition: ClockPosition.topCenter,
  );
}

void main() {
  group('LayerType (RE-CF-2)', () {
    test('exposes exactly four layers in fixed order', () {
      expect(LayerType.values, _layerOrder);
      expect(LayerType.values, hasLength(4));
    });
  });

  group('ConfiguratorState.copyWith (RE-CF-1)', () {
    test('yields a new instance and leaves the previous state unchanged', () {
      final original = _baseState();
      final updated = original.copyWith(activeLayerIndex: 3);

      expect(identical(updated, original), isFalse);
      expect(updated.activeLayerIndex, 3);
      expect(original.activeLayerIndex, 0);
      expect(updated.clockPosition, original.clockPosition);
      expect(updated.modes, original.modes);
      expect(updated.pools, original.pools);
      expect(updated.selectedIds, original.selectedIds);
      expect(updated.frozen, original.frozen);
    });

    test('changing one field leaves every other field equal to the previous '
        'state', () {
      final original = _baseState();
      final updated = original.copyWith(
        modes: const [
          LayerMode.fixed,
          LayerMode.fixed,
          LayerMode.fixed,
          LayerMode.fixed,
        ],
      );

      expect(
        updated.modes,
        const [LayerMode.fixed, LayerMode.fixed, LayerMode.fixed, LayerMode.fixed],
      );
      expect(
        original.modes,
        const [
          LayerMode.dynamic,
          LayerMode.dynamic,
          LayerMode.dynamic,
          LayerMode.dynamic,
        ],
      );
      expect(updated.activeLayerIndex, original.activeLayerIndex);
      expect(updated.pools, original.pools);
      expect(updated.selectedIds, original.selectedIds);
      expect(updated.frozen, original.frozen);
      expect(updated.clockPosition, original.clockPosition);
    });

    test('with no arguments returns a distinct instance with equal values', () {
      final original = _baseState();
      final clone = original.copyWith();

      expect(identical(clone, original), isFalse);
      expect(clone.activeLayerIndex, original.activeLayerIndex);
      expect(clone.modes, original.modes);
      expect(clone.pools, original.pools);
      expect(clone.selectedIds, original.selectedIds);
      expect(clone.frozen, original.frozen);
      expect(clone.clockPosition, original.clockPosition);
    });

    test('produces unmodifiable lists, including the pools themselves', () {
      final updated = _baseState().copyWith(
        modes: const [
          LayerMode.fixed,
          LayerMode.fixed,
          LayerMode.fixed,
          LayerMode.fixed,
        ],
        pools: [
          <BackgroundItem>[
            BackgroundItem(id: 'bg_a', label: 'A', color: const Color(0xFF000000)),
          ],
          <PhraseItem>[PhraseItem(id: 'ph_a', label: 'A', text: 'a')],
          <CharacterItem>[CharacterItem(id: 'ch_a', label: 'A', bytes: _tinyPng())],
          <FontItem>[FontItem(id: 'fo_a', label: 'A', family: 'Roboto')],
        ],
      );

      expect(() => updated.modes.add(LayerMode.dynamic), throwsUnsupportedError);
      expect(() => updated.selectedIds.add('x'), throwsUnsupportedError);
      expect(() => updated.frozen.add(true), throwsUnsupportedError);
      expect(() => updated.pools.add(const []), throwsUnsupportedError);
      expect(
        () => updated.pools[0].add(
              BackgroundItem(id: 'bg_b', label: 'B', color: const Color(0xFFFFFFFF)),
            ),
        throwsUnsupportedError,
      );
    });
  });

  group('four-layer stack under copyWith (RE-CF-2)', () {
    test('every state carries four index-keyed layer stacks', () {
      final state = _baseState();

      expect(state.modes, hasLength(4));
      expect(state.pools, hasLength(4));
      expect(state.selectedIds, hasLength(4));
      expect(state.frozen, hasLength(4));
      expect(state.activeLayerIndex, inInclusiveRange(0, 3));
    });

    test('the stack count and order are immutable under any copyWith', () {
      final base = _baseState();
      final variants = <ConfiguratorState>[
        base.copyWith(activeLayerIndex: 3),
        base.copyWith(clockPosition: ClockPosition.bottomCenter),
        base.copyWith(
          modes: const [
            LayerMode.fixed,
            LayerMode.fixed,
            LayerMode.fixed,
            LayerMode.fixed,
          ],
        ),
        base.copyWith(frozen: const [true, false, false, true]),
        base.copyWith(selectedIds: const ['a', 'b', 'c', 'd']),
        base.copyWith(
          pools: [
            <BackgroundItem>[],
            <PhraseItem>[],
            <CharacterItem>[],
            <FontItem>[],
          ],
        ),
      ];

      for (final variant in variants) {
        expect(variant.modes, hasLength(_layerOrder.length));
        expect(variant.pools, hasLength(_layerOrder.length));
        expect(variant.selectedIds, hasLength(_layerOrder.length));
        expect(variant.frozen, hasLength(_layerOrder.length));
        expect(variant.activeLayerIndex, inInclusiveRange(0, 3));
      }
      expect(LayerType.values, _layerOrder);
    });

    test('activeLayerIndex maps into the fixed stack order', () {
      final phrase = _baseState().copyWith(activeLayerIndex: 1);
      final font = _baseState().copyWith(activeLayerIndex: 3);

      expect(LayerType.values[phrase.activeLayerIndex], LayerType.phrase);
      expect(LayerType.values[font.activeLayerIndex], LayerType.font);
    });
  });

  group('placeholder catalogs (RE-CF-5 / RE-CF-11)', () {
    test('every catalog holds placeholder items with unique ids and English '
        'labels', () {
      expect(kBackgroundCatalog, hasLength(greaterThan(0)));
      expect(kPhraseCatalog, hasLength(greaterThan(0)));
      expect(kCharacterCatalog, hasLength(greaterThan(0)));
      expect(kFontCatalog, hasLength(greaterThan(0)));

      for (final item in kBackgroundCatalog) {
        expect(item, isA<BackgroundItem>());
        expect(item.id, isNotEmpty);
        expect(item.label, isNotEmpty);
      }
      for (final item in kPhraseCatalog) {
        expect(item, isA<PhraseItem>());
        expect(item.id, isNotEmpty);
        expect(item.label, isNotEmpty);
      }
      for (final item in kCharacterCatalog) {
        expect(item, isA<CharacterItem>());
        expect(item.id, isNotEmpty);
        expect(item.label, isNotEmpty);
      }
      for (final item in kFontCatalog) {
        expect(item, isA<FontItem>());
        expect(item.id, isNotEmpty);
        expect(item.label, isNotEmpty);
      }

      final backgroundIds = kBackgroundCatalog.map((item) => item.id).toSet();
      final phraseIds = kPhraseCatalog.map((item) => item.id).toSet();
      final characterIds = kCharacterCatalog.map((item) => item.id).toSet();
      final fontIds = kFontCatalog.map((item) => item.id).toSet();
      expect(backgroundIds, hasLength(kBackgroundCatalog.length));
      expect(phraseIds, hasLength(kPhraseCatalog.length));
      expect(characterIds, hasLength(kCharacterCatalog.length));
      expect(fontIds, hasLength(kFontCatalog.length));
    });

    test('character placeholders carry real, non-empty PNG bytes', () {
      expect(kCharacterCatalog, hasLength(greaterThan(0)));

      for (final item in kCharacterCatalog) {
        final character = item as CharacterItem;
        expect(character.bytes, isNotEmpty);
        expect(character.bytes.sublist(0, 4), const [0x89, 0x50, 0x4e, 0x47]);
      }
    });

    test('default pools index the four placeholder catalogs', () {
      expect(kDefaultPools, hasLength(4));
      expect(kDefaultPools[0], same(kBackgroundCatalog));
      expect(kDefaultPools[1], same(kPhraseCatalog));
      expect(kDefaultPools[2], same(kCharacterCatalog));
      expect(kDefaultPools[3], same(kFontCatalog));
    });
  });
}
