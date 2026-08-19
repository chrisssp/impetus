// LayerPage — the interaction surface for one stack layer (design D3/D9,
// RE-CF-4/5, tasks 6.1/6.5).
//
// Each swipe-shell page shows its layer's mode toggle (RE-CF-4), its catalog of
// addable placeholders and its pool of removable, selectable items (RE-CF-5).
//
// The toggle + catalog + pool body is extracted into [LayerControls] so the
// immersive bottom sheet reuses the exact same controls and stable keys
// (D20, tasks 4.1-4.7); [LayerPage] keeps only the shell-specific chrome
// (the layer title) until the shell is removed in a later slice. Blocked-layer
// presentation no longer lives here: the old _BlockedBanner + Opacity
// attenuation was replaced by the immersive [BlockedPill] overlay on the
// preview (D22, RE-CF-7, tasks 5.1-5.4).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impetus/configurator/catalog.dart';
import 'package:impetus/configurator/configurator_notifier.dart';
import 'package:impetus/configurator/layer_model.dart';

/// The swipe-shell page for [layerIndex] (a fixed index into [LayerType.values],
/// RE-CF-2).
class LayerPage extends ConsumerWidget {
  const LayerPage({super.key, required this.layerIndex});

  final int layerIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layer = LayerType.values[layerIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(layer.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              LayerControls(layerIndex: layerIndex),
            ],
          ),
        ),
      ],
    );
  }
}

/// The mode toggle, catalog chips and pool list for one layer (RE-CF-4/5,
/// design D3/D20). Shared by the swipe-shell [LayerPage] and the immersive
/// bottom sheet, so both surfaces expose the same stable control keys.
class LayerControls extends ConsumerWidget {
  const LayerControls({super.key, required this.layerIndex});

  final int layerIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(configuratorStateProvider);
    final notifier = ref.read(configuratorStateProvider.notifier);

    final layer = LayerType.values[layerIndex];
    final pool = state.pools[layerIndex];
    final selectedId = state.selectedIds[layerIndex];
    final fixed = state.modes[layerIndex] == LayerMode.fixed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: ValueKey('mode_toggle_$layerIndex'),
            onPressed: () => notifier.toggleMode(layerIndex),
            icon: Icon(fixed ? Icons.lock : Icons.autorenew),
            label: Text(fixed ? 'Mode: Fixed' : 'Mode: Dynamic'),
          ),
        ),
        const SizedBox(height: 8),
        Column(
          key: ValueKey('pool_management_$layerIndex'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Catalog', style: Theme.of(context).textTheme.labelLarge),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final item in _catalogFor(layer))
                  ActionChip(
                    key: ValueKey('catalog_add_${item.id}'),
                    label: Text(item.label),
                    onPressed: () => notifier.addToPool(layerIndex, item),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Pool', style: Theme.of(context).textTheme.labelLarge),
            for (final item in pool)
              ListTile(
                key: ValueKey('pool_item_${item.id}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  selectedId == item.id
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                ),
                title: Text(item.label),
                onTap: () => notifier.selectItem(layerIndex, item.id),
                trailing: IconButton(
                  key: ValueKey('pool_remove_${item.id}'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => notifier.removeFromPool(layerIndex, item.id),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The placeholder catalog shown for [layer] (design D3).
List<LayerItem> _catalogFor(LayerType layer) {
  switch (layer) {
    case LayerType.background:
      return kBackgroundCatalog;
    case LayerType.phrase:
      return kPhraseCatalog;
    case LayerType.character:
      return kCharacterCatalog;
    case LayerType.font:
      return kFontCatalog;
  }
}
