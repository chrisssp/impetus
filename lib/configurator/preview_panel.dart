// PreviewPanel — the WYSIWYG preview surface (design D13, RE-CF-9,
// tasks 5.1/5.2).
//
// The panel watches previewProvider and blits the latest rendered PNG onto an
// Image.memory. gaplessPlayback keeps the previous frame visible while the next
// render lands, so bursty edits never flash white; RepaintBoundary isolates the
// rasterized image from the rest of the tree; and a fixed 9:16 aspect ratio
// keeps the layout stable while the image loads.
//
// While the preview is loading or errored the panel shows a static placeholder
// box instead of an image — a blocked or failed render must never crash the
// panel (RE-CF-7).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impetus/configurator/preview_provider.dart';

/// Key on the static placeholder box so tests can assert the fallback state.
const Key kPreviewPlaceholderKey = ValueKey('preview_placeholder');

/// Live wallpaper preview driven by [previewProvider].
class PreviewPanel extends ConsumerWidget {
  const PreviewPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(previewProvider);
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: preview.when(
          data: (result) => Image.memory(
            result.png,
            gaplessPlayback: true,
            fit: BoxFit.contain,
          ),
          loading: () => const _Placeholder(),
          error: (error, stackTrace) => const _Placeholder(),
        ),
      ),
    );
  }
}

/// Static placeholder shown while the preview is loading or errored (D13).
class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: kPreviewPlaceholderKey,
      color: const Color(0x14000000),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 48, color: Colors.black26),
      ),
    );
  }
}
