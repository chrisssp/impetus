// Tests for the ConfiguratorNotifier.cycleItem action (design D18/D24,
// RE-CF-3, tasks 2.1-2.3).
//
// Strict TDD: this file is the RED test for Phase 2 (PR 2 of the
// immersive-shell chain). Coverage:
//   - +1 advances the selection to the next pool item; -1 retreats to the
//     previous item, wrapping modulo the pool length at both edges (RE-CF-3).
//   - An empty pool is a no-op; a single-item pool stays on that item.
//   - The action goes through the immutable state flow: only the target
//     layer's selection changes, everything else persists.
//   - The preview config derived from the state reflects the cycled selection
//     (RE-CF-3: the preview updates immediately on item cycle).
//   - Direction sign convention (D18): +1 is next (left swipe, velocity < 0),
//     -1 is previous (right swipe, velocity > 0). The velocity-to-sign mapping
//     itself is exercised by the Phase 3 widget tests.
//
// Deterministic by design (no randomProvider needed): cycleItem only does
// modulo arithmetic over the seeded pool.

import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/configurator/catalog.dart';
import 'package:impetus/configurator/configurator_notifier.dart';
import 'package:impetus/configurator/preview_provider.dart';

/// A [ProviderContainer] with the notifier wired and disposed on teardown.
ProviderContainer _container() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('cycleItem advances (direction +1)', () {
    test('moves the selection to the next pool item', () {
      final container = _container();
      final notifier = container.read(configuratorStateProvider.notifier);

      notifier.selectItem(0, 'bg_navy');
      notifier.cycleItem(0, 1);

      expect(
        container.read(configuratorStateProvider).selectedIds[0],
        'bg_midnight',
      );
    });

    test('treats an unselected layer as positioned at the first item and '
        'steps from there (D24)', () {
      final container = _container();
      final notifier = container.read(configuratorStateProvider.notifier);

      // Nothing selected: the preview resolves pool.first as current, so the
      // first step lands on the second item.
      notifier.cycleItem(0, 1);
      expect(
        container.read(configuratorStateProvider).selectedIds[0],
        'bg_midnight',
      );

      final backwards = _container();
      final backwardsNotifier = backwards.read(
        configuratorStateProvider.notifier,
      );
      backwardsNotifier.cycleItem(0, -1);
      // Backwards from the first position wraps to the last item (D18).
      expect(
        backwards.read(configuratorStateProvider).selectedIds[0],
        'bg_forest',
      );
    });
  });

  group('cycleItem retreats (direction -1)', () {
    test('moves the selection to the previous pool item', () {
      final container = _container();
      final notifier = container.read(configuratorStateProvider.notifier);

      notifier.selectItem(0, 'bg_midnight');
      notifier.cycleItem(0, -1);

      expect(
        container.read(configuratorStateProvider).selectedIds[0],
        'bg_navy',
      );
    });
  });

  group('cycleItem wraps at pool edges', () {
    test('last item +1 wraps to the first item', () {
      final container = _container();
      final notifier = container.read(configuratorStateProvider.notifier);

      notifier.selectItem(0, 'bg_forest');
      notifier.cycleItem(0, 1);

      expect(
        container.read(configuratorStateProvider).selectedIds[0],
        'bg_navy',
      );
    });

    test('first item -1 wraps to the last item', () {
      final container = _container();
      final notifier = container.read(configuratorStateProvider.notifier);

      notifier.selectItem(0, 'bg_navy');
      notifier.cycleItem(0, -1);

      expect(
        container.read(configuratorStateProvider).selectedIds[0],
        'bg_forest',
      );
    });
  });

  group('cycleItem edge cases', () {
    test('empty pool is a no-op for both directions', () {
      final container = _container();
      final notifier = container.read(configuratorStateProvider.notifier);

      // Empty the background pool through real actions: the selection falls
      // back to null and the pool becomes empty (design D8).
      notifier.removeFromPool(0, 'bg_navy');
      notifier.removeFromPool(0, 'bg_midnight');
      notifier.removeFromPool(0, 'bg_forest');
      final before = container.read(configuratorStateProvider);

      notifier.cycleItem(0, 1);
      notifier.cycleItem(0, -1);

      final after = container.read(configuratorStateProvider);
      expect(after, before);
      expect(after.pools[0], isEmpty);
      expect(after.selectedIds[0], isNull);
    });

    test('single-item pool stays on that item for both directions', () {
      final container = _container();
      final notifier = container.read(configuratorStateProvider.notifier);

      notifier.selectItem(0, 'bg_navy');
      notifier.removeFromPool(0, 'bg_midnight');
      notifier.removeFromPool(0, 'bg_forest');

      notifier.cycleItem(0, 1);
      expect(
        container.read(configuratorStateProvider).selectedIds[0],
        'bg_navy',
      );
      notifier.cycleItem(0, -1);
      expect(
        container.read(configuratorStateProvider).selectedIds[0],
        'bg_navy',
      );
    });
  });

  group('cycleItem participates in the state flow', () {
    test(
      'changes only the target layer selection; everything else persists',
      () {
        final container = _container();
        final notifier = container.read(configuratorStateProvider.notifier);

        notifier.setActiveLayer(3);
        notifier.toggleMode(1); // phrase -> fixed
        notifier.freeze(2);
        notifier.selectItem(1, 'ph_strength');
        notifier.selectItem(2, 'ch_alpha');
        notifier.selectItem(3, 'fo_roboto');
        final before = container.read(configuratorStateProvider);

        notifier.cycleItem(0, 1);

        final after = container.read(configuratorStateProvider);
        expect(after.selectedIds[0], 'bg_midnight');
        expect(after.selectedIds[1], 'ph_strength');
        expect(after.selectedIds[2], 'ch_alpha');
        expect(after.selectedIds[3], 'fo_roboto');
        expect(after.pools, before.pools);
        expect(after.modes, before.modes);
        expect(after.frozen, before.frozen);
        expect(after.activeLayerIndex, before.activeLayerIndex);
        expect(after.clockPosition, before.clockPosition);
      },
    );

    test('preview config reflects the cycled selection (RE-CF-3)', () {
      final container = _container();
      final notifier = container.read(configuratorStateProvider.notifier);

      // Nothing selected yet: the preview resolves the first phrase.
      expect(
        container.read(previewConfigProvider).quoteText,
        kPhraseCatalog[0].text,
      );

      notifier.cycleItem(1, 1);
      expect(
        container.read(previewConfigProvider).quoteText,
        kPhraseCatalog[1].text,
      );

      notifier.cycleItem(1, -1);
      expect(
        container.read(previewConfigProvider).quoteText,
        kPhraseCatalog[0].text,
      );
    });
  });

  group('cycleItem direction semantics (D18)', () {
    test('+1 is next and -1 is previous from the same selection', () {
      final container = _container();
      final notifier = container.read(configuratorStateProvider.notifier);

      notifier.selectItem(1, 'ph_strength'); // phrase index 0

      notifier.cycleItem(1, 1);
      expect(
        container.read(configuratorStateProvider).selectedIds[1],
        'ph_consistency',
      );

      notifier.selectItem(1, 'ph_strength');
      notifier.cycleItem(1, -1);
      // Backwards from the first item wraps to the last (D18).
      expect(
        container.read(configuratorStateProvider).selectedIds[1],
        'ph_discipline',
      );
    });
  });
}
