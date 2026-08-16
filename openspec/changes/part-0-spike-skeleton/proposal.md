# Proposal: Part 0 — Spike + Skeleton

## Intent

Validate the highest-risk technical assumption before building anything: that `WallpaperManager.setBitmap` renders a PNG on the lock screen of stock Android 13/14 and Xiaomi devices. Simultaneously wire project foundations so Part 1 can start immediately on a greenfield with no scaffolding debt.

## Scope

### In Scope
- Kotlin MethodChannel (`setBitmap`) with `FLAG_LOCK | FLAG_SYSTEM` — spike only, no persistence or scheduler
- Add all MVP dependencies to pubspec: riverpod, shared_preferences, sqflite, workmanager, path_provider
- Confirm/adjust `android/app/build.gradle.kts` minSdk ≥ 21 (required by workmanager)
- Basic app shell: `ProviderScope` in `main.dart`, replace placeholder `Text('Impetus')`
- Golden-test harness: bundle Roboto font, pin `fontFamily` in test setup, single deterministic golden test
- CI release signing: design keystore + GitHub secrets structure, update `.github/workflows/release.yml`
- `flutter analyze` clean, `flutter test` passes

### Out of Scope
- Rendering engine or Canvas→PNG pipeline (Part 1)
- Configurator UI beyond shell (Part 2)
- Content curation or phrase selection (Part 3)
- Scheduler/WorkManager periodic tasks (Part 4)
- Branding (launcher, splash, web) — uncommitted; intentionally excluded from this part

## Capabilities

### New Capabilities
- `wallpaper-bridge`: Kotlin MethodChannel for `setBitmap(bitmap, null, true, FLAG_LOCK | FLAG_SYSTEM)` — spike-only test path designed for Part 1+ reuse
- `golden-harness`: Roboto font bundling, pinned `fontFamily` in tests, deterministic golden baseline
- `app-shell`: Riverpod `ProviderScope` wrapping, minimal `MaterialApp` with placeholder home
- `ci-signing`: Keystore generation recipe, GitHub secrets structure, `release.yml` update for signed APK

### Modified Capabilities
- None (greenfield; `openspec/specs/` is empty)

## Approach

1. **MethodChannel spike**: `MainActivity.kt` exposes `setBitmap` → Flutter sends a test PNG byte array → Kotlin receives via `MethodChannel`, decodes to `Bitmap`, applies via `WallpaperManager`. Single one-shot test button in the app shell.
2. **Deps + minSdk**: Add all MVP deps in one `pubspec.yaml` edit; bump `minSdkVersion` to 21 if below. Verify with `flutter pub get`.
3. **App shell**: `main.dart` wraps `ProviderScope` → `MaterialApp` → placeholder `Scaffold` with a floating action button that triggers the spike.
4. **Golden harness**: Add `fonts/Roboto-Regular.ttf` to `test/`, configure `golden_tool` to use it, write one deterministic widget golden.
5. **CI signing**: Recipe: `keytool -genkeypair` → base64 `keystore.jks` → GitHub secret `KEYSTORE_BASE64`; `release.yml` decodes and signs with `apksigner`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `android/app/src/main/kotlin/.../MainActivity.kt` | Modified | Add MethodChannel + setBitmap spike |
| `lib/main.dart` | Modified | Wrap with ProviderScope, add spike trigger UI |
| `pubspec.yaml` | Modified | Add 5 MVP dependencies |
| `android/app/build.gradle.kts` | Modified | Confirm/set minSdk ≥ 21 |
| `test/` | New | Golden harness with Roboto font |
| `.github/workflows/release.yml` | Modified | Add keystore decode + APK signing step |
| `openspec/specs/wallpaper-bridge/` | New | Spike spec for MethodChannel contract |
| `openspec/specs/golden-harness/` | New | Test determinism spec |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| setBitmap behaves differently on Xiaomi MIUI vs stock Android | High | Spike targets both; photo proof as exit criterion |
| workmanager needs minSdk 21+ and current is lower | Low | Check build.gradle.kts; bump if needed |
| Keystore setup is manual (repo-admin step) | Medium | Document exact recipe in proposal; apply-time execution |
| Golden test flakiness if font not bundled | Low | Bundle Roboto in test assets, pin fontFamily |

## Rollback Plan

Each change is atomic and revertible. MethodChannel spike is a single file addition. Deps are additive (revert pubspec + `flutter pub get`). CI signing is workflow-only. No persistent data or migration risk.

## Dependencies

- **Manual step**: Keystore generation + GitHub secret provisioning (repo admin must execute at apply time)
- **Device matrix**: Emulator (stock Android 13/14) + Xiaomi real device for spike validation

## Success Criteria

- [ ] `setBitmap` renders a test PNG on lock screen — photo proof from emulator + Xiaomi
- [ ] `flutter analyze` clean (zero issues)
- [ ] `flutter test` passes (including golden harness)
- [ ] `release.yml` produces a signed release APK via GitHub Actions
- [ ] Golden test runs deterministically across CI runs
