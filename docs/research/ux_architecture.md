# Legon Lift: UX, Visual Identity and Flutter Architecture

Status: design proposal v1 (2026-11-20). Audience: the 4-6 engineers building the app and the content author.
Scope: information architecture, every screen, gym-floor ergonomics, visual identity and icon, verified Flutter packages, code architecture, data models, DB schema, JSON asset formats, and who owns which files.

---

## 0. Key decisions (TL;DR)

| Decision | Choice | Why |
|---|---|---|
| Platform | Android only, Flutter 3.50.0 / Dart 3.14.0 (verified on this machine) | User's phone: Samsung Galaxy A55, Android 17, 1080x2340 (~412 x 892 dp) |
| Material import | `package:material_ui/material_ui.dart` (material_ui 1.11.1 already locked) | In Flutter 3.50 `package:flutter/material.dart` is marked `@Deprecated` ("Use package:material_ui ... deprecated after v3.47") |
| State | `provider` ^6.1.5+1 with plain `ChangeNotifier` stores | Already in the local pub cache; same ChangeNotifier write-through pattern the expense_tracker app uses |
| Persistence | `sqflite` ^2.4.5 only (settings in a `kv` table) | Proven on this machine; one store means one backup file |
| Exercise images | Bundled as assets (WebP), not fetched | Gym Wi-Fi/data is unreliable; app must work 100% offline |
| Charts | `fl_chart` ^1.3.1 + one custom painter for the calendar heatmap | fl_chart has no heatmap widget |
| Notifications | `flutter_local_notifications` **^22.3.3** (not 23.x) | 23.x requires compileSdk 37, and only android-35/36 platforms are installed here |
| Program model | A rotation ("next workout in the sequence"), not fixed weekdays | Beginners miss days; Strong, Hevy and Boostcamp all advance by sequence. Weekdays are used only for reminders and the week strip |
| Default split | Push / Pull / Legs, 3x per week, 45-60 min | User request |
| Theme | Dark by default, high contrast, tabular big numbers | Gym lighting, sweat, glance-ability |

---

## 1. Lessons taken from the best gym apps

| App | What it does well | What we copy | What we avoid |
|---|---|---|---|
| **Strong** | Very fast set table (Set / Previous / kg / Reps / check), plate calculator, warm-up calculator, rest timer that starts when you tick a set | Set table layout, "Previous" column, auto rest timer, plate and warm-up calculators | Dense rows that need precise taps |
| **Hevy** | Clean logging, inline previous values, weekly streaks, PR badges per set, auto-fill from last session | Weekly (not daily) streak; PR trophies on the summary; pre-filled values | Social feed (we have none) |
| **Fitbod** | Generates the session for you, "swap exercise" with alternatives filtered by equipment, muscle recovery map | One-tap Swap with equipment-aware alternatives; "Replace for today" vs "Replace in program" | Black-box algorithm; beginners need to see *why* |
| **JEFIT** | Huge exercise library with animations, muscle and equipment filters | Library filters (muscle chips + equipment chips), two-frame animated demo | Ad-heavy, cluttered UI |
| **Boostcamp** | Structured programs from coaches, clear week/day progression | Program view as Day cards; progression shown as "next time: +2.5 kg" | Program marketplace complexity |
| **Caliber** | Coach tone, simple targets, strength score | Friendly coach copy, a single "what's next" focus | Paid coaching upsell |
| **Alpha Progression** | RIR-based autoregulation, colour-coded "increase / keep / decrease" suggestions | RIR input, translated into plain language; colour-coded next-time suggestions | Jargon ("RIR", "RPE") shown to beginners |
| **Nike Training Club** | Guided, step-by-step player, big visuals, voice/timers, warm-up and cool-down as part of the session | A full-screen guided *player* that owns the whole visit, warm-up through cool-down | Video streaming (we must work offline) |

UX-writing principles for workout loggers, gathered from these apps and general logger UX:
1. **One primary action per screen state.** In the player it is always "Log set" (or "Start rest" / "Next exercise").
2. **Pre-fill everything.** The user should mostly confirm, not type. The progression engine supplies weight and reps; "Previous" shows last time.
3. **Speak beginner.** Say "How many more could you have done?", not "RIR". Say "Rest", not "Inter-set recovery". Say "Heaviest set", not "e1RM" (the chart tooltip explains "estimated 1-rep max").
4. **Undo beats confirm.** Tapping logs immediately and a 5-second "Undo" snackbar appears. No "Are you sure?" dialogs mid-session, except for "End workout".
5. **Celebrate specific wins.** "New best: Leg Press 80 kg x 10" beats "Great job!".
6. **Explain why the app changed the numbers.** "+2.5 kg: you hit 12, 12, 11 last time."

---

## 2. Information architecture

```
App launch
 ├─ First run ──> Onboarding (9 steps) ──> Plan preview ──> Today
 └─ Normal ─────> Today  (a "Resume workout" banner shows if a session is in progress)

Bottom navigation (5 tabs, IndexedStack keeps each tab's state)
 1. Today       Home: next workout, week strip, streak, quick body-weight log, protein mini-checklist
 │   └─ Session Player (full-screen route, no bottom nav)
 │        Warm-up ─> Exercise 1..N (sets, rest) ─> Cool-down ─> Summary
 │        Sheets: Swap | Plates | How-to | Rest | Reorder/Skip | End workout
 2. Program     Active program: split, Day cards ─> Day editor ─> Exercise picker (Library in "pick" mode)
 │   └─ Change split (templates) | Rotation order | Weekday reminders
 3. Library     Search + muscle/equipment filters ─> Exercise detail (frames, cues, mistakes, video, my history)
 4. Progress    Overview | Exercises (e1RM) | Body | Calendar
 │   └─ Session detail (from history list or calendar)
 5. You         Profile, Body tracking, Nutrition helper, Settings, Backup, Safety, About/credits
```

Deep links inside the app (named routes, all in `app/routes.dart`):
`/onboarding`, `/session` (player), `/session/summary/:id`, `/exercise/:id`, `/program/day/:dayId`, `/history/:sessionId`, `/body`, `/nutrition`, `/settings`, `/backup`, `/safety`.

---

## 3. Screens

Reference viewport: 412 x 892 dp (Galaxy A55). Also test at 360 x 780 dp. Mockups below are ASCII sketches; sizes are in dp/sp.

### 3.1 Onboarding (target: done in under 2 minutes; every step has a sensible pre-selected default)

| # | Step | Content | Default for this user |
|---|---|---|---|
| 1 | Welcome | "Legon Lift: your step-by-step coach for the UG gym." Optional first name. | blank |
| 2 | Units | kg / lb (weights), cm / ft-in (height) | kg, ft-in |
| 3 | Body | Sex, age (number stepper), height, weight, waist (optional, with a "how to measure" tip) | male, 22, 5'7.5" (171 cm), 95 kg |
| 4 | Goal | Lose fat / Build muscle / **Both (recomposition)** with one line each | Both |
| 5 | Experience | **Brand new** / under 6 months / 6+ months | Brand new |
| 6 | Schedule | Days per week (2-5 stepper); preferred weekdays (chips Mon-Sun); session length 45 / 60 min | 3: Mon, Wed, Fri; 60 min |
| 7 | Split | Cards: **Push / Pull / Legs** (recommended badge), Upper / Lower, Chest+Back / Legs / Arms+Shoulders, Custom (build later). Each card shows the days and the muscles. | PPL |
| 8 | Equipment | UG gym preset checklist (from equipments.txt). "Ankle machine" is shown as **Calf raise machine** (user confirmed, see USER_NOTES.md). Untick anything that is broken. Also: available plates (kg chips) and bar weights. | all ticked |
| 9 | Safety | Readiness questions in the PAR-Q style (heart condition, chest pain, fainting/dizziness, bone/joint problem, blood-pressure medication, other medical reason). Any "yes" shows "Please talk to a doctor before starting. You can still continue." Heat card: "Accra is hot and humid: bring 1 L of water, sip between exercises, stop if dizzy or nauseous." Pain rule: "Muscle burn is normal. Sharp or joint pain: stop that exercise." Checkbox "I understand". | (required tick) |
| -> | Plan preview | "Your first week": three Day cards with exercises, "First session will feel light on purpose: we find your starting weights." Button **Let's go** | |

Rules: a progress dots row at the top, Back and Next buttons in the bottom thumb zone (56 dp tall), and every step after 3 has "Skip, use defaults". Everything stays editable later under You -> Profile.

