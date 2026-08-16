// Immutable configurator state (design D1).
//
// The state is a value object: every field is final, the constructor is const
// when the lists are const, and [copyWith] always returns a new instance with
// all list fields wrapped in unmodifiable views (RE-CF-1, RE-CF-2).

import 'package:flutter/foundation.dart';

import 'package:impetus/configurator/layer_model.dart';
import 'package:impetus/models/render_config.dart' show ClockPosition;

/// The full, immutable state of the configurator.
///
/// All four layer stack fields are parallel lists indexed by
/// [LayerType.values]. The stacks never change order, count or layer kinds
/// (RE-CF-2); only the payloads (mode, pool, selection, frozen flag) evolve,
/// always through [copyWith].
class ConfiguratorState {
  const ConfiguratorState({
    this.activeLayerIndex = 0,
    this.modes = const [
      LayerMode.dynamic,
      LayerMode.dynamic,
      LayerMode.dynamic,
      LayerMode.dynamic,
    ],
    this.pools = const [],
    this.selectedIds = const [null, null, null, null],
    this.frozen = const [false, false, false, false],
    this.clockPosition = ClockPosition.topCenter,
  }) : assert(
         activeLayerIndex >= 0 && activeLayerIndex < LayerType.values.length,
       ),
       assert(modes.length == LayerType.values.length),
       assert(pools.length == LayerType.values.length),
       assert(selectedIds.length == LayerType.values.length),
       assert(frozen.length == LayerType.values.length);

  /// Index of the layer currently selected in the UI.
  ///
  /// Always a valid index into [LayerType.values] (assert-enforced).
  final int activeLayerIndex;

  /// Per-layer shuffle mode, indexed by [LayerType.values].
  final List<LayerMode> modes;

  /// Per-layer item pools, indexed by [LayerType.values].
  final List<List<LayerItem>> pools;

  /// Per-layer selected item id (or null when nothing is selected).
  final List<String?> selectedIds;

  /// Per-layer frozen flag (a pinned layer is excluded from shuffle).
  final List<bool> frozen;

  /// Clock placement for the rendered wallpapers (RE-CF-12).
  final ClockPosition clockPosition;

  /// Returns a new state with every provided field replaced.
  ///
  /// All list fields on the result are unmodifiable views, including the inner
  /// pools. The receiver is never mutated (RE-CF-1).
  ConfiguratorState copyWith({
    int? activeLayerIndex,
    List<LayerMode>? modes,
    List<List<LayerItem>>? pools,
    List<String?>? selectedIds,
    List<bool>? frozen,
    ClockPosition? clockPosition,
  }) {
    return ConfiguratorState(
      activeLayerIndex: activeLayerIndex ?? this.activeLayerIndex,
      modes: List<LayerMode>.unmodifiable(modes ?? this.modes),
      pools: pools != null
          ? List<List<LayerItem>>.unmodifiable(
              pools.map((pool) => List<LayerItem>.unmodifiable(pool)),
            )
          : List<List<LayerItem>>.unmodifiable(
              this.pools.map((pool) => List<LayerItem>.unmodifiable(pool)),
            ),
      selectedIds: List<String?>.unmodifiable(selectedIds ?? this.selectedIds),
      frozen: List<bool>.unmodifiable(frozen ?? this.frozen),
      clockPosition: clockPosition ?? this.clockPosition,
    );
  }

  @override
  String toString() {
    return 'ConfiguratorState('
        'activeLayerIndex: $activeLayerIndex, '
        'modes: $modes, '
        'pools: $pools, '
        'selectedIds: $selectedIds, '
        'frozen: $frozen, '
        'clockPosition: $clockPosition)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ConfiguratorState &&
        other.activeLayerIndex == activeLayerIndex &&
        listEquals(other.modes, modes) &&
        _poolsEquals(other.pools, pools) &&
        listEquals(other.selectedIds, selectedIds) &&
        listEquals(other.frozen, frozen) &&
        other.clockPosition == clockPosition;
  }

  @override
  int get hashCode {
    return Object.hash(
      activeLayerIndex,
      Object.hashAll(modes),
      Object.hashAll(pools),
      Object.hashAll(selectedIds),
      Object.hashAll(frozen),
      clockPosition,
    );
  }
}

bool _poolsEquals(List<List<LayerItem>> a, List<List<LayerItem>> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (!listEquals(a[i], b[i])) {
      return false;
    }
  }
  return true;
}
