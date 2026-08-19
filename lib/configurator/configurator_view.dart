// ConfiguratorView — the immersive shell (design D5/D16/D17/D19/D20/D23/D27,
// RE-CF-3/7/9/12, tasks 3.1-3.3 + 4.1-4.7 + 5.1-5.4 + 6.1-6.3 + 7.1-7.3).
//
// The view IS the app home (task 7.3): it hosts the shell Scaffold and the
// slim 'Impetus' AppBar (the minimal chrome kept for the title, D27) with the
// kDebugMode-only dev spike trigger (RE-AS-3) in its actions. Below that
// chrome, the whole app body IS the live wallpaper: the body is a Stack whose
// only non-positioned child — the item-cycle swipe surface wrapping
// PreviewPanel — fills the body via StackFit.expand (D23, RE-CF-9). The
// controls FAB (Key('controls_fab'), D27) floats over the preview and opens
// the immersive bottom sheet ([_openControlsSheet], D20). The blocked-layer
// suggestion pill (BlockedPill, D22) overlays the top of the preview and
// ignores pointer events, so the item-cycle swipe passes through it (RE-CF-7).
//
// Device-adaptive canvas (D16, RE-CF-9): a LayoutBuilder measures the body and
// a nested ProviderScope overrides previewSizeProvider with those constraints,
// so previewConfigProvider re-derives the RenderConfig at the device's aspect
// ratio. The nested scope inherits every other provider from its parent, so
// the configurator state and the preview pipeline are shared with the bottom
// sheet (which lives in the navigator overlay, outside this scope). Tests and
// goldens keep the 540x960 pin (D25) by pumping PreviewPanel directly or by
// overriding previewSizeProvider higher in the tree; the widget-level device
// tests observe the override through the recorded renderer configs.
//
// The old PageView shell, ShuffleBar and ClockSelector bars are gone (slice 6):
// layer selection happens in the sheet's SegmentedButton (RE-CF-3) and every
// control key now exists exactly once, inside the sheet (RE-CF-12).
//
// The view reads the notifier once instead of watching state, so the preview
// and the overlays survive every state change (mode toggles, pool edits,
// freezes) without being recreated.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impetus/configurator/blocked_pill.dart';
import 'package:impetus/configurator/configurator_notifier.dart';
import 'package:impetus/configurator/immersive_bottom_sheet.dart';
import 'package:impetus/configurator/item_cycle_gesture.dart';
import 'package:impetus/configurator/preview_panel.dart';
import 'package:impetus/configurator/preview_provider.dart';
import 'package:impetus/configurator/spike_dev_trigger.dart';

/// The four-layer configurator: the app home whose body is the live wallpaper
/// preview, with the slim shell AppBar, the overlay controls FAB and the
/// blocked-layer pill on top.
class ConfiguratorView extends ConsumerStatefulWidget {
  const ConfiguratorView({super.key});

  @override
  ConsumerState<ConfiguratorView> createState() => _ConfiguratorViewState();
}

class _ConfiguratorViewState extends ConsumerState<ConfiguratorView> {
  /// Whether the controls bottom sheet is open (design D19). While true the
  /// item-cycle swipe on the preview is disabled (null callback), so a swipe
  /// over the open sheet's scrim never cycles the active item (RE-CF-3).
  bool _sheetOpen = false;

  /// Raises or lowers the sheet-open gate that disables the preview swipe
  /// (design D19, RE-CF-3).
  void setSheetOpen(bool open) {
    if (_sheetOpen == open) {
      return;
    }
    setState(() => _sheetOpen = open);
  }

  /// Opens the controls bottom sheet and raises the sheet-open gate for the
  /// duration of the modal (design D19/D20/D27, RE-CF-12).
  ///
  /// The gate is raised BEFORE the sheet animates in, so a swipe during the
  /// transition never cycles an item, and lowered when the modal route is
  /// popped (drag down, scrim tap or back) so the preview swipe works again.
  Future<void> _openControlsSheet() async {
    setSheetOpen(true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black26,
      builder: (_) => const ImmersiveBottomSheet(),
    );
    if (mounted) {
      setSheetOpen(false);
    }
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
    return Scaffold(
      // The slim shell chrome kept over the full-bleed preview (D27): the
      // title plus the kDebugMode-only dev spike trigger (RE-AS-3).
      appBar: AppBar(
        title: const Text('Impetus'),
        actions: const [SpikeDevTrigger()],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // The render canvas follows the device body (D16): every layout
          // change re-derives previewConfigProvider, which re-renders through
          // the debounced pipeline (D12). constraints.biggest is finite here —
          // the view fills a Scaffold body; unbounded parents are not
          // supported.
          return ProviderScope(
            overrides: [
              previewSizeProvider.overrideWithValue(constraints.biggest),
            ],
            child: Stack(
              fit: StackFit.expand,
              children: [
                ItemCycleGesture(
                  key: const Key('immersive_preview'),
                  sheetOpen: _sheetOpen,
                  onCycle: _onCycleItem,
                  child: const PreviewPanel(),
                ),
                // The controls FAB floats over the preview (D27) and is
                // hidden while the sheet is open — the sheet owns the
                // interaction surface.
                if (!_sheetOpen)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      key: const ValueKey('controls_fab'),
                      onPressed: _openControlsSheet,
                      tooltip: 'Controls',
                      child: const Icon(Icons.tune),
                    ),
                  ),
                // The blocked-layer suggestion pill (D22, RE-CF-7). Always
                // mounted: it overlays the preview and never intercepts
                // pointer events, so the item-cycle swipe passes through it.
                const BlockedPill(),
              ],
            ),
          );
        },
      ),
    );
  }
}
