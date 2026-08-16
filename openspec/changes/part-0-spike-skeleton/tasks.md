# Tasks: Part 0 — Spike + Skeleton

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 250-350 (excluding binary font + golden image) |
| 400-line budget risk | Medium |
| Chained PRs recommended | Yes |
| Suggested split | PR 1: Foundation + wallpaper-bridge | PR 2: golden-harness + app-shell | PR 3: ci-signing + verification |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Foundation deps + minSdk + wallpaper-bridge (Dart + Kotlin + unit/widget tests) | PR 1 | `flutter test test/services/wallpaper_bridge_test.dart` | `flutter run` on emulator; tap FAB → SnackBar shows result | `pubspec.yaml`, `build.gradle.kts`, `lib/services/wallpaper_bridge.dart`, `MainActivity.kt`, test files |
| 2 | golden-harness (Roboto font + golden test) + app-shell (ProviderScope + widget test updates) | PR 2 | `flutter test test/golden/app_shell_golden_test.dart` && `flutter test test/widget_test.dart` | `flutter run` renders shell with pinned Roboto | `test/fonts/`, `test/golden/`, `test/widget_test.dart`, `lib/main.dart` providers |
| 3 | ci-signing (gradle + workflow + gitignore) + final verification (analyze + test + manual spike) | PR 3 | `flutter analyze` && `flutter test` | GitHub Actions release.yml on tag push → signed APK attached | `.gitignore`, `build.gradle.kts`, `.github/workflows/release.yml` |

## Phase 1: Foundation (Dependencies + minSdk)

- [x] 1.1 Add MVP dependencies to `pubspec.yaml`: `flutter_riverpod`, `shared_preferences`, `sqflite`, `workmanager`, `path_provider` under `dependencies`
- [x] 1.2 Set `minSdk = 21` explicitly in `android/app/build.gradle.kts` (replace `flutter.minSdkVersion`)
- [x] 1.3 Run `flutter pub get` to resolve dependencies

## Phase 2: wallpaper-bridge (MethodChannel + Spike) — Strict TDD

- [x] 2.1 **RED** Write unit tests for `WallpaperBridge` in `test/services/wallpaper_bridge_test.dart`: mock `MethodChannel`, verify `setBitmap` sends correct args, asserts `PlatformException` with codes `INVALID_ARGUMENT` / `INVALID_BITMAP` / `SET_BITMAP_FAILED`
- [x] 2.2 **GREEN** Create `lib/services/wallpaper_bridge.dart` with `WallpaperBridge` class per design.md contract (MethodChannel name `com.impetus.impetus/wallpaper`, `setBitmap(Uint8List) → Future<bool>`)
- [x] 2.3 **GREEN** Implement Kotlin handler in `android/app/src/main/kotlin/com/impetus/impetus/MainActivity.kt`: `MethodChannel.MethodCallHandler`, decode bytes, `WallpaperManager.setBitmap(bitmap, null, true, FLAG_LOCK | FLAG_SYSTEM)`, return `true` or error codes per spec
- [x] 2.4 **RED** Write widget test for spike trigger in `test/widget_test.dart` (or new `test/spike_test.dart`): mock channel, tap FAB, verify `spikeStateProvider` transitions 0→1→2/3, SnackBar shows result
- [x] 2.5 **GREEN** Update `lib/main.dart`: wrap with `ProviderScope`, add `wallpaperBridgeProvider` (FutureProvider) + `spikeStateProvider` (StateProvider<int>), add FAB that triggers spike, show SnackBar on result
- [ ] 2.6 **MANUAL** Run app on Android 13/14 emulator and Xiaomi device; tap FAB; photograph lock screen showing test PNG — photo proof is exit criterion per spec — **DEFERRED (slice 1): cannot run device matrix in apply environment; requires emulator + Xiaomi device**

## Phase 3: golden-harness (Roboto + Deterministic Golden)

- [x] 3.1 Add `test/fonts/Roboto-Regular.ttf` (canonical Roboto Regular, ~170KB)
- [x] 3.2 **RED** Create `test/golden/app_shell_golden_test.dart`: load font via `FontLoader('Roboto').addFont(rootBundle.load('test/fonts/Roboto-Regular.ttf'))` in `setUpAll`, pump `ProviderScope(child: MainApp())` with `fontFamily: 'Roboto'` pinned, `await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/app_shell.png'))`
- [x] 3.3 **GREEN** First run generates golden baseline; subsequent runs must match byte-identically on CI and local

## Phase 4: app-shell (ProviderScope + Widget Tests)

- [x] 4.1 **RED** Update `test/widget_test.dart`: wrap `MainApp()` with `ProviderScope`, verify `find.text('Impetus')` and `find.byType(FloatingActionButton)` exist
- [x] 4.2 **GREEN** Verify `lib/main.dart` from Phase 2.5 satisfies updated widget test (ProviderScope, MaterialApp, placeholder home, FAB)
- [x] 4.3 **GREEN** Run `flutter test test/widget_test.dart` — must pass

## Phase 5: ci-signing (Keystore + Workflow + Gitignore)

- [x] 5.1 Update `.gitignore`: add `*.jks`, `*.keystore` patterns
- [x] 5.2 Update `android/app/build.gradle.kts`: add conditional `signingConfigs.release` reading `KEYSTORE_PATH`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` from `System.getenv()`; fallback to `signingConfigs.debug` when unset; apply to `buildTypes.release`
- [x] 5.3 Update `.github/workflows/release.yml`: add step to decode `KEYSTORE_BASE64` → `/tmp/keystore.jks` before `flutter build apk --release`; ensure `apksigner` uses `--ks --ks-pass --ks-key-alias --key-pass` with v2+v3; fail workflow if signing fails; attach signed APK to release
- [ ] 5.4 **MANUAL (Non-code)** Document keystore generation recipe in PR description: `keytool -genkeypair -alias impetus-key -keyalg RSA -keysize 2048 -validity 10000 -keystore keystore.jks` → `base64 -w0 keystore.jks` → add 4 GitHub secrets (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`) — repo admin executes at apply time

## Phase 6: Verification (Exit Criteria)

- [x] 6.1 Run `flutter analyze --fatal-infos` — zero issues required
- [x] 6.2 Run `flutter test` — all tests pass (unit, widget, golden)
- [x] 6.3 Verify `flutter test --update-goldens` regenerates golden cleanly on intentional changes
- [ ] 6.4 Tag push triggers `release.yml` → signed APK attached to GitHub Release (manual verification in CI)
