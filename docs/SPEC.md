# Legon Lift: Build Specification (v1)

Status: definitive build spec, 2026-11-20. It supersedes `docs/research/*.md` wherever they disagree.
Audience: the engineers building the app. You should be able to build the app by reading only this file and the
three data files in `assets/data/`.

Product in one line: an offline Android app that a complete gym beginner carries into the University of Ghana (Legon)
campus gym and follows step by step, from the warm-up to the cool-down, on a 3-day Push / Pull / Legs program built
for body recomposition (lose fat and build muscle), with only the equipment that gym has.

Default user (all onboarding defaults): male, 22 years, 172 cm, 95 kg, complete beginner, goal "recomp", 3 days a week
(Mon/Wed/Fri), 60-minute sessions, Push/Pull/Legs. Phone: Samsung Galaxy A55 (Android 17, 1080x2340, about 412x892 dp).

---

## 0. Ground rules

1. **Offline first.** No network calls except the user-initiated "Watch video" button (opens YouTube outside the app).
   Every image, font, sound and data file is bundled.
2. **Material import.** Flutter 3.50 deprecates `package:flutter/material.dart`. Always
   `import 'package:material_ui/material_ui.dart';`. Never import `flutter/material.dart` (lint rule in 13.4).
3. **Units in storage.** Weights in kg (`double`), lengths in cm, durations in seconds, instants as epoch
   milliseconds UTC (`int`), calendar dates as `yyyy-MM-dd` local strings. Conversion to lb / ft-in happens only in
   the UI (`core/units.dart`).
4. **Weight semantics** (applies to every logged set, prescription and chart):

   | `loadType` | `weightKg` means | Total external load (`totalLoadKg`) |
   |---|---|---|
   | `dumbbell` | weight of ONE dumbbell | `weightKg * dumbbellCount` |
   | `smith`, `barbell` | total on the bar INCLUDING the bar | `weightKg` |
   | `plate_loaded` (leg press) | plates added to the sled (both sides) | `weightKg + (legPressSledKnown ? legPressSledKg : 0)` |
   | `stack`, `cable` | the pin number in kg as printed on the stack | `weightKg` |
   | `bodyweight`, `time` | `0` | `0` |

   Volume of a set = `totalLoadKg * reps * (unilateral ? 2 : 1)`. Reps for unilateral exercises are logged per side.
5. **Plain language.** The UI never shows "RIR", "RPE" or "e1RM". Say "How many more could you have done?",
   "Stop with 2 left in the tank", "Estimated best single". Code and data use the technical names.
6. **One owner per file** (section 13). Shared contracts are created in Phase 0 by WS1 and then frozen; changing a
   contract requires a PR reviewed by every workstream that imports it.

---

## 1. Environment and build

| Item | Value (verified on this machine 2026-11-20) |
|---|---|
| Flutter / Dart | 3.50.0 stable / 3.14.0 at `~/development/flutter` (NOT on PATH: use `~/development/flutter/bin/flutter`) |
| Project | `/home/gbesh/coding/workout`, package `legon_lift`, applicationId `com.gbesh.legon_lift` |
| Android SDK | `/home/gbesh/Android/Sdk`, platforms android-35 and android-36 only; build-tools 36.x |
| Android build | AGP 9.3.1, Kotlin 2.4.20, Gradle 9.5.0, Java 17; `compileSdk = flutter.compileSdkVersion` (36) |
| Tools | `magick` (ImageMagick 7), `rsvg-convert`, `ffmpeg`, `python3` with PIL |

**Dependencies are all in the local pub cache** (`~/.pub-cache`): the full set below was resolved with
`flutter pub get --offline` on 2026-11-20, so no network is needed to build. (expense_tracker's packages were already
cached; the remaining ones were fetched earlier today.)

### 1.1 pubspec.yaml (owned by WS1; exact content of the dependency sections)

```yaml
name: legon_lift
description: "Legon Lift — beginner gym coach for the UG gym"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.14.0

dependencies:
  flutter:
    sdk: flutter
  material_ui: ^1.11.1                    # resolved 1.11.1
  provider: ^6.1.5+1                      # resolved 6.1.5+1
  sqflite: ^2.4.6                         # resolved 2.4.6
  path: ^1.9.1                            # 1.9.1
  path_provider: ^2.1.6                   # 2.1.6
  intl: ^0.20.3                           # 0.20.3
  share_plus: ^13.3.1                     # 13.3.1
  file_picker: ^13.4.0                    # 13.4.0
  url_launcher: ^6.3.3                    # 6.3.3
  uuid: ^4.6.0                            # 4.6.0
  collection: ^1.19.1                     # 1.19.1
  fl_chart: ^1.3.1                        # 1.3.1
  wakelock_plus: ^1.8.2                   # 1.8.2
  flutter_local_notifications: ^22.3.3    # 22.3.3 — NOT 23.x (needs compileSdk 37, not installed)
  timezone: ^0.11.2                       # 0.11.2 (for zonedSchedule)
  audioplayers: ^6.8.1                    # 6.8.1
  confetti: ^0.8.0                        # 0.8.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0                   # 6.0.0
  sqflite_common_ffi: ^2.4.7              # 2.4.7 (DB tests on the VM)
  flutter_launcher_icons: ^0.14.4         # 0.14.4

flutter:
  uses-material-design: true
  assets:
    - assets/data/
    - assets/exercises/
    - assets/sounds/
  fonts:
    - family: BarlowSemiCondensed
      fonts:
        - asset: assets/fonts/BarlowSemiCondensed-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/BarlowSemiCondensed-Bold.ttf
          weight: 700
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Variable.ttf   # variable font; weights via FontVariation

flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon/icon_1024.png"
  adaptive_icon_background: "assets/icon/icon_background_1024.png"
  adaptive_icon_foreground: "assets/icon/icon_foreground_1024.png"
  adaptive_icon_monochrome: "assets/icon/icon_monochrome_1024.png"
  min_sdk_android: 24
```

Rejected: riverpod, drift/hive/isar, shared_preferences (settings live in SQLite so they ride along in backups),
google_fonts (network), cached_network_image, go_router, image_picker (progress photos are out of scope for v1).

### 1.2 Android configuration (WS1)

- `android/app/build.gradle.kts`:
  ```kotlin
  android {
      compileOptions {
          isCoreLibraryDesugaringEnabled = true
          sourceCompatibility = JavaVersion.VERSION_17
          targetCompatibility = JavaVersion.VERSION_17
      }
      defaultConfig { minSdk = 24 }
  }
  dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5") }
  ```
- `AndroidManifest.xml`: `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`,
  `<uses-permission android:name="android.permission.VIBRATE"/>`; no `USE_EXACT_ALARM`; `SCHEDULE_EXACT_ALARM` is
  optional (see 9.3). Add the url_launcher query:
  `<queries><intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent></queries>`.
  Set `android:label="Legon Lift"`.
- `android/app/src/main/res/raw/rest_done.ogg` for the notification channel sound. WS1 owns this copy (it is under
  `android/**`); the source of truth is `assets/sounds/rest_done.ogg` (WS6). `tool/make_sounds.sh` writes only
  `assets/sounds/`; WS1 re-copies when WS6 announces a sound change.

---

## 2. Data files (read-only, bundled)

Built from `docs/research/` by `tool/build_data.py`, images by `tool/fetch_images.py`, checked by
`tool/validate_data.py` (must exit 0 before every merge). **Never hand-edit `assets/data/*.json`**: edit the research
inputs or the build script and rebuild.

```
python3 -I tool/build_data.py && python3 -I tool/fetch_images.py && python3 -I tool/validate_data.py --require-images
```

| File | Shape | Content |
|---|---|---|
| `assets/data/exercises.json` | JSON **array** of 96 exercises | merged library, cross-linked substitutions |
| `assets/exercises/<id>_<n>.jpg` | 180 JPEGs, 560 px max side, 4.6 MB total | two frames per exercise (6 exercises have none) |
| `assets/data/programs.json` | object, `schemaVersion: 1` | 5 programs x 5 phases (14 weeks), progression config |
| `assets/data/personalization.json` | object, `schemaVersion: 1` | onboarding fields, defaults, gym profile, formulas, meals, milestones, PAR-Q, tips |

### 2.1 Exercise record (`exercises.json[i]`)

Fields in this exact order (validator enforces it):

| Field | Type | Notes |
|---|---|---|
| `id` | string | snake_case, unique |
| `name` | string | display name |
| `aliases` | string[] | search terms |
| `category` | enum | `push pull legs core cardio warmup mobility` |
| `primaryMuscles`, `secondaryMuscles` | Muscle[] | `chest front_delts side_delts rear_delts triceps biceps forearms lats upper_back traps lower_back abs obliques quads hamstrings glutes adductors abductors calves cardio` |
| `equipment` | Equipment[] | ALL are needed, except that `bike`+`treadmill` on a cardio entry means either (see 7.6). Vocabulary: `cable lat_pulldown_machine shoulder_press_machine chest_press_machine bike treadmill barbell dumbbell leg_press plates calf_raise_machine leg_curl_machine leg_extension_machine smith_machine bench bodyweight ankle_strap` |
| `mechanic` | enum | `compound isolation` |
| `difficulty` | int | 1 easy, 2 medium, 3 hard |
| `unilateral` | bool | reps logged per side |
| `loadType` | enum | `dumbbell cable time bodyweight stack smith barbell plate_loaded` |
| `weightIncrementKg` | number or null | default step (total for barbell/smith, per dumbbell for dumbbells) |
| `startingWeightKg` | `{low, high, note}` or null | conservative beginner range in the semantics of section 0.4 |
| `defaultSets` | int | |
| `repRange` | `[min, max]` or null | exactly one of `repRange` / `durationSeconds` is set |
| `restSeconds` | int | |
| `durationSeconds` | int or null | timed holds and cardio |
| `setup`, `cues`, `mistakes` | string[] | shown in the player and the detail page |
| `breathing`, `safety` | string | |
| `substitutions` | id[] | ordered most-similar first, max 6, all resolve |
| `freeExerciseDbId` | string or null | credit (free-exercise-db, Unlicense) |
| `images` | url[] | remote originals (build-time only, never fetched by the app) |
| `video` | `{url, title, channel, verified}` or null | pinned YouTube video (oEmbed-verified) |
| `sources` | url[] | references |
| `movementPattern` | enum | `horizontal_push incline_push vertical_push chest_fly horizontal_pull vertical_pull straight_arm_pull rear_delt lateral_raise front_raise elbow_flexion elbow_extension shrug back_extension squat lunge hinge hip_thrust knee_extension knee_flexion calf_raise glute_isolation core cardio mobility stretch` |
| `tracking` | enum | `weight_reps` (loaded), `reps` (bodyweight), `time` |
| `dumbbellCount` | 1, 2 or null | set only for `loadType: dumbbell` |
| `localImages` | string[] | `assets/exercises/<id>_0.jpg`, `_1.jpg` (asset keys) |

Data facts the code must respect:
- The two frames are **not** consistently "start, end" (for some exercises frame 0 is the bottom). The animator shows
  them as an alternating loop with neutral dots, never labelled "Start"/"End".
- Photos often have busy gym backgrounds (not white); frame them in a rounded card with `surface2` padding.
- 6 exercises have no pictures (`localImages: []`): show the `PlaceholderFigure` (muscle icon + name) and the video button.
- `cable_glute_kickback` needs `ankle_strap`, which is not confirmed at the gym (unticked by default).
- `barbell_bench_press` needs uprights or a spotter: never a default, only a substitute shown when the user ticks
  "Bench with uprights + spotter available" in Settings (`AppSettings.hasBenchUprights`).

### 2.2 programs.json

```
{ schemaVersion: 1, defaultProgramId: "ppl_3day",
  progression: {...},             // documentation of section 6 (the code implements section 6, not this text)
  equipmentAssumptions: {...},
  idMigrations: {oldId: newId},   // ids used in the research draft -> library ids (for imports of old backups)
  programs: [ Program ] }

Program { programId, name, default, splitType, splitKey, daysPerWeek, dayOrder[dayId], description, targetUser,
          scheduling: "rotating_pointer", schedulingNotes, recommendedWeekdays[1..7 (Mon=1)],
          totalWeeks: 14, cycleRestartWeek: 5, phases: [Phase] }
Phase   { phaseId: foundation|build|progress|deload|retest, name, weeks[int], goal,
          rirWeekOffsets {"<week>": int}, rirFloorByRole {role: int} | null, loadMultiplier (1.0 | 0.9),
          unlocks [machines|dumbbells|cables|smith_machine|barbell_floor_lifts],
          approxWeeklyDirectSetsPerMuscle {..} | null, days: [Day] }      // days in dayOrder order
Day     { dayId, name, focus[muscle|"core"], notes, estimatedMinutes {core, withOptionalExercises, withFinisher},
          blocks: [Block] }
Block   { blockType: warmup|main|superset|finisher|cooldown, name, optional: bool,
          supersetGroup: "A"|"B"|null, restBetweenRoundsSeconds: int|null, items: [Item] }
Item    { exerciseId, sets, repRange [min,max] | null, durationSeconds | null, rir: int|null, restSeconds,
          role: primary|secondary|accessory|core|warmup|cardio|cooldown|stretch,
          warmupSets: "auto"|0|1, weightIncrementKg: number|null, perSide: bool, optional: bool,
          test: "rir1_rep_test"|null, substitutions [id] (max 4), notes }
```

Programs shipped:

| programId | Split | Days/week | Day order |
|---|---|---|---|
| `ppl_3day` (default) | Push / Pull / Legs | 3 | push, pull, legs |
| `upper_lower_rotating_3day` | Upper/Lower rotating | 3 | upper_a, lower_a, upper_b, lower_b |
| `chest_back_legs_arms_3day` | Chest+Back / Legs / Arms+Shoulders | 3 | chest_back, legs, arms_shoulders |
| `upper_lower_2day` | Upper/Lower | 2 | upper_a, lower_a |
| `upper_lower_4day` | Upper/Lower | 4 | upper_a, lower_a, upper_b, lower_b |

Every program has phases: foundation (weeks 1-4, machines and dumbbells), build (5-8, Smith squat/bench),
progress (9-12, floor-started barbell RDL and row, 5-8 rep main lifts), deload (13), retest (14). Then the cycle
restarts at week 5 (`cycleRestartWeek`). Calves on leg days use `machine_calf_raise` (the gym's "ankle machine",
which the user said is a calf raise machine, `docs/research/USER_NOTES.md`). Every calf slot is `optional` and its
first substitution is `leg_press_calf_raise`, so if the machine turns out to be something else (or is broken) the user
unticks it in Settings > Equipment and nothing else changes. Onboarding step 7 shows the machine's photo with "Is this
the 'ankle machine'?" (yes / no / not sure = keep ticked). Leg curl defaults to `seated_leg_curl`.

### 2.3 personalization.json

Top-level keys: `schemaVersion, app, disclaimer, values_note, defaultProfile, programSelection, gym, defaults,
onboarding, formulas, worked_example, protein_points, daily_checklist, good_day_rule, portion_guide, meal_ideas,
low_protein_foods_pair_with_protein, pantry_protein_boosters, progress_tracking, expectations_timeline, adherence,
safety, milestones, milestone_notes, tips, tips_rotation, references, limitation_rules`. Keys inside are **snake_case** (unlike the
other files); the Dart models map them explicitly. Notable parts:

- `gym`: equipment ids ticked by default, labels, notes, `platesKg [25,20,15,10,5,2.5,1.25]`, `barKg 20`,
  `smithBarKg 10` (`smithBarKnown false`), `legPressSledKg 0` (`legPressSledKnown false`), `legCurlType "seated"`,
  `dumbbellStepKg 2`, `dumbbellMaxKg 40`.
- `programSelection.table`: maps (split, days_per_week) to a programId (custom -> editor).
- `formulas`: BMR (Mifflin-St Jeor), activity multipliers, calorie target, protein (reference weight at BMI 25),
  water, steps. `worked_example` is the unit-test fixture (95 kg, 172 cm, 22 y -> 2,100 kcal, 140 g protein = 7 points,
  water 3,250 / 4,000 ml). **The nutrition numbers in `docs/research/ux_architecture.md` (150 g, 1.45 factor) are
  superseded by this file.**
