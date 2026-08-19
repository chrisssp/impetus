// PreviewPanel widget (design D13, RE-CF-9, tasks 5.1/5.2).
//
// The preview renderer is real engine code that never completes under the
// widget-test fake async zone, so every test overrides previewProvider with a
// fake notifier. The tests then push new PreviewResults into the panel and
// assert that Image.memory consumes the new bytes (RE-CF-9) and that an
// AsyncError falls back to a static placeholder box without crashing
// (RE-CF-7). The state changes driving those results (pool/preset/selection)
// are covered at the provider level in preview_provider_test.dart; mode
// toggles are render-irrelevant (D12).

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impetus/configurator/blocking.dart';
import 'package:impetus/configurator/placeholder_assets.dart';
import 'package:impetus/configurator/preview_panel.dart';
import 'package:impetus/configurator/preview_pipeline.dart';
import 'package:impetus/configurator/preview_provider.dart';

/// A fake notifier whose build stays pending until the test decides, and that
/// exposes [emitData]/[emitError] to drive the panel state directly.
class _FakePreviewNotifier extends PreviewNotifier {
  _FakePreviewNotifier() : _initial = Completer<PreviewResult>();

  final Completer<PreviewResult> _initial;

  @override
  Future<PreviewResult> build() => _initial.future;

  void completeInitial(PreviewResult result) {
    _initial.complete(result);
  }

  void emitData(PreviewResult result) {
    state = AsyncData(result);
  }

  void emitError(Object error, StackTrace stackTrace) {
    state = AsyncError(error, stackTrace);
  }
}

PreviewResult _result(Uint8List bytes) {
  return PreviewResult(png: bytes, blocks: const LayerBlockStatuses.empty());
}

/// Pumps a [PreviewPanel] inside a provider scope whose previewProvider is the
/// fake notifier, and returns that notifier to drive the panel.
Future<_FakePreviewNotifier> _pumpPanel(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [previewProvider.overrideWith(_FakePreviewNotifier.new)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: PreviewPanel())),
    ),
  );
  return container.read(previewProvider.notifier) as _FakePreviewNotifier;
}

/// The PNG bytes the panel's Image.memory is currently consuming.
Uint8List _consumedBytes(WidgetTester tester) {
  final image = tester.widget<Image>(find.byType(Image));
  return (image.image as MemoryImage).bytes;
}

void main() {
  testWidgets('loading shows the static placeholder box and no image', (
    tester,
  ) async {
    await _pumpPanel(tester);

    expect(find.byKey(const ValueKey('preview_placeholder')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets(
    'consumes preview bytes via Image.memory and re-renders on new bytes',
    (tester) async {
      final notifier = await _pumpPanel(tester);

      notifier.completeInitial(_result(kAlphaPngBytes));
      await tester.pump();
      expect(_consumedBytes(tester), kAlphaPngBytes);

      notifier.emitData(_result(kBravoPngBytes));
      await tester.pump();
      expect(_consumedBytes(tester), kBravoPngBytes);

      notifier.emitData(_result(kDeltaPngBytes));
      await tester.pump();
      expect(_consumedBytes(tester), kDeltaPngBytes);
    },
  );

  testWidgets('AsyncError falls back to the placeholder box without crashing '
      '(RE-CF-7)', (tester) async {
    final notifier = await _pumpPanel(tester);
    notifier.completeInitial(_result(kAlphaPngBytes));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);

    notifier.emitError(StateError('render failed'), StackTrace.current);
    await tester.pump();

    expect(find.byKey(const ValueKey('preview_placeholder')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview fills the available body with no fixed aspect ratio '
      '(RE-CF-9, D23)', (tester) async {
    final notifier = await _pumpPanel(tester);
    notifier.completeInitial(_result(kAlphaPngBytes));
    await tester.pump();

    // The 9:16 AspectRatio shell is gone: the panel is not tied to a fixed
    // aspect (D23) and no hardcoded 160px SizedBox constrains it.
    expect(find.byType(AspectRatio), findsNothing);

    // Full-bleed: the rendered image spans the whole test surface (800x600)
    // from the origin — the whole body IS the wallpaper (RE-CF-9).
    final imageRect = tester.getRect(find.byType(Image));
    expect(imageRect.topLeft, Offset.zero);
    expect(imageRect.width, 800);
    expect(imageRect.height, 600);
  });

  testWidgets('renders the preview with BoxFit.cover inside a RepaintBoundary '
      '(D23)', (tester) async {
    final notifier = await _pumpPanel(tester);
    notifier.completeInitial(_result(kAlphaPngBytes));
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.cover);
    expect(image.gaplessPlayback, isTrue);

    // The fill chain: RepaintBoundary isolates the raster, LayoutBuilder fills
    // the available space (D23).
    expect(
      find.ancestor(
        of: find.byType(Image),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
    expect(find.byType(LayoutBuilder), findsOneWidget);
  });

  testWidgets('golden determinism: previewSizeProvider override pins the '
      'canvas at 540x960 (D25)', (tester) async {
    final container = ProviderContainer(
      overrides: [
        previewProvider.overrideWith(_FakePreviewNotifier.new),
        previewSizeProvider.overrideWithValue(const Size(540, 960)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: PreviewPanel())),
      ),
    );

    // The pinned override flows into the render config the engine consumes;
    // goldens render at this fixed size regardless of the panel's bounds (D25).
    expect(container.read(previewConfigProvider).size, const Size(540, 960));
  });
}
