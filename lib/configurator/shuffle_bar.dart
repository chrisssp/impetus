// ShuffleBar — shuffle + freeze/unfreeze controls (RE-CF-6, design D6,
// tasks 6.1/6.4).
//
// Shuffle re-selects the current item of every dynamic, non-frozen layer from
// its pool (design D6). Freeze pins the ACTIVE layer — the one the user is
// looking at in the swipe shell — so the bar names that layer and flips its
// button between freeze and unfreeze. The bar watches the active layer's frozen
// flag so the button label always reflects the next action.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impetus/configurator/configurator_notifier.dart';
import 'package:impetus/configurator/layer_model.dart';

/// The bottom action bar: shuffle the dynamic layers, pin the active one.
class ShuffleBar extends ConsumerWidget {
  const ShuffleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(configuratorStateProvider);
    final activeLayerIndex = state.activeLayerIndex;
    final isFrozen = state.frozen[activeLayerIndex];
    final notifier = ref.read(configuratorStateProvider.notifier);
    final layerName = LayerType.values[activeLayerIndex].name;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilledButton.icon(
            key: const ValueKey('shuffle_button'),
            onPressed: notifier.shuffle,
            icon: const Icon(Icons.shuffle),
            label: const Text('Shuffle'),
          ),
          const Spacer(),
          Text('$layerName layer'),
          IconButton(
            key: const ValueKey('freeze_button'),
            tooltip: isFrozen ? 'Unfreeze layer' : 'Freeze layer',
            onPressed: isFrozen
                ? () => notifier.unfreeze(activeLayerIndex)
                : () => notifier.freeze(activeLayerIndex),
            icon: Icon(isFrozen ? Icons.lock : Icons.lock_open),
          ),
        ],
      ),
    );
  }
}