### 3.2 Today (Home)

```
┌──────────────────────────────────────┐
│ Good evening                    (⚙)  │
│ ┌── RESUME WORKOUT (if any) ───────┐ │  amber banner, 72dp
│ │ Push A · 3 of 5 done · 24 min    │ │
│ └──────────────────────────────────┘ │
│ NEXT WORKOUT                         │
│ ┌──────────────────────────────────┐ │
│ │ PUSH  ·  Day 1 of 3              │ │  hero card
│ │ Chest · Shoulders · Triceps      │ │
│ │ 5 exercises · ~52 min            │ │
│ │ [ thumbnails of 5 exercises ]    │ │
│ │ ┌──────────────────────────────┐ │ │
│ │ │        START WORKOUT  ▶      │ │ │  64dp primary button
│ │ └──────────────────────────────┘ │ │
│ │  Preview · Do a different day ▾  │ │
│ └──────────────────────────────────┘ │
│ THIS WEEK          🔥 3-week streak  │  (an icon, not an emoji, in the app)
│  M   T   W   T   F   S   S           │
│  ●   ·   ◐   ·   ○   ·   ·           │  ● done, ◐ today planned, ○ planned
│ ┌ Body weight ┐ ┌ Protein today ───┐ │
│ │ 94.6 kg avg │ │ ■■■□□  90/150 g  │ │
│ │ [+ Log]     │ │ [Tick a portion] │ │
│ └─────────────┘ └──────────────────┘ │
│ Last time: Legs · Tue · 2 new bests  │
├──────────────────────────────────────┤
│ Today Program Library Progress  You  │
└──────────────────────────────────────┘
```
- The streak counts **weeks in which the weekly target was met** (Hevy-style), which suits 3 days per week far better than a daily streak.
- "Do a different day" lets the user choose any day of the rotation, for example when the leg press is broken today.
- Rest-day state: "Rest day: recovery is when muscles grow. Next: Pull (Wed)." with a light "Start anyway" link.

### 3.3 Session Player (the core)

The player is one full-screen route driven by a `SessionPlayerController`. A session is a flat list of **steps**:

`Warm-up (cardio 5 min + 3-4 mobility moves) -> [Exercise 1: warm-up sets -> working sets (rest between)] -> ... -> Cool-down (3-5 stretches, 30 s each) -> Summary`

Hydration nudges ("Sip water") appear on the "Up next" screen between exercises.

#### 3.3.1 Exercise screen layout

```
┌──────────────────────────────────────┐
│ ✕   Push A        2/5  ▮▮▯▯▯   18:42 │  56dp top bar, segmented progress, elapsed time
├──────────────────────────────────────┤
│ ┌──────────────────────────────────┐ │
│ │                                  │ │  Illustration 16:10, light card
│ │    [frame 0 ⇄ frame 1 loop]      │ │  (source photos have white backgrounds)
│ │                        ● ○ START │ │  phase dots + label
│ └──────────────────────────────────┘ │
│ Incline Dumbbell Press               │  24sp bold, max 2 lines
│ 3 × 8–12 · rest 2:00 · leave 2 in tank│ 16sp muted
│ [⇄ Busy? Swap] [▤ Plates] [? How] [▶] │  48dp chips; Plates only for barbell/Smith
│ ❝ Shoulder blades pinned to bench ❞  │  cue carousel: tap = next cue
├──────────────────────────────────────┤
│ SET  PREVIOUS      KG     REPS    ✓  │
│ W1   —             10  ×   10    ✔   │  warm-up rows muted, "W"
│ W2   —             14  ×    6    ✔   │
│ 1    20 × 12       22.5 ×  10    ✔   │  done rows collapse to 48dp
│┌────────────────────────────────────┐│
││ SET 2            last: 20 × 11     ││  ACTIVE ROW (expanded)
││  ( – )    22.5 kg    ( + )         ││  64×64dp steppers, value 40sp tabular
││  ( – )    10 reps    ( + )         ││
│└────────────────────────────────────┘│
│ 3    20 × 10       22.5 ×  10    ○   │
├──────────────────────────────────────┤
│ ┌──────────────────────────────────┐ │
│ │          ✓  LOG SET 2            │ │  72dp primary, full width, thumb zone
│ └──────────────────────────────────┘ │
│  Skip set        ⋯ More              │  More: reorder, skip exercise, add set, notes, end
└──────────────────────────────────────┘
```
- **Pre-filled targets** come from the progression engine (see §6.3 `ProgressionEngine`). The "PREVIOUS" column is the same set from the last time this exercise was done.
- Tapping a number opens a big numeric keypad sheet for typed entry. The steppers use the exercise's increment (barbell 2.5 kg total, dumbbell 2 kg or 2.5 kg per hand depending on the rack, cable stack 5 kg by default, editable per exercise).
- Dumbbell weights are shown **per hand** ("2 × 12.5 kg"). Volume maths uses the total.
- **Machine setting note** (Settings icon on the card): free text such as "seat 4, back pad 2", saved per exercise and shown again next time. This removes a big beginner pain point.
- First-ever exercise (no history): the active row shows "Find your weight: pick something you could lift 15 times. Aim for 10." The RIR answer then calibrates the next set (see the engine).

#### 3.3.2 Logging and the rest screen (one combined flow, so it costs the fewest taps)

Tap **LOG SET** -> a light haptic, the row turns green, and the rest sheet slides up and covers about 75% of the screen:

