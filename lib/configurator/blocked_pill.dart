// BlockedPill — the non-intrusive blocked-layer suggestion overlay (design
// D22, RE-CF-7, tasks 5.1-5.4).
//
// Replaces the old full-page attenuation and per-page _BlockedBanner: instead
// of dimming a whole layer page, a small Chip-style pill floats at the top of
// the immersive preview (Positioned top:12, left/right:16) and shows the FIRST
// blocked layer's unblocking suggestion in stack order — when several layers
// are blocked, the earliest one wins so the user fixes the root cause first
// (RE-CF-7 "visible suggestion" intent without full-page attenuation).
//
// The pill is wrapped in IgnorePointer: it never absorbs taps, drags or
// flings, so pointer events fall through to the preview's ItemCycleGesture and
// the item-cycle swipe keeps working even when the gesture starts on top of
// the pill (D22 non-intrusive). It is intentionally NOT gated on the sheet-
// open state — the modal sheet overlays it, but the pill itself stays in the
// tree (it must not be hidden or unmounted by unrelated UI state).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impetus/configurator/preview_provider.dart';

/// Key on the pill's [Chip] so tests can find it and scope Positioned/inset
/// and text assertions (D22, stable keys table).
const Key kBlockedPillKey = ValueKey('blocked_pill');

/// The pill's top inset from the preview edge (design D22).
const double _kPillTopInset = 12;

/// The pill's horizontal insets from the preview edges (design D22).
const double _kPillSideInset = 16;

/// Positioned suggestion pill over the preview for blocked layers (D22).
class BlockedPill extends ConsumerWidget {
  const BlockedPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(blockStatusProvider);
    final firstBlocked = statuses.entries
        .where((status) => status.blocked)
        .firstOrNull;
    if (firstBlocked == null) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      top: _kPillTopInset,
      left: _kPillSideInset,
      right: _kPillSideInset,
      child: IgnorePointer(
        child: Chip(
          key: kBlockedPillKey,
          avatar: Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: scheme.onErrorContainer,
          ),
          label: Text(
            firstBlocked.suggestion!,
            style: TextStyle(color: scheme.onErrorContainer),
          ),
          backgroundColor: scheme.errorContainer,
        ),
      ),
    );
  }
}
