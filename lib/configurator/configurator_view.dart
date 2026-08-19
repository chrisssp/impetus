// ConfiguratorView — the swipe shell (design D5, RE-CF-3, tasks 6.2/6.6).
//
// A persistent PreviewPanel sits above a PageView with exactly one fixed page
// per stack layer ([LayerType.values], RE-CF-2). The PageController uses the
// default clamp physics, so the shell never wraps past the font layer.
// onPageChanged routes into ConfiguratorNotifier.setActiveLayer; navigation is
// render-irrelevant (D12) because previewConfigProvider excludes
// activeLayerIndex, so swiping never re-renders the preview (RE-CF-3).
//
// The view reads the notifier once instead of watching state, so the page
// controller and the current page survive every state change (mode toggles,
// pool edits, freezes) without being recreated.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impetus/configurator/clock_selector.dart';
import 'package:impetus/configurator/configurator_notifier.dart';
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 160, child: Center(child: PreviewPanel())),
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
