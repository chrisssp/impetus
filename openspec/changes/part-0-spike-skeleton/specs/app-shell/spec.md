# Delta for app-shell

## ADDED Requirements

### Requirement: ProviderScope Wrapping

The system SHALL wrap the Flutter app with Riverpod's `ProviderScope` in `main.dart`.

#### Scenario: App launches with ProviderScope

- GIVEN `main.dart` is the entry point
- WHEN `runApp()` is called
- THEN the widget tree root is `ProviderScope`
- AND `MaterialApp` is a child of `ProviderScope`

### Requirement: MaterialApp with Placeholder Home

The system SHALL provide a `MaterialApp` with a placeholder home screen containing the app title.

#### Scenario: Home screen displays

- GIVEN the app launches
- WHEN the home screen renders
- THEN a `Scaffold` is displayed
- AND the screen shows an identifiable placeholder (e.g., app name or icon)

### Requirement: Spike Trigger Button

The system SHALL include a single one-shot trigger (e.g., FloatingActionButton) on the home screen that invokes the wallpaper bridge spike.

#### Scenario: User taps spike trigger

- GIVEN the home screen is displayed
- WHEN the user taps the spike trigger button
- THEN Flutter sends a test PNG byte array to the `setBitmap` MethodChannel
- AND a success/error result is shown (e.g., SnackBar or text update)

#### Scenario: Spike trigger is one-shot

- GIVEN the spike trigger has been tapped once
- WHEN the result is displayed
- THEN the button does not re-trigger until the app is restarted
- AND no persistent state is stored from the spike