- `milestones[]`: `{id, category, title, desc, rule}`; exercise rules use `exercise_any: [ids]` (section 10.3).
- `safety`: PAR-Q (7 questions + 3 Ghana-specific), red flags, heat illness, emergency numbers 112 and 193,
  University of Ghana Hospital (Legon).
- `limitation_rules`: one entry per onboarding [limitations] option (`knee lower_back shoulder wrist_elbow hip ankle
  other`): `{avoid_ids: [exerciseId], avoid_patterns: [movementPattern], lock_unlocks?: [unlockKey], cue}`. Used by
  the session builder (6.8 step 3) and the swap suggester (6.9). The validator guarantees every non-optional working
  slot keeps at least one usable replacement under every rule.

---

## 3. Architecture

```
UI (lib/features/**, lib/widgets/**)
   │ context.watch / context.read
   ▼
Stores (lib/state/**, ChangeNotifier)  ──calls──►  Domain (lib/domain/**, pure Dart, no Flutter except foundation.dart)
   │                                                   ▲ plain models only
   └──► Repositories (lib/data/repositories/**) ───────┘
            ├─ AppDatabase (sqflite)
            └─ AssetCatalog (JSON assets, loaded once)
Services (lib/services/**): RestAlarm, Notifications, Sound, Haptics, Wakelock, Launcher — interfaces + impls
```

Rules: UI never imports sqflite; domain never imports Flutter widgets, sqflite or services; every repository and
service has an abstract class and an in-memory fake in `test/fakes/`; stores are the only classes that call
repositories from UI code paths. State management is `provider` with `ChangeNotifier`; no global singletons except
`AssetCatalog` provided at the root.

### 3.1 Folder structure and owners (WS ids from section 13)

```
lib/
  main.dart                                   WS1  bootstrap (3.3)
  app/
    app.dart                                  WS4  LegonLiftApp: MaterialApp, theme, onboarding gate
    routes.dart                               WS4  route names + onGenerateRoute
    shell.dart                                WS4  bottom NavigationBar + IndexedStack (5 tabs)
    theme/tokens.dart                         WS4  palettes A/B/C (section 11)
    theme/app_theme.dart                      WS4  ThemeData builders
    theme/typography.dart                     WS4  text styles
  core/
    units.dart  format.dart  clock.dart  ids.dart  result.dart          WS1
  data/
    models/*.dart                             WS1  section 5
    db/app_database.dart  db/schema.dart  db/migrations.dart             WS1
    assets/asset_catalog.dart                 WS1
    repositories/*.dart                       WS1  section 7.1
    backup/backup_service.dart                WS1
  domain/
    api.dart                                  WS1 (Phase 0) then frozen: domain value types + re-exports (7.2)
    progression_engine.dart  warmup_planner.dart  find_weight.dart  load_rounding.dart
    plate_calculator.dart  one_rep_max.dart  session_builder.dart  schedule.dart
    swap_suggester.dart  pr_detector.dart  deload_advisor.dart  duration_estimator.dart  stats.dart   WS2
    nutrition_calculator.dart  milestone_evaluator.dart  adherence.dart  checkin_advisor.dart       WS6
  services/
    api.dart                                  WS1 (Phase 0) then frozen: service interfaces (7.3)
    rest_alarm_service.dart  notification_service.dart  sound_service.dart
    haptics_service.dart  wakelock_service.dart  launcher_service.dart                               WS3
  state/
    types.dart  settings_store.dart  profile_store.dart                                             WS1
    program_store.dart  today_store.dart                                                            WS4
    session_player_controller.dart                                                                  WS3
    history_store.dart  body_store.dart  library_store.dart                                         WS5
    nutrition_store.dart  milestone_store.dart                                                      WS6
  features/
    onboarding/**  today/**  program/**  you/**                                                     WS4
    session_player/**                                                                               WS3
    library/**  progress/**  body/**                                                                WS5
    nutrition/**  milestones/**  safety/**                                                          WS6
    settings/**  backup/**                                                                          WS1
  widgets/                                    WS4  shared widgets (12.3)
assets/                                       WS6  data/, exercises/, fonts/, sounds/, icon/
tool/                                         WS6  build_data.py, fetch_images.py, validate_data.py, make_icons.sh, make_sounds.sh
docs/research/                                WS6  research inputs
test/fakes/** test/data/**                    WS1
integration_test/**                           WS3  end-to-end DoD flow (onboarding -> week-1 Push -> kill -> resume -> summary)
test/domain/**                                WS2 (WS6 for its domain files: test/domain/nutrition_*, milestone_*, adherence_*)
test/features/<feature>/**                    owner of the feature
android/**  pubspec.yaml  analysis_options.yaml                                                     WS1
```

### 3.2 Routes (`lib/app/routes.dart`, WS4)

| Route name | Screen class (file) | Args |
|---|---|---|
| `/` | `Shell` (app/shell.dart) | |
| `/onboarding` | `OnboardingFlow` (features/onboarding/onboarding_flow.dart) | |
| `/session` | `PlayerScreen` (features/session_player/player_screen.dart) | `PlayerArgs {String? sessionId, String? dayId}` |
| `/session/summary` | `SummaryScreen` (features/session_player/summary_screen.dart) | `String sessionId` |
| `/exercise` | `ExerciseDetailScreen` (features/library/exercise_detail_screen.dart) | `ExerciseDetailArgs {String exerciseId, bool pickMode}` |
| `/program/day` | `DayEditorScreen` (features/program/day_editor_screen.dart) | `String dayId` |
| `/program/split` | `SplitPickerScreen` (features/program/split_picker_screen.dart) | |
| `/history/session` | `SessionDetailScreen` (features/progress/session_detail_screen.dart) | `String sessionId` |
| `/body` | `BodyScreen` (features/body/body_screen.dart) | |
| `/nutrition` | `NutritionScreen` (features/nutrition/nutrition_screen.dart) | |
| `/milestones` | `MilestonesScreen` (features/milestones/milestones_screen.dart) | |
| `/safety` | `SafetyScreen` (features/safety/safety_screen.dart) | |
| `/settings` | `SettingsScreen` (features/settings/settings_screen.dart) | |
| `/backup` | `BackupScreen` (features/backup/backup_screen.dart) | |

Phase 0 creates every screen file above as a stub `StatelessWidget` with that exact class name and constructor, so
routes compile from day one. Owners replace the stub body.

### 3.3 Startup (`main.dart`, WS1)

1. `WidgetsFlutterBinding.ensureInitialized()`.
2. In parallel (`Future.wait`): `AppDatabase.open()`, `JsonAssetCatalog.load(rootBundle)` (decode JSON with
   `compute(jsonDecode, s)` for files > 200 KB).
3. `tz.initializeTimeZones()`; `NotificationService.init()` (creates channels, no permission prompt).
4. Build repositories (sqflite impls) and services (real impls).
5. `runApp(MultiProvider(providers: [Provider<AssetCatalog>, Provider<...Repository>..., Provider<...Service>...,
   ChangeNotifierProvider<SettingsStore>, ProfileStore, ProgramStore, TodayStore, HistoryStore, BodyStore,
   LibraryStore, NutritionStore, MilestoneStore], child: const LegonLiftApp()))`.
   `SessionPlayerController` is created per player route (`ChangeNotifierProvider` inside `PlayerScreen`).
6. `LegonLiftApp`: if `ProfileStore.profile == null` -> `/onboarding`; else `Shell` (Today checks
   `SessionRepository.findInProgress()` for the resume banner).

---

## 4. Features and screens

Reference viewport 412x892 dp; must also work at 360x780 dp and with system font scale 1.3.

### 4.1 Gym-floor rules (requirements)

1. Screen stays awake in the player (`WakelockService.enable()` on open; `disable()` on summary, discard, or 10 min
   in background). Setting `keepAwake` (default on).
2. Every player action writes through to SQLite immediately (set log + cursor in one transaction). Killing the app at
   any moment loses nothing; on relaunch Today shows "Resume workout".
3. Tap targets: min 56 dp; steppers 64 dp; main action 72 dp; >= 8 dp between destructive and primary actions.
4. All primary actions in the bottom 40% of the screen; sheets instead of dialogs; undo snackbars (5 s) instead of
   confirmations. The ONLY confirm dialog is "End workout".
5. Numbers: weights/reps 40 sp, rest countdown 96 sp, tabular figures.
6. No swipe-only or long-press-only actions; reorder uses up/down buttons as well as drag.
7. Hydration nudge ("Sip water") between exercises and on every rest sheet, more often when "Hot today" is on.
8. Beeps duck music (transient focus) instead of stopping it.

### 4.2 Onboarding (WS4) — target under 2 minutes, every step pre-filled

Fields come from `personalization.onboarding.fields` (ids in brackets). Back/Next in the thumb zone, progress dots,
"Skip, use defaults" after step 3.

