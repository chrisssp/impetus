import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impetus/configurator/configurator_view.dart';
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
      // The configurator IS the app home (task 7.3, D27): it hosts its own
      // shell Scaffold and the 'Impetus' AppBar with the dev spike trigger,
      // so the whole body below the slim chrome is the live wallpaper.
      home: const ConfiguratorView(),
    );
  }
}
