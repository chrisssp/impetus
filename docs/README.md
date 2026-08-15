# Impetus

Your lock screen, pushing you forward every day.

A motivational Android wallpaper built with Flutter. It composes a quote, a
character and the time of day into a daily push that greets you every time you
unlock your phone.

## The idea

Most of us check our phone hundreds of times a day. Each unlock is a tiny
decision point — an instant where you either act on what matters or drift.
Impetus turns that instant into a nudge: a carefully composed wallpaper that
reconnects you with your goals.

This is the lock screen as a **daily reminder**, not a passive image.

## How it works

The wallpaper is composed in **layers**:

- **Background** — a base canvas (color or gradient)
- **Quote** — a curated phrase from the quote library
- **Character** — an optional transparent character PNG
- **Font** — typography choices for the quote

Everything is configurable. The user picks the layers, Impetus renders them
into the wallpaper bitmap and the Android system sets it as the lock screen
background.

### The motivational heart

Beyond decoration, Impetus adapts to the person and the moment:

1. **Declared intent** — onboarding asks "what are you working on?" and uses the
   answer to filter the quote pool.
2. **Quote of the day** — a curated quote picked deterministically by the day of
   the year (anti-repetition), with metadata for category, natural time slot and
   intensity.
3. **Moment awareness** — morning quotes lean energetic, night quotes lean calm;
   time of day weights the selection.

### Modes

- **Fixed** — one composition you set and keep.
- **Dynamic** — the wallpaper changes automatically on a schedule.

## Goals

- **Offline-first** — the app works 100% without a network connection; it
  ships a bundled, curated quote library.
- **Battery friendly** — scheduling uses Android's WorkManager; no background
  churn.
- **Privacy** — no accounts, no tracking, no cloud dependency.
- **Deterministic rendering** — the same inputs always produce the same
  wallpaper; tested with golden tests.

## Roadmap

1. Spike: `WallpaperManager.setBitmap` on a real device.
2. **Repository skeleton** — clean architecture, CI, releases. ← we are here
3. Rendering engine with golden tests.
4. The configurator UI.
5. Content: the curated quote and character library.
6. The motivational heart (intent, quote of the day, moment awareness).
7. Auto-change scheduling with WorkManager.
8. First public release.

## Technical stack

- Flutter / Dart (stable channel)
- Android (min SDK per Flutter defaults)
- WorkManager for scheduling
- GitHub Actions for CI and releases (APK via GitHub Releases)
- License: MIT

## Contributing

Contributions are welcome and appreciated. Start with
[CONTRIBUTING.md](../CONTRIBUTING.md) and please respect our
[Code of Conduct](../CODE_OF_CONDUCT.md).

## Community

All contributions are welcome. Open an issue to report a bug or suggest an
idea, or open a pull request — every improvement makes Impetus better for
everyone who unlocks their phone looking for a push.
