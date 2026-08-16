import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      home: const HomeShell(),
    );
  }
}

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spikeState = ref.watch(spikeStateProvider);
    return Scaffold(
      body: const Center(child: Text('Impetus')),
      floatingActionButton: FloatingActionButton(
        onPressed: spikeState == 0
            ? () => unawaited(_runSpike(ref, context))
            : null,
        tooltip: 'Wallpaper spike',
        child: const Icon(Icons.wallpaper),
      ),
    );
  }
}

Future<void> _runSpike(WidgetRef ref, BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  ref.read(spikeStateProvider.notifier).state = 1; // loading
  try {
    final success = await ref.read(wallpaperBridgeProvider.future);
    ref.read(spikeStateProvider.notifier).state = success ? 2 : 3;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Wallpaper set successfully' : 'Wallpaper set failed',
        ),
      ),
    );
  } on PlatformException catch (e) {
    ref.read(spikeStateProvider.notifier).state = 3;
    messenger.showSnackBar(SnackBar(content: Text('Spike failed: ${e.code}')));
  }
}
