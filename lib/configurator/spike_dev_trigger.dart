// Dev-only spike trigger for the wallpaper bridge (app-shell spec RE-AS-3,
// design D14). Rendered into the app bar actions on debug builds only; a
// no-op in release builds.
//
// The providers it drives — spikeStateProvider and wallpaperBridgeProvider —
// live in main.dart and are kept intact. The trigger is one-shot: once the
// spike has run it disables itself until the app restarts.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:impetus/main.dart';

class SpikeDevTrigger extends ConsumerWidget {
  const SpikeDevTrigger({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    final spikeState = ref.watch(spikeStateProvider);
    return IconButton(
      tooltip: 'Wallpaper spike',
      icon: const Icon(Icons.wallpaper),
      onPressed: spikeState == 0
          ? () => unawaited(_runSpike(ref, context))
          : null,
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
