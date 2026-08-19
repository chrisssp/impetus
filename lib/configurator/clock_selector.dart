// ClockControls — the four ClockPosition presets (design D2, RE-CF-8,
// tasks 6.1/6.3 + 4.6).
//
// A wrap of ChoiceChips, one per ClockPosition; the active preset is marked
// selected. Tapping a preset routes into
// ConfiguratorNotifier.setClockPosition, which only changes the render clock
// placement (RE-CF-8). The selector is a small ConsumerWidget that watches a
// narrow slice of state, so preset edits never rebuild the immersive shell.
//
// The controls live in [ClockControls] inside the immersive bottom sheet
// (D20, tasks 4.1-4.7). The old swipe-shell [ClockSelector] bottom-bar wrapper
// was removed in slice 6: the sheet is now the single control surface
// (RE-CF-12).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impetus/configurator/configurator_notifier.dart';
import 'package:impetus/models/render_config.dart';

/// The four clock placement presets (RE-CF-8).
class ClockControls extends ConsumerWidget {
  const ClockControls({super.key});

  /// English labels for the four presets (RE-CF-11).
  static const Map<ClockPosition, String> _labels = {
    ClockPosition.topCenter: 'Top center',
    ClockPosition.topLeft: 'Top left',
    ClockPosition.topRight: 'Top right',
    ClockPosition.bottomCenter: 'Bottom center',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(
      configuratorStateProvider.select((state) => state.clockPosition),
    );
    return Padding(
      key: const ValueKey('clock_presets'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final preset in ClockPosition.values)
            ChoiceChip(
              key: ValueKey('clock_preset_${preset.name}'),
              label: Text(_labels[preset]!),
              selected: selected == preset,
              onSelected: (_) => ref
                  .read(configuratorStateProvider.notifier)
                  .setClockPosition(preset),
            ),
        ],
      ),
    );
  }
}
