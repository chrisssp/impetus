# Delta for app-shell

## MODIFIED Requirements

### Requirement: MaterialApp Hosting Configurator (RE-AS-2)

The system SHALL provide a `MaterialApp` whose home screen hosts the layered
swipe configurator as the app's primary surface, replacing the Part 0
placeholder home.
(Previously: the home screen showed an identifiable placeholder — the app title.)

#### Scenario: Configurator is the app home

- GIVEN the app launches
- WHEN the home screen renders
- THEN a `Scaffold` is displayed
- AND the home content is the configurator (four-layer swipe UI), not a
  placeholder title

#### Scenario: App-shell golden baseline updated deliberately

- GIVEN the home screen now hosts the configurator
- WHEN the app-shell golden test runs
- THEN the baseline `app_shell.png` is regenerated via
  `flutter test --update-goldens`
- AND the regenerated baseline passes on subsequent runs

### Requirement: Dev-Only Spike Trigger (RE-AS-3)

The system SHALL retain the wallpaper-bridge spike trigger as a developer-only
entry point, relocated so it is not the primary home-screen action.
(Previously: the spike trigger was a FloatingActionButton on the home screen.)

#### Scenario: Spike trigger via dev entry

- GIVEN the configurator is the app home
- WHEN a developer activates the dev-only spike entry
- THEN Flutter sends a test PNG byte array to the `setBitmap` MethodChannel
- AND a success/error result is shown (e.g., SnackBar or text update)

#### Scenario: Spike trigger is one-shot

- GIVEN the spike trigger has been tapped once
- WHEN the result is displayed
- THEN the trigger does not re-run until the app is restarted
- AND no persistent state is stored from the spike
