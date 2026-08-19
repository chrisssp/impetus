// ShuffleControls — shuffle + freeze/unfreeze controls (RE-CF-6, design D6,
// tasks 6.1/6.4 + 4.5).
//
// Shuffle re-selects the current item of every dynamic, non-frozen layer from
// its pool (design D6). Freeze pins the ACTIVE layer — the one the user is
// looking at — so the controls name that layer and flip its button between
// freeze and unfreeze. The controls watch the active layer's frozen flag so
// the button label always reflects the next action.
//
// The controls live in [ShuffleControls] inside the immersive bottom sheet
// (D20, tasks 4.1-4.7). The old swipe-shell [ShuffleBar] bottom-bar wrapper
// was removed in slice 6: the sheet is now the single control surface
// (RE-CF-12).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impetus/configurator/configurator_notifier.dart';
import 'package:impetus/configurator/layer_model.dart';

/// Shuffle + freeze/unfreeze controls for the active layer (RE-CF-6, D6).
class ShuffleControls extends ConsumerWidget {
  const ShuffleControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(configuratorStateProvider);
    final activeLayerIndex = state.activeLayerIndex;
    final isFrozen = state.frozen[activeLayerIndex];
    final notifier = ref.read(configuratorStateProvider.notifier);
    final layerName = LayerType.values[activeLayerIndex].name;

    return Padding(
      key: const ValueKey('shuffle_controls'),
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
