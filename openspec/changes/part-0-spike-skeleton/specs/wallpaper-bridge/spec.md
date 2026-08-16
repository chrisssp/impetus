# Delta for wallpaper-bridge

## ADDED Requirements

### Requirement: MethodChannel Contract

The system SHALL expose a MethodChannel named `com.impetus.impetus/wallpaper` from `MainActivity.kt` to Flutter.

#### Scenario: Channel registration

- GIVEN the app launches on Android
- WHEN `MainActivity` initializes
- THEN a `MethodChannel` with name `com.impetus.impetus/wallpaper` is registered
- AND the channel handler is set to `this`

#### Scenario: Flutter invokes setBitmap

- GIVEN the MethodChannel is registered
- WHEN Flutter calls `invokeMethod('setBitmap', pngBytes)` where `pngBytes` is a `Uint8List`
- THEN Kotlin receives the call on the main thread
- AND the byte array is decoded to an `android.graphics.Bitmap`

### Requirement: setBitmap Wallpaper Application

The system SHALL apply the decoded Bitmap via `WallpaperManager.setBitmap(bitmap, null, true, WallpaperManager.FLAG_LOCK | WallpaperManager.FLAG_SYSTEM)`.

#### Scenario: Successful wallpaper set on stock Android

- GIVEN a valid PNG byte array is sent via `setBitmap`
- WHEN Kotlin decodes it to a Bitmap and calls `WallpaperManager.setBitmap`
- THEN the wallpaper is applied to both lock screen and system wallpaper
- AND the method returns `true` to Flutter

#### Scenario: Wallpaper set on Xiaomi MIUI

- GIVEN a valid PNG byte array is sent via `setBitmap` on a Xiaomi device running MIUI
- WHEN `WallpaperManager.setBitmap` is called with `FLAG_LOCK | FLAG_SYSTEM`
- THEN the wallpaper is applied successfully
- AND the method returns `true` to Flutter

#### Scenario: setBitmap with null byte array

- GIVEN Flutter sends `null` as the argument to `setBitmap`
- WHEN Kotlin receives the call
- THEN the method returns an error with code `INVALID_ARGUMENT` and message `PNG bytes must not be null`

### Requirement: Error Handling

The system SHALL return structured error responses for all failure modes.

#### Scenario: Invalid bitmap data

- GIVEN Flutter sends a byte array that does not decode to a valid Bitmap
- WHEN Kotlin attempts `BitmapFactory.decodeByteArray`
- THEN the method returns an error with code `INVALID_BITMAP` and message `Failed to decode bitmap from provided bytes`

#### Scenario: WallpaperManager exception

- GIVEN a valid Bitmap is decoded
- WHEN `WallpaperManager.setBitmap` throws an exception
- THEN the method returns an error with code `SET_BITMAP_FAILED` with the exception message

### Requirement: Spike Test Path

The system SHALL provide a one-shot spike test path where Flutter sends a test PNG byte array to verify the bridge end-to-end.

#### Scenario: Spike test via app shell trigger

- GIVEN the app shell displays a spike trigger button
- WHEN the user taps the button
- THEN Flutter generates or loads a test PNG byte array
- AND sends it to Kotlin via the `setBitmap` method
- AND the result (success or error) is displayed in the UI

#### Scenario: Photo proof exit criterion

- GIVEN the spike test completes with `true` result
- WHEN a device photo is taken of the lock screen
- THEN the test PNG is visible on the lock screen
- AND this serves as manual verification evidence for stock Android 13/14 and Xiaomi devices
