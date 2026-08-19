// ConfiguratorView — the swipe shell (design D5, RE-CF-3, tasks 6.2/6.6) plus
// the item-cycle swipe surface (design D17/D18/D19, RE-CF-3, tasks 3.1-3.3).
//
// A persistent PreviewPanel sits above a PageView with exactly one fixed page
// per stack layer ([LayerType.values], RE-CF-2). The PageController uses the
// default clamp physics, so the shell never wraps past the font layer.
// onPageChanged routes into ConfiguratorNotifier.setActiveLayer; navigation is
// render-irrelevant (D12) because previewConfigProvider excludes
// activeLayerIndex, so swiping never re-renders the preview (RE-CF-3).
//
// The preview area is wrapped in ItemCycleGesture (Key('immersive_preview'),
// D17): a horizontal swipe there cycles the ACTIVE layer's item — left = next,
// right = previous (D18) — through ConfiguratorNotifier.cycleItem, wrapping at
// the pool edges. The gesture lives OUTSIDE the PageView subtree, so shell
// navigation is untouched. While the controls bottom sheet is open the
// [_sheetOpen] gate nulls the drag callback, disabling the swipe (D19); slice
// 4 raises and lowers the gate as the sheet opens and closes.
//
// The view reads the notifier once instead of watching state, so the page
// controller and the current page survive every state change (mode toggles,
// pool edits, freezes) without being recreated.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impetus/configurator/clock_selector.dart';
import 'package:impetus/configurator/configurator_notifier.dart';
import 'package:impetus/configurator/item_cycle_gesture.dart';
import 'package:impetus/configurator/layer_model.dart';
import 'package:impetus/configurator/layer_page.dart';
import 'package:impetus/configurator/preview_panel.dart';
import 'package:impetus/configurator/shuffle_bar.dart';

/// The four-layer configurator: persistent preview above the swipe shell.
class ConfiguratorView extends ConsumerStatefulWidget {
  const ConfiguratorView({super.key});

  @override
  ConsumerState<ConfiguratorView> createState() => _ConfiguratorViewState();
}

class _ConfiguratorViewState extends ConsumerState<ConfiguratorView> {
  late final PageController _pageController;

  /// Whether the controls bottom sheet is open (design D19). While true the
  /// item-cycle swipe on the preview is disabled (null callback), so a swipe
  /// over the open sheet's scrim never cycles the active item (RE-CF-3).
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Raises or lowers the sheet-open gate that disables the preview swipe.
  ///
  /// Slice 4 (FAB + immersive bottom sheet) calls this when the sheet opens
  /// and closes, so the swipe never fires while the sheet is up (D19).
  void setSheetOpen(bool open) {
    if (_sheetOpen == open) {
      return;
    }
    setState(() => _sheetOpen = open);
  }

  /// Cycles the active layer's item by [direction]: +1 for a left swipe (next
  /// pool item) or -1 for a right swipe (previous pool item) (design D18).
  void _onCycleItem(int direction) {
    final activeLayer = ref.read(configuratorStateProvider).activeLayerIndex;
    ref
        .read(configuratorStateProvider.notifier)
        .cycleItem(activeLayer, direction);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ItemCycleGesture(
          key: const Key('immersive_preview'),
          sheetOpen: _sheetOpen,
          onCycle: _onCycleItem,
          child: const SizedBox(
            height: 160,
            child: Center(child: PreviewPanel()),
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (page) => ref
                .read(configuratorStateProvider.notifier)
                .setActiveLayer(page),
            itemCount: LayerType.values.length,
            itemBuilder: (context, index) => LayerPage(layerIndex: index),
          ),
        ),
        const ShuffleBar(),
        const ClockSelector(),
      ],
    );
  }
}
