# Design: Part 0 — Spike + Skeleton

## Technical Approach

Wire the highest-risk assumption first: prove `WallpaperManager.setBitmap` works on stock Android 13/14 and Xiaomi via a Kotlin MethodChannel spike. Simultaneously scaffold project foundations (Riverpod shell, golden harness, CI signing) so Part 1 starts on clean ground.

## Architecture Decisions

### Decision: Test PNG Generation

**Choice**: Hardcoded 1×1 red pixel PNG bytes as a Dart `Uint8List` literal.
**Alternatives considered**: (a) Bundle a PNG in `test/assets/`, (b) Generate via `dart:ui` at runtime.
**Rationale**: A 67-byte 1×1 PNG literal is deterministic across platforms, requires zero asset management, and avoids `dart:ui` test-framework overhead. The spike only needs *any* valid PNG — size is irrelevant. Part 1 replaces this with the real rendering engine.

### Decision: Font Bundling for Golden Tests

**Choice**: Copy `Roboto-Regular.ttf` to `test/fonts/`, load it in the golden test setup via `FontLoader('Roboto')` (from the bytes read off `test/fonts/Roboto-Regular.ttf`), and pin `fontFamily: 'Roboto'` on the widget under test.
**Alternatives considered**: (a) Use `fonts.gstatic.com` import, (b) rely on host system fonts.
**Rationale**: Bundling in `test/fonts/` guarantees byte-identical rendering across CI (Ubuntu) and local (macOS/Linux). Host fonts differ between OS versions. The font is ~170KB — negligible in test assets.

### Decision: Riverpod Provider Graph

**Choice**: Two minimal providers: `wallpaperBridgeProvider` (FutureProvider wrapping the MethodChannel call) and `spikeStateProvider` (StateProvider<int> tracking spike result: 0=idle, 1=success, 2=error). `ProviderScope` wraps `runApp()`.
**Alternatives considered**: (a) No providers, just `StatefulWidget`, (b) full service locator pattern.
**Rationale**: The spec requires ProviderScope. Two providers demonstrate the Riverpod pattern without over-engineering. Part 1 adds the rendering engine provider on top.

### Decision: CI Signing Configuration

**Choice**: `build.gradle.kts` reads keystore path/passwords from environment variables; falls back to debug signing when unset. `release.yml` decodes `KEYSTORE_BASE64` → `/tmp/keystore.jks` before `flutter build apk`.
**Alternatives considered**: (a) Always use `apksigner` post-build, (b) signingConfig block only in CI.
**Rationale**: Gradle-native signing integrates with `flutter build apk` and is the standard Android approach. Environment-based conditional (`if (System.getenv("KEYSTORE_BASE64") != null)`) lets local builds succeed without secrets.

### Decision: minSdk Version

**Choice**: Set `minSdk = 21` explicitly in `build.gradle.kts`.
**Alternatives considered**: Keep `flutter.minSdkVersion` (currently 21 in Flutter 3.47).
**Rationale**: Explicit beats inherited. Flutter's default is already 21, but workmanager requires ≥21 and the contract is clearer when pinned. No dependency usage yet — only the floor is set.

## Data Flow

```
Spike Button Tap
    │
    ▼
spikeStateProvider = 1 (loading)
    │
    ▼
wallpaperBridgeProvider ──→ MethodChannel('com.impetus.impetus/wallpaper')
    │                              │
    │  invokeMethod('setBitmap', pngBytes)
    │                              ▼
    │                     MainActivity.kt
    │                     BitmapFactory.decodeByteArray
    │                     WallpaperManager.setBitmap(FLAG_LOCK | FLAG_SYSTEM)
    │                              │
    │  result (true / error)       │
    │◀─────────────────────────────┘
    ▼
spikeStateProvider = 2 (success) or 3 (error)
    │
    ▼
SnackBar displays result
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/main.dart` | Modify | Wrap with `ProviderScope`, add spike trigger FAB |
| `lib/services/wallpaper_bridge.dart` | Create | Dart-side MethodChannel wrapper |
| `android/app/src/main/kotlin/.../MainActivity.kt` | Modify | Implement `MethodChannel.MethodCallHandler`, add `setBitmap` logic |
| `android/app/build.gradle.kts` | Modify | Set `minSdk = 21`, add conditional release signing config |
| `pubspec.yaml` | Modify | Add `flutter_riverpod`, `shared_preferences`, `sqflite`, `workmanager`, `path_provider` |
| `test/fonts/Roboto-Regular.ttf` | Create | Bundled Roboto font for golden determinism |
| `test/golden/app_shell_golden_test.dart` | Create | Deterministic golden baseline test |
| `test/widget_test.dart` | Modify | Update to match ProviderScope wrapping |
| `.github/workflows/release.yml` | Modify | Add keystore decode + signing steps to the existing release workflow |
| `.gitignore` | Modify | Add `*.jks`, `*.keystore` exclusions |

## Interfaces / Contracts

### Dart Side — MethodChannel Wrapper

```dart
class WallpaperBridge {
  static const _channel =
      MethodChannel('com.impetus.impetus/wallpaper');

  static Future<bool> setBitmap(Uint8List pngBytes) async {
    final result = await _channel.invokeMethod<bool>(
      'setBitmap',
      pngBytes,
    );
    return result ?? false;
  }
}
```

### Kotlin Side — MainActivity Handler

```kotlin
class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.impetus.impetus/wallpaper"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "setBitmap" -> {
                val bytes = call.arguments as? ByteArray
                if (bytes == null) {
                    result.error("INVALID_ARGUMENT",
                        "PNG bytes must not be null", null)
                    return
                }
                val bitmap = BitmapFactory.decodeByteArray(
                    bytes, 0, bytes.size
                )
                if (bitmap == null) {
                    result.error("INVALID_BITMAP",
                        "Failed to decode bitmap from provided bytes",
                        null)
                    return
                }
                try {
                    val mgr = WallpaperManager.getInstance(this)
                    mgr.setBitmap(bitmap, null, true,
                        WallpaperManager.FLAG_LOCK or
                        WallpaperManager.FLAG_SYSTEM)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SET_BITMAP_FAILED",
                        e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }
}
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `WallpaperBridge.setBitmap` sends correct args | Mock `MethodChannel` via `TestDefaultBinaryMessengerBinding.defaultBinaryMessenger.setMockMethodCallHandler` |
| Unit | Error handling: null args, invalid bytes, exception | Same mock; assert `PlatformException` with correct error codes |
| Widget | App shell renders placeholder + FAB | `tester.pumpWidget(ProviderScope(child: MainApp()))`, verify `find.text('Impetus')` and `find.byType(FloatingActionButton)` |
| Widget | Spike trigger sends bytes and shows result | Mock channel, tap FAB, verify SnackBar text |
| Golden | Baseline golden test | `tester.pumpWidget`, `matchesGoldenFile`, pinned `fontFamily: 'Roboto'` |
| Manual | `setBitmap` on emulator + Xiaomi | Photo proof of test PNG on lock screen |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.

## Migration / Rollout

No migration required. All changes are greenfield additions or atomic file modifications. The MethodChannel spike is designed for Part 1 reuse — no contract changes needed.

## Open Questions

- [ ] None — all technical decisions resolved by the specs and proposal scope.
