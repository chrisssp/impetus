import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impetus/configurator/configurator_view.dart';
import 'package:impetus/configurator/spike_dev_trigger.dart';
import 'package:impetus/services/wallpaper_bridge.dart';

/// Spike trigger state machine.
///
/// 0 = idle, 1 = loading, 2 = success, 3 = error.
final spikeStateProvider = StateProvider<int>((ref) => 0);

/// Runs the wallpaper spike by sending the deterministic test PNG through
/// the platform bridge. One-shot: the cached future is never re-evaluated.
final wallpaperBridgeProvider = FutureProvider<bool>(
  (ref) => WallpaperBridge.setBitmap(kSpikePngBytes),
);

void main() {
  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Impetus'),
          actions: const [SpikeDevTrigger()],
        ),
        body: const ConfiguratorView(),
      ),
    );
  }
}