```
┌──────────────────────────────────────┐
│ Nice. How many more could you        │
│ have done?                           │
│ [ 0 ]  [ 1 ]  [ 2 ]  [ 3 ]  [ 4+ ]   │  56dp buttons; captions under 0 "none left", 4+ "easy"
│                                      │
│              1:47                    │  96sp countdown, circular ring
│          ( −15 )   ( +15 )           │
│ Next: Set 3 · 22.5 kg × 10           │
│ 💧 Sip some water                    │  (icon in the app)
│ ┌──────────────────────────────────┐ │
│ │          SKIP REST               │ │
│ └──────────────────────────────────┘ │
└──────────────────────────────────────┘
```
- The RIR question is optional. If it is not answered within the rest period it stays null. After 2 sessions of answering, a setting can switch it to "only on the last set" to cut taps.
- Rest durations default to compound 2:00, isolation 1:15 (adjustable per slot and in Settings). Defaults are longer than many apps use because of the heat.
- Alerts: at 10 s left, a light haptic; at 0, `HapticFeedback.heavyImpact()` three times about 150 ms apart plus a short beep (it ducks the user's music; it does not stop it); if the app is backgrounded, a heads-up notification "Rest over: Set 3 of Incline DB Press" fires.
- The timer is based on a **wall-clock deadline** (`restEndsAt` epoch ms, persisted), never on a ticking counter, so it survives the app being backgrounded or killed.

#### 3.3.3 Two-frame exercise "animation"

The source photos (free-exercise-db, Unlicense) give `0.jpg` = start position and `1.jpg` = end position.
- **Loop**: one `AnimationController(duration: 2400 ms)..repeat()`. The opacity of frame 1 follows a `TweenSequence`: hold 0 (700 ms) -> ease-in-out to 1 (500 ms) -> hold 1 (700 ms) -> ease-in-out to 0 (500 ms). Both images sit in a `Stack`; frame 1 is wrapped in a `FadeTransition`. The rhythm roughly matches a controlled rep.
- Add a subtle 1.00 -> 1.02 scale on the "end" phase for a sense of motion, plus phase dots and a "START" / "END" label for clarity.
- **Tap** the image to pause and step manually (flip between frames). **Long-press** opens the detail page.
- With **reduced motion** (`MediaQuery.disableAnimationsOf(context)`) show the two frames side by side, labelled "Start" and "End".
- Pause the controller when the rest sheet covers the image or the app is in the background (`TickerMode` / lifecycle). Call `precacheImage` on both frames of the current and the next exercise.
- The photos have white backgrounds, so frame them in a light card (`#E9EDF1`, radius 16) instead of fighting them with a dark theme.

#### 3.3.4 "Machine busy? Swap"

A bottom sheet lists up to 4 alternatives. They come from the exercise's `alternatives` list, then the rest are filled by the same `movementPattern` and primary muscle, filtered to equipment the user has ticked, and ranked by beginner-friendliness.
```
Machine busy? Try one of these instead:
 [img] Smith Machine Incline Press     same muscles · barbell feel
 [img] Incline Cable Press             cable station
 [img] Machine Chest Press (incline)   …
 ( ) Just for today   ( ) Replace in my program
                    [ SWAP ]
```
- Keep the sets/rep target; the weight is prefilled from that exercise's own history, or shows "Find your weight".
- The swap is stored in `session_exercises.original_exercise_id` so progress charts stay honest.
- A secondary option, "Wait: do the next exercise first", moves this exercise to after the next one (a reorder) instead of swapping.

#### 3.3.5 Plate calculator (barbell and Smith machine)

- Input: target total (prefilled from the set), bar weight (Olympic 20 kg by default; **Smith machine bar weight is set by the user**, default 10 kg, with an "unknown? count it as 0 and only track plates" option, because Smith bars differ and some are counterbalanced), available plates (from Settings; default 25, 20, 15, 10, 5, 2.5, 1.25 kg).
- Output: **per side**, a coloured plate-stack drawing (plate height scaled by weight) plus text "Each side: 20 + 5 + 1.25". If the exact weight is impossible, show the nearest lower and higher loads that are achievable.
- The algorithm is greedy over the sorted plates. It lives in `domain/plate_calculator.dart` (pure, unit tested).

#### 3.3.6 Warm-up sets

These are auto-generated for the **first exercise that hits each main muscle group** and for any barbell/Smith/leg-press lift where the working weight is above about 30 kg:
- Working weight ≥ 40 kg: 50% × 8, 70% × 5, 85% × 2 (rounded to achievable loads).
- Under 40 kg: 50% × 10, 75% × 5.
- Isolation exercises: none, or one optional "feeler" set at 50% × 10 (setting).
- Warm-up sets are shown as "W1, W2", are not counted in volume or PRs, and have a short 45 s rest.

#### 3.3.7 Skip and reorder
- "More ⋯" -> **Reorder exercises** opens a drag list with large handles. Up/Down arrow buttons are also offered, because drag is unreliable with sweaty hands.
- **Skip exercise** asks for a reason chip (busy / pain / no time / other); the reason is logged. "Pain" shows the safety tip and suggests a swap.
- **Add set**, **Remove last set**, **Exercise note**.
- **End workout**: the only confirm dialog. Choices "Finish and save" (unfinished sets marked skipped) or "Discard".

#### 3.3.8 Warm-up and cool-down steps
- Warm-up: "Bike or treadmill: 5 min, easy pace (you can talk)." A big countdown with a pause button, then a checklist of mobility moves (arm circles, empty-bar or light-cable shoulder pass-throughs (no bands at this gym), bodyweight squats, hip hinges), each with a 30-40 s timer and a "Done" tap.
- Cool-down: 3-5 stretches matched to the day's muscles (`programs.json` -> `cooldown`), 30 s each, auto-advancing with a beep.

#### 3.3.9 Session summary
- Header: confetti burst if there is at least one PR **or** it is the first session ever, or a streak milestone.
- Stats tiles: duration, sets done, total volume (kg), exercises.
- "New bests" list: trophy rows such as "Leg Press: 80 kg × 10 (heaviest weight)" and "Lat Pulldown: est. 1RM 62 kg (+3)".
- "Next time" list: per exercise, a coloured hint (green ↑ +2.5 kg / grey = keep / amber ↓). This is the Alpha Progression idea in plain words.
- Optional: "How did it feel?" (5 faces as icons), body weight quick entry, note.
- Button **Done** -> Today. The session status is set to `completed` and the wakelock is released.

### 3.4 Exercise Library
- Search field (matches name and aliases, e.g. "pec deck"), filter chips: **Muscle** (Chest, Back, Shoulders, Biceps, Triceps, Quads, Hamstrings, Glutes, Calves, Abs) and **Equipment** (only equipment the user ticked; toggle "show all"). A "Beginner-friendly" chip is on by default.
- List row: thumbnail (frame 0), name, primary muscle, equipment icon, ★ favourite.
- **Detail page**: two-frame player (larger), "Muscles worked" chips (primary bold, secondary regular), **Setup** steps, **Cues** (3-5 short lines), **Common mistakes** (2-4), **Watch a video** button, my history (best set, e1RM sparkline, last 5 sessions), machine-setting note, alternatives.
- **Video**: opens a YouTube search in the YouTube app or browser: `https://www.youtube.com/results?search_query=<name>+proper+form`, or `youtubeUrl` if the content author pinned a specific video. Search URLs never go dead. A badge "Needs internet" is shown. Use `url_launcher` with `LaunchMode.externalApplication`, and add the `<queries>` VIEW/https intent to the AndroidManifest (Android 11+ package visibility).
- Pick mode (from the program editor): the same screen, with a checkmark and an "Add" FAB.

### 3.5 Program view and editor
- **Program tab**: active program name + split, "Next up: Pull", and an ordered list of **Day cards** (name, muscles, exercise count, estimated minutes).
- **Change split**: template gallery from `programs.json` (PPL, Upper/Lower, Chest+Back / Legs / Arms+Shoulders, Custom from blank). Switching keeps history, and the progression engine works per exercise, so weights carry over.
- **Rotation order**: drag or arrow buttons to reorder days; "Next workout" pointer can be moved.
- **Day editor**: list of slots. Each slot: exercise, sets, rep range (min-max), rest, "leave X in the tank" target, and a warm-up toggle. Actions: add exercise (opens Library in pick mode), swap, remove, reorder. A live **time estimate** turns amber above the session-length goal. Duration formula: sum over sets of (≈40 s work + rest) + 5 min warm-up + 4 min cool-down + 1 min per exercise for transitions.
- "Reset to template" undoes custom edits.

### 3.6 History and Progress (Progress tab, segmented control)
1. **Overview**: sessions this month, total volume per week (fl_chart `BarChart`, last 12 weeks), **hard sets per muscle per week** (horizontal bars, with the 10-20 sets target band shaded), and recent PRs.
2. **Exercises**: pick an exercise -> **estimated 1RM** line (`LineChart`, Epley `w × (1 + reps/30)`, only sets with reps ≤ 12, best per session), with toggles for heaviest weight and best-set volume. Tooltip: "Estimated 1-rep max: what you could probably lift once."
3. **Body**: weight dots (daily) + **7-day average** line + waist (secondary axis or separate small chart). Recomp insight card: "Waist −2 cm and strength +15% in 6 weeks: you're recomping even though weight only moved 1 kg."
4. **Calendar**: a GitHub-style **heatmap** of the last 20 weeks (7 rows × 20 columns, colour intensity = sets done; a custom `CustomPainter` because fl_chart lacks heatmaps), plus a month calendar. Tap a day -> **Session detail** (exercises, sets, notes; editable after the fact; "Repeat this workout").

### 3.7 Body tracking (You -> Body)
- Quick entry: weight (big stepper, 0.1 kg), waist (cm, at the navel, relaxed, morning), date (defaults to today; one entry per date, editing replaces it).
- Guidance copy: "Weigh in the morning after the toilet, before food. Daily swings of 1-2 kg are water, salt and heat: watch the 7-day average."
- Optional reminder (notification) on chosen days.

### 3.8 Nutrition helper (You -> Nutrition)

It is a helper, not a food logger: estimates, a protein checklist and meal ideas, plus the disclaimer "not medical advice".
- **Calories**: Mifflin-St Jeor BMR (male: 10 × kg + 6.25 × cm − 5 × age + 5) × activity factor 1.45 (3 training days + campus walking) − 15-20% for recomp. For 95 kg, 171 cm, age 22: BMR ≈ 1,914, TDEE ≈ 2,775, **target ≈ 2,250-2,350 kcal**. Show it as a range, never false precision.
- **Protein**: about 1.6 g/kg of current body weight, rounded -> **≈ 150 g/day**, shown as **5 portions of ~30 g**.
- **Protein checklist (daily)**: 5 big tick boxes, each portion with examples: 3 eggs + a sachet of milk; a palm-size piece of grilled tilapia/mackerel; a chicken thigh or breast; a can of sardines or mackerel; a bowl of beans (red red, go easy on the oil) + 2 eggs; Greek-style yoghurt + groundnuts (small handful).
- **Ghana meal ideas** (from `personalization.json`): kenkey + grilled tilapia + pepper and onions; waakye with egg and fish, light on gari, spaghetti and oil; banku with okro or light soup + fish; kontomire stew + boiled eggs + boiled yam or plantain; light soup with chicken or goat + a smaller fufu ball; tuo zaafi + ayoyo soup + fish; jollof (one ladle) + grilled chicken + salad; oats or Tom Brown porridge with milk + boiled eggs for breakfast. Each idea is tagged ~protein grams, "budget", "campus/canteen", and a "swap to lighten it" tip.
- **Hydration**: target 3-4 L/day on training days in Accra heat, with a water tick row.

### 3.9 Settings (You -> Settings)
| Group | Items |
|---|---|
| Units | Weight kg/lb, height cm/ft-in |
| Equipment | Ticked equipment list, available plates, Olympic bar weight, Smith bar weight, dumbbell increment (1/2/2.5 kg) |
| Workout | Default rest (compound / isolation), auto-start rest timer, ask "how many more" (every set / last set / never), warm-up sets on/off, warm-up/cool-down on/off, hydration nudges |
| Feedback | Sound on/off, volume, vibration on/off, rest notification on/off (requests POST_NOTIFICATIONS), **keep screen awake during workouts** (on by default) |
| Appearance | Theme dark (default) / light / system, palette (3 options), large-text mode |
| Data | **Export backup (JSON)** via the share sheet or "Save to device", **Import backup** (file picker, preview, then Replace or Merge), automatic weekly local backup (keep the last 4), reset all data |
| About | Safety info, exercise data credits (free-exercise-db, Unlicense), version |

---

## 4. Gym-floor ergonomics (requirements, not suggestions)

1. **Keep screen awake**: `WakelockPlus.enable()` when the player opens, `disable()` on summary, discard, or `AppLifecycleState.paused` longer than 10 min. It is controlled by a setting.
2. **Resume after kill**: every user action in the player writes through to SQLite (set logs and a `player_state_json` cursor holding `stepIndex`, `exerciseIndex`, `setIndex`, `restEndsAt`, `startedAt`). On launch, `SessionRepository.findInProgress()` -> Today shows the "Resume workout" banner (sessions older than 12 h offer "Finish and save" / "Discard"). The rest countdown is recomputed from `restEndsAt`.
3. **Offline**: no network calls at all except the user-initiated YouTube button. All exercise data, images and fonts are bundled. **Do not use `google_fonts` at runtime**; bundle the TTFs.
4. **One-handed**: all primary actions sit in the bottom 40% of the screen. The top bar holds only navigation/info. Bottom sheets rather than top dialogs.
5. **Sweaty hands**: minimum tap target 56 dp, 64 dp for steppers, 72 dp for the main button; at least 8 dp spacing between destructive and primary actions; no swipe-only or long-press-only actions; undo snackbars instead of confirmations.
6. **Glanceable**: weight/rep values 40 sp, rest countdown 96 sp, tabular figures (`FontFeature.tabularFigures()`) so digits don't jump.
7. **Dark and high contrast by default**: body text ≥ 15:1 against the background, secondary text ≥ 7:1 (see palettes).
8. **Earbuds and music**: beeps use transient audio focus with ducking (audioplayers `AudioContextAndroid(audioFocus: AndroidAudioFocus.gainTransientMayDuck, usageType: AndroidUsageType.assistanceSonification)`).
9. **Heat**: hydration nudges between exercises, slightly longer default rests, and safety copy about dizziness.
10. **Battery**: the animation pauses off-screen, there is no background service, and the only background work is one scheduled notification per rest.

---

## 5. Visual identity

### 5.1 Name
**Legon Lift** (primary). Alternates, in case:
1. **Legon Iron**: same campus anchor, stronger "weights" signal.
2. **Ahoɔden** (Twi for "strength"; written "Ahoden" in ASCII): local and memorable. Confirm the spelling and tone with a native speaker before using it.
3. **RepRoute**: describes the guided, step-by-step player and works beyond Legon.

### 5.2 Three colour palettes (dark-first; contrast ratios computed against background / surface)

**A. "Legon Night": recommended default.** A subtle nod to UG's blue-and-gold identity.
| Token | Hex | Use | Contrast on bg / surface |
|---|---|---|---|
| bg | `#0B0F14` | scaffold | n/a |
| surface | `#151B23` | cards, sheets | n/a |
| surface2 | `#1E2630` | inputs, inactive rows | n/a |
| onSurface | `#F2F5F8` | primary text | 17.6 / 15.8 |
| muted | `#9AA7B4` | secondary text | 7.8 / 7.1 |
| primary (gold) | `#FFC629` | main buttons, active row, rings | 12.2 / 11.0 |
| onPrimary | `#0B0F14` | text on gold | 12.2 |
| secondary (Legon blue) | `#4C8DFF` | links, charts series 2, selected chips | 6.0 / 5.4 |
| success | `#2ED47A` | done sets, ↑ hints | 9.9 / 8.9 |
| danger | `#FF5A5F` | end/discard, pain | 6.3 / 5.7 |
| warmup | `#9AA7B4` at 60% | warm-up rows | n/a |

**B. "Kente Energy"**: gold, green and red on near-black, energetic.
bg `#0D0D0F`, surface `#18181C`, text `#F5F5F0` (17.8), muted `#A3A39A` (7.6), primary gold `#F5B700` (10.8), secondary green `#00B37A` (7.2), accent orange `#FF8A3D` (8.3), danger `#E5484D` (5.0: use it for icons/large text only).

**C. "Volt Teal"**: modern and cool; it stands out against the gym environment.
bg `#07110F`, surface `#0F1E1B`, text `#E8FFF9` (18.3), muted `#8FB3AA` (8.4), primary teal `#2DE1C2` (11.6), secondary amber `#FFB020` (10.5), danger `#FF6B6B` (6.9), info `#7AA2FF` (7.7).

A light theme for each palette can be derived (bg `#F6F8FA`, surface `#FFFFFF`, primary darkened ~25%) but it is a secondary priority.

### 5.3 Typography (bundled TTFs, OFL licensed)
- **Display / numbers**: *Barlow Semi Condensed* (SemiBold 600, Bold 700). It has an athletic feel, and condensed digits fit "122.5" at 40 sp in narrow columns.
- **Body / UI**: *Inter* (Regular 400, Medium 500, SemiBold 600), with `tnum` enabled for tables.
- Scale (sp): display 96 (rest timer) / 56 (summary stats) / 40 (stepper values); headline 28; title 22; body 16; label 14; caption 12. Minimum 14 sp anywhere in the player.
- Download the files once from github.com/google/fonts (`ofl/barlowsemicondensed`, `ofl/inter`) into `assets/fonts/`.

### 5.4 App icon (exact vector, 1024 × 1024 canvas)

Concept: **a gold barbell with a white upward chevron above it**: "lift" and "progress" in one mark. It reads at 48 px and fits the Android adaptive-icon safe zone (a circle of radius 313 centred on 512,512, i.e. 66/108 of the canvas; every shape below stays within radius ~290).

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <radialGradient id="bg" cx="50%" cy="42%" r="70%">
      <stop offset="0" stop-color="#16294A"/>   <!-- Legon blue glow -->
      <stop offset="1" stop-color="#0B0F14"/>   <!-- palette A bg -->
    </radialGradient>
  </defs>
  <rect width="1024" height="1024" rx="224" fill="url(#bg)"/>   <!-- omit rx for adaptive background layer -->
  <!-- chevron (progress) -->
  <path d="M392 452 L512 332 L632 452" fill="none" stroke="#FFFFFF"
        stroke-width="60" stroke-linecap="round" stroke-linejoin="round"/>
  <!-- barbell (gold #FFC629) -->
  <rect x="280" y="590" width="464" height="36"  rx="18" fill="#FFC629"/> <!-- bar + sleeves -->
  <rect x="300" y="510" width="52"  height="196" rx="14" fill="#FFC629"/> <!-- left big plate -->
  <rect x="364" y="544" width="36"  height="128" rx="10" fill="#FFC629"/> <!-- left small plate -->
  <rect x="672" y="510" width="52"  height="196" rx="14" fill="#FFC629"/> <!-- right big plate -->
  <rect x="624" y="544" width="36"  height="128" rx="10" fill="#FFC629"/> <!-- right small plate -->
</svg>
```
This was rendered and checked with `rsvg-convert`; the composition is centred and inside the safe zone.
Deliverables: `assets/icon/icon.svg` (full), `icon_foreground.svg` (shapes only, transparent), `icon_background.svg` (gradient only), `icon_monochrome.svg` (all shapes in white, for Android 13+ themed icons). Rasterise with `rsvg-convert -w 1024` (installed at /usr/bin) and generate the launcher icons with `flutter_launcher_icons` (adaptive_icon_background / foreground / monochrome).
Splash: bg `#0B0F14` with the same mark at 192 dp (Android 12 splash API, via `flutter_launcher_icons`-generated assets or a plain `launch_background.xml`).

---

## 6. Flutter technology choices

### 6.1 Environment (verified on this machine, 2026-11-20)
- Flutter **3.50.0** stable, Dart **3.14.0**, SDK at `/home/gbesh/development/flutter` (not on PATH; call `~/development/flutter/bin/flutter`).
- Project `/home/gbesh/coding/workout` (package `legon_lift`): `environment: sdk: ^3.14.0`, deps `material_ui ^1.1.0` (locked 1.11.1) and `cupertino_icons`. Android: AGP 9.3.1, Kotlin 2.4.20, Gradle 9.5.0, Java 17, `compileSdk = flutter.compileSdkVersion` (= 36), minSdk 24.
- Android SDK at `/home/gbesh/Android/Sdk`: platforms **android-35, android-36** only; build-tools 36.0.0 / 36.1.0.
- **Answer to "the deps should be there, right?"** Partly. The local pub cache (`~/.pub-cache/hosted/pub.dev`) already holds what expense_tracker used: `sqflite 2.4.5` (+ android/darwin/common/ffi), `path_provider 2.1.6`, `intl 0.20.3`, `share_plus 13.3.1`, `file_picker 13.3.2`, `path 1.9.1`, `archive 4.6.0`, plus `provider 6.1.5+1`, `url_launcher 6.3.2`, `uuid 4.5.3/4.6.0`, `collection 1.19.1`, `material_ui 1.11.1`. **Not cached**: `fl_chart`, `wakelock_plus`, `flutter_local_notifications`, `audioplayers`, `confetti`, `flutter_launcher_icons`. So one online `flutter pub get` is needed; after that, builds work offline (`flutter pub get --offline`).

### 6.2 Package set: versions checked on the pub.dev API today, and the full set resolved with `flutter pub get --dry-run` on Flutter 3.50

```yaml
environment:
  sdk: ^3.14.0

dependencies:
  flutter:
    sdk: flutter
  material_ui: ^1.11.1              # Material widgets (Flutter 3.50 deprecates package:flutter/material.dart)
  provider: ^6.1.5+1                # state (cached locally)
  sqflite: ^2.4.5                   # DB (cached; 2.4.6 is the latest)
  path: ^1.9.1
  path_provider: ^2.1.6
  intl: ^0.20.3                     # dates, number formatting
  share_plus: ^13.3.1               # export backup via share sheet
  file_picker: ^13.3.2              # import backup / save file (13.4.0 latest)
  url_launcher: ^6.3.2              # YouTube button
  uuid: ^4.5.3                      # ids for sessions/sets
  collection: ^1.19.1
  fl_chart: ^1.3.1                  # charts (published 2026-11-09)
  wakelock_plus: ^1.8.2             # keep screen awake (needs Flutter >=3.44)
  flutter_local_notifications: ^22.3.3   # rest-over notification; NOT 23.x (needs compileSdk 37)
  audioplayers: ^6.8.1              # short beep with ducking
  confetti: ^0.8.0                  # summary celebration (pure Dart; last release 2024-09, stable API)

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  sqflite_common_ffi: ^2.4.5        # run DB tests on the desktop VM
  flutter_launcher_icons: ^0.14.4
```
The dry-run resolved: provider 6.1.5+1, sqflite 2.4.6, fl_chart 1.3.1, wakelock_plus 1.8.2, flutter_local_notifications 22.3.3, audioplayers 6.8.1, confetti 0.8.0, share_plus 13.3.1, file_picker 13.4.0, url_launcher 6.3.3, intl 0.20.3, path_provider 2.1.6.

Considered and rejected:
- `flutter_riverpod` 3.5.0: fine, but it adds a concept for 6 engineers and is not cached locally. Provider plus ChangeNotifier is enough.
- `drift`, `hive`, `isar`: codegen or maintenance risk; sqflite is proven here.
- `shared_preferences` 2.5.6: unnecessary, since settings live in the sqflite `kv` table and so ride along in backups automatically.
- `google_fonts` 9.0.0: fetches over the network; bundle the TTFs instead.
- `cached_network_image`: bundle the images instead (offline-first).
- `go_router` 18.1.4: named routes plus `Navigator` are enough for this app.
- `vibration` 3.2.1: optional fallback only if `HapticFeedback` turns out too weak on the A55 with system haptics turned down.
- `flutter_local_notifications` 23.0.3: requires compileSdk 37 and AGP 9.1.1+. **Upgrade later** by installing the `platforms;android-37` SDK and setting `compileSdk = 37` in `android/app/build.gradle.kts`.

### 6.3 Android configuration checklist
- `android/app/build.gradle.kts`: enable **core library desugaring** (required by flutter_local_notifications 10+):
  `compileOptions { isCoreLibraryDesugaringEnabled = true }` and `dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5") }` (use the version the plugin README states).
- `AndroidManifest.xml`: `POST_NOTIFICATIONS` (request at the first rest timer, not at launch), `VIBRATE`, `WAKE_LOCK` (added by wakelock_plus), `RECEIVE_BOOT_COMPLETED` is not needed. For an exact rest alarm, `SCHEDULE_EXACT_ALARM` is optional: call `canScheduleExactNotifications()`. If it is denied, use `AndroidScheduleMode.inexactAllowWhileIdle` **plus** an ongoing notification with `usesChronometer: true, chronometerCountDown: true, when: restEndsAt`, so the shade still shows an accurate live countdown. Never request `USE_EXACT_ALARM` (reserved for alarm-clock apps).
- `<queries><intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent></queries>` for url_launcher.
- Notification channel `rest_timer`: importance high, custom vibration pattern `[0, 300, 150, 300, 150, 300]`, sound = bundled `res/raw/rest_done.ogg`.
- API usage notes from the working expense_tracker code: `FilePicker.pickFiles(...)` / `FilePicker.saveFile(bytes: ...)` (static API in v13) and `SharePlus.instance.share(ShareParams(files: [XFile(path)]))`.

### 6.4 Asset bundling
- Images: copy only the curated exercises (~60-80) from free-exercise-db (`https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/<id>/0.jpg`, `1.jpg`) with a one-time script `tool/fetch_images.py`, convert to WebP at quality 80, max width 720 (`magick` is installed) -> `assets/images/exercises/<exerciseId>/0.webp`, `1.webp`. Expect about 4-8 MB in total.
- Sounds: `assets/sounds/beep_short.ogg`, `rest_done.ogg` (also copied into `android/app/src/main/res/raw/` for the notification).
- Fonts: `assets/fonts/BarlowSemiCondensed-*.ttf`, `Inter-*.ttf`.
- Data: `assets/data/exercises.json`, `programs.json`, `personalization.json`.

---

## 7. Code architecture

### 7.1 Layers
```
UI (features/*)  ──watch──>  Stores (ChangeNotifier, state/*)  ──call──>  Domain (pure Dart, domain/*)
                                     │                                       ▲
                                     └──> Repositories (data/repositories/*) ─┘ (domain gets plain models)
                                              ├─ AppDatabase (sqflite)
                                              └─ AssetCatalog (JSON assets, read-only)
Services (services/*): RestAlarm, Sound, Haptics, Wakelock, Launcher: thin wrappers behind interfaces
```
Rules: the domain layer imports no Flutter except `foundation.dart` and is 100% unit-testable. UI never touches sqflite. Every repository and service has an abstract class plus a fake in `test/fakes/` so features can be built before the real implementation lands.

### 7.2 Folder structure and ownership

```
lib/
  main.dart                          [E1] bootstrap: open DB, load assets, runApp(MultiProvider)
  app/
    app.dart                         [E4] MaterialApp, theme, routes, onboarding gate
    routes.dart                      [E4] route names + builders
    shell.dart                       [E4] bottom NavigationBar + IndexedStack
    theme/
      tokens.dart                    [E4] palettes A/B/C as const ColorTokens
      app_theme.dart                 [E4] ThemeData builder (dark/light per palette)
      typography.dart                [E4] TextTheme, tabular figures
  core/
    units.dart                       [E2] kg<->lb, cm<->ft-in, rounding to increments
    format.dart                      [E2] weight/duration/date formatting (intl)
    clock.dart                       [E2] Clock interface (testable now())
    ids.dart                         [E1] uuid helper
  data/
    models/                          [E1] immutable models with toMap/fromMap/toJson/fromJson + copyWith
      exercise.dart  program.dart  session.dart  set_log.dart  body_entry.dart
      user_profile.dart  app_settings.dart  personalization.dart  nutrition_day.dart  enums.dart
    db/
      app_database.dart              [E1] open, onCreate, onUpgrade (versioned migrations)
      schema.dart                    [E1] CREATE TABLE strings (§7.4)
    assets/
      asset_catalog.dart             [E1] loads + validates the 3 JSON files once at startup
    repositories/                    [E1] abstract + sqflite implementations
      profile_repository.dart  settings_repository.dart  program_repository.dart
      session_repository.dart  body_repository.dart  nutrition_repository.dart
      exercise_prefs_repository.dart
    backup/
      backup_service.dart            [E1] export/import JSON, validation, merge/replace
  domain/                            [E2] pure Dart + unit tests
    progression_engine.dart          next targets from history + RIR
    warmup_planner.dart
    plate_calculator.dart
    one_rep_max.dart                 Epley/Brzycki, best-of-session
    session_builder.dart             Program day + history -> SessionPlan (steps)
    swap_suggester.dart
    pr_detector.dart
    stats.dart                       weekly volume, sets/muscle, streak, 7-day moving avg, heatmap buckets
    nutrition_calculator.dart
    duration_estimator.dart
  services/                          [E3]
    rest_alarm_service.dart          schedule/cancel notification at restEndsAt
    sound_service.dart               audioplayers with ducking
    haptics.dart                     patterns over HapticFeedback
    wakelock_service.dart
    launcher_service.dart            YouTube URLs
  state/
    profile_store.dart               [E4]
    settings_store.dart              [E1]
    program_store.dart               [E4]
    session_player_controller.dart   [E3] THE state machine (see 7.6)
    history_store.dart               [E5]
    body_store.dart                  [E5]
    nutrition_store.dart             [E6-UI owner below]
  features/
    onboarding/                      [E4] onboarding_flow.dart + steps/*.dart + safety_step.dart
    today/                           [E4] today_screen.dart, week_strip.dart, resume_banner.dart
    session_player/                  [E3]
      player_screen.dart  warmup_step_view.dart  exercise_step_view.dart  cooldown_step_view.dart
      widgets/ frame_animator.dart set_table.dart active_set_editor.dart rest_sheet.dart
               rir_picker.dart plate_calculator_sheet.dart swap_sheet.dart reorder_sheet.dart
               up_next_card.dart
      summary_screen.dart
    library/                         [E5] library_screen.dart, exercise_detail_screen.dart, filters.dart
    program/                         [E4] program_screen.dart, day_editor_screen.dart, split_picker.dart
    progress/                        [E5] progress_screen.dart, volume_chart.dart, e1rm_chart.dart,
                                          body_chart.dart, calendar_heatmap.dart, session_detail_screen.dart
    body/                            [E5] body_screen.dart, body_entry_sheet.dart
    nutrition/                       [E6] nutrition_screen.dart, protein_checklist.dart, meal_ideas.dart
    settings/                        [E1] settings_screen.dart, backup_screen.dart, equipment_settings.dart
    you/                             [E4] you_screen.dart (hub)
  widgets/                           [E4] shared: big_button.dart, number_stepper.dart, stat_tile.dart,
                                          section_header.dart, empty_state.dart, undo_snackbar.dart
assets/                              [E6] data/*.json, images/exercises/**, fonts/**, sounds/**, icon/**
tool/                                [E6] fetch_images.py, validate_assets.dart, make_icons.sh
test/
  fakes/                             [E1] in-memory repos, FakeClock, FakeRestAlarm
  domain/                            [E2]
  data/                              [E1] (sqflite_common_ffi)
  widgets/                           [owners of each feature]
```

**Teams (6 engineers; with 4, merge E5 into E4 and E6 into E2):**
| Id | Owns | First deliverable (day 1-2) that unblocks others |
|---|---|---|
| E1 Data platform | models, DB, repositories, asset catalog, backup, settings screen, main.dart | All model classes + abstract repository interfaces + fakes merged first |
| E2 Domain engine | domain/*, core/units, core/format | Signatures of every domain function (stubs returning simple values) |
| E3 Session Player | session_player/*, services/*, session_player_controller | Player running on FakeSessionRepository + stub engine |
| E4 Shell & planning | app shell, theme, shared widgets, onboarding, Today, Program, You hub | Theme tokens + shared widgets (others use them) |
| E5 Insight | Library, Progress charts, Body, history store | Library list on AssetCatalog |
| E6 Content & brand | exercises.json, programs.json, personalization.json, images, fonts, icon, sounds, Nutrition screen, validate script | A minimal valid JSON set (10 exercises, PPL) on day 1 |

Merge-conflict hot spots and their single owners: `pubspec.yaml` (E1), `routes.dart` (E4; others send their route builder in a PR), `schema.dart` (E1).

### 7.3 Data models (Dart; abridged, all `@immutable` with `copyWith`, `toMap`/`fromMap` for DB and `toJson`/`fromJson` for assets and backup)

```dart
// enums.dart
enum Muscle { chest, lats, upperBack, traps, frontDelts, sideDelts, rearDelts, biceps, triceps,
              forearms, quads, hamstrings, glutes, calves, adductors, abductors, abs, lowerBack }
enum Equipment { barbell, dumbbell, cable, latPulldown, shoulderPressMachine, chestPressMachine,
                 legPress, legCurl, legExtension, calfRaiseMachine, smith, bench, bike, treadmill, bodyweight }
enum LoadType { barbell, smith, dumbbellPair, dumbbellSingle, stack, plateLoaded, bodyweight }
enum MovementPattern { horizontalPush, inclinePush, verticalPush, horizontalPull, verticalPull,
                       squat, hinge, lunge, kneeFlexion, kneeExtension, calfRaise, elbowFlexion,
                       elbowExtension, lateralRaise, rearDelt, core, cardio, mobility, stretch }
enum SetKind { warmup, working }
enum SessionStatus { inProgress, completed, abandoned }
enum StepKind { warmupCardio, mobility, exercise, cooldown }
enum Goal { loseFat, buildMuscle, recomp }
enum Experience { brandNew, under6m, over6m }

// exercise.dart: read-only, from assets
class Exercise {
  final String id;                 // "machine_chest_press"
  final String name;
  final List<String> aliases;
  final List<Equipment> equipment; // all required
  final LoadType loadType;
  final MovementPattern pattern;
  final List<Muscle> primary, secondary;
  final bool compound;
  final int difficulty;            // 1 easy .. 3 hard
  final List<String> images;       // ["assets/images/exercises/machine_chest_press/0.webp", ".../1.webp"]
  final List<String> setup, cues, mistakes;
  final String? youtubeUrl;        // optional pinned video
  final String youtubeQuery;       // fallback search terms
  final double incrementKg;        // smallest sensible jump (total)
  final double? defaultStartKg;    // conservative beginner starting load
  final List<String> alternatives; // exercise ids
  final String? sourceId;          // free-exercise-db id (credits)
}

// program.dart: stored as a JSON document in the programs table
class Program { final String id, name, splitKey; final List<ProgramDay> days; final int nextDayIndex;
                final List<int> reminderWeekdays; final bool isActive; final String? templateId; }
class ProgramDay { final String id, name; final List<Muscle> focus; final List<Slot> slots;
                   final List<String> warmupMobility, cooldown; }
class Slot { final String id, exerciseId; final int sets, repMin, repMax, restSec, targetRir;
             final bool warmupSets; final String? note; }

// session.dart
class Session { final String id, programId, dayId, dayName; final SessionStatus status;
                final DateTime startedAt; final DateTime? endedAt; final double? bodyweightKg;
                final int? feeling; final String? note; final PlayerCursor? cursor;
                final List<SessionExercise> exercises; }
class SessionExercise { final String id, sessionId, exerciseId; final String? originalExerciseId;
                        final int position; final String status; // pending|done|skipped
                        final String? skipReason; final Slot target; final List<SetLog> sets; }
class SetLog { final String id, sessionExerciseId, sessionId, exerciseId; final int setIndex;
               final SetKind kind; final double? targetKg; final int? targetReps;
               final double weightKg; final int reps; final int? rir; final DateTime completedAt;
               final bool isPr; }
class PlayerCursor { final int stepIndex, exerciseIndex, setIndex; final DateTime? restEndsAt; }

// others
class BodyEntry { final String date; final double? weightKg, waistCm; final String? note; }
class UserProfile { final String? name; final String sex; final int age; final double heightCm, weightKg;
                    final Goal goal; final Experience experience; final int daysPerWeek, sessionMinutes;
                    final List<Equipment> equipment; final bool safetyAccepted; final List<String> safetyFlags; }
class AppSettings { final bool useLb, useFtIn, keepAwake, sound, vibration, restNotification,
                    autoRest, warmups, hydrationNudges; final String rirPrompt; // every|last|never
                    final int restCompoundSec, restIsolationSec; final List<double> platesKg;
                    final double barKg, smithBarKg, dumbbellStepKg; final String palette, themeMode; }
class NutritionDay { final String date; final List<bool> proteinPortions; final int waterTicks; }
```

### 7.4 SQLite schema (DB version 1; all weights in **kg**, all timestamps in **epoch ms UTC**, dates `yyyy-MM-dd` local)

```sql
CREATE TABLE kv (key TEXT PRIMARY KEY, value TEXT NOT NULL);           -- 'profile','settings' JSON, flags
CREATE TABLE programs (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, split_key TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 0, data_json TEXT NOT NULL,       -- days/slots document
  updated_at INTEGER NOT NULL);
CREATE TABLE sessions (
  id TEXT PRIMARY KEY, program_id TEXT, day_id TEXT, day_name TEXT NOT NULL,
  status TEXT NOT NULL,                                                -- in_progress|completed|abandoned
  started_at INTEGER NOT NULL, ended_at INTEGER, bodyweight_kg REAL,
  feeling INTEGER, note TEXT, cursor_json TEXT,                        -- PlayerCursor for resume
  total_volume_kg REAL NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL);
CREATE INDEX idx_sessions_started ON sessions(started_at);
CREATE INDEX idx_sessions_status ON sessions(status);
CREATE TABLE session_exercises (
  id TEXT PRIMARY KEY, session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  position INTEGER NOT NULL, exercise_id TEXT NOT NULL, original_exercise_id TEXT,
  status TEXT NOT NULL, skip_reason TEXT, target_json TEXT NOT NULL, note TEXT);
CREATE INDEX idx_se_session ON session_exercises(session_id, position);
CREATE TABLE set_logs (
  id TEXT PRIMARY KEY,
  session_exercise_id TEXT NOT NULL REFERENCES session_exercises(id) ON DELETE CASCADE,
  session_id TEXT NOT NULL, exercise_id TEXT NOT NULL, set_index INTEGER NOT NULL,
  kind TEXT NOT NULL,                                                  -- warmup|working
  target_kg REAL, target_reps INTEGER, weight_kg REAL NOT NULL, reps INTEGER NOT NULL,
  rir INTEGER, completed_at INTEGER NOT NULL, is_pr INTEGER NOT NULL DEFAULT 0);
CREATE INDEX idx_sets_exercise_time ON set_logs(exercise_id, completed_at);
CREATE INDEX idx_sets_session ON set_logs(session_id);
CREATE TABLE personal_records (
  exercise_id TEXT NOT NULL, type TEXT NOT NULL,                       -- e1rm|max_weight|max_reps_at_weight|best_volume
  value REAL NOT NULL, set_log_id TEXT NOT NULL, achieved_at INTEGER NOT NULL,
  PRIMARY KEY (exercise_id, type));
CREATE TABLE body_entries (date TEXT PRIMARY KEY, weight_kg REAL, waist_cm REAL, note TEXT,
  updated_at INTEGER NOT NULL);
CREATE TABLE nutrition_days (date TEXT PRIMARY KEY, protein_json TEXT NOT NULL, water_ticks INTEGER NOT NULL DEFAULT 0);
CREATE TABLE exercise_prefs (exercise_id TEXT PRIMARY KEY, favorite INTEGER NOT NULL DEFAULT 0,
  hidden INTEGER NOT NULL DEFAULT 0, increment_kg REAL, machine_note TEXT);
```
- Open with `PRAGMA foreign_keys = ON` in `onConfigure`. Migrations are `onUpgrade` steps keyed by version, as the expense tracker does (its DB is at version 3).
- Write-through: a logged set = one transaction (insert set_log + update sessions.cursor_json + updated_at). `personal_records` is recomputed for that exercise at session completion.

### 7.5 JSON assets (read-only, loaded once by `AssetCatalog.load()` in `main()` via `rootBundle.loadString`, decoded in a background isolate with `compute(jsonDecode, ...)` if larger than 200 KB)

Each file carries `"schemaVersion": 1`. `tool/validate_assets.dart` (run in CI or before a commit) checks that: ids are unique; every `exerciseId` in programs exists; every image path exists in the pubspec asset folder; alternatives resolve; and no exercise needs equipment outside the UG list.

**assets/data/exercises.json**
```json
{ "schemaVersion": 1,
  "exercises": [{
    "id": "machine_chest_press", "name": "Machine Chest Press", "aliases": ["chest press", "seated chest press"],
    "equipment": ["chestPressMachine"], "loadType": "stack", "pattern": "horizontalPush",
    "primary": ["chest"], "secondary": ["frontDelts", "triceps"], "compound": true, "difficulty": 1,
    "images": ["assets/images/exercises/machine_chest_press/0.webp", "assets/images/exercises/machine_chest_press/1.webp"],
    "setup": ["Set the seat so handles are at mid-chest.", "Feet flat, back against the pad."],
    "cues": ["Squeeze shoulder blades together", "Push, don't lock elbows hard", "2 seconds back"],
    "mistakes": ["Shoulders shrugging up", "Bouncing the weight stack"],
    "youtubeQuery": "machine chest press proper form", "youtubeUrl": null,
    "incrementKg": 5, "defaultStartKg": 20,
    "alternatives": ["smith_bench_press", "dumbbell_bench_press", "cable_chest_press"],
    "sourceId": "Leverage_Chest_Press" }] }
```

**assets/data/programs.json**
```json
{ "schemaVersion": 1,
  "templates": [{
    "id": "ppl_3", "name": "Push / Pull / Legs", "splitKey": "ppl", "daysPerWeek": 3, "recommended": true,
    "description": "Each muscle group gets its own day. Great for 3 days a week.",
    "days": [{
      "id": "push", "name": "Push", "focus": ["chest", "frontDelts", "sideDelts", "triceps"],
      "warmup": { "cardio": { "exerciseId": "stationary_bike", "minutes": 5 },
                  "mobility": ["arm_circles", "cable_external_rotation_light", "pushup_incline_bench"] },
      "slots": [
        { "exerciseId": "machine_chest_press",   "sets": 3, "repMin": 8,  "repMax": 12, "restSec": 120, "targetRir": 2, "warmupSets": true },
        { "exerciseId": "incline_dumbbell_press","sets": 3, "repMin": 8,  "repMax": 12, "restSec": 120, "targetRir": 2 },
        { "exerciseId": "machine_shoulder_press","sets": 3, "repMin": 8,  "repMax": 12, "restSec": 120, "targetRir": 2 },
        { "exerciseId": "dumbbell_lateral_raise","sets": 2, "repMin": 12, "repMax": 15, "restSec": 75,  "targetRir": 2 },
        { "exerciseId": "cable_triceps_pushdown","sets": 3, "repMin": 10, "repMax": 15, "restSec": 75,  "targetRir": 2 } ],
      "cooldown": ["chest_doorway_stretch", "triceps_overhead_stretch", "shoulder_cross_body_stretch"] }]
  }]}
```
Templates to ship: `ppl_3` (Push: chest press machine, incline DB press, shoulder press machine, lateral raise, triceps pushdown; Pull: lat pulldown, seated cable row, one-arm DB row, cable face pull, DB curl; Legs: leg press, DB/barbell Romanian deadlift, leg extension, leg curl, calf raise machine, cable crunch), `upper_lower` (rotation of Upper A / Lower A / Upper B / Lower B over 3 days a week), `cb_legs_arms` (Chest+Back / Legs / Arms+Shoulders), `custom_blank`. The final exercise prescriptions are owned by E6 together with the programming research.

**assets/data/personalization.json**
```json
{ "schemaVersion": 1,
  "defaultProfile": { "sex": "male", "age": 22, "heightCm": 171, "weightKg": 95, "goal": "recomp",
                      "experience": "brandNew", "daysPerWeek": 3, "sessionMinutes": 60,
                      "reminderWeekdays": [1, 3, 5], "templateId": "ppl_3" },
  "gym": { "name": "University of Ghana gym (Legon)",
           "equipment": ["cable", "latPulldown", "shoulderPressMachine", "chestPressMachine", "bike",
                         "treadmill", "barbell", "dumbbell", "legPress", "calfRaiseMachine", "legCurl",
                         "legExtension", "smith", "bench"],
           "equipmentNotes": { "calfRaiseMachine": "Listed as 'Ankle machine' in equipments.txt; user confirmed it is a calf raise machine." },
           "platesKg": [25, 20, 15, 10, 5, 2.5, 1.25], "barKg": 20, "smithBarKg": 10 },
  "defaults": { "restCompoundSec": 120, "restIsolationSec": 75, "hydrationNudgeEveryMin": 15 },
  "nutrition": {
    "activityFactor": 1.45, "deficitPct": [0.15, 0.20], "proteinGPerKg": 1.6, "portionGrams": 30,
    "hydrationLitres": [3, 4],
    "proteinPortions": [ { "label": "3 eggs + sachet of milk", "grams": 27 } ],
    "meals": [ { "name": "Kenkey with grilled tilapia", "proteinG": 35, "tags": ["canteen", "budget"],
                 "tip": "Go easy on shito; add pepper, onion and tomato." } ] },
  "safety": { "parqQuestions": ["..."], "heatTips": ["..."] },
  "copy": { "rirQuestion": "How many more could you have done?" } }
```

### 7.6 Core interfaces (the contracts that let teams work in parallel)

```dart
// data/assets/asset_catalog.dart (E1)
abstract class AssetCatalog {
  List<Exercise> get exercises; Exercise exercise(String id);
  List<ProgramTemplate> get templates; Personalization get personalization;
}

// data/repositories (E1)
abstract class SessionRepository {
  Future<Session> start(SessionPlan plan);
  Future<Session?> findInProgress();
  Future<void> logSet(SetLog set, PlayerCursor cursor);       // one transaction
  Future<void> updateSet(SetLog set);  Future<void> deleteSet(String setId);
  Future<void> saveCursor(String sessionId, PlayerCursor cursor);
  Future<void> replaceExercise(String sessionExerciseId, String newExerciseId);
  Future<void> reorder(String sessionId, List<String> sessionExerciseIdsInOrder);
  Future<Session> complete(String sessionId, {int? feeling, String? note, double? bodyweightKg});
  Future<void> discard(String sessionId);
  Future<List<SetLog>> historyFor(String exerciseId, {int limitSessions = 10});
  Future<List<Session>> listCompleted({DateTime? from, DateTime? to});
}
abstract class ProgramRepository { Future<Program> active(); Future<void> save(Program p);
  Future<void> activateTemplate(String templateId); Future<void> advanceRotation(); }
abstract class BodyRepository { Future<void> upsert(BodyEntry e); Future<List<BodyEntry>> range(String from, String to); }
abstract class SettingsRepository { Future<AppSettings> load(); Future<void> save(AppSettings s);
  Future<UserProfile?> profile(); Future<void> saveProfile(UserProfile p); }
abstract class BackupService { Future<Uint8List> exportJson(); Future<ImportPreview> preview(Uint8List bytes);
  Future<void> import(Uint8List bytes, {required bool replace}); }

// domain (E2), all pure
class Prescription { final double weightKg; final int reps; final String reason; final Trend trend; } // Trend: up|same|down|calibrate
abstract class ProgressionEngine {
  List<Prescription> prescribe(Slot slot, Exercise ex, List<SetLog> history, AppSettings s, UserProfile p);
}
List<WarmupSet> planWarmups(double workingKg, Exercise ex, AppSettings s);
PlateResult calculatePlates(double totalKg, double barKg, List<double> platesKg);
SessionPlan buildSession(Program p, ProgramDay day, AssetCatalog c, Map<String, List<SetLog>> history, AppSettings s, UserProfile u);
List<Exercise> suggestSwaps(Exercise ex, AssetCatalog c, Set<Equipment> available, {int max = 4});
List<PrCandidate> detectPrs(List<SetLog> newSets, Map<String, List<PersonalRecord>> existing);
double epley1rm(double kg, int reps);
NutritionTargets nutritionTargets(UserProfile u, Personalization p);
Duration estimateDuration(ProgramDay day, AppSettings s);

// services (E3)
abstract class RestAlarm { Future<void> schedule(DateTime at, {required String title, required String body}); Future<void> cancel(); }
abstract class SoundService { Future<void> beep(); Future<void> restDone(); }
abstract class WakelockService { Future<void> enable(); Future<void> disable(); }
```

**Progression engine behaviour (for E2; tune together with the programming research):** double progression within the slot's rep range.
- No history -> `calibrate`: use `defaultStartKg` (or 50% of the user-entered estimate). If set 1 RIR ≥ 4, raise set 2 by 1-2 increments; if RIR 0 with reps under repMin, drop 10%.
- When every working set last time reached `repMax` with RIR ≥ 1 -> `up`: +1 increment (dumbbells: next pair, barbell +2.5 kg, stack +1 plate).
- Any set below `repMin` in 2 consecutive sessions -> `down`: −10%, rounded to an achievable load.
- Otherwise `same` weight, target reps = last reps + 1 (capped at repMax).
- The `reason` string is shown in the UI ("You hit 12, 12, 11 last time: +2.5 kg").

### 7.7 SessionPlayerController (E3): state machine
```
States: loading -> warmup -> exercise(i, set j, editing) <-> resting(i, j, endsAt) -> ... -> cooldown -> summary
Events: logSet, undoLast, skipSet, skipExercise(reason), swap(exId, scope), reorder(ids),
        addSet, adjustRest(±15), skipRest, restExpired, appResumed, endWorkout(save|discard)
Persistence: each event -> SessionRepository write -> notifyListeners(). On appResumed/launch: rebuild from DB.
Side effects: logSet -> haptic.light + RestAlarm.schedule(endsAt); restExpired/skipRest -> RestAlarm.cancel;
              restExpired (foreground) -> haptic.heavy x3 + SoundService.restDone()
```
A 1-second `Timer.periodic` only repaints the countdown; the truth is `restEndsAt`.

### 7.8 Startup sequence (`main.dart`)
1. `WidgetsFlutterBinding.ensureInitialized()`
2. `final db = await AppDatabase.open();` and `final catalog = await JsonAssetCatalog.load();` (in parallel with `Future.wait`)
3. Initialise notifications (channel creation only, with no permission prompt yet).
4. `runApp(MultiProvider(providers: [...repositories as Provider, ...stores as ChangeNotifierProvider], child: LegonLiftApp()))`
5. `LegonLiftApp`: no profile -> `/onboarding`; else Today, which checks `findInProgress()` for the resume banner.

### 7.9 Testing
- Domain: table-driven unit tests (progression cases, plate maths for 20-200 kg, warm-ups, e1RM, streaks, 7-day average with gaps).
- Data: `sqflite_common_ffi` in-memory DB tests for every repository and for backup round trips (export -> import -> deep-equal).
- Widgets: player golden-path test with fakes (log 3 sets, rest expires, swap, reorder, kill/resume by rebuilding the controller from the fake DB).
- Manual gym test on the Galaxy A55: screen-awake, backgrounded rest notification, music ducking, and sweat test (wet finger on the steppers).

---

## 8. Open questions and risks
1. **Smith machine bar weight** at the UG gym is unknown. The user must set it (default 10 kg), and the UI calls this out.
2. **Plate and dumbbell inventory** is unknown (e.g. are there 1.25 kg plates? Do dumbbells go up in 2 kg or 2.5 kg steps?). Settings handles it; ask the user to note it on his first visit.
3. **"Ankle machine"** has been resolved to a calf raise machine (USER_NOTES.md). Keep a fallback calf exercise (calf press on the leg press, Smith calf raise) in `alternatives` in case it is broken.
4. flutter_local_notifications 23.x needs the Android 37 SDK platform; stay on 22.3.x until it is installed.
5. free-exercise-db photos vary in quality and some exercises have none suitable. E6 must review each image pair and write custom cues/mistakes (source instructions are long-form and not beginner-tuned).
6. Age is unknown, so the nutrition numbers are recalculated once onboarding captures it.
