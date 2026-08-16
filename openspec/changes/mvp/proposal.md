# Proposal: Impetus MVP

## Intent

Deliver the Impetus MVP: an Android app that auto-changes the lock screen wallpaper, rendering a motivational quote over a curated background. The spec is complete (vault); this proposal defines the division into reviewable parts for staged delivery.

## Scope

### In Scope
- WallpaperManager.setBitmap spike (Kotlin MethodChannel, FLAG_LOCK | FLAG_SYSTEM)
- Rendering engine (3-zone model, Canvas→PNG, golden tests)
- Layered swipe configurator (fijo/dinámico, pool, shuffle, blocked layers, simulated clock)
- Curated English phrase bank + character PNGs (10-15, waist-up)
- Phrase-of-the-day deterministic selection + anti-repetition sqlite + time-of-day weighting
- WorkManager auto-change scheduler + persistence + battery guidance
- Release APK signed via CI (keystore + GitHub secrets)
- State management: **Riverpod** (justification below)

### Out of Scope
- Share/favorites (post-MVP, decision 17)
- Spanish i18n (post-MVP, decision 18)
- API/AI content sources (architecture ready, decision 19)
- iOS, desktop, widgets, web configurator

## Capabilities

### New Capabilities
- `wallpaper-engine`: Kotlin MethodChannel for setBitmap, 3-zone layout, Canvas→PNG render pipeline
- `configurator`: Layered swipe UI, fijo/dinámico modes, pool management, simulated clock, WYSIWYG preview
- `content`: Curated phrase bank with metadata, character catalog, deterministic selection, anti-repetition
- `scheduler`: WorkManager integration, persistence, battery optimization guidance

### Modified Capabilities
- None (greenfield project)

## Approach

**State management: Riverpod.** The configurator is pure state (layers, modes, pools, preview). Riverpod gives compile-time safety, testability (ProviderContainer), and composable providers — ideal for golden + widget tests from day 1. Bloc adds ceremony without benefit at this scale; plain setState doesn't compose well across 4+ layered providers.

**Persistence: shared_preferences (config) + sqlite (history).** Already decided in spec §3. Confirmed.

