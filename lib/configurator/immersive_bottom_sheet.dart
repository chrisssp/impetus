// ImmersiveBottomSheet — the FAB-opened controls sheet (design D20/D21,
// RE-CF-12, tasks 4.1-4.7).
//
// The sheet centralizes every configurator control: the layer selector
// (SegmentedButton, D21), the active layer's mode toggle + pool management
// (LayerControls), shuffle/freeze (ShuffleControls) and the clock presets
// (ClockControls). It is presented through showModalBottomSheet — dismissible
// by dragging the sheet down or tapping outside (RE-CF-12) — with a
// transparent sheet background and a DraggableScrollableSheet body, so the
// modal barrier reads as a subtle scrim behind the rounded panel (D20).
//
// The sheet and the swipe shell share the same stable control keys
// (mode_toggle_*, shuffle_button, clock_preset_*, ...); tests scope finders to
// [kImmersiveSheetKey] to tell them apart while the shell is still in the
// tree (the shell is removed in a later slice).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impetus/configurator/clock_selector.dart';
import 'package:impetus/configurator/configurator_notifier.dart';
import 'package:impetus/configurator/layer_model.dart';
import 'package:impetus/configurator/layer_page.dart';
import 'package:impetus/configurator/shuffle_bar.dart';

/// Key on the sheet's root container; tests scope sheet finders to it while
/// the swipe shell renders the same control keys behind the modal.
const Key kImmersiveSheetKey = Key('immersive_sheet');

/// Key on the drag handle at the top of the sheet. The modal sheet's own drag
/// gesture dismisses the sheet when the handle is dragged down (RE-CF-12).
const Key kSheetDragHandleKey = ValueKey('sheet_drag_handle');

/// All configurator controls, centralized in a dismissible bottom sheet.
class ImmersiveBottomSheet extends ConsumerWidget {
  const ImmersiveBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeLayer = ref.watch(
      configuratorStateProvider.select((state) => state.activeLayerIndex),
    );
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Material(
          key: kImmersiveSheetKey,
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const _DragHandle(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<int>(
                        key: const ValueKey('layer_selector'),
                        segments: [
                          for (var i = 0; i < LayerType.values.length; i++)
                            ButtonSegment(
                              value: i,
                              label: Text(LayerType.values[i].name),
                            ),
                        ],
                        selected: {activeLayer},
                        onSelectionChanged: (selection) => ref
                            .read(configuratorStateProvider.notifier)
                            .setActiveLayer(selection.first),
                      ),
                      const SizedBox(height: 16),
                      LayerControls(layerIndex: activeLayer),
                      const Divider(height: 32),
                      const ShuffleControls(),
                      const Divider(height: 32),
                      const ClockControls(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The grab handle at the top of the sheet. Dragging it down dismisses the
/// sheet through the modal's own drag gesture (RE-CF-12).
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: kSheetDragHandleKey,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
