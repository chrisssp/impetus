# Contributing to Impetus

First off, thanks for taking the time to contribute! ❤️

Impetus is a motivational Android wallpaper built in Flutter. It composes a
quote, a character and the time of day into a daily push on your lock screen.

This project cares about clear, readable code and wants contributing to be a
great experience.

## Table of contents

- [Code of Conduct](#code-of-conduct)
- [What we're building](#what-were-building)
- [Getting started](#getting-started)
- [Project structure](#project-structure)
- [How to contribute](#how-to-contribute)
- [Development workflow](#development-workflow)
- [Commit messages](#commit-messages)
- [Testing](#testing)
- [Style guide](#style-guide)
- [Questions?](#questions)

## Code of Conduct

This project and everyone participating in it is governed by our
[Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to
uphold this code.

## What we're building

The product and design decisions live in the repository docs (see
`docs/`). The short version:

- An **Android app** that sets a motivational wallpaper on the lock screen.
- The wallpaper is **composed in layers**: background, quote, character and
  font — all configurable by the user.
- The heart of the product is the **motivational experience**: a declared
  intent ("what are you working on?"), a curated quote of the day, and
  adaptation to the time of day.
- **Offline-first**: works 100% without a network connection.

## Getting started

### Prerequisites

- Flutter SDK (stable channel)
- Android SDK (with `platform-tools`)
- A device or emulator running Android

See the official [Flutter installation guide](https://docs.flutter.dev/get-started/install)
if you don't have the toolchain set up yet.

### Running the project

```sh
# Get dependencies
flutter pub get

# Run the app (on a connected device or emulator)
flutter run

# Run on Chrome/Brave for fast web iteration
flutter run -d chrome
```

## Project structure

```
lib/
  main.dart            # App entry point
android/               # Android host (native layer, rarely touched)
web/                   # Web host (used for fast development iteration)
test/                  # Unit, widget and golden tests
```

The Android and web folders are generated platform hosts. They are only
touched when strictly necessary — the product logic lives in `lib/` and
`test/`.

## How to contribute

### Report a bug

1. Open an issue using the **Bug report** template.
2. Include: the device model, Android version, app version, and steps to
   reproduce.
3. Screenshots or a screen recording are always appreciated.

### Request a feature

1. Open an issue using the **Feature request** template.
2. Explain the problem you're trying to solve, not just the solution you have
   in mind. The *why* is more valuable than the *what*.

### Submit a change

1. Fork the repository and create a branch from `main`:

   ```sh
   git checkout -b fix/describe-the-fix
   ```

2. Make your changes. Keep them **small and focused** — one logical change per
   PR.
3. Add or update tests for your change.
4. Run the checks (see [Development workflow](#development-workflow)).
5. Open a pull request using the **Pull request template**. Reference the issue
   it fixes (e.g. "Fixes #12").

## Development workflow

Run all checks before pushing:

```sh
# Static analysis
flutter analyze

# Tests
flutter test

# Check formatting (Dart)
dart format --output=none --set-exit-if-changed lib test
```

The CI pipeline runs exactly these checks on every pull request. A green PR
is the fastest path to review.

## Commit messages

We use **Conventional Commits**:

```
<type>(<scope>): <subject>
```

- `feat`: a new feature
- `fix`: a bug fix
- `docs`: documentation only
- `test`: adding or updating tests
- `refactor`: code change that neither fixes a bug nor adds a feature
- `chore`: maintenance (dependencies, tooling, CI)

Examples:

```sh
feat(engine): compose wallpaper layers into a bitmap
fix(quotes): prevent same-day quote repetition
test(selection): cover deterministic daily selection
chore(ci): add Android SDK setup to build job
```

Keep the subject concise and in the imperative mood. Add a body explaining
**why** when it's not obvious.

## Testing

- **Unit tests** for pure logic (quote selection, time-of-day weighting).
- **Widget tests** for the configurator UI.
- **Golden tests** for the rendering engine — the rendered wallpaper must be
  deterministic.

Test files live next to the code they cover, or under `test/` following the
`lib/` structure.

## Style guide

We follow the [Dart effective style](https://dart.dev/effective-dart) and the
lints defined in `analysis_options.yaml`. When in doubt, run `flutter analyze`
— it's the source of truth.

A few preferences:

- Prefer small, single-responsibility functions and classes.
- Name things for what they *do*, not how they do it.
- No comments that restate the code. Comments explain *why*.
- Keep the UI on the dark base palette (`#1e1e2e`) with the amber accent
  (`#f59e0b`).

## Questions?

Open a discussion or an issue. There are no bad questions — if something is
unclear, it's a documentation problem, and we'll fix it.

Thank you again for contributing to Impetus. 🚀