**Content curation runs in parallel with code** (spec §7 biggest risk). Phrase bank + character PNGs must be ready before Part 4 integration.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/main.dart` | Modified | Replace placeholder with app shell + Riverpod |
| `lib/engine/` | New | Rendering engine, zone model, Canvas→PNG |
| `lib/configurator/` | New | Layered swipe UI, WYSIWYG preview |
| `lib/content/` | New | Phrase bank, selection, anti-repetition |
| `lib/scheduler/` | New | WorkManager bridge, persistence |
| `android/app/src/main/` | New | Kotlin MethodChannel for setBitmap |
| `pubspec.yaml` | Modified | Add deps: riverpod, shared_preferences, sqflite, workmanager, path_provider |
| `.github/workflows/` | Modified | Fix release signing (keystore + secrets) |
| `test/` | New | Golden tests, unit tests, widget tests |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| setBitmap behaves differently across Android 13/14/OEMs | High | Spike in Part 0; matrix testing on stock + Xiaomi |
| Content curation delays entire MVP | Medium | Run in parallel from Day 1; start with 20 phrases + 5 characters minimum |
| WorkManager killed by aggressive OEM battery savers | Medium | Battery guide in-app; test on Xiaomi real device |
| Golden test flakiness across CI environments | Low | Pin font (Google Fonts bundle), deterministic fontFamily, fixed canvas size |

## Rollback Plan

Each part is independently revertible via git. setBitmap spike (Part 0) is a standalone branch — merge only after device matrix passes. CI signing fix is infra-only, zero app code risk.

## MVP Division into Parts

### Part 0 — Spike + Skeleton
- **Goal**: Validate setBitmap works on target devices; wire project foundations
- **Scope IN**: Kotlin MethodChannel (FLAG_LOCK|FLAG_SYSTEM), setBitmap spike on emulator + Xiaomi, add all MVP deps to pubspec (riverpod, shared_preferences, sqflite, workmanager, path_provider), fix CI release signing (generate keystore, add GitHub secrets, update release.yml), golden-test harness (bundle Roboto font, pin fontFamily in tests), basic app shell with Riverpod ProviderScope
- **Scope OUT**: No rendering logic, no UI beyond shell, no content
- **Exit criteria**: setBitmap renders a test PNG on lock screen (emulator + Xiaomi photo proof), `flutter analyze` clean, `flutter test` passes, release.yml produces signed debug APK, golden-test harness runs deterministically
- **Estimated changed lines**: ~500 (Kotlin + Dart + YAML + workflow)
- **Dependency**: None (first part)

### Part 1 — Rendering Engine
- **Goal**: Implement 3-zone layout model and Canvas→PNG pipeline
- **Scope IN**: Zone calculation (system/subject/free), layout filtering by free zone position, subject bbox detection via alpha channel, zoom/pan for subject repositioning, text rendering in free zone (contrast check), Canvas→PNG via PictureRecorder, golden tests for deterministic renders
- **Scope OUT**: No configurator UI, no phrase selection, no wallpaper application
- **Exit criteria**: Given config (bg + subject + phrase + font + clock position) → identical PNG every time (golden test), zone calculation handles all clock presets, text never overlaps subject/system zones
- **Estimated changed lines**: ~600 (engine code + golden baselines)
- **Dependency**: Part 0 (setBitmap infrastructure, deps)

### Part 2 — Configurator UI
- **Goal**: Build the layered swipe configurator with WYSIWYG preview
- **Scope IN**: Horizontal swipe between layers (bg→phrase→character→font), fijo/dinámico toggle per layer, pool management (add/remove from catalog), shuffle button + freeze (congelar), blocked layers (attenuated + suggestion), simulated clock presets (4 positions), WYSIWYG preview wired to render engine, widget tests for swipe/toggle/shuffle flows
- **Scope OUT**: No content yet (placeholder items), no auto-change, no persistence
- **Exit criteria**: User can swipe layers, toggle modes, see preview update in real-time, blocked layers show attenuation + suggestion, widget tests pass
- **Estimated changed lines**: ~700 (UI + widget tests)
- **Dependency**: Part 1 (render engine for preview)

### Part 3 — Content + Motivational Heart
- **Goal**: Wire curated content and phrase-of-the-day selection logic
- **Scope IN**: Bundle 30+ curated English phrases with metadata (category, time-of-day, intensity), bundle 10-15 character PNGs (waist-up, transparent), deterministic phrase-of-the-day (day-of-year → index), anti-repetition via sqlite history, time-of-day weighting in selection, category/intention selector, unit tests for selection algorithm
- **Scope OUT**: No auto-change scheduling, no UI beyond category selector
- **Exit criteria**: Phrase selection is deterministic (same day = same phrase), anti-repetition works (no phrase repeated within 30 days), time-of-day weighting favors appropriate phrases, all unit tests pass
- **Estimated changed lines**: ~500 (data files + selection logic + tests)
- **Dependency**: Part 1 (render engine needs content to render); can start data curation in parallel from Day 1

### Part 4 — Auto-Change Scheduler
- **Goal**: Implement WorkManager-based wallpaper auto-change
- **Scope IN**: WorkManager periodic task, apply rendered wallpaper on schedule, persist config to shared_preferences, survive device restart, configurable interval, battery optimization guidance screen, integration test on real device
- **Scope OUT**: No content curation (already done), no UI beyond settings
- **Exit criteria**: Wallpaper changes automatically at configured interval, config survives reboot, battery guide visible, integration test passes on emulator
- **Estimated changed lines**: ~400 (scheduler + persistence + settings UI)
- **Dependency**: Part 2 (configurator must save config) + Part 3 (content must exist to render)

### Part 5 — Release MVP
- **Goal**: Ship signed APK with full content and documentation
- **Scope IN**: Full content catalog (30+ phrases, 10-15 characters), release APK signed via CI, INSTALL.md guide, smoke test (install → configure → set wallpaper → auto-change), final golden test sweep
- **Scope OUT**: Play Store, marketing, analytics
- **Exit criteria**: APK installs on stock Android 13/14 + Xiaomi, full user flow works end-to-end, README updated, GitHub Release created
- **Estimated changed lines**: ~200 (content finalization, docs, CI)
- **Dependency**: All prior parts

### Content Curation (parallel track, not a code part)
- **Goal**: Prepare all visual and textual content before Part 3 integration
- **Scope**: 30+ English phrases (public domain) with metadata, 10-15 character PNGs (waist-up, transparent background, consistent style), phrase categories mapped to time-of-day
- **Timeline**: Starts Day 1, must be ready by Part 3
- **Owner**: Separate from code delivery; tracked as content artifact

## Success Criteria

- [ ] setBitmap works on Android 13/14 (emulator + Xiaomi)
- [ ] Golden tests produce deterministic renders across CI runs
- [ ] Configurator UI: swipe, toggle, shuffle, preview all functional
- [ ] Phrase-of-the-day is deterministic and anti-repetitive
- [ ] Auto-change fires at configured interval
- [ ] Signed APK installs and runs on target devices
- [ ] All parts under 800 changed lines each
