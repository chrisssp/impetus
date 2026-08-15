![Impetus](design/logo/logotipo/banner.svg)

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

## Getting started

You need the Flutter SDK (stable channel) and an Android device or emulator.

```sh
git clone https://github.com/chrisssp/impetus.git
cd impetus
flutter pub get
flutter run
```

For the full contribution setup, development workflow and commit conventions,
see [CONTRIBUTING.md](CONTRIBUTING.md).

## Technical stack

- Flutter / Dart (stable channel)
- Android
- WorkManager for scheduling
- GitHub Actions for CI and releases (APK via GitHub Releases)
- License: MIT

## Contributing

Contributions are welcome and appreciated. Start with
[CONTRIBUTING.md](CONTRIBUTING.md) and please respect our
[Code of Conduct](CODE_OF_CONDUCT.md).