| # | Step | Content |
|---|---|---|
| 1 | Welcome | "Legon Lift: your step-by-step coach for the UG gym." Optional first name. |
| 2 | Safety check | PAR-Q 7 yes/no questions [parq] + 3 Ghana questions. Any PAR-Q yes -> doctor message from `safety.parq.on_any_yes` with an acknowledgement checkbox ("I've been cleared..."); the program is blocked until ticked (browsing allowed). Ghana answers show their advice (non-blocking). Under-18 age later shows the supervision notice. |
| 3 | Body | units [units], sex, age [age_y], height [height_cm] (ft-in picker if imperial), weight [weight_kg], optional waist [waist_cm] and goal weight [goal_weight_kg]. |
| 4 | Goal & experience | [goal] cards with `labels`; [experience]. |
| 5 | Schedule | [days_per_week] stepper 2-6, weekday chips (default from program `recommendedWeekdays`), [session_minutes] 30/45/60/75, [training_time]. |
| 6 | Split | Cards PPL (Recommended), Upper/Lower, Chest+Back / Legs / Arms+Shoulders, Custom. Program chosen via `programSelection.table`. |
| 7 | Equipment | Checklist from `gym.equipment` with labels (calf raise machine shown as "Calf raise machine ('ankle machine')"); optional `ankle_strap` unticked; "Bench with uprights + spotter" unticked; Smith bar weight (default 10 kg, "Don't know yet" -> `smithBarKnown=false`); leg curl type (seated / lying / don't know = seated); dumbbells available (default `dumbbellStepKg` steps up to `dumbbellMaxKg`); plates. |
| 8 | Limitations & food | [limitations] chips, [activity_level] (hint text), [budget], [diet_notes]. |
| 9 | Plan preview | First week's day cards, "Your first sessions feel light on purpose: we find your starting weights.", targets card (calories, protein points, water). Button **Let's go** saves profile, settings, equipment, activates the program, schedules reminders. |

### 4.3 Today (WS4)

- Resume banner (amber, 72 dp) if a session is `in_progress`: "Push · 3 of 5 done · 24 min" -> `/session`.
  Sessions older than 12 h offer "Finish and save" / "Discard".
- Next workout hero card: day name, phase name + week ("Week 2 of 14 · Foundation"), focus muscles, exercise
  thumbnails, estimated minutes for the user's session length, **START WORKOUT** (64 dp). Links: Preview, "Do a
  different day" (any day in the rotation).
- Pre-start sheet (shown when Start is tapped): "Hot today?" toggle (default on between 11:00 and 17:00),
  "Power cut / cardio machines off" toggle (`cardioOff`, default off), "Fever or malaria in the last 2 weeks?"
  (`recentIllness`), optional readiness check-in (sleep, soreness, energy 1-5 as icons), gap message if 10+ days
  since last session. The sheet shows the session estimate for today's choices ("About 52 min").
- Cards: weekly streak (weeks meeting target, icon not emoji), week strip Mon-Sun (done / planned / today),
  body-weight quick log with 7-day average, protein points and water counters (tap to add), suggestions
  (deload advisor card, calorie check-in card on the weekly check-in day, milestone just earned), "Log cardio"
  (rest-day walk/bike, writes `cardio_logs`), daily tip from `tips` (rotation rules in `tips_rotation`).
- Rest-day state: "Rest day: recovery is when muscles grow. Next: Pull (Wed)." with "Start anyway".
- Week 1 notice on the hero card: "This week's sessions take ~5 min longer while we find your weights; the cardio
  finisher is skipped."

### 4.4 Session player (WS3) — the core

One full-screen route. A session is a flat list of **steps** built by `buildSession` (section 6.8):

`WarmupCardioStep -> MobilityStep(s) -> ExerciseStep x N (or SupersetStep) -> ExtrasStep? -> FinisherStep? -> CooldownStep -> Summary`

**Top bar** (56 dp): close (x -> End workout sheet), day name, segmented progress, elapsed time.

**Timed steps** (warm-up cardio, finisher, cool-down walk, stretches, planks): exercise card, big countdown with
pause/resume, "Done" button, auto-advance with a beep for stretches. Mobility items with reps show a checklist row
with "Done". Equipment hint (bike or treadmill). Stretch items are optional ("Skip stretches").

**Exercise step**:
```
[two-frame animator card 16:10]
Incline Dumbbell Press                     (24 sp, 2 lines max)
3 × 8–12 · rest 2:00 · leave 3 in the tank (16 sp muted; plain-language RIR)
[⇄ Busy? Swap] [▤ Plates*] [? How] [▶ Video]   (*barbell/smith only)
"Shoulder blades pinned to the bench"     (cue carousel, tap = next cue)
Machine note: "seat 4" (editable, per exercise)
SET  PREVIOUS   KG      REPS   ✓
W1   —          10 ×    10     ✔    warm-up rows muted
1    20 × 12    22.5 ×  10     ✔
[ACTIVE ROW: SET 2 · last 20 × 11 ; (–) 22.5 kg (+) ; (–) 10 reps (+)]   64 dp steppers, 40 sp values
3    20 × 10    22.5 ×  10     ○
[ ✓ LOG SET 2 ]   (72 dp)
Skip set · ⋯ More (reorder, skip exercise, add set, remove set, note, "it hurts", end)
```
- Dumbbell weights show "2 × 12.5 kg" (per hand). Stepper step = rounding step for the load type (6.1).
- Tapping a value opens a numeric keypad sheet.
- Find-weight mode (no history): rows labelled F1-F4, banner "Find your weight: pick something you could lift 15
  times. Aim for {targetReps}." (6.2).
- "It hurts" (also in More): marks `painFlag` on the last set, shows the 3/10 rule, offers swap or skip.
- Up-next card between exercises with hydration nudge.

**Log set -> rest sheet** (covers ~75%): "Nice. How many more could you have done?" buttons 0 / 1 / 2 / 3 / 4+
(captions "none left", "easy"); 96 sp countdown ring; −15 / +15; "Next: Set 3 · 22.5 kg × 10"; "Sip some water";
SKIP REST. The RIR answer is optional (null if not answered). Setting `rirPrompt`: every set / last set only / never.
In-session suggestions (6.4) appear on this sheet as a one-tap chip ("Add 2.5 kg for the next set?").

**Rest timer**: deadline-based (`restEndsAt` epoch ms persisted in the cursor). 10 s left: light haptic. 0: three
heavy haptics 150 ms apart + `restDone` sound; if backgrounded, the scheduled notification "Rest over: Set 3 of
Incline DB Press" fires (9.3). A 1 s `Timer.periodic` only repaints.

**Supersets**: items of a superset block alternate A1, B1, rest `restBetweenRoundsSeconds`, A2, B2, ... The rest
sheet appears only after the last item of a round.

**Swap sheet ("Machine busy?")**: three choices: "Wait 2 min / ask to work in" (2:00 timer + etiquette line), "Do the
next exercise first" (reorder: moves this exercise after the next one; a primary may move at most 1 slot), and up to
4 alternatives from `suggestSwaps` (6.9) with thumbnail, name, "why" line. Radio: "Just for today" / "Replace in my
program". Swap keeps the sets/rep target, takes the substitute's own working weight or starts find-weight.
`session_exercises.original_exercise_id` keeps the original id. Used twice in a row "just for today" -> prompt
"Make this your default?".

**Plate calculator sheet**: target total (prefilled), bar weight (20 kg barbell; Smith bar from settings; if
`smithBarKnown` is false show "Smith bar weight unknown: counting the bar as {smithBarKg} kg"), plates available.
Output per side as coloured plate stack + text "Each side: 20 + 5 + 1.25"; if impossible, nearest lower/higher.

**How-to sheet**: setup steps, cues, mistakes, breathing, safety, video button.

**End workout**: dialog "Finish and save" (unfinished sets marked skipped) / "Discard" / "Keep going".

**Dead ends and their exits** (each must be covered by a widget test in `test/features/session_player/`):

| Situation in the gym | What the player offers |
|---|---|
| Machine busy | Swap sheet (above). Superset: swap one member only. All alternatives also busy: "Do the next exercise first"; if it is the last exercise: 2-min wait timer, or skip with reason `busy` |
| Gym does not have it at all (or broken) | Swap sheet option "Not at this gym": sets `ExercisePrefs.hidden = true`, swaps "Replace in my program", and never suggests it again (Settings > Equipment can undo) |
| Wants to do exercises out of order | Tap the segmented progress bar -> step list sheet -> jump to any pending step (`jumpTo(stepIndex)`); skipped/pending steps stay reachable until End |
| Skipped a set | `skipSet` writes no set log; row shows "skipped"; progression treats the exercise as unfinished (6.5) instead of a stall |
| Logged a wrong number | Tap any logged row -> edit sheet (weight, reps, RIR) -> `SessionRepository.updateSet`; delete with 5 s undo |
| App killed, phone died, phone locked | Resume from DB (8): same step, set, find-weight state and rest deadline; a rest that ended while the app was dead shows "Rest over" at once |
| Out of time / leaving early | "End workout" -> Finish and save: finished exercises progress, partly done ones get no verdict, untouched ones are `skipped(no_time)` and stay in the program |
| Bike/treadmill all busy or power cut | Warm-up cardio step: "No machine free" -> runs the warm-up drills twice instead; finisher: "Skip"; Today pre-start toggle `cardioOff` (6.8) |
| Feels unwell / heat | More -> "I feel unwell": heat-illness steps and red flags from `safety`, then End workout (save) |
| Pain | "It hurts" (above) |
| Wants to read the next exercise during rest | Rest sheet shows the next exercise card with "How" and the cue carousel |
| Already trained today | Today shows "Done today"; "Start another session" is under More (no block) |

**Summary** (`/session/summary`): confetti if any PR, first session ever, or a milestone; tiles: duration, sets,
volume, exercises; "New bests" list; "Next time" list (green up +2.5 kg / grey same / amber down, with the reason
string); optional feeling (5 icons), body weight, note; newly earned milestones; **Done** -> Today.

### 4.5 Program (WS4)

- Program tab: program name, phase + week, "Next up: Pull", ordered day cards (name, muscles, exercise count,
  estimated minutes for the user's session length), "Change split", "Rotation order" (up/down + drag, and a "Next
  workout" pointer selector), reminder weekdays and time.
- Day editor (`/program/day`): list of the day's items for the **current phase** with exercise, sets, reps, rest,
  "leave X in the tank". For template programs the editable things are: swap exercise ("Replace in my program" ->
  `program_overrides`, applies to that slot in all phases), toggle optional items on/off. "Reset to template" removes
  overrides. For **custom** programs every field is editable, plus add (Library in pick mode), remove, reorder.
  Live time estimate (6.10), amber above `sessionMinutes`.
- Split picker (`/program/split`): the 5 templates + "Custom from blank" + "Custom from PPL". Switching keeps all
  history; progression is per exercise, so weights carry over. The new program starts at week 1 unless the user picks
  "Start at Phase 2" (only offered if >= 8 completed sessions).

### 4.6 Library (WS5)

Search (name + aliases, accent/case-insensitive), filter chips: muscle groups (Chest, Back = lats+upper_back,
Shoulders = 3 delts, Biceps, Triceps, Quads, Hamstrings, Glutes, Calves, Core = abs+obliques+lower_back, Cardio,
Mobility) and equipment (only ticked equipment; "Show all" toggle). "Beginner friendly" (difficulty 1) chip on by
default. Row: thumbnail, name, primary muscle, equipment icon, favourite star.
Detail (`/exercise`): large animator, muscles worked chips, setup, cues, mistakes, breathing, safety, video
button (pinned `video.url`; if null, `https://www.youtube.com/results?search_query=<name>+proper+form`; "Needs
internet" badge; `url_launcher` external application), my history (best set, estimated-best sparkline, last 5
sessions), machine note, alternatives (tap to open), credits line (free-exercise-db). Pick mode adds an "Add" FAB.

### 4.7 Progress (WS5)

Segmented: **Overview** (sessions this month; weekly volume bar chart, last 12 weeks; hard sets per muscle this week
as horizontal bars with the 10-20 target band shaded; recent PRs), **Exercises** (pick exercise -> estimated best
single line chart, Epley, best per session, reps <= 12 only; toggles heaviest weight / best-set volume),
**Body** (daily weight dots + 7-day average line; waist chart; recomp insight card), **Calendar** (20-week heatmap
via CustomPainter, intensity = working sets; month calendar; tap -> session detail). Session detail: exercises,
sets, notes, editable after the fact, "Repeat this workout" (starts that day).

### 4.8 Body (WS5)

Weight (0.1 kg stepper), waist (cm at navel), date (default today; one entry per date; edit replaces). Guidance text
from `progress_tracking.weigh_in`. 7-day average needs >= 3 weigh-ins in the window, otherwise show "Need 3 weigh-ins".

### 4.9 Nutrition helper (WS6)

Not a food logger. Shows targets from `nutritionTargets` (calories as a range ±100 kcal, protein grams and **points**
of 20 g, water ml and 500 ml sachets for rest/training day, steps), daily checklist from `daily_checklist`
(protein points counter in 0.5 steps, water sachet counter, 4 yes/no items, optional steps number), "good day"
rule, protein point examples (`protein_points.items`), meal ideas (filter by meal type, cost tier, diet notes;
exclude meals whose `contains` clash with `diet_notes`), portion guide, weekly check-in card (10.2), expectations
timeline, disclaimer at the top. Recalculate targets every 4 kg lost or 8 weeks (`formulas.recalculate_targets`).

### 4.10 Milestones (WS6)

Badge wall grouped by category (consistency, strength, body, habit), earned with date, locked ones greyed with the
`desc`. Evaluation in 10.3, run after each session completion, body entry, nutrition day save, and daily on app open.

### 4.11 Safety (WS6)

Red flags (stop now), heat illness table with actions, heat prevention tips, 3/10 pain rule, emergency card with
tap-to-call 112 and 193 (`tel:` via url_launcher) and "University of Ghana Hospital, Legon", optional emergency
contact (name + phone in profile), PAR-Q re-check (every 12 months a Today card prompts it).

### 4.12 You hub, Settings, Backup

- **You** (WS4): profile summary + edit (reuses onboarding step widgets), links to Body, Nutrition, Milestones,
  Safety, Settings, Backup, About/credits.
- **Settings** (WS1): Units; Equipment (ticked list, plates, bar 20 kg, Smith bar + known flag, leg press sled +
  known flag, leg curl type, dumbbells available list, bench uprights flag, ankle strap); Workout (rest compound /
  isolation defaults, auto-start rest, `rirPrompt`, warm-up sets on/off, warm-up & cool-down blocks on/off,
  hydration nudges, hot-day auto); Feedback (sound, vibration, rest notification, keep screen awake); Reminders
  (workout days + time, weigh-in time, gym-bag evening reminder); Appearance (theme dark/light/system, palette
  A/B/C, large text); Data (backup, reset all data with typed confirmation "RESET"); About.
- **Backup** (WS1): Export (JSON via share sheet or "Save to device" with `FilePicker.saveFile`), Import
  (`FilePicker.pickFiles`, preview counts, Replace or Merge), automatic weekly backup to app documents (keep last 4).

---

## 5. Data models (Dart; `lib/data/models/`, WS1)

All models: `@immutable`, `const` constructors, `copyWith`, `==`/`hashCode` (use `collection`'s `ListEquality`
where needed), `toMap()/fromMap()` for SQLite rows and `toJson()/fromJson()` for assets and backup. Enums carry a
`wire` string (the JSON/DB value) and `static X fromWire(String)` that throws `FormatException` on unknown values.

### 5.1 enums.dart

```dart
enum ExerciseCategory { push, pull, legs, core, cardio, warmup, mobility }           // wire = name
enum Muscle { chest('chest'), frontDelts('front_delts'), sideDelts('side_delts'), rearDelts('rear_delts'),
  triceps('triceps'), biceps('biceps'), forearms('forearms'), lats('lats'), upperBack('upper_back'),
  traps('traps'), lowerBack('lower_back'), abs('abs'), obliques('obliques'), quads('quads'),
  hamstrings('hamstrings'), glutes('glutes'), adductors('adductors'), abductors('abductors'),
  calves('calves'), cardio('cardio'); const Muscle(this.wire); final String wire; }
enum Equipment { cable('cable'), latPulldownMachine('lat_pulldown_machine'),
  shoulderPressMachine('shoulder_press_machine'), chestPressMachine('chest_press_machine'), bike('bike'),
  treadmill('treadmill'), barbell('barbell'), dumbbell('dumbbell'), legPress('leg_press'), plates('plates'),
  calfRaiseMachine('calf_raise_machine'), legCurlMachine('leg_curl_machine'),
  legExtensionMachine('leg_extension_machine'), smithMachine('smith_machine'), bench('bench'),
  bodyweight('bodyweight'), ankleStrap('ankle_strap'); ... }
enum Mechanic { compound, isolation }
enum LoadType { dumbbell('dumbbell'), cable('cable'), time('time'), bodyweight('bodyweight'), stack('stack'),
  smith('smith'), barbell('barbell'), plateLoaded('plate_loaded'); ... }
enum MovementPattern { horizontalPush('horizontal_push'), inclinePush('incline_push'), verticalPush('vertical_push'),
  chestFly('chest_fly'), horizontalPull('horizontal_pull'), verticalPull('vertical_pull'),
  straightArmPull('straight_arm_pull'), rearDelt('rear_delt'), lateralRaise('lateral_raise'),
  frontRaise('front_raise'), elbowFlexion('elbow_flexion'), elbowExtension('elbow_extension'), shrug('shrug'),
  backExtension('back_extension'), squat('squat'), lunge('lunge'), hinge('hinge'), hipThrust('hip_thrust'),
  kneeExtension('knee_extension'), kneeFlexion('knee_flexion'), calfRaise('calf_raise'),
  gluteIsolation('glute_isolation'), core('core'), cardio('cardio'), mobility('mobility'), stretch('stretch'); ... }
enum Tracking { weightReps('weight_reps'), reps('reps'), time('time'); ... }
enum BlockType { warmup, main, superset, finisher, cooldown }
enum ItemRole { primary, secondary, accessory, core, warmup, cardio, cooldown, stretch }
enum PhaseId { foundation, build, progress, deload, retest, custom }
enum SetKind { warmup, ramp, working, test, calibration }   // ramp = find-weight sets
enum SessionStatus { inProgress('in_progress'), completed('completed'), discarded('discarded'); ... }
enum SessionExerciseStatus { pending, active, done, skipped }
enum SkipReason { busy, pain, noTime('no_time'), other; ... }
enum Trend { up, same, down, calibrate, deload }
enum Sex { male, female }
enum Goal { recomp, fatLoss('fat_loss'), muscleGain('muscle_gain'), maintain; ... }
enum Experience { never('never'), lt3Months('lt_3_months'), m3to12('3_to_12_months'), gt1Year('gt_1_year'); ... }
enum ActivityLevel { sedentary, lightlyActive('lightly_active'), moderatelyActive('moderately_active'),
  veryActive('very_active'), extraActive('extra_active'); ... }
enum SplitKey { pushPullLegs('push_pull_legs'), upperLower('upper_lower'),
  chestbackLegsArmsshoulders('chestback_legs_armsshoulders'), fullBody('full_body'), custom('custom'); ... }
enum LegCurlType { seated, lying }
enum RirPrompt { every, last, never }
enum ThemeModePref { dark, light, system }
enum PaletteId { legonNight('legon_night'), kenteEnergy('kente_energy'), voltTeal('volt_teal'); ... }
enum PrType { e1rm, maxWeight('max_weight'), bestVolume('best_volume'); ... }
```

### 5.2 Asset models

```dart
// exercise.dart
class StartingWeight { final double low, high; final String note; }
class ExerciseVideo { final String url, title, channel; final bool verified; }
class Exercise {
  final String id, name; final List<String> aliases; final ExerciseCategory category;
  final List<Muscle> primaryMuscles, secondaryMuscles; final List<Equipment> equipment;
  final Mechanic mechanic; final int difficulty; final bool unilateral; final LoadType loadType;
  final double? weightIncrementKg; final StartingWeight? startingWeightKg; final int defaultSets;
  final (int, int)? repRange; final int restSeconds; final int? durationSeconds;
  final List<String> setup, cues, mistakes; final String breathing, safety;
  final List<String> substitutions; final String? freeExerciseDbId;
  final ExerciseVideo? video; final List<String> sources;
  final MovementPattern movementPattern; final Tracking tracking; final int? dumbbellCount;
  final List<String> localImages;           // asset keys
  // derived getters
  bool get isLoaded => tracking == Tracking.weightReps;
  bool get needsBarMath => loadType == LoadType.smith || loadType == LoadType.barbell;
  String get unlockKey => switch (loadType) { LoadType.smith => 'smith_machine',
      LoadType.barbell => 'barbell_floor_lifts', _ => 'always' };
}

// program_template.dart
class ProgramItem { final String exerciseId; final int sets; final (int, int)? repRange; final int? durationSeconds;
  final int? rir; final int restSeconds; final ItemRole role; final Object warmupSets; // 'auto' | 0 | 1
  final double? weightIncrementKg; final bool perSide, optional; final String? test;
  final List<String> substitutions; final String notes;
  String slotKey() => '${role.name}:$exerciseId'; }       // identity used by overrides
class ProgramBlock { final BlockType blockType; final String name; final bool optional; final String? supersetGroup;
  final int? restBetweenRoundsSeconds; final List<ProgramItem> items; }
class EstimatedMinutes { final int core, withOptionalExercises, withFinisher; }
class ProgramDay { final String dayId, name; final List<String> focus; final String notes;
  final EstimatedMinutes estimatedMinutes; final List<ProgramBlock> blocks; }
class Phase { final PhaseId phaseId; final String name; final List<int> weeks; final String goal;
  final Map<int, int> rirWeekOffsets; final Map<ItemRole, int>? rirFloorByRole; final double loadMultiplier;
  final Set<String> unlocks; final List<ProgramDay> days; }
class ProgramTemplate { final String programId, name; final bool isDefault; final String splitType;
  final SplitKey splitKey; final int daysPerWeek; final List<String> dayOrder; final String description;
  final List<int> recommendedWeekdays; final int? totalWeeks; final int cycleRestartWeek;
  final List<Phase> phases; }
  // custom programs: totalWeeks == null, exactly one Phase(phaseId: custom, weeks: [1], unlocks: all)

// personalization.dart — typed views over the parts the code needs; the rest stays Map<String, dynamic>
class GymProfileDefaults { final List<Equipment> equipment; final List<Equipment> optionalEquipment;
  final Map<String, String> equipmentLabels, equipmentNotes; final List<double> platesKg;
  final double barKg, smithBarKg, legPressSledKg, dumbbellStepKg, dumbbellMaxKg; final LegCurlType legCurlType; }
class Milestone { final String id, category, title, desc; final Map<String, Object?> rule; }
class MealIdea { final String id, name, mealType; final List<String> components; final int proteinG, kcalApprox;
  final String costTier, tips; final List<String> tags, contains; }
class ParqQuestion { final String id, text; final String? note; }
class Personalization { final Map<String, dynamic> raw; final GymProfileDefaults gym;
  final Map<String, dynamic> formulas, workedExample, defaultProfile, programSelection, defaults;
  final List<Milestone> milestones; final List<MealIdea> meals; final List<ParqQuestion> parq;
  final Map<String, List<String>> tips; final Map<String, dynamic> limitationRules; }   // 'limitation_rules' 
```

### 5.3 Runtime models

```dart
class UserProfile { final String? name; final Sex sex; final int ageY; final double heightCm, weightKg;
  final double? goalWeightKg, startWaistCm; final ActivityLevel activityLevel; final Goal goal;
  final Experience experience; final int daysPerWeek, sessionMinutes; final List<int> workoutWeekdays; // 1=Mon
  final String trainingTime; final SplitKey split; final List<String> limitations; final String budget;
  final List<String> dietNotes; final int? baselineSteps; final bool parqAnyYes, parqCleared;
  final Map<String, String> ghanaAnswers; final DateTime parqAnsweredAt; final String? emergencyName,
  emergencyPhone; final bool useLb, useFtIn; final DateTime createdAt; }

class EquipmentProfile { final Set<Equipment> available; final List<double> platesKg; final double barKg,
  smithBarKg; final bool smithBarKnown; final double legPressSledKg; final bool legPressSledKnown;
  final LegCurlType legCurlType; final List<double> dumbbellsKg; final bool hasBenchUprights; }

class AppSettings { final bool keepAwake, sound, vibration, restNotification, autoRest, warmupSets,
  warmupBlock, cooldownBlock, hydrationNudges, hotDayAuto, largeText; final RirPrompt rirPrompt;
  final int restCompoundSec, restIsolationSec; final ThemeModePref themeMode; final PaletteId palette;
  final String? reminderTime /*HH:mm*/, weighInTime; final bool gymBagReminder; final EquipmentProfile equipment; }

class ActiveProgram { final String id /*uuid*/; final String? templateId; final ProgramTemplate? customTemplate;
  final String name; final List<String> dayOrder; final int nextDayIndex; final DateTime startedAt;
  final int cycle; final int startWeek; final int reactiveDeloadRemaining; final bool isActive; }
class ProgramOverride { final String programId, dayId, slotKey, exerciseId; final bool? optionalEnabled; }

class ReadinessCheck { final int? sleep, soreness, energy; }   // 1..5
class PlayerCursor { final int stepIndex, setIndex; final DateTime? restEndsAt;
  final FindWeightState? findWeight; final List<int> visitedSteps; }   // stored as JSON in sessions.cursor_json
class Session { final String id, programId; final String? templateId; final PhaseId phaseId;
  final int trainingWeek; final String dayId, dayName; final SessionStatus status; final DateTime startedAt;
  final DateTime? endedAt; final bool isDeload, hotDay; final ReadinessCheck readiness; final double? bodyweightKg;
  final int? feeling; final String? note; final PlayerCursor? cursor; final SessionPlan plan;
  final double totalVolumeKg; final List<SessionExercise> exercises; }
class SessionExercise { final String id, sessionId, exerciseId, slotKey; final String? originalExerciseId;
  final int position, blockIndex; final BlockType blockType; final String? supersetGroup; final ItemRole role;
  final SessionExerciseStatus status; final SkipReason? skipReason; final Prescription target;
  final String? note; final List<SetLog> sets; }
class SetLog { final String id, sessionExerciseId, sessionId, exerciseId; final int setIndex; final SetKind kind;
  final double? targetKg; final int? targetReps; final double weightKg; final int reps; final int? durationSec;
  final int? rir; final int? calibrationExtraReps; final bool painFlag; final DateTime completedAt; final bool isPr; }

class ExerciseState { final String exerciseId; final double? workingKg; final List<int> repTargets;
  final int stallCount, resetCount; final Trend lastTrend; final String lastReason; final String? lastSessionId;
  final (int, int)? lastRepRange; final double? firstE1rm, bestE1rm; final double? lastJumpPct;  // 6.5 grace
  final DateTime updatedAt; }
class PersonalRecord { final String exerciseId; final PrType type; final double value; final String setLogId;
  final DateTime achievedAt; }
class ExercisePrefs { final String exerciseId; final bool favorite, hidden; final double? incrementKg;
  final String? machineNote; final DateTime? lastPainAt; }
class BodyEntry { final String date; final double? weightKg, waistCm; final String? note; }
class NutritionDay { final String date; final double proteinPoints, waterSachets; final bool vegFruit, stepsHit,
  sleepOk, noSugaryDrinks; final int? steps; }
class CardioLog { final String id, date, exerciseId; final int durationSec; final String? note; }
class MilestoneAward { final String milestoneId; final DateTime awardedAt; final Map<String, Object?> context; }
class Pause { final String id; final String kind; /* pause|tag */ final String reason; final String startDate;
  final String? endDate; }
class CalorieAdjustment { final String id, date, ruleId; final int deltaKcal; final int? deltaSteps; }

// domain value types (lib/domain/api.dart)
class PlannedSet { final SetKind kind; final double weightKg; final int reps; final int? durationSec;
  final int? targetRir; }
class Prescription { final String exerciseId; final List<PlannedSet> warmups; final List<PlannedSet> working;
  final int restSec; final int? targetRir; final Trend trend; final String reason; final bool findWeight;
  final double incrementKg; }
sealed class SessionStep { final int index; }
class WarmupCardioStep extends SessionStep { final ProgramItem item; }
class MobilityStep extends SessionStep { final List<ProgramItem> items; }
class ExerciseStep extends SessionStep { final ProgramItem item; final Prescription rx; final String slotKey; }
class SupersetStep extends SessionStep { final String group; final List<ExerciseStep> members; final int roundRestSec; }
class FinisherStep extends SessionStep { final ProgramItem item; final int durationSec; }
class ExtrasStep extends SessionStep { final List<ExerciseStep> extras; }   // 6.8 "Extras if you have time"
class CooldownStep extends SessionStep { final List<ProgramItem> items; }
class SessionPlan { final String programId; final String? templateId; final PhaseId phaseId; final int trainingWeek;
  final String dayId, dayName; final bool isDeload, hotDay, includesFinisher; final int estimatedMinutes;
  final List<SessionStep> steps; final List<String> notices; }
class FindWeightState { final double currentKg; final double? previousKg; final int step; final int targetReps;
  final int targetRir; }
sealed class RampResult {}  class RampNext extends RampResult { final double nextKg; }
class RampDone extends RampResult { final double workingKg; }
class WarmupSet { final double weightKg; final int reps; }
class PlateResult { final double totalKg; final List<double> perSide; final bool exact; final double? lowerKg,
  higherKg; }
class SwapOption { final Exercise exercise; final String why; final bool hasHistory; }
class DeloadAdvice { final bool suggest; final List<String> reasons; }
class NutritionTargets { final double bmi; final int bmrKcal, tdeeKcal, calorieTargetKcal, proteinMinG,
  proteinTargetG, proteinMaxG, proteinPointsTarget, proteinPointsGoodDay, waterRestMl, waterTrainingMl,
  stepsTarget; final double referenceWeightKg; final (double, double) ratePctPerWeek; }
```

---

## 6. Training engine (WS2; exact behaviour)

All functions are pure and live in `lib/domain/`. Constants:

```
WORK_S = 40; PER_SIDE_WORK_S = 70; TRANSITION_S = 90; WARMUP_SET_S = 75     // duration model
HOT_EXTRA_REST = 30; WARMUP_REST = 45
```

### 6.1 Load rounding (`load_rounding.dart`)

```
increment(ex, item, prefs) = prefs.incrementKg ?? item.weightIncrementKg ?? ex.weightIncrementKg ?? 2.5

availableLoads(ex, eq, prefs):
  dumbbell     -> eq.dumbbellsKg (sorted; default dumbbellStepKg..dumbbellMaxKg in dumbbellStepKg steps)
  smith        -> { bar + 2*s : s in achievablePerSide(eq.platesKg) }, bar = eq.smithBarKg
  barbell      -> same with bar = eq.barKg
  plate_loaded -> { 2*s : s in achievablePerSide(eq.platesKg) }  (0 allowed)
  stack, cable -> { k * increment : k = 1..60 }
  bodyweight, time -> {0}
achievablePerSide(plates): all sums of a multiset of plates with each plate size usable up to 4 times per side, <= 150 kg
roundToAvailable(w)  = nearest available load (ties -> lower)
roundDown(w)         = largest available load <= w (or the smallest available load)
nextUp(w)            = smallest available load > w (or w if none)
```

### 6.2 First exposure: "find your weight" ramp (`find_weight.dart`)

Used when `ExerciseState.workingKg == null` for a loaded exercise **with role primary or secondary**, or when forced
by the >21-day gap rule. Loaded accessory/core items with no history use **quick start** instead: every working set is
prescribed at `seed(...)` (no ramp sets), and 6.4 rule 1 applies after every set (not only set 1), so the weight moves
up within the session if it is too light. Reason: ramping all ~5 loaded exercises made week-1 sessions 10-25 min
longer (Arms+Shoulders day: 70 min); ramping only the big lifts keeps every week-1 day <= 55 min at the 60-min setting.

```
seed(ex, eq, lastKnown?):
  if lastKnown != null: return roundDown(lastKnown)
  if SEED_TRANSFER[ex.id] has a source with a known workingKg: return roundDown(that formula)   // table below
  if ex.startingWeightKg == null: return smallest available load
  return roundDown(ex.startingWeightKg.low)            // per dumbbell / total bar / added plates / pin

start(ex, item, rir): FindWeightState(currentKg: seed, previousKg: null, step: 1,
                                      targetReps: item.repRange.min + 2, targetRir: rir ?? 3)

findWeightStep(s, repsDone, reportedRir /*0..4, null -> treat as targetRir+1*/, formBrokeOrPain) -> RampResult:
  if formBrokeOrPain: return RampDone(roundDown(s.previousKg ?? s.currentKg * 0.8))
  r     = reportedRir ?? s.targetRir + 1
  e1rm  = s.currentKg * (1 + (repsDone + r) / 30)
  ideal = e1rm / (1 + (s.targetReps + s.targetRir) / 30)       // load that gives targetReps @ targetRir
  cand  = roundToAvailable(ideal)
  if cand < s.currentKg:  return RampDone(max(roundDown(ideal), smallest available load))   // too heavy: stop ramping
  if cand == s.currentKg: return RampDone(s.currentKg)                                       // close enough
  if s.step == 4:         return RampDone(roundDown(ideal))
  next = min(cand, roundDown(s.currentKg * 1.5)); if next <= s.currentKg: next = nextUp(s.currentKg)
  return RampNext(next)        // new state: previousKg = currentKg, currentKg = next, step + 1
```

This version is reps-aware (the earlier draft accepted a weight whenever the RIR answer matched, even if he only
managed 5 of 10 reps) and never asks for more than 4 ramp sets. Test table (WS2): seed 20 kg stack, target 10 @ 3:
`(18 reps, rir 4) -> Next 25`; `(10, 3) -> Done 20`; `(6, 1) -> Done 15`; `(10, null) -> Done 20`; pain -> `Done 15`
(0.8x = 16, rounded down to the 5 kg stack step).

`SEED_TRANSFER` (lifts that appear in later phases seed from the lift they replace, so week 5/9 ramps are short):

| New exercise | Source (its `workingKg`) | Seed formula (then `roundDown`) |
|---|---|---|
| `smith_machine_bench_press` | `machine_chest_press` | `0.8 * src` (total incl. bar) |
| `smith_machine_squat` | `leg_press` | `max(smithBarKg + 10, 0.4 * src)` |
| `barbell_romanian_deadlift` | `dumbbell_romanian_deadlift` | `1.6 * src` (src is per dumbbell) |
| `barbell_bent_over_row` | `chest_supported_db_row` or `one_arm_db_row` | `1.5 * src` |
| `seated_dumbbell_shoulder_press` | `machine_shoulder_press` | `0.35 * src` per dumbbell |

Player: ramp sets are logged with `kind = ramp`, rest 75 s, are not counted as working sets, and after
`RampDone` the remaining working sets are `max(1, item.sets - 1)` at the found weight. The found weight becomes
`ExerciseState.workingKg` at session completion. Ramp sets replace warm-up sets for that exercise. The live
`FindWeightState` is persisted in `PlayerCursor.findWeight` on every ramp set, so killing the app mid-ramp resumes
at the same step. If the user skips the exercise mid-ramp, nothing is saved for it (next session ramps again,
seeded from the last ramp set's weight via `lastKnown`).
Dumbbell ramp: same maths on the per-dumbbell weight.

### 6.3 Warm-up sets (`warmup_planner.dart`)

Only for `tracking == weight_reps`, only if `AppSettings.warmupSets`, never in find-weight mode.

```
planWarmups(W, ex, item, eq):
  if item.warmupSets == 0: return []
  minLoad = smith ? eq.smithBarKg : barbell ? eq.barKg : plate_loaded ? 0 : smallest available load
  if ex.loadType == dumbbell: return item.warmupSets == 0 ? [] : [ (roundDown(0.5W), 10) ]
  if item.warmupSets == 1: return [ (roundDown(0.6W), 6) ]
  // "auto"
  if W <= minLoad * 1.5 or W < 30: sets = [ (0.5W, 10) ]
  else: sets = [ (0.5W, 8), (0.7W, 5) ]; if W >= 60: sets += [ (0.85W, 2) ]
  return dedupe([ (max(minLoad, roundDown(load)), reps) for (load, reps) in sets if roundDown(load) < W ])
```
Warm-up rest 45 s; logged with `kind = warmup`; never count for volume, PRs or progression.

### 6.4 In-session autoregulation (suggestions, never automatic)

After each working set `i` (reps, rir) of an exercise with rep range [lo, hi] and target RIR t:
1. If (`i == 1`, or any `i` while the exercise is in quick start, 6.2) and `reps >= hi + 3` and `(rir ?? t) >= t`:
   suggest "Add {increment} for the next set" (one tap).
2. If `reps < lo - 2` (`lo - 4` in the first session after a jump > 10%, see 6.5 `grace`) (too heavy): set the next
   sets' target to `roundDown(load - increment)` automatically and show "Lighter for the next set: that was too
   heavy." (this one IS automatic).
3. If `rir == 0 and reps < lo`: next set target `roundDown(load * 0.9)` (automatic, same message).
4. Pain flag: offer swap/skip; never continue suggesting heavier loads.

### 6.5 Double progression after a session (`progression_engine.dart`)

Runs at session completion for every exercise with >= 1 working set (`kind == working`), not on deload or retest
sessions (those leave `ExerciseState` unchanged except `bestE1rm`), not for `tracking != weight_reps`.

```
afterSession(state, ex, item, sets /*working, in order*/, lastExposure /*sets of the previous session of this exerciseId*/,
             eq, prefs) -> ExerciseState:
  load = the most common weight among sets (ties -> the higher one)
  lo, top = item.repRange; t = effectiveRir(item)           // 6.7; t == null -> rirOK is true
  planned = number of working sets in the session plan for this exercise (after swaps / add / remove set)
  if len(sets) < planned:      // skipped sets or ended early (find-weight: planned = max(1, sets - 1)): no verdict
      state stays (workingKg, repTargets, stallCount unchanged), trend: same,
      reason: "Unfinished last time: same target"; then apply only the pain rule below, return
  inc = increment(ex, item, prefs)
  jump = (nextUp(load) - load) / max(load, 1)                // real next step for this equipment
  effTop = top + (jump > 0.20 ? 3 : jump > 0.10 ? 2 : 0)    // small-load guard
  rirOK = all(s.rir == null or s.rir >= t - 1 for s in sets)

  if all(s.reps >= effTop for s in sets) and rirOK:
      bonus = all(s.reps >= effTop + 2 and (s.rir ?? 0) >= t + 1 for s in sets)
      next = bonus ? nextUp(nextUp(load)) : nextUp(load)
      return state(workingKg: next, repTargets: [lo]*n, stall: 0, trend: up,
                   reason: "You hit ${reps joined ', '} last time: +${fmt(next-load)}")
  progressed = lastExposure == null or sum(reps) > sum(lastExposure.reps) or load > lastExposure.load
  if progressed:
      return state(workingKg: load, repTargets: [min(s.reps + 1, effTop) for s in sets] (pad with lo),
                   stall: 0, trend: same, reason: "Same weight: beat ${weakest} reps on your weakest set")
  stall = state.stallCount + 1
  if stall >= 3:
      return state(workingKg: roundDown(load * 0.90), repTargets: [lo]*n, stall: 0, resetCount: +1,
                   trend: down, reason: "3 sessions without progress: -10% to build back up"),
             and if resetCount + 1 >= 2: flag suggestSubstitution (Today card "Try a variation?")
  return state(workingKg: load, repTargets: [s.reps + 1 capped at effTop], stall: stall, trend: same,
               reason: "Same weight, aim for one more rep")

  // applied after the above:
  grace = state.lastTrend == up and (state.lastJumpPct ?? 0) > 0.10      // first session after a big jump
  if sets[0].reps < lo - (grace ? 4 : 2): workingKg = roundDown(load - inc); trend = down; reason = "Too heavy last time"
  lastJumpPct = trend == up ? (workingKg - load) / max(load, 1) : null
  // Why: a 4 -> 6 kg dumbbell step is +50%. Without the grace he hits 9 reps at 6 kg, the old rule sent him back
  // to 4 kg, he earned 6 kg again, and so on forever. With it, 8-9 reps at the new weight is accepted as a
  // start and the normal "+1 rep" path takes over.
  if any(s.painFlag): workingKg = min(workingKg, roundDown(load * 0.9)); trend = down;
                      prefs.lastPainAt = now; reason = "Lighter after the pain flag"
  bestE1rm = max(bestE1rm, best epley over sets with reps <= 12); firstE1rm ??= that value
  lastRepRange = item.repRange
```

`prescribe(...)` (used by the session builder):
```
prescribe(ex, item, phase, week, state, history, eq, prefs, gap, isDeload) -> Prescription:
  t = effectiveRir(item, phase, week) + gap.rirBonus (cap 4); if isDeload: t = 4
  if tracking == time: working = [ (0, 0, duration = item.durationSeconds) ] * item.sets
  if tracking == reps: working = [ (0, item.repRange.max) ] * item.sets          // bodyweight
  if state.workingKg == null or gap.forceFindWeight(item.role): findWeight = true; working = seed-based plan
  else:
     W = state.workingKg
     if state.lastRepRange != null and state.lastRepRange != item.repRange:     // phase transition
         e = state.bestE1rm ?? W*(1+(state.repTargets.first + t)/30)
         mid = (item.repRange.min + item.repRange.max) / 2
         W = roundDown(e / (1 + (mid + t) / 30))
     W = roundToAvailable(W * phase.loadMultiplier * gap.loadMultiplier)
     reps = state.repTargets (length item.sets, pad/truncate with item.repRange.min), clamp to [lo, effTop]
     working = [ (W, reps[i], targetRir: t) for i in 0..sets-1 ]
  warmups = findWeight ? [] : planWarmups(W, ex, item, eq)
  rest = item.restSeconds + (hotDay ? 30 : 0)
  trend/reason from state (or calibrate: "First time: we'll find your weight")
```

### 6.6 Retest and calibration

- Retest item (`test == "rir1_rep_test"`): one set at the last Phase-3 working weight (`workingKg`), target "as many
  good reps as possible, stop with ~1 left". After the set: `e1rm = w * (1 + (reps + 1)/30)`; store as PR candidate;
  summary shows "Week 1 vs now: {firstE1rm} -> {e1rm} (+x%)". Then a back-off set at 80% x 8 (RIR 3), logged as working.
- Calibration set: in training weeks 6 and 10 (once per week, first session of that week), on the
  LAST set of the first exercise in the session with `mechanic == isolation` and loadType `stack` or `cable`. Before
  the set: "Calibration set: do your reps, tell us how many you think are left, then keep going until you can't
  do another clean rep." Log `rir` (predicted) and `calibrationExtraReps` (actual). Rest sheet shows "You predicted
  {rir}, you actually had {extra}." Never on smith, barbell, dumbbell pressing, squat or hinge patterns.

### 6.7 Schedule and effective RIR (`schedule.dart`)

```
completedNonDeload = completed sessions of this active program with is_deload == 0 (reactive deload sessions excluded)
rawWeek = active.startWeek + completedNonDeload ~/ template.daysPerWeek          // startWeek default 1
trainingWeek(rawWeek):
  if template.totalWeeks == null: return 1                                         // custom
  if rawWeek <= totalWeeks: return rawWeek
  span = totalWeeks - cycleRestartWeek + 1
  return cycleRestartWeek + (rawWeek - totalWeeks - 1) % span                     // 15 -> 5, 16 -> 6, ...
phaseFor(week) = the phase whose weeks contain week
dayForToday = active.dayOrder[active.nextDayIndex]   (or the day the user picked)
after completion of a session on day d: nextDayIndex = (index of d in dayOrder + 1) % dayOrder.length
  (if the user did a different day, the pointer moves to the day after the one done)
effectiveRir(item, phase, week):
  if item.rir == null: return null
  r = item.rir + (phase.rirWeekOffsets[week] ?? 0)
  floor = phase.rirFloorByRole?[item.role] ?? 0
  return clamp(r, floor, 4)
```

Reactive deload (`active.reactiveDeloadRemaining > 0`): build the day from the **current** phase with the deload
transform (non-optional blocks only, no finisher, sets = ceil(sets/2), rir 4, loadMultiplier 0.9), mark the session
`is_deload = 1`, decrement after completion.

### 6.8 Session builder (`session_builder.dart`)

```
buildSession(template, active, overrides, dayId?, catalog, states, history, settings, profile, now, hotDay) -> SessionPlan:
  week = trainingWeek(...); phase = phaseFor(week); day = phase.days[dayId ?? dayOrder[nextDayIndex]]
  gap = gapRule(daysSince(last completed session of any program))
        // < 10 days: none
        // 10-21: loadMultiplier 0.9, rirBonus +1, notice "Welcome back: a bit lighter today"
        // > 21:  loadMultiplier 0.8, rirBonus -> RIR 4, forceFindWeight for role primary (seed = 0.8 x workingKg)
        // illness answer on the pre-start sheet ("I had a fever/malaria in the last 2 weeks") -> treat as deload session
  for each item in day (in block order):
     ex = catalog[override(slotKey) ?? item.exerciseId]
     if settings.equipment.legCurlType == lying and ex.id == 'seated_leg_curl': ex = lying_leg_curl
     if avoided(ex, profile.limitations) or !available(ex, equipment) or (input.cardioOff and ex is bike/treadmill):
          ex = first of item.substitutions + ex.substitutions that is available, unlocked and not avoided;
          if none: drop the item, notice "Skipped X: needs <equipment>"
     avoided(ex, lims) = for any l in lims: ex.id in limitation_rules[l].avoid_ids
                         or ex.movementPattern in limitation_rules[l].avoid_patterns
     (limitation_rules[l].lock_unlocks removes those keys from phase.unlocks for this user; each active
      limitation's `cue` is added once to `notices`)
  cardioOff (pre-start sheet "Power cut / cardio machines off"): warm-up cardio becomes a MobilityStep that runs
            the day's warm-up drills twice (est. +0 s); the finisher is dropped with the notice "Walk 10 min later
            (not in the midday heat)"; cool-down walk is dropped, stretches stay.
  blocks: drop warmup block if !settings.warmupBlock (keep the cardio item), drop cooldown stretches if !cooldownBlock
  if hotDay: finisher durationSec = max(300, duration - 180)
  TIME BUDGET (B = profile.sessionMinutes * 60; est(...) = estimateSeconds with hotDay and findWeightIds, 6.10):
    1. if est(core) > B, apply this ladder, re-estimating after each single change, stop as soon as it fits:
       a. warm-up cardio 300 -> 180 s (never below 180)
       b. accessory items, from the last main/superset block backwards: sets - 1 (never below 2)
       c. accessory items, same order: remove (each becomes an "Extra")
       d. secondary items, from last to first: sets - 1 (never below 2)
       e. still over: keep the plan, notice "This day needs about {m} min. Pick 60 min in Settings or use
          'End workout' when you are out of time: finished exercises still count."
       Never touched: primaries, the warm-up drills, the cool-down walk. Deload/retest days are never trimmed.
    2. finisher: include iff rawWeek > 1 and !isDeload and est(core) + finisher <= B. For the recomp goal the
       finisher outranks optional extras (fat-loss priority, and he is 95 kg: low-impact incline walk/bike).
    3. optional items, in day order: include each iff est(everything included so far + it) <= B.
       Everything not included (optional items and ladder removals) is listed as "Extras if you have time".
  Extras placement: an `ExtrasStep` right after the last main/superset step and BEFORE the finisher/cool-down,
            with one-tap "Skip extras". (Extras after the cool-down would never be done.)
  prescriptions: prescribe(...) per ExerciseStep
  superset blocks -> SupersetStep; warmup block -> WarmupCardioStep (first cardio item) + MobilityStep (others);
  finisher -> FinisherStep; cooldown -> CooldownStep
  notices: week-1 longer-session notice; gap notice; equipment notices; phase-start notice ("New this phase: Smith squat")
```

`available(ex, eq)`: every equipment id is in `eq.available`, except an exercise listing both `bike` and `treadmill`
needs either; `barbell_bench_press` additionally needs `eq.hasBenchUprights`.

### 6.9 Swap suggester (`swap_suggester.dart`)

```
suggestSwaps(ex, item, catalog, eq, phase, todayIds, prefs, max = 4):
  candidates = item.substitutions + ex.substitutions
             + catalog where movementPattern == ex.movementPattern and primary muscles intersect
               (sorted by difficulty asc, then name)
  keep c if: c != ex, available(c, eq), c.unlockKey in phase.unlocks or == 'always',
             c not in todayIds, prefs[c].lastPainAt older than 14 days, not hidden,
             !avoided(c, profile.limitations) (6.8)
  dedupe, take max; why = "Same muscles · {equipment label}" ; hasHistory from states
```

### 6.10 Duration estimate (`duration_estimator.dart`)

Same model as `tool/build_data.py` (keep them identical):
```
warmup block = (durationSeconds of its cardio item) + (180 if its name contains "8 min" else 120); cooldown block = 240
            (= the old 420 / 480 s for the shipped 300 s cardio; the formula lets the 6.8 ladder shorten the cardio)
finisher = sum of item.durationSeconds
superset = rounds * (40 * nItems + 20 + roundRest) - roundRest + 90, rounds = max(item.sets)
main item = sets * (work + rest) - rest + 90 + warmupSetCount * 75, work = perSide ? 70 : 40,
            warmupSetCount = auto -> 2, 1 -> 1, 0 -> 0
find-weight item (ids in findWeightIds): sets -> max(1, sets - 1), warmupSetCount -> 0, plus 3 * (work + 75)
            for the ramp sets (3 = planning average; the ramp allows up to 4)
hotDay: + 30 s per working set of main/superset items (HOT_EXTRA_REST)
```

### 6.11 PRs (`pr_detector.dart`) and stats (`stats.dart`)

- `epley1rm(totalLoadKg, reps) = reps == 1 ? w : w * (1 + reps/30)`; only reps <= 12; uses totalLoadKg (0.4).
- PR types per exercise: `e1rm`, `max_weight` (totalLoadKg, reps >= 1), `best_volume` (single-set volume). The first
  session of an exercise sets baselines silently (no trophies); later improvements get `is_pr = 1`.
- Weekly volume = sum of working-set volume per ISO week (Mon start). Hard sets per muscle per week: working sets with
  `rir == null or rir <= 4`, primary muscles count 1.0, secondary 0.5.
- 7-day moving average weight: mean of entries in [d-6, d]; null if fewer than 3.
- Heatmap buckets: working sets per day: 0, 1-9, 10-14, 15-19, 20+.

### 6.12 Deload advisor (`deload_advisor.dart`)

After each completed session, suggest a reactive deload (dismissible; once dismissed, not again for 7 days) if any:
1. >= 2 exercises with role primary/secondary have `stallCount >= 2` at the same time.
2. Session total reps fell > 10% vs the previous session of the same dayId, two times in a row.
3. Readiness mean (sleep, soreness inverted, energy) <= 2 for the last 2 sessions.
4. Pain flags on exercises sharing a primary muscle in 2 different sessions within 14 days.
5. trainingWeek >= 9 and >= 6 weeks since the last deload (scheduled or reactive).
Accept -> `reactiveDeloadRemaining = daysPerWeek`.

---

## 7. Shared interfaces (created in Phase 0 by WS1, then frozen)

### 7.1 Repositories (`lib/data/repositories/`)

```dart
abstract class AssetCatalog {
  List<Exercise> get exercises; Exercise exercise(String id); Exercise? tryExercise(String id);
  List<ProgramTemplate> get templates; ProgramTemplate template(String programId);
  Personalization get personalization; Map<String, String> get idMigrations;
}
abstract class SettingsRepository {
  Future<AppSettings> loadSettings(); Future<void> saveSettings(AppSettings s);
  Future<UserProfile?> loadProfile(); Future<void> saveProfile(UserProfile p);
  Future<String?> getFlag(String key); Future<void> setFlag(String key, String? value);
}
abstract class ProgramRepository {
  Future<ActiveProgram?> active(); Future<List<ActiveProgram>> all();
  Future<ActiveProgram> activateTemplate(String templateId, {int startWeek = 1});
  Future<ActiveProgram> createCustom(ProgramTemplate custom);
  Future<void> save(ActiveProgram p);
  Future<void> advanceAfter(String programId, String completedDayId);
  Future<List<ProgramOverride>> overrides(String programId);
  Future<void> setOverride(ProgramOverride o); Future<void> clearOverrides(String programId, {String? dayId});
}
abstract class SessionRepository {
  Future<Session> start(SessionPlan plan, {required ReadinessCheck readiness});
  Future<Session?> findInProgress(); Future<Session?> byId(String id);
  Future<void> logSet(SetLog set, PlayerCursor cursor);                 // one transaction
  Future<void> updateSet(SetLog set); Future<void> deleteSet(String setId);
  Future<void> saveCursor(String sessionId, PlayerCursor cursor);
  Future<void> setExerciseStatus(String sessionExerciseId, SessionExerciseStatus s, {SkipReason? reason});
  Future<SessionExercise> replaceExercise(String sessionExerciseId, String newExerciseId, Prescription rx);
  Future<void> reorder(String sessionId, List<String> sessionExerciseIdsInOrder);
  Future<SessionExercise> addExtra(String sessionId, ExerciseStep step);
  Future<Session> complete(String sessionId, {int? feeling, String? note, double? bodyweightKg});
  Future<void> discard(String sessionId);
  Future<List<SetLog>> setsFor(String exerciseId, {int limitSessions = 10, Set<SetKind>? kinds});
  Future<List<SetLog>> lastExposure(String exerciseId, {String? excludingSessionId});
  Future<List<Session>> listCompleted({DateTime? from, DateTime? to, String? programId});
  Future<int> countCompleted({required String programId, bool excludeDeload = true});
  Future<DateTime?> lastCompletedAt();
  Stream<void> get changes;                                             // fires after any write
}
abstract class ExerciseStateRepository {
  Future<ExerciseState?> get(String exerciseId); Future<Map<String, ExerciseState>> getAll(Iterable<String> ids);
  Future<void> put(ExerciseState s);
  Future<List<PersonalRecord>> records(String exerciseId); Future<void> putRecord(PersonalRecord r);
  Future<ExercisePrefs> prefs(String exerciseId); Future<void> putPrefs(ExercisePrefs p);
  Future<Map<String, ExercisePrefs>> allPrefs();
}
abstract class BodyRepository { Future<void> upsert(BodyEntry e); Future<void> delete(String date);
  Future<List<BodyEntry>> range(String from, String to); Future<BodyEntry?> latest(); Future<BodyEntry?> first(); }
abstract class NutritionRepository { Future<NutritionDay> day(String date); Future<void> save(NutritionDay d);
  Future<List<NutritionDay>> range(String from, String to);
  Future<void> addCalorieAdjustment(CalorieAdjustment a); Future<List<CalorieAdjustment>> adjustments(); }
abstract class ActivityRepository { Future<void> addCardio(CardioLog c); Future<List<CardioLog>> cardio(String from, String to);
  Future<List<Pause>> pauses(); Future<void> savePause(Pause p); }
abstract class MilestoneRepository { Future<List<MilestoneAward>> awards(); Future<void> award(MilestoneAward a); }
abstract class BackupService { Future<Uint8List> exportJson(); Future<ImportPreview> preview(Uint8List bytes);
  Future<void> import(Uint8List bytes, {required bool replace}); Future<String> autoBackup(); }
class ImportPreview { final int sessions, sets, bodyEntries, nutritionDays; final DateTime exportedAt;
  final int dbVersion; final List<String> warnings; }
```

### 7.2 Domain API: exact signatures, implemented by WS2/WS6

Dart has no body-less top-level functions, so: `lib/domain/api.dart` holds the **value types** (section 5.3 domain
types plus the ones below) and re-exports every domain file; each function below lives in the owner file named in
3.1 (`prescribe` in `progression_engine.dart`, `buildSession` in `session_builder.dart`, `trainingWeek`/`phaseFor`/
`effectiveRir`/`gapRule` in `schedule.dart`, rounding in `load_rounding.dart`, etc.) with exactly this signature.

```dart
// extra value types in lib/domain/api.dart
class GapRule { final double loadMultiplier; final int rirBonus; final bool forceFindWeightPrimary,
  treatAsDeload; final String? notice; static const none = GapRule(1.0, 0, false, false, null); }
class InSessionHint { final String message; final double? suggestedKg; final bool automatic; }
class BuildSessionInput { final ProgramTemplate template; final ActiveProgram active;
  final List<ProgramOverride> overrides; final String? dayId; final AssetCatalog catalog;
  final Map<String, ExerciseState> states; final Map<String, ExercisePrefs> prefs; final int completedNonDeload;
  final DateTime? lastCompletedAt; final AppSettings settings; final UserProfile profile; final DateTime now;
  final bool hotDay, recentIllness, cardioOff; final Map<String, dynamic> limitationRules; }
class DeloadInput { final List<Session> recentSessions; final Map<String, ExerciseState> states;
  final int trainingWeek; final DateTime? lastDeloadAt; final DateTime? lastDismissedAt; final DateTime now; }
class WeeklyStats { final int sessions, workingSets; final double volumeKg; final Map<Muscle, double> hardSets; }
class CheckinInput { final List<BodyEntry> body; final List<NutritionDay> nutrition;
  final List<CalorieAdjustment> adjustments; final Map<String, ExerciseState> anchorStates;
  final UserProfile profile; final Personalization p; final DateTime now; }
class CheckinAdvice { final String ruleId, message; final int deltaKcal; final int deltaSteps; final bool canApply; }
class MilestoneInput { final List<Session> sessions; final List<SetLog> workingSets; final List<BodyEntry> body;
  final List<NutritionDay> nutrition; final List<CardioLog> cardio; final List<Pause> pauses;
  final Map<String, ExerciseState> states; final List<PersonalRecord> newPrs; final UserProfile profile;
  final EquipmentProfile eq; final AssetCatalog catalog; final DateTime now; }
class StreakInfo { final int weeks; final int graceTokens; final bool thisWeekCounted; final int sessionsThisWeek,
  targetThisWeek; }
// UI-side value types (lib/state/types.dart, WS1 Phase 0)
class OnboardingResult { final UserProfile profile; final AppSettings settings; final String templateId; }
class LibraryQuery { final String text; final Set<Muscle> muscles; final Set<Equipment> equipment;
  final bool beginnerOnly, showAllEquipment, favoritesOnly; }
sealed class TodayCard {}   // DeloadCard, CheckinCard(CheckinAdvice), MilestoneCard(Milestone), VariationCard(exerciseId), ParqRecheckCard, TipCard(String)
```

```dart
double increment(Exercise ex, ProgramItem? item, ExercisePrefs? prefs);
List<double> availableLoads(Exercise ex, EquipmentProfile eq, ExercisePrefs? prefs);
double roundToAvailable(double kg, Exercise ex, EquipmentProfile eq, ExercisePrefs? prefs);
double roundDown(double kg, Exercise ex, EquipmentProfile eq, ExercisePrefs? prefs);
double nextUp(double kg, Exercise ex, EquipmentProfile eq, ExercisePrefs? prefs);
FindWeightState startFindWeight(Exercise ex, ProgramItem item, int targetRir, EquipmentProfile eq, {double? lastKnownKg});
RampResult findWeightStep(FindWeightState s, int reps, int? reportedRir, bool formBrokeOrPain, Exercise ex, EquipmentProfile eq);
List<WarmupSet> planWarmups(double workingKg, Exercise ex, ProgramItem item, EquipmentProfile eq);
InSessionHint? inSessionHint(SetLog last, int setNumber, ProgramItem item, int? targetRir, Exercise ex, EquipmentProfile eq);
ExerciseState afterSession(ExerciseState? state, Exercise ex, ProgramItem item, int? targetRir, List<SetLog> working,
    List<SetLog> lastExposure, EquipmentProfile eq, ExercisePrefs? prefs, DateTime now);
Prescription prescribe(Exercise ex, ProgramItem item, Phase phase, int week, ExerciseState? state,
    EquipmentProfile eq, ExercisePrefs? prefs, GapRule gap, {required bool isDeload, required bool hotDay,
    double? seedKg});   // seedKg: SEED_TRANSFER result computed by buildSession from the other states (6.2)
double? transferSeed(String exerciseId, Map<String, ExerciseState> states, EquipmentProfile eq);   // find_weight.dart
int trainingWeek(ProgramTemplate t, ActiveProgram a, int completedNonDeload);
Phase phaseFor(ProgramTemplate t, int week);
int? effectiveRir(ProgramItem item, Phase phase, int week);
GapRule gapRule(DateTime? lastCompleted, DateTime now, {bool recentIllness = false});
SessionPlan buildSession(BuildSessionInput input);         // BuildSessionInput bundles 6.8 inputs
List<SwapOption> suggestSwaps(Exercise ex, ProgramItem item, AssetCatalog c, EquipmentProfile eq, Phase phase,
    Set<String> todayIds, Map<String, ExercisePrefs> prefs, Map<String, ExerciseState> states, {int max = 4});
PlateResult calculatePlates(double totalKg, double barKg, List<double> platesKg);
double epley1rm(double totalKg, int reps);
double totalLoadKg(SetLog s, Exercise ex, EquipmentProfile eq);
List<PersonalRecord> detectPrs(List<SetLog> sessionSets, Map<String, List<PersonalRecord>> existing,
    AssetCatalog c, EquipmentProfile eq);
DeloadAdvice adviseDeload(DeloadInput input);
int estimateSeconds(ProgramDay day, {bool includeOptional = false, bool includeFinisher = false,
    bool hotDay = false, Set<String> findWeightIds = const {}});   // ids = exerciseIds ramping this session
WeeklyStats weeklyStats(List<Session> sessions, AssetCatalog c, EquipmentProfile eq);
double? movingAverage7(List<BodyEntry> entries, String date);
// WS6
NutritionTargets nutritionTargets(UserProfile u, Personalization p, {double? currentWeightKg});
CheckinAdvice weeklyCheckin(CheckinInput input);           // 10.2
List<MilestoneAward> evaluateMilestones(MilestoneInput input, Personalization p, Set<String> alreadyAwarded);
StreakInfo weeklyStreak(List<Session> completed, List<Pause> pauses, UserProfile u, DateTime now);
```
Phase 0 ships each as a stub that returns a simple, valid value (e.g. `prescribe` returns `repRange.min` reps at
`startingWeightKg.low`), so UI work can proceed.

### 7.3 Services (`lib/services/api.dart`)

```dart
abstract class RestAlarm { Future<void> schedule(DateTime at, {required String title, required String body});
  Future<void> cancel(); Future<bool> ensurePermission(); }
abstract class NotificationService { Future<void> init();
  Future<void> scheduleWorkoutReminders(List<int> weekdays, String hhmm, String Function(int weekday) body);
  Future<void> scheduleWeighIn(String hhmm); Future<void> scheduleGymBag(List<int> workoutWeekdays);
  Future<void> cancelAllReminders(); }
abstract class SoundService { Future<void> beep(); Future<void> restDone(); }
abstract class HapticsService { Future<void> light(); Future<void> heavyTriple(); }
abstract class WakelockService { Future<void> enable(); Future<void> disable(); }
abstract class LauncherService { Future<bool> openVideo(Exercise ex); Future<bool> call(String number); }
```

### 7.4 Stores (`lib/state/`), public API frozen in Phase 0

```dart
class SettingsStore extends ChangeNotifier { AppSettings get settings; Future<void> update(AppSettings s); }
class ProfileStore extends ChangeNotifier { UserProfile? get profile; Future<void> save(UserProfile p);
  Future<void> completeOnboarding(OnboardingResult r); }     // saves profile, settings, activates program, reminders
class ProgramStore extends ChangeNotifier { ActiveProgram? get active; ProgramTemplate? get template;
  int get trainingWeek; Phase? get phase; ProgramDay? get nextDay; List<ProgramOverride> get overrides;
  Future<void> switchTemplate(String id, {int startWeek = 1}); Future<void> setNextDay(int index);
  Future<void> reorderDays(List<String> order); Future<void> replaceInProgram(String dayId, String slotKey, String exId);
  Future<void> resetDay(String dayId); Future<void> acceptReactiveDeload(); }
class TodayStore extends ChangeNotifier { Session? get inProgress; SessionPlan? get preview; StreakInfo get streak;
  List<TodayCard> get cards; Future<void> refresh(); Future<String> startSession({String? dayId, required bool hotDay,
  required ReadinessCheck readiness, bool recentIllness = false, bool cardioOff = false}); }
class SessionPlayerController extends ChangeNotifier { /* section 8 */ }
class HistoryStore extends ChangeNotifier { Future<List<Session>> sessions({DateTime? from, DateTime? to});
  WeeklyStats get thisWeek; Future<List<(DateTime, double)>> e1rmSeries(String exerciseId); }
class BodyStore extends ChangeNotifier { List<BodyEntry> get entries; double? get avg7; Future<void> upsert(BodyEntry e); }
class LibraryStore extends ChangeNotifier { LibraryQuery get query; List<Exercise> get results; void setQuery(LibraryQuery q);
  Future<void> toggleFavorite(String id); }
class NutritionStore extends ChangeNotifier { NutritionTargets get targets; NutritionDay get today;
  Future<void> addProtein(double points); Future<void> addWater(double sachets); Future<void> setCheck(String id, bool v); }
class MilestoneStore extends ChangeNotifier { List<MilestoneAward> get awards; List<Milestone> get recent;
  Future<List<Milestone>> evaluateNow(); }
```

---

## 8. Session player state machine (WS3)

```
States: loading -> step(stepIndex) where step is one of
        warmupCardio(timer) | mobility(checklist) | exercise(stepIndex, setIndex, mode: findWeight|warmup|working)
        | resting(endsAt, nextTarget) | finisher(timer) | cooldown(itemIndex, timer) -> summary
Events: start, logSet(weight, reps, durationSec?), answerRir(rir?), undoLast, skipSet, addSet, removeSet,
        skipExercise(reason), painFlag, swap(exerciseId, scope: today|program), reorder(ids), waitTimer,
        adjustRest(±15), skipRest, restExpired, timerDone, pauseTimer, resumeTimer, nextStep, prevStep,
        jumpTo(stepIndex), editSet(setId, weight, reps, rir), deleteSet(setId), notAtGym(exerciseId),
        cardioUnavailable, skipExtras, feelUnwell, appResumed, endWorkout(save|discard)
```
Constructor (frozen in Phase 0, `lib/state/session_player_controller.dart`):
```dart
SessionPlayerController({required String sessionId, required AssetCatalog catalog,
  required SessionRepository sessions, required ExerciseStateRepository states, required ProgramRepository programs,
  required SettingsStore settings, required MilestoneStore milestones, required RestAlarm restAlarm,
  required SoundService sound, required HapticsService haptics, required WakelockService wakelock,
  required Clock clock});
Future<void> load();   // rebuilds from DB; PlayerScreen calls it once
```
- Every event: repository write first, then `notifyListeners()`. `logSet` = `SessionRepository.logSet(set, cursor)`
  in one transaction, then `RestAlarm.schedule(restEndsAt)`, light haptic.
- `restExpired` (foreground): heavy haptic x3 + `SoundService.restDone()`; `skipRest`/`restExpired` -> `RestAlarm.cancel()`.
- On launch/resume: rebuild from DB (`Session.plan` snapshot + sets + cursor). Remaining rest = `restEndsAt - now`.
- `undoLast`: deletes the last set log (snackbar 5 s), restores cursor.
- Completion (`endWorkout(save)` or last step done): `SessionRepository.complete`, then for each exercise
  `afterSession` -> `ExerciseStateRepository.put`, `detectPrs`, `ProgramRepository.advanceAfter`, decrement reactive
  deload, `adviseDeload`, `MilestoneStore.evaluateNow()`, `WakelockService.disable()`, navigate to summary.
- Supersets: cursor walks members round by round; rest only after the last member of a round.

---

## 9. Storage

### 9.1 SQLite schema (`lib/data/db/schema.dart`, DB name `legon_lift.db`, version 1)

`onConfigure`: `PRAGMA foreign_keys = ON`. Migrations: `onUpgrade` runs `migrations[v]` for each version step.

```sql
CREATE TABLE kv (key TEXT PRIMARY KEY, value TEXT NOT NULL);
  -- keys: 'profile' (UserProfile JSON), 'settings' (AppSettings JSON incl. equipment), 'flags.*'
CREATE TABLE programs (
  id TEXT PRIMARY KEY, template_id TEXT, name TEXT NOT NULL, custom_json TEXT,
  day_order_json TEXT NOT NULL, next_day_index INTEGER NOT NULL DEFAULT 0,
  started_at INTEGER NOT NULL, start_week INTEGER NOT NULL DEFAULT 1, cycle INTEGER NOT NULL DEFAULT 1,
  reactive_deload_remaining INTEGER NOT NULL DEFAULT 0, is_active INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL);
CREATE TABLE program_overrides (
  program_id TEXT NOT NULL REFERENCES programs(id) ON DELETE CASCADE, day_id TEXT NOT NULL,
  slot_key TEXT NOT NULL, exercise_id TEXT, optional_enabled INTEGER,
  PRIMARY KEY (program_id, day_id, slot_key));
CREATE TABLE sessions (
  id TEXT PRIMARY KEY, program_id TEXT NOT NULL, template_id TEXT, phase_id TEXT NOT NULL,
  training_week INTEGER NOT NULL, day_id TEXT NOT NULL, day_name TEXT NOT NULL,
  status TEXT NOT NULL,                              -- in_progress|completed|discarded
  started_at INTEGER NOT NULL, ended_at INTEGER, is_deload INTEGER NOT NULL DEFAULT 0,
  hot_day INTEGER NOT NULL DEFAULT 0, readiness_sleep INTEGER, readiness_soreness INTEGER, readiness_energy INTEGER,
  bodyweight_kg REAL, feeling INTEGER, note TEXT, cursor_json TEXT, plan_json TEXT NOT NULL,
  total_volume_kg REAL NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL);
CREATE INDEX idx_sessions_started ON sessions(started_at);
CREATE INDEX idx_sessions_status ON sessions(status);
CREATE TABLE session_exercises (
  id TEXT PRIMARY KEY, session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  position INTEGER NOT NULL, block_index INTEGER NOT NULL, block_type TEXT NOT NULL, superset_group TEXT,
  exercise_id TEXT NOT NULL, original_exercise_id TEXT, slot_key TEXT NOT NULL, role TEXT NOT NULL,
  status TEXT NOT NULL, skip_reason TEXT, target_json TEXT NOT NULL, note TEXT);
CREATE INDEX idx_se_session ON session_exercises(session_id, position);
CREATE TABLE set_logs (
  id TEXT PRIMARY KEY,
  session_exercise_id TEXT NOT NULL REFERENCES session_exercises(id) ON DELETE CASCADE,
  session_id TEXT NOT NULL, exercise_id TEXT NOT NULL, set_index INTEGER NOT NULL,
  kind TEXT NOT NULL,                                -- warmup|ramp|working|test|calibration
  target_kg REAL, target_reps INTEGER, weight_kg REAL NOT NULL, reps INTEGER NOT NULL, duration_sec INTEGER,
  rir INTEGER, calibration_extra_reps INTEGER, pain_flag INTEGER NOT NULL DEFAULT 0,
  completed_at INTEGER NOT NULL, is_pr INTEGER NOT NULL DEFAULT 0);
CREATE INDEX idx_sets_exercise_time ON set_logs(exercise_id, completed_at);
CREATE INDEX idx_sets_session ON set_logs(session_id);
CREATE TABLE exercise_state (
  exercise_id TEXT PRIMARY KEY, working_kg REAL, rep_targets_json TEXT NOT NULL DEFAULT '[]',
  stall_count INTEGER NOT NULL DEFAULT 0, reset_count INTEGER NOT NULL DEFAULT 0,
  last_trend TEXT NOT NULL DEFAULT 'calibrate', last_reason TEXT NOT NULL DEFAULT '',
  last_session_id TEXT, last_rep_min INTEGER, last_rep_max INTEGER, first_e1rm REAL, best_e1rm REAL,
  last_jump_pct REAL, updated_at INTEGER NOT NULL);
CREATE TABLE personal_records (
  exercise_id TEXT NOT NULL, type TEXT NOT NULL, value REAL NOT NULL, set_log_id TEXT NOT NULL,
  achieved_at INTEGER NOT NULL, PRIMARY KEY (exercise_id, type));
CREATE TABLE exercise_prefs (
  exercise_id TEXT PRIMARY KEY, favorite INTEGER NOT NULL DEFAULT 0, hidden INTEGER NOT NULL DEFAULT 0,
  increment_kg REAL, machine_note TEXT, last_pain_at INTEGER);
CREATE TABLE body_entries (date TEXT PRIMARY KEY, weight_kg REAL, waist_cm REAL, note TEXT, updated_at INTEGER NOT NULL);
CREATE TABLE nutrition_days (
  date TEXT PRIMARY KEY, protein_points REAL NOT NULL DEFAULT 0, water_sachets REAL NOT NULL DEFAULT 0,
  veg_fruit INTEGER NOT NULL DEFAULT 0, steps_hit INTEGER NOT NULL DEFAULT 0, steps INTEGER,
  sleep_ok INTEGER NOT NULL DEFAULT 0, no_sugary_drinks INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL);
CREATE TABLE calorie_adjustments (id TEXT PRIMARY KEY, date TEXT NOT NULL, rule_id TEXT NOT NULL,
  delta_kcal INTEGER NOT NULL DEFAULT 0, delta_steps INTEGER);
CREATE TABLE cardio_logs (id TEXT PRIMARY KEY, date TEXT NOT NULL, exercise_id TEXT NOT NULL,
  duration_sec INTEGER NOT NULL, note TEXT);
CREATE TABLE pauses (id TEXT PRIMARY KEY, kind TEXT NOT NULL, reason TEXT NOT NULL, start_date TEXT NOT NULL,
  end_date TEXT);
CREATE TABLE milestone_awards (milestone_id TEXT PRIMARY KEY, awarded_at INTEGER NOT NULL, context_json TEXT);
```

Write-through: logging a set = one transaction (insert `set_logs`, update `sessions.cursor_json`, `updated_at`,
`total_volume_kg`). `personal_records` and `exercise_state` are written at completion.

### 9.2 Backup format

```json
{ "format": "legon_lift_backup", "version": 1, "dbVersion": 1, "exportedAt": 1763600000000,
  "appVersion": "1.0.0+1", "tables": { "kv": [ {...row} ], "programs": [...], "...": [...] } }
```
All tables exported as row maps. Import: check `format`, `dbVersion <= current` (migrate rows forward), map old
exercise ids through `idMigrations`. **Replace** = delete all rows then insert in FK order; **Merge** = insert or
ignore by primary key, except `body_entries` / `nutrition_days` where the newer `updated_at` wins. File name
`legon_lift_backup_yyyyMMdd_HHmm.json`. Auto-backup weekly into `getApplicationDocumentsDirectory()/backups`, keep 4.

### 9.3 Notifications (WS3)

- Channels: `rest_timer` (importance high, vibration `[0,300,150,300,150,300]`, sound `res/raw/rest_done`),
  `reminders` (default importance).
- Rest: `zonedSchedule(id: 1, at restEndsAt)` with `AndroidScheduleMode.exactAllowWhileIdle` if
  `canScheduleExactNotifications()`, else `inexactAllowWhileIdle` plus an ongoing notification with
  `usesChronometer: true, chronometerCountDown: true, when: restEndsAt` so the shade shows a live countdown.
  Request `POST_NOTIFICATIONS` at the first rest timer, not at launch.
- Time zone: `tz.initializeTimeZones()`; convert local times to an absolute instant and schedule in `tz.UTC`.
  Ghana is UTC+0 without daylight saving, so weekly repeats (`matchDateTimeComponents: dayOfWeekAndTime`) stay
  correct. (Known limitation for other zones: acceptable for v1.)
- Reminders: workout days at `reminderTime` ("Push day today. Pack 1 L of water."), weigh-in at `weighInTime`,
  gym bag at 20:00 the evening before a workout day (items from `adherence.gym_bag_reminder`).

---

## 10. Personalization logic (WS6)

### 10.1 Nutrition targets (`nutrition_calculator.dart`)

Implement `formulas` exactly; the test fixture is `worked_example` (all 11 values must match):
```
bmi = w / (h/100)^2
bmr = 10w + 6.25h - 5age + (male ? 5 : -161)
tdee = bmr * activity_multipliers[level]
adj = goal_adjustment[goal]   (recomp: bmi>=25 -> -0.20 else -0.10; fat_loss -0.20, -0.25 cap if bmi>=30; ...)
calorieTarget = max(floor, roundTo(tdee * (1 + adj), 50)), floor = max(min_kcal[sex], bmr * min_fraction_of_bmr[sex])
refWeight = bmi < 25 ? w : goalWeight != null ? max(goalWeight, 25*h_m^2) : 25*h_m^2
protein min/target/max = roundTo(refWeight * {1.6, 1.9, 2.2}, 5), and >= 1.2 * w (sanity)
points target = round(proteinTarget / 20); good-day points = round(proteinMin / 20)
water = roundTo(clamp(30w, 2000, 4000) + 500 + (training ? 750 * sessionMin/60 : 0), 250), cap 5000; sachets = ml/500
steps start = baseline != null ? clamp(baseline + 2000, 6000, 10000) : 7000; +1000 every 2 weeks if hit on >= 5/7 days, max 10000
```
Use the 7-day average weight once available; recalc every 4 kg lost or 8 weeks.

### 10.2 Weekly check-in (`checkin_advisor.dart`)

Once a week (on the first workout weekday) from week 3: compute
`loss_pct = (avg_last_week - avg_this_week) / avg_last_week * 100` (2-week means once >= 3 weeks of data). Evaluate
`progress_tracking.weekly_check_in.rules` in order with their `consecutive` counts; apply guards (max 200 kcal per
change, >= 2 weeks between changes, never below floor). Output a Today card with the rule's message and, if the rule
has an action, "Apply" -> `calorie_adjustments` row; the calorie target shown = formula target + sum(deltas).
Weeks 1-2 are ignored.

### 10.3 Milestones (`milestone_evaluator.dart`)

Load = `totalLoadKg` (0.4); bodyweight = latest 7-day average or profile weight; only working/test sets count.

| Rule key(s) | Meaning |
|---|---|
| `sessions_completed_gte: n` | completed sessions (all programs) >= n |
| `week_index: 1, sessions_eq_planned` | within the first 7 days after the first program start, completed sessions >= daysPerWeek |
| `week_streak_gte: n` | current weekly streak >= n |
| `streak_maintained_during_tag: t` | a `pauses` row of kind `tag`, reason t, lasting >= 7 days, ended, with every overlapping week counted for the streak |
| `weeks_trained_in_months: [m], gte: n` | in the last 12 months, number of ISO weeks with >= 1 session whose date month is in m >= n |
| `sessions_started_before: "HH:mm", gte: n` | sessions with local start time before HH:mm >= n |
| `session_within_days_after_missed_week: d` | a week with 0 sessions (no pause) followed by a session within d days |
| `exercise_any, load_kg_gte, reps_gte` | a set on any listed exercise with totalLoad >= x and reps >= r |
| `exercise_any, load_x_bodyweight_gte, reps_gte, include_sled_weight` | totalLoad >= f * bodyweight (sled weight counted only if known) |
| `estimated_1rm_gt_previous_best` | any e1rm PR (not first-session baselines) |
| `anchor_lifts_avg_increase_pct_gte: p` | mean over anchors with data (>= 3 anchors) of (best e1rm in last 14 days / first e1rm - 1) * 100 >= p |
| `avg7_loss_kg_gte` / `avg7_loss_pct_gte` | first available 7-day avg minus latest 7-day avg (kg / %) |
| `waist_loss_cm_gte` | first waist minus latest waist |
| `waist_cm_lt, sex, only_if_start_gte` | latest waist < x, sex matches, first waist >= start |
| `waist_to_height_lt` | latest waist / height < x |
| `bmi_lt, only_if_start_gte` | BMI from latest 7-day avg < x and starting BMI >= start |
| `weeks, abs_weight_change_pct_lt, waist_loss_cm_gte` | over the last n weeks |Δ avg7| % < x and waist down >= y |
| `habit, days_of_7_gte` | in some Mon-Sun week the habit was met on >= n days (protein: points >= daily target; water: sachets >= target) |
| `badge, consecutive_weeks_gte` | the named badge's weekly condition held for n consecutive weeks |
| `weekly_avg_steps_gte` | a week with >= 5 step entries averaging >= n |
| `weekly_avg_sleep_h_gte` | a week where `sleep_ok` was ticked on >= 6 days |
| `cardio_continuous_min_gte: n` | a single finisher or cardio log lasting >= n minutes |

### 10.4 Adherence (`adherence.dart`)

Weekly streak (Mon-Sun): a week counts if completed sessions >= max(`min_sessions_floor`, plannedDays - 1);
paused weeks are frozen (neither break nor extend); grace tokens: earn 1 per 4 counted weeks, max 2 banked, auto-used
on a missed week. "Never miss twice" nudge after one missed planned day. Pause mode reasons and max 3 weeks from
`adherence.pause_mode`.

---

## 11. Visual identity

### 11.1 Palettes (`lib/app/theme/tokens.dart`)

```dart
class ColorTokens { final Color bg, surface, surface2, onSurface, muted, primary, onPrimary, secondary,
  success, warning, danger, warmup, imageCard; }
const legonNight = ColorTokens(  // DEFAULT
  bg: Color(0xFF0B0F14), surface: Color(0xFF151B23), surface2: Color(0xFF1E2630),
  onSurface: Color(0xFFF2F5F8), muted: Color(0xFF9AA7B4), primary: Color(0xFFFFC629),
  onPrimary: Color(0xFF0B0F14), secondary: Color(0xFF4C8DFF), success: Color(0xFF2ED47A),
  warning: Color(0xFFFFB020), danger: Color(0xFFFF5A5F), warmup: Color(0x999AA7B4), imageCard: Color(0xFFE9EDF1));
const kenteEnergy = ColorTokens(
  bg: Color(0xFF0D0D0F), surface: Color(0xFF18181C), surface2: Color(0xFF232329),
  onSurface: Color(0xFFF5F5F0), muted: Color(0xFFA3A39A), primary: Color(0xFFF5B700),
  onPrimary: Color(0xFF0D0D0F), secondary: Color(0xFF00B37A), success: Color(0xFF00B37A),
  warning: Color(0xFFFF8A3D), danger: Color(0xFFE5484D), warmup: Color(0x99A3A39A), imageCard: Color(0xFFEDEDE8));
const voltTeal = ColorTokens(
  bg: Color(0xFF07110F), surface: Color(0xFF0F1E1B), surface2: Color(0xFF172A26),
  onSurface: Color(0xFFE8FFF9), muted: Color(0xFF8FB3AA), primary: Color(0xFF2DE1C2),
  onPrimary: Color(0xFF07110F), secondary: Color(0xFFFFB020), success: Color(0xFF7AE582),
  warning: Color(0xFFFFB020), danger: Color(0xFFFF6B6B), warmup: Color(0x998FB3AA), imageCard: Color(0xFFE6F2EF));
```
Contrast (Legon Night): onSurface 17.6:1 on bg, muted 7.8:1, primary 12.2:1, secondary 6.0:1, success 9.9:1,
danger 6.3:1. Kente `danger` is 5.0:1: use only for icons/large text. Light variants (secondary priority):
bg `#F6F8FA`, surface `#FFFFFF`, surface2 `#EEF1F4`, onSurface `#0B0F14`, muted `#4A5561`, primary darkened 25%
(`#B88A00` for gold), keep hue for the others darkened until >= 4.5:1 on white.

### 11.2 Spacing, shape, sizes

```dart
abstract final class Space { static const xs = 4.0, s = 8.0, m = 12.0, l = 16.0, xl = 24.0, xxl = 32.0; }
abstract final class Radii { static const card = 16.0, sheet = 24.0, button = 14.0, chip = 12.0, imageCard = 16.0; }
abstract final class Sizes { static const minTap = 56.0, stepper = 64.0, primaryButton = 72.0, heroButton = 64.0,
  topBar = 56.0, resumeBanner = 72.0, rirButton = 56.0; }
abstract final class Motion { static const frameLoop = Duration(milliseconds: 2400), snackUndo = Duration(seconds: 5); }
```
Page padding 16 dp. Cards: `surface`, radius 16, no elevation, 1 px border `surface2`. Bottom sheets: `surface`,
top radius 24, drag handle 32x4. Buttons: primary = `primary` fill + `onPrimary` text 18 sp SemiBold;
secondary = outlined `muted`; destructive = text `danger`.

### 11.3 Typography (`typography.dart`)

Fonts bundled (downloaded once by WS6 from google/fonts, OFL):
`assets/fonts/BarlowSemiCondensed-SemiBold.ttf`, `-Bold.ttf`
(`https://github.com/google/fonts/raw/main/ofl/barlowsemicondensed/...`), and `assets/fonts/Inter-Variable.ttf`
(`https://github.com/google/fonts/raw/main/ofl/inter/Inter%5Bopsz,wght%5D.ttf`). Inter weights are set with
`fontVariations: [FontVariation.weight(400|500|600)]`. All numeric styles use
`fontFeatures: [FontFeature.tabularFigures()]`.

| Style | Font | Size sp / weight | Use |
|---|---|---|---|
| displayTimer | Barlow SC | 96 / 700 | rest countdown |
| displayStat | Barlow SC | 56 / 700 | summary tiles |
| value | Barlow SC | 40 / 600 | stepper values |
| headline | Barlow SC | 28 / 700 | screen titles |
| title | Inter | 22 / 600 | exercise name (24 in player) |
| body | Inter | 16 / 400 | text |
| label | Inter | 14 / 500 | chips, buttons small |
| caption | Inter | 12 / 400 | captions (never inside the player; player minimum 14) |

### 11.4 Two-frame animator (`widgets/frame_animator.dart`, WS4)

`AnimationController(duration: 2400 ms)..repeat()`. Frame 1 opacity `TweenSequence`: 0 hold 700 ms -> easeInOut to 1
over 500 ms -> hold 700 ms -> easeInOut to 0 over 500 ms. Both images in a `Stack`, frame 1 in `FadeTransition`, plus
a 1.00 -> 1.02 scale while frame 1 is visible. Two neutral dots (no Start/End labels). Tap toggles pause and flips
frames manually; reduced motion (`MediaQuery.disableAnimationsOf`) shows both frames side by side. Pause under the
rest sheet and in background (`TickerMode`). `precacheImage` both frames of the current and next exercise.
Image card: `imageCard` colour, radius 16, `BoxFit.contain`, aspect 16:10. No images -> `PlaceholderFigure`.

### 11.5 App icon (`assets/icon/`, WS6)

Concept: a gold barbell under a white upward chevron ("lift" + "progress"). 1024x1024 canvas; every shape stays
inside radius 290 around (512,512), within the adaptive-icon safe zone (radius 313 = 66/108).

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <radialGradient id="bg" cx="50%" cy="42%" r="70%">
      <stop offset="0" stop-color="#16294A"/>
      <stop offset="1" stop-color="#0B0F14"/>
    </radialGradient>
  </defs>
  <rect width="1024" height="1024" rx="224" fill="url(#bg)"/>
  <path d="M392 452 L512 332 L632 452" fill="none" stroke="#FFFFFF"
        stroke-width="60" stroke-linecap="round" stroke-linejoin="round"/>
  <rect x="280" y="590" width="464" height="36"  rx="18" fill="#FFC629"/>
  <rect x="300" y="510" width="52"  height="196" rx="14" fill="#FFC629"/>
  <rect x="364" y="544" width="36"  height="128" rx="10" fill="#FFC629"/>
  <rect x="672" y="510" width="52"  height="196" rx="14" fill="#FFC629"/>
  <rect x="624" y="544" width="36"  height="128" rx="10" fill="#FFC629"/>
</svg>
```
Precise description: background = radial gradient centred at (512, 430), radius 717, `#16294A` -> `#0B0F14`,
square with 224 corner radius (full icon only). Chevron = open polyline (392,452) -> (512,332) -> (632,452), stroke 60,
white, round caps and joins. Barbell (all `#FFC629`): bar 464x36 at (280,590) radius 18; outer plates 52x196 at
x=300 and x=672, y=510, radius 14; inner plates 36x128 at x=364 and x=624, y=544, radius 10 (symmetric about x=512).
Files: `icon.svg` (above), `icon_foreground.svg` (chevron + barbell, transparent, no rect),
`icon_background.svg` (gradient rect without rx), `icon_monochrome.svg` (foreground shapes all `#FFFFFF`).
`tool/make_icons.sh` rasterises each with `rsvg-convert -w 1024 -h 1024` to `*_1024.png`, then runs
`~/development/flutter/bin/dart run flutter_launcher_icons`. Splash: `launch_background.xml` with bg `#0B0F14` and the
foreground mark at 192 dp.

### 11.6 Sounds (WS6)

`tool/make_sounds.sh` generates with ffmpeg: `beep_short.ogg` (880 Hz, 150 ms, -6 dB fade),
`rest_done.ogg` (three 988 Hz beeps of 120 ms with 90 ms gaps). Played via audioplayers with
`AudioContextAndroid(audioFocus: AndroidAudioFocus.gainTransientMayDuck, usageType: AndroidUsageType.assistanceSonification,
contentType: AndroidContentType.sonification)`.

---

## 12. Copy and shared widgets

### 12.1 Plain-language mapping

| Concept | UI text |
|---|---|
| RIR 4+/3/2/1/0 | "4+ left (easy)" / "3 left" / "2 left" / "1 left" / "none left" |
| target RIR t | "leave {t} in the tank" |
| e1RM | "estimated best single" |
| deload | "easy week" |
| find-weight | "find your weight" |
| superset | "pair: alternate these two" |

### 12.2 Coaching content sources

Pain rule (3/10), heat steps, RIR explainer, rest timer tips: `personalization.tips.*` and
`personalization.safety.*`. The first time each concept appears, show a one-time explainer sheet (flag in `kv`).

### 12.3 Shared widgets (`lib/widgets/`, WS4; signatures frozen in Phase 0)

```dart
class BigButton extends StatelessWidget { const BigButton({required String label, IconData? icon,
  required VoidCallback? onPressed, BigButtonKind kind = BigButtonKind.primary, double height = Sizes.primaryButton}); }
class NumberStepper extends StatelessWidget { const NumberStepper({required double value, required double step,
  required ValueChanged<double> onChanged, required String unit, double min = 0, double? max, int decimals = 1,
  VoidCallback? onTapValue}); }
class StatTile extends StatelessWidget { const StatTile({required String label, required String value, String? delta}); }
class SectionHeader extends StatelessWidget { const SectionHeader(String title, {Widget? trailing}); }
class EmptyState extends StatelessWidget { const EmptyState({required IconData icon, required String title, String? body, Widget? action}); }
void showUndoSnackBar(BuildContext context, String message, VoidCallback onUndo);
class FrameAnimator extends StatefulWidget { const FrameAnimator({required List<String> assetPaths, double aspectRatio = 1.6, bool large = false}); }
class PlaceholderFigure extends StatelessWidget { const PlaceholderFigure({required Exercise exercise}); }
class ExerciseThumb extends StatelessWidget { const ExerciseThumb({required Exercise exercise, double size = 56}); }
class MuscleChips extends StatelessWidget { const MuscleChips({required List<Muscle> primary, required List<Muscle> secondary}); }
class WeightText extends StatelessWidget { const WeightText({required double kg, required Exercise exercise, TextStyle? style}); } // "2 × 12.5 kg", lb aware
```
Shared across features but owned by WS1 (used by Settings and by onboarding step 7, so the two equipment UIs cannot
drift): `lib/features/settings/widgets/equipment_editor.dart`
```dart
class EquipmentEditor extends StatelessWidget { const EquipmentEditor({required EquipmentProfile value,
  required GymProfileDefaults defaults, required ValueChanged<EquipmentProfile> onChanged, bool compact = false}); }
```

---

## 13. Workstreams (parallel implementation)

Six workstreams. **Exclusive ownership**: a file is created and edited only by its owner. Anyone needing a change in
someone else's file opens an issue/PR request to that owner. Integration points are the frozen contracts in
section 7 and 12.3.

### Phase 0: Foundation (WS1 alone, day 1; everyone else reviews)

WS1 creates and merges, in one PR:
1. `pubspec.yaml` (1.1), Android config (1.2), `analysis_options.yaml` (flutter_lints + `avoid_print`,
   `prefer_const_constructors`, `always_declare_return_types`; banned import `package:flutter/material.dart`).
2. All models and enums (section 5) with JSON/map round-trip tests.
3. `AssetCatalog` real implementation (loads the three JSON files; throws with a clear message on schema errors).
4. All repository interfaces (7.1) + sqflite implementations stubs that compile (real impls follow in Phase 1) +
   in-memory fakes in `test/fakes/` (`FakeSessionRepository`, etc., fully working) + `FakeClock`.
5. `lib/domain/api.dart` and `lib/services/api.dart` with every signature from 7.2/7.3; stub implementations in the
   owner files (`progression_engine.dart`, etc.) returning simple valid values; fake services
   (`FakeRestAlarm`, `SilentSound`, `NoopHaptics`, `NoopWakelock`).
6. Store classes (7.4) with the public API and trivial bodies.
7. `tokens.dart` with the exact palettes (11.1) and spacing constants, `app_theme.dart` minimal dark theme,
   shared widget files (12.3) with the exact constructors and a simple implementation.
8. All screen files from 3.2 as stubs; `routes.dart`, `shell.dart`, `app.dart`, `main.dart` wired so the app runs.
9. `test/fakes/sample_data.dart`: a scripted 3-session history for widget tests.

Exit criteria: `flutter analyze` clean, `flutter test` green, app launches to the onboarding stub on the A55.
After merge, ownership transfers per 3.1 and contracts are frozen.

### Phase 1+: parallel workstreams

| WS | Name | Exclusive files | Builds | Depends on (contracts only) |
|---|---|---|---|---|
| WS1 | Data platform | `pubspec.yaml`, `android/**`, `analysis_options.yaml`, `lib/main.dart`, `lib/core/**`, `lib/data/**`, `lib/state/settings_store.dart`, `lib/state/profile_store.dart`, `lib/features/settings/**`, `lib/features/backup/**`, `test/fakes/**`, `test/data/**` | sqflite repositories with migrations, backup export/import/auto-backup, settings + equipment screens, profile store incl. `completeOnboarding` | 7.2 (`buildSession` not needed) |
| WS2 | Training engine | `lib/domain/{progression_engine,warmup_planner,find_weight,load_rounding,plate_calculator,one_rep_max,session_builder,schedule,swap_suggester,pr_detector,deload_advisor,duration_estimator,stats}.dart`, `test/domain/**` (except WS6 files) | section 6 exactly, table-driven tests: rounding for each load type, ramp cases, warm-ups, double progression incl. stall/reset/bonus/small-load guard, phase transition, gap rules, schedule week wrap (15 -> 5), buildSession time ladder for 30/45/60 min (every template day fits 45 min after the ladder; 60 min with hotDay needs no trimming), finisher-vs-extras priority, quick start vs ramp, post-jump grace, unfinished-session rule, limitation replacement, SEED_TRANSFER, swaps filtering, plates 20-200 kg, PRs, deload triggers, duration estimates equal to `estimatedMinutes` in programs.json | models, AssetCatalog |
| WS3 | Session player | `lib/features/session_player/**`, `lib/state/session_player_controller.dart`, `lib/services/*.dart` (impls), `test/features/session_player/**`, `integration_test/**` | player UI (4.4), state machine (8), rest timer + notifications (9.3), sound/haptics/wakelock, swap/plates/how-to/end sheets, summary, resume after kill | domain API, SessionRepository, services API, shared widgets |
| WS4 | Shell & planning | `lib/app/**`, `lib/widgets/**`, `lib/state/{program_store,today_store}.dart`, `lib/features/{onboarding,today,program,you}/**`, `test/features/{onboarding,today,program,you}/**` | theme (11), shared widgets (12.3), onboarding (4.2), Today (4.3), Program + day editor + split picker + custom builder (4.5), You hub | domain API, repositories, stores API |
| WS5 | Insight | `lib/state/{history_store,body_store,library_store}.dart`, `lib/features/{library,progress,body}/**`, `test/features/{library,progress,body}/**` | Library + detail (4.6), Progress charts (fl_chart + heatmap painter) (4.7), Body (4.8), session detail/edit | domain stats/pr API, repositories, shared widgets |
| WS6 | Content, nutrition & motivation | `assets/**`, `tool/**`, `docs/research/**`, `lib/domain/{nutrition_calculator,milestone_evaluator,adherence,checkin_advisor}.dart`, `lib/state/{nutrition_store,milestone_store}.dart`, `lib/features/{nutrition,milestones,safety}/**`, `test/domain/{nutrition,milestone,adherence,checkin}_*`, `test/features/{nutrition,milestones,safety}/**` | data pipeline (keep `validate_data.py` green), fonts, sounds, icon + launcher icons, nutrition helper (4.9, 10.1-10.2), milestones (4.10, 10.3), adherence/streak (10.4), safety screen (4.11) | models, repositories, stores API |

With 4 engineers: merge WS5 into WS4 and WS6 into WS2.

**Merge-conflict hot spots** and their single owners: `pubspec.yaml` (WS1; WS6 sends asset/font changes as a
request), `routes.dart` (WS4), `schema.dart` (WS1), `api.dart` files (frozen; change by RFC).

### Definition of done (all workstreams)

- `flutter analyze` with zero warnings; `flutter test` green; `python3 -I tool/validate_data.py --require-images` exits 0.
- Works offline (airplane mode) end to end: onboarding -> week 1 Push with find-weight -> kill app mid-rest ->
  resume -> finish -> summary -> Today shows Pull next.
- Manual gym test on the Galaxy A55: screen stays awake, rest notification fires in background, music ducks, wet
  finger on the steppers works, readable in bright light.

---

## 14. Open questions (tracked, with safe defaults already in place)

1. Smith machine bar weight: unknown (default 10 kg, `smithBarKnown=false`; the plate calculator says so).
2. Plate and dumbbell inventory: unknown (defaults: plates 25-1.25 kg, dumbbells 2-40 kg in 2 kg steps; editable).
3. Leg curl machine type: unknown (default seated; Settings switch).
4. Leg press empty sled weight: unknown (only added plates logged; milestones ignore the sled until known).
5. Ankle strap for the cable: not confirmed (unticked; only `cable_glute_kickback` needs it, never a default).
6. Calf raise machine: standing or seated unknown; one exercise entry covers both setups.
7. Some exercise sources (ExRx, Mayo Clinic) block automated checks (403); some nutrition references were cited from
   memory and should be checked before quoting them in marketing text.
8. "Ankle machine" = calf raise machine comes from `docs/research/USER_NOTES.md`; please re-confirm on the first gym
   visit with the onboarding photo. If it is wrong, untick it: all calf slots are optional and fall back to the calf
   raise on the leg press.

---

## Critic review (2026-11-20)

Skeptical completeness pass against the user profile (male, ~95 kg, 170-173 cm, complete beginner, recomp, 3 days,
PPL, 45-60 min incl. warm-up, UG Legon gym equipment only, hot and humid). Data changes were made in the generators
(`tool/build_data.py`, `docs/research/exercises_added.json`) and rebuilt, per section 2. `python3 -I
tool/validate_data.py --require-images`: 0 errors, 1 warning (6 exercises without pictures).

### What was checked and held up
- Equipment: no program or substitute uses a pull-up bar, kettlebell, EZ bar, bands or squat rack. The validator
  now requires ALL of an exercise's equipment (it used to pass when only one item was present).
- Time at 60 min (the default): every template day's core <= 52 min and core + finisher <= 60, and with a hot day
  (+30 s rest per set) every day still fits without trimming (simulated).
- Nutrition for the default profile: 2,100 kcal, 140 g protein, 3,250 / 4,000 ml water (re-derived by hand).
- Every program exercise has two pictures or a pinned video.

### Changes made
1. **Calf fallback bug (data).** `leg_press_calf_raise` was dropped from calf slots' substitutions by the id-rename
   map and only came back last. It is now the first substitute in every calf slot. The ankle-machine wording now cites
   USER_NOTES.md and says what happens if it is wrong (2.2, open question 8).
2. **Find-your-weight (6.2) rewritten.** The old version accepted a weight whenever the RIR answer matched, even
   at 5 of 10 reps, and could not go down. The new version uses reps and RIR, stops when the next weight rounds to
   the same load, steps down when too heavy, and has a test table. Lifts that start in later phases seed from the
   lift they replace (`SEED_TRANSFER`). The ramp state is saved in the cursor, so it survives an app kill.
3. **Week-1 length.** Ramping every loaded exercise added 10-25 min (Arms+Shoulders reached 70 min). Now only
   primary and secondary lifts ramp. Accessories use "quick start" (start weight plus in-session suggestions). Every
   week-1 day is now <= 55 min, and the Today notice says ~5 min longer.
4. **Double progression (6.5) edge cases.** The mode tie-break and null-RIR handling are now defined. A skipped set
   or an early finish gives "no verdict" instead of a false stall. A grace rule handles big relative jumps (4 -> 6 kg
   dumbbells is +50%), which used to bounce back down forever. This adds `lastJumpPct` to the model and DB.
5. **Time budget (6.8).** The finisher and the optional extras were checked separately and could add up to 61+ min.
   There is now one budget with a fixed trim ladder (shorter cardio, then accessory sets, then accessories, then
   secondary sets, then a notice). Simulated: every template day fits 45 min, and at 60 min a hot day needs no
   trimming. Extras now come before the cool-down. The estimator (6.10) includes hot-day rest and find-weight sets.
6. **Limitations did nothing.** Added `personalization.limitation_rules` (knee, lower back, shoulder, wrist/elbow,
   hip, ankle). The builder and the swap suggester apply it. The validator checks that every working slot keeps a
   replacement under every rule.
7. **Session player dead ends (4.4).** Added a table of gym situations and exits: everything busy, "not at this
   gym", out-of-order steps, editing a wrongly logged set, skipped sets, ending early, cardio machines off or a power
   cut, feeling unwell, reading the next exercise during rest. Added the matching state-machine events and a frozen
   `SessionPlayerController` constructor.
8. **Exercise coverage.** Side delts and rear delts had only one beginner (difficulty 1) option each. Added
   `seated_dumbbell_lateral_raise` and `head_supported_db_rear_delt_raise`, with pictures, cross-linked as
   substitutes.
9. **Ownership and interfaces.** Fixed the `res/raw/rest_done.ogg` overlap (WS1 owns the copy). Gave
   `integration_test/**` to WS3. Added a shared WS1 `EquipmentEditor` for onboarding and Settings. Updated the
   `prescribe` and `estimateSeconds` signatures, `BuildSessionInput` (`cardioOff`, `limitationRules`), the pre-start
   sheet toggles and the WS2 test list.
10. **Validator.** Now also checks: strict equipment, pictures or video for every program exercise, the time budget
    (core <= 55, core + finisher <= 60) and the limitation rules.

### Still open (need the user)
- Re-confirm the "ankle machine" on site (open question 8). Also: Smith bar weight, leg press sled, leg curl type,
  and the real dumbbell and plate list (questions 1-4). All have safe defaults.
- Two cool-down stretches (`chest_doorway_stretch`, `bench_lat_stretch`) have no pictures. Offline they show the
  placeholder and text; the video needs internet. Accept, or replace them with stretches that have pictures?
- Real age (the default is 22) and whether any knee or back problems exist. At 95 kg, ticking "knee" or "lower back"
  in onboarding changes the exercises.
- 30-min sessions cannot fit any template day even after the ladder. The app shows a notice. Should 30 min be
  offered at all? The user's stated range is 45-60.
