// Tests for the configurator state foundation and notifier actions.
//
// Strict TDD (openspec/config.yaml apply.tdd: true): Part A is the RED test
// for Phase 1 tasks 1.1-1.5, Part B for Phase 2 tasks 2.1-2.2. Coverage:
//   - RE-CF-1: copyWith yields a new instance and leaves the previous state
//     unchanged.
//   - RE-CF-2: exactly four layers in fixed order background -> phrase ->
//     character -> font, and the order is immutable under any copyWith.
//   - RE-CF-5 / RE-CF-11: placeholder catalogs and default pools (foundation).
//   - RE-CF-4/5/6/8 (Part B): ConfiguratorNotifier actions via
//     ProviderContainer, no widget tree. shuffle determinism uses a seeded
//     randomProvider override (design D7).

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/configurator/catalog.dart';
import 'package:impetus/configurator/configurator_notifier.dart';
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
Uint8List _tinyPng() =>
    Uint8List.fromList(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

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

      expect(updated.modes, const [
        LayerMode.fixed,
        LayerMode.fixed,
        LayerMode.fixed,
        LayerMode.fixed,
      ]);
      expect(original.modes, const [
        LayerMode.dynamic,
        LayerMode.dynamic,
        LayerMode.dynamic,
        LayerMode.dynamic,
      ]);
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
            BackgroundItem(
              id: 'bg_a',
              label: 'A',
              color: const Color(0xFF000000),
            ),
          ],
          <PhraseItem>[PhraseItem(id: 'ph_a', label: 'A', text: 'a')],
          <CharacterItem>[
            CharacterItem(id: 'ch_a', label: 'A', bytes: _tinyPng()),
          ],
          <FontItem>[FontItem(id: 'fo_a', label: 'A', family: 'Roboto')],
        ],
      );

      expect(
        () => updated.modes.add(LayerMode.dynamic),
        throwsUnsupportedError,
      );
      expect(() => updated.selectedIds.add('x'), throwsUnsupportedError);
      expect(() => updated.frozen.add(true), throwsUnsupportedError);
      expect(() => updated.pools.add(const []), throwsUnsupportedError);
      expect(
        () => updated.pools[0].add(
          BackgroundItem(
            id: 'bg_b',
            label: 'B',
            color: const Color(0xFFFFFFFF),
          ),
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

      for (final character in kCharacterCatalog) {
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

  group('ConfiguratorNotifier (RE-CF-4/5/6/8)', () {
    /// A [ProviderContainer] with the notifier wired and, when [seed] is
    /// given, [randomProvider] overridden with a seeded [Random] (design D7).
    ProviderContainer _container({int? seed}) {
      final container = ProviderContainer(
        overrides: [
          if (seed != null) randomProvider.overrideWithValue(Random(seed)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('setActiveLayer clamps out-of-range indexes to the stack edges', () {
      final container = _container();
      final notifier =
          container.read(configuratorStateProvider.notifier);

      notifier.setActiveLayer(-1);
      expect(
        container.read(configuratorStateProvider).activeLayerIndex,
        0,
      );
      notifier.setActiveLayer(99);
      expect(
        container.read(configuratorStateProvider).activeLayerIndex,
        3,
      );
      notifier.setActiveLayer(2);
      expect(
        container.read(configuratorStateProvider).activeLayerIndex,
        2,
      );
    });

    test('toggleMode flips a layer between fixed and dynamic (RE-CF-4)', () {
      final container = _container();
      final notifier =
          container.read(configuratorStateProvider.notifier);

      expect(
        container.read(configuratorStateProvider).modes[0],
        LayerMode.dynamic,
      );
      notifier.toggleMode(0);
      expect(
        container.read(configuratorStateProvider).modes[0],
        LayerMode.fixed,
      );
      notifier.toggleMode(0);
      expect(
        container.read(configuratorStateProvider).modes[0],
        LayerMode.dynamic,
      );
    });

    test('toggleMode survives setActiveLayer navigation (RE-CF-4)', () {
      final container = _container();
      final notifier =
          container.read(configuratorStateProvider.notifier);

      notifier.toggleMode(1);
      notifier.setActiveLayer(3);
      notifier.setActiveLayer(1);

      final state = container.read(configuratorStateProvider);
      expect(state.modes[1], LayerMode.fixed);
      expect(state.activeLayerIndex, 1);
    });

    test('addToPool dedupes by id so an item appears exactly once (RE-CF-5)',
        () {
      final container = _container();
      final notifier =
          container.read(configuratorStateProvider.notifier);
      const nova = BackgroundItem(
        id: 'bg_nova',
        label: 'Nova',
        color: Color(0xFF000000),
      );

      notifier.addToPool(0, nova);
      notifier.addToPool(0, nova);

      final ids = container
          .read(configuratorStateProvider)
          .pools[0]
          .map((item) => item.id)
          .toList();
      expect(ids.where((id) => id == nova.id), hasLength(1));
    });

    test('removeFromPool falls back to the first remaining item or null '
        '(RE-CF-5, D8)', () {
      final container = _container();
      final notifier =
          container.read(configuratorStateProvider.notifier);

      notifier.selectItem(0, 'bg_navy');
      notifier.removeFromPool(0, 'bg_navy');
      expect(
        container.read(configuratorStateProvider).selectedIds[0],
        'bg_midnight',
      );

      notifier.removeFromPool(0, 'bg_midnight');
      expect(
        container.read(configuratorStateProvider).selectedIds[0],
        'bg_forest',
      );

      notifier.removeFromPool(0, 'bg_forest');
      final state = container.read(configuratorStateProvider);
      expect(state.pools[0], isEmpty);
      expect(state.selectedIds[0], isNull);
    });

    test('removeFromPool of a non-selected item keeps the selection '
        '(RE-CF-5, D8)', () {
      final container = _container();
      final notifier =
          container.read(configuratorStateProvider.notifier);

      notifier.selectItem(0, 'bg_navy');
      notifier.removeFromPool(0, 'bg_midnight');

      expect(
        container.read(configuratorStateProvider).selectedIds[0],
        'bg_navy',
      );
    });

    test('shuffle re-selects only dynamic, non-frozen layers (RE-CF-6, '
        'seeded D7)', () {
      final container = _container(seed: 3);
      final notifier =
          container.read(configuratorStateProvider.notifier);

      notifier.selectItem(0, 'bg_navy');
      notifier.toggleMode(1); // phrase -> fixed
      notifier.selectItem(1, 'ph_strength');
      notifier.freeze(2); // character frozen (still dynamic)
      notifier.selectItem(2, 'ch_alpha');
      notifier.selectItem(3, 'fo_roboto');

      notifier.shuffle();

      final state = container.read(configuratorStateProvider);
      expect(state.selectedIds[0], 'bg_midnight'); // nextInt(3) == 1
      expect(state.selectedIds[1], 'ph_strength'); // fixed, unchanged
      expect(state.selectedIds[2], 'ch_alpha'); // frozen, unchanged
      expect(state.selectedIds[3], 'fo_roboto_mono'); // nextInt(2) == 1
    });

    test('freeze pins the selection across shuffle; unfreeze restores '
        'participation (RE-CF-6)', () {
      final container = _container(seed: 3);
      final notifier =
          container.read(configuratorStateProvider.notifier);

      notifier.toggleMode(1);
      notifier.toggleMode(2);
      notifier.toggleMode(3);
      notifier.selectItem(0, 'bg_navy');

      notifier.freeze(0);
      expect(container.read(configuratorStateProvider).frozen[0], isTrue);
      notifier.shuffle(); // frozen layer consumes no draw
      expect(
        container.read(configuratorStateProvider).selectedIds[0],
        'bg_navy',
      );

      notifier.unfreeze(0);
      expect(container.read(configuratorStateProvider).frozen[0], isFalse);
      notifier.shuffle(); // first draw on the seeded Random -> index 1
      expect(
        container.read(configuratorStateProvider).selectedIds[0],
        'bg_midnight',
      );
    });

    test('setClockPosition accepts all four presets (RE-CF-8)', () {
      final container = _container();
      final notifier =
          container.read(configuratorStateProvider.notifier);

      expect(ClockPosition.values, hasLength(4));
      for (final preset in ClockPosition.values) {
        notifier.setClockPosition(preset);
        expect(
          container.read(configuratorStateProvider).clockPosition,
          preset,
        );
      }
    });
  });
}
