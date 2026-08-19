// ItemCycleGesture — the horizontal swipe surface of the immersive preview
// (design D17/D18/D19, RE-CF-3, tasks 3.1-3.3).
//
// The horizontal drag recognizer lives ONLY on the immersive preview surface:
// the old PageView layer shell is gone (slice 6), so this gesture is the sole
// horizontal-swipe consumer in the shell — it cycles the ACTIVE layer's item.
// The view owns the active-layer decision and receives a direction — +1 for a
// left swipe (next pool item) and -1 for a right swipe (previous pool item),
// per design D18.
//
// While [sheetOpen] is true the onHorizontalDragEnd callback is null, which is
// the idiomatic Flutter way to disable a gesture: the bottom sheet owns the
// interaction surface while it is up, so a swipe over the open sheet's scrim
// never cycles the active item (RE-CF-3 "Swipe SHALL NOT fire while the bottom
// sheet is open", design D19).

import 'package:flutter/material.dart';

/// Horizontal drag surface that reports item-cycle directions.
class ItemCycleGesture extends StatelessWidget {
  const ItemCycleGesture({
    super.key,
    required this.sheetOpen,
    required this.onCycle,
    required this.child,
  });

  /// Whether the controls bottom sheet is open. While true the swipe is
  /// disabled (null callback, design D19).
  final bool sheetOpen;

  /// Called with +1 for a left swipe (next item) or -1 for a right swipe
  /// (previous item), per design D18.
  final ValueChanged<int> onCycle;

  /// The preview surface the gesture wraps.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: sheetOpen ? null : _handleDragEnd,
      child: child,
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    onCycle(velocity < 0 ? 1 : -1);
  }
}
