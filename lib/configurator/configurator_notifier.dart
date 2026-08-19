// Configurator actions: the Riverpod notifier that mutates the immutable
// configurator state (design D1).
//
// Every action builds a new [ConfiguratorState] through [copyWith]; nothing is
// mutated in place (RE-CF-1). Fixed/dynamic mode and freeze are orthogonal
// (design D6): shuffle re-selects a layer iff it is dynamic and not frozen.
// Pool identity is by item id (RE-CF-5); removing the selected item falls back
// to the first remaining pool item or null (design D8).

import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:impetus/configurator/catalog.dart' show kDefaultPools;
import 'package:impetus/configurator/configurator_state.dart';
import 'package:impetus/configurator/layer_model.dart';
import 'package:impetus/models/render_config.dart' show ClockPosition;

/// Source of randomness for [ConfiguratorNotifier.shuffle].
///
/// Tests override it with a seeded [Random] for deterministic assertions
/// (design D7).
final randomProvider = Provider<Random>((_) => Random());

/// The app-lifetime configurator state provider (design D1).
final configuratorStateProvider =
    NotifierProvider<ConfiguratorNotifier, ConfiguratorState>(
      ConfiguratorNotifier.new,
    );

/// Mutations over the four-layer configurator state.
class ConfiguratorNotifier extends Notifier<ConfiguratorState> {
  @override
  ConfiguratorState build() {
    return ConfiguratorState(pools: kDefaultPools);
  }

  /// Selects the layer shown in the swipe shell, clamped to the fixed stack.
  void setActiveLayer(int index) {
    final clamped = index.clamp(0, LayerType.values.length - 1);
    state = state.copyWith(activeLayerIndex: clamped);
  }

  /// Flips a layer between [LayerMode.fixed] and [LayerMode.dynamic]
  /// (RE-CF-4). The mode survives navigation because it lives in the state.
  void toggleMode(int layer) {
    final modes = List<LayerMode>.from(state.modes);
    modes[layer] = modes[layer] == LayerMode.fixed
        ? LayerMode.dynamic
        : LayerMode.fixed;
    state = state.copyWith(modes: modes);
  }

  /// Adds an item to a layer pool, deduped by id (RE-CF-5).
  void addToPool(int layer, LayerItem item) {
    if (state.pools[layer].any((existing) => existing.id == item.id)) {
      return;
    }
    final pools = List<List<LayerItem>>.from(state.pools);
    pools[layer] = List<LayerItem>.from(state.pools[layer])..add(item);
    state = state.copyWith(pools: pools);
  }

  /// Removes an item from a layer pool by id (RE-CF-5).
  ///
  /// If the currently selected item is removed, the selection falls back to
  /// the pool's first remaining item, or to null when the pool is empty
  /// (design D8).
  void removeFromPool(int layer, String id) {
    final pools = List<List<LayerItem>>.from(state.pools);
    pools[layer] = List<LayerItem>.from(state.pools[layer])
      ..removeWhere((item) => item.id == id);

    var selectedIds = List<String?>.from(state.selectedIds);
    if (selectedIds[layer] == id) {
      selectedIds[layer] = pools[layer].isEmpty ? null : pools[layer].first.id;
    }

    state = state.copyWith(pools: pools, selectedIds: selectedIds);
  }

  /// Pins a layer's selection to the given pool item id.
  void selectItem(int layer, String id) {
    final selectedIds = List<String?>.from(state.selectedIds);
    selectedIds[layer] = id;
    state = state.copyWith(selectedIds: selectedIds);
  }

  /// Re-selects the current item of every dynamic, non-frozen layer from its
  /// pool (RE-CF-6, design D6). Fixed and frozen layers keep their selection.
  void shuffle() {
    final rng = ref.read(randomProvider);
    final selectedIds = List<String?>.from(state.selectedIds);
    for (var i = 0; i < state.pools.length; i++) {
      final pool = state.pools[i];
      if (state.modes[i] == LayerMode.dynamic &&
          !state.frozen[i] &&
          pool.isNotEmpty) {
        selectedIds[i] = pool[rng.nextInt(pool.length)].id;
      }
    }
    state = state.copyWith(selectedIds: selectedIds);
  }

  /// Pins a layer's current item so shuffle skips it (RE-CF-6).
  void freeze(int layer) {
    final frozen = List<bool>.from(state.frozen);
    frozen[layer] = true;
    state = state.copyWith(frozen: frozen);
  }

  /// Restores a layer's shuffle participation (RE-CF-6).
  void unfreeze(int layer) {
    final frozen = List<bool>.from(state.frozen);
    frozen[layer] = false;
    state = state.copyWith(frozen: frozen);
  }

  /// Selects a clock placement preset (RE-CF-8).
  void setClockPosition(ClockPosition preset) {
    state = state.copyWith(clockPosition: preset);
  }
}
