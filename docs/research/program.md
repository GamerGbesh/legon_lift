# Legon Lift: Training Program Research and Design

Status: research draft for the synthesizer. Machine-readable version: `program_draft.json` (built by `program_draft_gen.py`; run `python3 program_draft_gen.py program_draft.json` to rebuild). The exercise ids are snake_case. Section 8 lists every id used, so they can be matched against the library.

## 0. Who this is for, and the design principles

**User profile:** male, about 95 kg, 170-173 cm (BMI about 32), complete beginner, wants body recomposition. He trains about 3 days a week and wants a split (Push/Pull/Legs by default). Sessions are 45-60 min. He trains at the University of Ghana (Legon) campus gym, which is hot and humid. He uses the app offline on an Android phone and follows it step by step.

**Equipment (from `equipments.txt`):** cable machine, lat pulldown, shoulder press machine, chest press machine, bike and treadmill, barbells, dumbbells, leg press, plates, an "ankle machine" (ambiguous), leg curl, leg extension, Smith machine, and adjustable benches.

**Not available:** pull-up bar, kettlebells, EZ bar, bands. **No squat rack or bench with uprights is listed**, which matters for the design below.

**Design principles (with evidence):**

| Principle | Why |
|---|---|
| 2-3 hard sets per exercise and roughly 5-10 direct sets per muscle per week at first, rising slowly | Beginners grow on low volumes. In Schoenfeld et al. 2017, hypertrophy rose with weekly sets, with more than 10 sets per muscle per week giving the most growth, but novices respond well to far less. The ACSM (2009) recommends 1-3 sets, 8-12 RM loads and 2-3 days a week for novices. In the Pelland et al. dose-response meta-regression, returns diminish as volume rises. |
| Once-a-week frequency per muscle is acceptable | The user asked for a split. Pelland et al. found that, with weekly volume equated, frequency has little effect on hypertrophy (it matters more for strength). The Upper/Lower alternative is offered for anyone who wants about 1.5-2x per week practice. |
| Stop sets short of failure, closer as skill grows | Refalo et al. 2023 found no significant hypertrophy difference between training to failure and stopping short. Robinson et al. 2024 found hypertrophy improves as sets get closer to failure, while strength is fairly insensitive. Plan: RIR 3-4 in Phase 1, RIR 2 in Phase 2, RIR 1-2 in Phase 3 (RIR 0 only on machine isolation work). |
| Machines and dumbbells first, then the Smith machine, then floor-started barbell lifts | Machines need little coordination and are safe to push hard alone. This order follows Nippard's Fundamentals and the r/Fitness wiki approach (learn the pattern, then load it). The Smith machine stands in for squat and bench because no rack is listed. |
| Double progression with automatic load increases | Simple, codeable, and robust for beginners. ACSM suggests a 2-10% load increase once the target reps are exceeded by 1-2. |
| Low-impact cardio finisher | At 95 kg, jogging adds high joint loading. An incline walk or bike burns comparable energy at lower impact. |
| Recomposition needs high protein and a modest deficit | Barakat et al. 2020 (SCJ) report that recomposition is realistic for beginners and people with higher body fat when progressive resistance training is paired with high protein (about 1.6-2.2 g/kg) and a modest deficit. Nutrition is mainly another agent's domain (see section 7). |

## 1. Default program: Push / Pull / Legs, 3 days a week, 12 weeks plus deload and re-test

**Scheduling:** the app keeps a rotation pointer (Push, then Pull, then Legs, and repeats). It does not tie workouts to weekdays, so a missed day never skips a workout. The suggested days are Mon/Wed/Fri or Tue/Thu/Sat, with a rest day between sessions.

**Phase overview:**

| Phase | Weeks | Target RIR (compound / isolation) | Rep ranges | New equipment | Weekly direct sets per muscle (approx.) |
|---|---|---|---|---|---|
| 1. Foundation | 1-4 | 3 (week 1: 4) / 3 | 8-12, 10-15 | Machines, dumbbells, cables | Chest 5, back 8, quads 5, hamstrings 5, arms 2 each, side delts 2 |
| 2. Build | 5-8 | 2 (week 5: 3) / 2 | 6-10 main lift, 8-15 others | Smith squat and Smith bench, DB one-arm row | Chest 6, back 8, quads 7, hamstrings 6, arms 3, side delts 3 |
| 3. Progress | 9-12 | 2, then 1 in weeks 11-12 / 1, then 0-1 | 5-8 main lift, 6-10 second lift, 8-20 others | Barbell RDL, barbell bent-over row, DB shoulder press | Same sets, harder effort, plus optional extras |
| Deload | 13 | 4 | Same | None | Half the sets, about 90% of the load |
| Re-test | 14 | Test set at RIR 1 | 3-15 reps on the test set | None | Test plus light accessories |

Week 2 of a new cycle restarts at Phase 2 (or Phase 3 for lifts that are still progressing), with substitutions rotated. Section 3.6 covers this.

**Indirect volume:** pressing also trains the front delts and triceps, and rows and pulldowns also train the biceps and rear delts. Counted fractionally (indirect set = 0.5, as in Pelland et al.), triceps and biceps get about 5-7 effective sets a week, which is plenty for a beginner.

**Session time model** (the generator computes this): each set is 40 s of work plus rest (70 s for per-side sets), with 90 s of transition after each exercise. An auto warm-up costs 2 x 75 s for a primary lift and 75 s for a secondary lift. The warm-up block is 7-8 min and the cool-down is 4 min.

| Day | Ph1 core / with finisher | Ph2 | Ph3 |
|---|---|---|---|
| Push | 43 / 51 min | 46 / 54 | 48 / 56 |
| Pull | 43 / 51 (48 with optional core) | 44 / 52 (53 with extras) | 45 / 53 |
| Legs | 40 / 45 (44 with calves) | 48 (53 with calves), no finisher | 50 (55 with calves), no finisher |

There is deliberate slack in Phase 1. Week 1 sessions run about 8-12 min longer because of the "find your weight" ramp sets and learning the machines. The app should **skip the finisher automatically in week 1** and tell the user that the session will be longer.

### 1.1 Warm-up blocks (all days, 7-8 min)

1. **Cardio, 5 min:** `stationary_bike` (or `incline_treadmill_walk` at 3-5%) at RPE 3-4, easy enough to talk. In Accra heat, the aim is to get warm, not soaked.
2. **Dynamic, 2-3 min, specific to the day:**
   - Push: `arm_circles` 10+10, `incline_push_up` (hands on a bench) x8-10, very light `cable_face_pull` x15.
   - Pull: `arm_circles` 10+10, `cat_cow` x8, `scapular_pulldown` (light, arms straight, shoulder blades down only) x10.
   - Legs: `leg_swings` 10+10 per leg, `bodyweight_good_morning` x10 (hip-hinge practice), then `db_goblet_squat` 2x8 with a **light** DB to a bench. This is daily squat-pattern practice and gets him ready for the Smith squat in Phase 2.
3. **Then the auto warm-up sets** on the first (primary) lift (section 3.3).

### 1.2 Phase 1: Foundation (weeks 1-4)

The goal is to learn each machine, find starting weights and build the habit. Every set stops with 3-4 good reps left (week 1: 4 or more).

**PUSH (chest, shoulders, triceps)**

| # | exerciseId | Sets x reps | RIR | Rest | Coaching cue |
|---|---|---|---|---|---|
| 1 | `machine_chest_press` (primary, auto warm-up) | 3 x 8-12 | 3 | 120 s | Handles at mid-chest, shoulder blades back, 2 s lowering |
| 2 | `machine_shoulder_press` | 3 x 8-12 | 3 | 120 s | Don't arch off the pad |
| 3 | `db_incline_bench_press` | 2 x 10-12 | 3 | 90 s | 30° bench, kick the DBs up from the knees |
| 4 | `db_lateral_raise` | 2 x 12-15 | 3 | 60 s | Light, no swinging |
| 5 | `cable_triceps_pushdown` | 2 x 10-15 | 3 | 60 s | Elbows pinned to the sides |

Finisher (optional): `incline_treadmill_walk`, 8 min, Zone 2. Cool-down: walk 2 min, then optional stretches.

**PULL (back, rear delts, biceps)**

| # | exerciseId | Sets x reps | RIR | Rest | Coaching cue |
|---|---|---|---|---|---|
| 1 | `lat_pulldown_wide` (primary) | 3 x 8-12 | 3 | 120 s | Bar to upper chest, lead with the elbows |
| 2 | `seated_cable_row` | 3 x 8-12 | 3 | 120 s | Sit tall, pull to the navel, let the shoulder blades stretch forward |
| 3 | `db_chest_supported_row` | 2 x 10-12 | 3 | 90 s | Chest on a 30-45° bench, which spares the lower back |
| 4 | `cable_face_pull` | 2 x 12-15 | 3 | 60 s | Rope to the eyes, elbows high |
| 5 | `db_biceps_curl` | 2 x 10-15 | 3 | 60 s | No swinging, full stretch |
| (opt) | `dead_bug` | 2 x 8 per side | n/a | 45 s | Lower back stays flat |

Finisher (optional): `incline_treadmill_walk`, 8 min.

**LEGS (quads, hamstrings, glutes, calves)**

| # | exerciseId | Sets x reps | RIR | Rest | Coaching cue |
|---|---|---|---|---|---|
| 1 | `leg_press` (primary) | 3 x 10-12 | 3 | 150 s | Knees to about 90° without the lower back rolling off the pad, never lock out hard, know where the safety handles are |
| 2 | `db_romanian_deadlift` | 3 x 8-12 | 3 | 120 s | Hips back, flat back, DBs to just below the knee |
| 3 | `leg_curl_machine` | 2 x 10-15 | 3 | 90 s | Knee lined up with the machine's pivot |
| 4 | `leg_extension` | 2 x 12-15 | 3 | 90 s | Pause 1 s at the top |
| (opt) | `leg_press_calf_raise` | 2 x 12-20 | 3 | 60 s | Safety catches set, knees soft. Avoids the uncertain ankle machine |

Optional 5 min easy spin on the bike.

### 1.3 Phase 2: Build (weeks 5-8)

RIR 2 (week 5 stays at RIR 3 as a bridge). This phase adds sets, introduces the Smith machine and uses supersets for accessories to save time.

**PUSH**

| # | exerciseId | Sets x reps | RIR | Rest |
|---|---|---|---|---|
| 1 | `smith_machine_bench_press` (new, primary) | 3 x 6-10 | 2 | 150 s |
| 2 | `machine_shoulder_press` | 3 x 8-12 | 2 | 90 s |
| 3 | `db_incline_bench_press` | 3 x 8-12 | 2 | 90 s |
| A1/A2 | `db_lateral_raise` superset with `cable_triceps_pushdown` | 3 x 12-20 / 3 x 10-15 | 2 | 60 s per round |

Set the Smith safety stops just below chest height. Finisher: 8 min.

**PULL**

| # | exerciseId | Sets x reps | RIR | Rest |
|---|---|---|---|---|
| 1 | `lat_pulldown_wide` | 3 x 8-12 | 2 | 120 s |
| 2 | `db_one_arm_row` (new, per side) | 3 x 8-12 | 2 | 90 s |
| 3 | `seated_cable_row` | 2 x 10-12 | 2 | 90 s |
| A1/A2 | `cable_face_pull` superset with `db_biceps_curl` | 3 x 12-15 / 3 x 10-15 | 2 | 60 s per round |
| (opt) | `db_hammer_curl` 2 x 10-15, `cable_pallof_press` 2 x 10-12 per side | | 2 | 60 / 45 s |

Finisher: 8 min.

**LEGS** (no finisher from this phase on. Do cardio as a 30-40 min walk on a rest day instead.)

| # | exerciseId | Sets x reps | RIR | Rest |
|---|---|---|---|---|
| 1 | `smith_machine_squat` (new, primary) | 3 x 6-10 | 2 | 150 s |
| 2 | `db_romanian_deadlift` | 3 x 8-12 | 2 | 120 s |
| 3 | `leg_press` | 2 x 10-15 | 2 | 120 s |
| 4 | `leg_curl_machine` | 3 x 10-15 | 2 | 75 s |
| 5 | `leg_extension` | 2 x 12-15 | 2 | 75 s |
| (opt) | `leg_press_calf_raise` | 3 x 12-20 | 2 | 60 s |

### 1.4 Phase 3: Progress (weeks 9-12)

RIR is 2 in weeks 9-10 and 1 in weeks 11-12. The floor is 1 for compounds and 0 for isolation; failure is only allowed on machine and cable isolation work. The main lifts get heavier and the floor-started barbell lifts begin.

**PUSH**

| # | exerciseId | Sets x reps | RIR | Rest |
|---|---|---|---|---|
| 1 | `smith_machine_bench_press` | 3 x 5-8 | 2 | 180 s |
| 2 | `db_seated_shoulder_press` (new) | 3 x 8-12 | 2 | 120 s |
| 3 | `db_incline_bench_press` | 3 x 8-12 | 1 | 90 s |
| A1/A2 | `db_lateral_raise` superset with `cable_triceps_pushdown` | 3 x 12-20 / 3 x 10-15 | 1 | 60 s |
| (opt) | `cable_fly` | 2 x 12-15 | 1 | 60 s |

Users who have a bench with uprights and a spotter can switch `barbell_bench_press` on in settings.

**PULL**

| # | exerciseId | Sets x reps | RIR | Rest |
|---|---|---|---|---|
| 1 | `lat_pulldown_wide` | 3 x 6-10 | 2 | 150 s |
| 2 | `barbell_bent_over_row` (new) | 3 x 6-10 | 2 | 120 s |
| 3 | `seated_cable_row` | 2 x 10-12 | 1 | 90 s |
| A1/A2 | `cable_face_pull` superset with `db_incline_curl` | 3 x 12-15 / 3 x 8-12 | 1 | 60 s |
| (opt) | `db_hammer_curl` | 2 x 10-15 | 1 | 60 s |

If the lower back is still tired from leg day, the row falls back to `smith_machine_row` or `db_chest_supported_row`.

**LEGS**

| # | exerciseId | Sets x reps | RIR | Rest |
|---|---|---|---|---|
| 1 | `smith_machine_squat` | 3 x 5-8 | 2 | 180 s |
| 2 | `barbell_romanian_deadlift` (new) | 3 x 6-10 | 2 | 150 s |
| 3 | `leg_press` | 2 x 10-15 | 1 | 120 s |
| 4 | `leg_curl_machine` | 3 x 10-15 | 1 | 75 s |
| 5 | `leg_extension` | 2 x 12-15 | 1 | 75 s |
| (opt) | `leg_press_calf_raise` | 3 x 12-20 | 1 | 60 s |

For the first session of `barbell_romanian_deadlift`, the starting weight is about 1.6-1.8 times the per-hand DB RDL weight, then the ramp in section 3.2.

### 1.5 Week 13 (deload) and week 14 (re-test)

**Deload:** use the Phase 3 days, drop the optional items, halve the sets (rounding up, minimum 1), use about 90% of the last working loads and keep RIR at 4. The finisher is Zone 2 only. Sessions take about 35 min.

**Re-test:** each day, after normal warm-ups, the primary lift and the first secondary lift each get one test set. Use the last Phase 3 working weight and do as many good reps as possible, stopping with about one rep left. The app computes `e1RM = w * (1 + (reps + RIR)/30)` (Epley with RIR added) and shows the change since weeks 1-2. Then one back-off set of 8 at 80%. All other exercises are 2 sets at RIR 2.

**Measurements** are taken once that week, in the morning before eating: body weight, waist at the navel and photos. For recomposition, the scale alone is misleading. Waist going down while lifts go up is success, even if body weight barely changes.

**Next cycle:** restart at Phase 2 structure with the new e1RM-derived weights. Rotate one variation per day (for example `db_bench_press` instead of `db_incline_bench_press`, or `lat_pulldown_close_grip` instead of `lat_pulldown_wide`) to keep it fresh, while keeping the main lifts the same so progress stays comparable.

## 2. Alternative splits and different week lengths

All alternatives use the same Phase 1 rules (RIR 3, week 1 at 4, same rests). For later phases, apply the same changes as PPL (`laterPhasesRule` in the JSON): RIR goes down, primaries gain sets, the Smith squat and Smith bench come in during Phase 2, and the barbell RDL and row come in during Phase 3.

### 2.1 Upper/Lower, rotating, 3 days (`upper_lower_rotating_3day`)

The rotation is Upper A, Lower A, Upper B, Lower B and continues across weeks: week 1 is UA/LA/UB, week 2 is LB/UA/LA, and so on. Each muscle gets about 1.5 sessions a week. Evidence-wise this is the strongest 3-day split option, and the best fit if he wants more practice on each lift.

| Upper A | Lower A (quad focus) | Upper B | Lower B (hinge/glute focus) |
|---|---|---|---|
| `machine_chest_press` 3x8-12 | `leg_press` 3x10-12 | `db_incline_bench_press` 3x8-12 | `db_romanian_deadlift` 3x8-12 |
| `lat_pulldown_wide` 3x8-12 | `db_romanian_deadlift` 3x8-12 | `db_chest_supported_row` 3x8-12 | `db_goblet_squat` 3x8-12 |
| `machine_shoulder_press` 2x10-12 | `leg_extension` 2x12-15 | `lat_pulldown_close_grip` 2x10-12 | `leg_curl_machine` 3x10-15 |
| `seated_cable_row` 2x10-12 | `leg_curl_machine` 2x10-15 | `machine_chest_press` 2x10-12 | `db_hip_thrust` 2x10-15 |
| SS `db_biceps_curl` + `cable_triceps_pushdown` 2x10-15 | `dead_bug` 2x8 per side | SS `db_lateral_raise` + `cable_face_pull` 2x12-15 | `leg_press_calf_raise` 2x12-20 |
| about 47 min (55 with an 8 min finisher) | about 44 min (50 with 5 min) | about 47 / 55 min | about 44 / 49 min |

### 2.2 Chest+Back / Legs / Arms+Shoulders, 3 days (`chest_back_legs_arms_3day`)

- **Chest+Back** (about 45 / 53 min): `machine_chest_press` 3x8-12, `lat_pulldown_wide` 3x8-12, `db_incline_bench_press` 2x10-12, `seated_cable_row` 2x10-12, `cable_fly` 2x12-15. Alternate chest and back exercises; the opposing muscles recover while the other works.
- **Legs:** identical to PPL Legs.
- **Arms+Shoulders** (about 45 / 55 min): `machine_shoulder_press` 3x8-12, `db_lateral_raise` 3x12-15, superset `db_biceps_curl` with `cable_triceps_pushdown` 3x10-15, superset `db_hammer_curl` with `db_overhead_triceps_extension` 2x10-15, `cable_face_pull` 2x12-15. This is the lightest day overall, so it gets the longest cardio finisher (10 min).

### 2.3 Custom splits

The app should allow the user to pick days from the template pool, or build a day from library exercises. To keep custom programs sound, the app applies these checks (soft warnings, not blocks):

- Every major group (chest, back, shoulders, quads, hamstrings/glutes) should get at least 4 direct sets a week.
- No more than 6 exercises or 18 working sets per session, so it fits in 60 min.
- Each day has one primary compound first.
- The same muscle should not be trained hard on 2 consecutive days.

### 2.4 Two-day and four-day weeks

- **The pointer handles irregular weeks automatically.** With PPL, a 2-session week just means Legs moves to next week, and nothing is skipped.
- **Consistently 2 days** (rolling 3-week average below 2.5 sessions a week): suggest `upper_lower_2day`, which is Upper A plus Lower A, so every muscle gets trained each week. Add 2-3 walks of 30 min on other days. If the user stays on PPL with 2 days a week, each muscle is only trained about every 10-11 days. That is still progress, but slower.
- **4 days:** either `upper_lower_4day` (UA Mon, LA Tue, UB Thu, LB Fri; each muscle twice a week; best option), or keep PPL on the pointer (P, Pu, L, P / Pu, L, P, Pu), which gives about 1.33x a week per muscle.
- **5 or more days:** not recommended in the first 12 weeks for a beginner who is recomposing. Extra days should be walking or easy cardio only.
- **A 4th "bonus" day in a normal 3-day week:** offer "Cardio + Core": 25-35 min `incline_treadmill_walk` or `stationary_bike` plus 2-3 core exercises. This should not be another lifting day.

## 3. Progression algorithm (app logic)

### 3.1 Data recorded per set

`exerciseId, setIndex, weightKg (or stackPin), reps, rir (0,1,2,3,4+; optional), isWarmup, timestamp, painFlag`. Machines differ: one stack's "40" is not another brand's 40 kg. The app should therefore allow **stack-pin units** per machine (an `equipmentProfile` per gym: increment, unit, Smith bar weight, leg press sled weight).

### 3.2 First session: "find your weight" ramp

The weight for every exercise is found on its first exposure with up to 4 ramp sets. The app shows a seed weight as a suggestion and the user adjusts.

```
SEED (male beginner, ~95 kg; deliberately light; user-editable):
  machine_chest_press 20 kg | machine_shoulder_press 15 | lat_pulldown_wide 25 | seated_cable_row 25
  leg_press: sled + 20 (sled weight unknown -> log added plates only) | leg_curl_machine 15 | leg_extension 20
  db_incline_bench_press 10/hand | db_lateral_raise 4/hand | db_romanian_deadlift 12/hand | db_goblet_squat 12
  db_biceps_curl 6/hand | cable_triceps_pushdown 10 | cable_face_pull 10 | db_chest_supported_row 10/hand
  smith_machine_* : bar only | barbell_* : empty bar 20 kg (or 1.6-1.8x the per-hand DB weight for RDL/row)

function findWorkingWeight(ex, targetReps = ex.repRange.min + 2, targetRIR = ex.rir):
    w = seedOrLastKnown(ex)
    for step in 1..4:
        user performs targetReps at w, rest 60-90 s, reports RIR r (or picks "easy / OK / hard / form broke")
        if formBroke or pain: return roundDown(prevW or w*0.8)
        e1rm   = w * (1 + (targetReps + r) / 30)            # Epley with reps-in-reserve
        wNext  = e1rm / (1 + (targetReps + targetRIR) / 30) # weight that should leave exactly targetRIR
        wNext  = clamp(wNext, w, w * 1.5)                    # never jump > +50% per step
        if r in [targetRIR, targetRIR + 1]: return roundToAvailable(w)
        if r < targetRIR: return roundDown(w * 0.9)           # overshot: back off ~10%
        w = roundToAvailable(wNext)
    return w
# Ramp sets count as warm-ups. After the weight is found, do (ex.sets - 1) working sets (min 1).
# Bias: beginners tend to UNDER-estimate how many reps they have left, so this is conservative
# by design; double progression corrects it within 1-3 sessions.
```

### 3.3 Warm-up set calculator (primary lifts, and first secondary as 1 set)

```
function warmups(W, ex):                 # W = working weight
    minLoad = ex.equipment == "smith" ? smithBar : ex.equipment == "barbell" ? 20 : stackMin
    if role == "secondary": return [ (0.6W, 6) ]
    if W <= minLoad*1.5 or W < 30: return [ (0.5W, 10) ]
    sets = [ (0.5W, 8), (0.7W, 5) ]
    if W >= 60: sets += [ (0.85W, 2) ]
    return dedupe(roundToAvailable(load) for load, reps in sets if load >= minLoad)
# Rest 45-60 s between warm-ups; warm-ups are never logged as working sets.
# Dumbbell lifts: 1 set of 10 with ~half the working DBs.
```

### 3.4 Double progression after each session

```
for each exercise ex in completed session (progress tracked per exerciseId, not per slot):
    sets = workingSets(ex); top = ex.repRange.max; lo = ex.repRange.min
    effTop = top
    jump = increment(ex) / currentLoad                                      # small-load guard
    if jump > 0.20: effTop = top + 3
    elif jump > 0.10: effTop = top + 2
    rirOK = all(s.rir is null or s.rir >= ex.rir - 1 for s in sets)        # missing RIR = assume on target

    if all(s.reps >= effTop for s in sets) and rirOK:
        bonus = all(s.reps >= effTop+2 and (s.rir ?? 0) >= ex.rir+1 for s in sets)
        nextLoad = roundToAvailable(load + increment(ex) * (bonus ? 2 : 1))
        stall = 0
    elif sum(s.reps) > lastExposure.sumReps or load > lastExposure.load:
        nextLoad = load; stall = 0                   # progressing: chase +1 rep on weakest set
    else:
        nextLoad = load; stall += 1
        if stall >= 3:
            nextLoad = roundDown(load * 0.90); stall = 0; resets += 1
            if resets >= 2 at this load band: suggestSubstitution(ex)   # e.g. DB<->machine variant
    if sets[0].reps < lo - 2: flag "too heavy" -> next set in-session: load - increment; nextLoad = load - increment
    if any(s.painFlag): nextLoad = min(nextLoad, load*0.9); suggest substitution; ask about pain next time
```

**Increments (defaults, user can edit per machine):**

| Equipment | Default increment |
|---|---|
| Upper-body machine stack, `seated_cable_row`, lat pulldown | 5 kg |
| Cable isolation | 2.5 kg |
| Leg press | 10 kg (5 kg per side) |
| Dumbbells | Next available DB, typically 2 kg (1 kg for laterals and curls only if available; otherwise rep extension handles it) |
| Smith machine and barbell, upper body | 2.5 kg |
| Smith machine and barbell, lower body | 5 kg |

**In-session autoregulation:** if set 1 is 3 or more reps over the top of the range at the target RIR, the app suggests "add one increment now" for the next set. This is especially useful in weeks 1-2.

**Phase transitions:** when the rep range drops (for example 8-12 to 6-10), the starting load is the old working load +5-10% (e1RM-based: `w_new = e1rm / (1 + (newMid + RIR)/30)`).

### 3.5 Deload triggers

The scheduled deload is week 13. The app suggests a reactive 1-week deload (the user can dismiss it) if any of these is true:

1. Two or more primary or secondary lifts are in a stall (at least 2 consecutive) at the same time.
2. Total reps across the session fall by more than 10% versus the last time this day was done, two sessions in a row.
3. The readiness check-in (sleep, soreness and motivation, each 1-5) averages 2 or below for 2 consecutive sessions.
4. A pain flag shows up on the same body area in two sessions.
5. Six or more weeks have passed since the last deload once RIR is 1 or lower (only relevant in week 9 and later).

Deload: half the sets, about 90% of the load, RIR 4, for 3 sessions.

### 3.6 Coming back after missed training

| Time off | What the app does |
|---|---|
| 10-21 days | Load -10% and RIR +1 for one session, then resume |
| More than 21 days | Load -20% and RIR 4; re-run the "find weight" ramp on the primary lifts |
| Illness, including fever or malaria | Do not train with a fever. The first session back is deload-style |

## 4. Substitution rules (busy machines at a campus gym)

The app offers three quick actions: **"Machine busy"**, **"Doesn't fit / hurts"** and **"Skip"**.

```
onMachineBusy(currentEx):
  1. Offer "Wait (~2 min) / Ask to work in" with a 2-min timer (etiquette tip: "Mind if I work in between your sets?").
  2. Offer REORDER: move currentEx later and pull forward the next exercise that uses DIFFERENT equipment.
     Rule: a session's primary may move by at most 1 slot; isolations can move freely.
  3. Offer SUBSTITUTE: first item in ex.substitutions[] that (a) is unlocked in current phase,
     (b) does not use the busy equipment, (c) isn't already in today's session, (d) user hasn't pain-flagged.
  4. Load for substitute: own history if exists, else quick 2-step find-weight ramp.
  5. Progression is tracked per exerciseId. If the same substitution is used in 2 consecutive sessions,
     ask "Make this your default?" (swap in the template).
```

The cable machine is the busiest shared station, so the app should tell the user up front which dumbbell versions to switch to.

**Substitution map** (ordered by similarity, using only the listed equipment; the full list is in the JSON items as `substitutions`):

| Exercise | Substitutes |
|---|---|
| `machine_chest_press` | `db_bench_press`, `smith_machine_bench_press`, `cable_chest_press_standing`, `incline_push_up` |
| `smith_machine_bench_press` | `db_bench_press`, `machine_chest_press`, `barbell_bench_press` (needs uprights) |
| `db_incline_bench_press` | `smith_machine_incline_press`, `machine_chest_press`, `cable_chest_press_standing` |
| `machine_shoulder_press` | `db_seated_shoulder_press`, `smith_machine_seated_overhead_press` |
| `db_lateral_raise` | `cable_lateral_raise`, `db_seated_lateral_raise` |
| `cable_triceps_pushdown` | `db_overhead_triceps_extension`, `db_lying_triceps_extension`, `bench_dip_feet_on_floor` (careful at 95 kg) |
| `cable_fly` | `db_flat_fly`, `db_incline_fly` |
| `lat_pulldown_wide` | `lat_pulldown_close_grip`, `half_kneeling_cable_pulldown`, `cable_straight_arm_pulldown`, `db_pullover`. There is no pull-up bar, so a busy pulldown means falling back to cables or DBs |
| `seated_cable_row` | `db_chest_supported_row`, `db_one_arm_row`, `smith_machine_row`, `barbell_bent_over_row` |
| `cable_face_pull` | `db_rear_delt_fly` (chest on an incline bench), `cable_reverse_fly` |
| `db_biceps_curl` / `cable_biceps_curl` | Each other, `barbell_curl`, `db_hammer_curl` |
| `leg_press` | `db_goblet_squat`, `smith_machine_squat`, `smith_machine_split_squat`, `db_split_squat` |
| `smith_machine_squat` | `leg_press`, `db_goblet_squat`, `barbell_back_squat` (needs a rack) |
| `db_romanian_deadlift` | `barbell_romanian_deadlift`, `smith_machine_romanian_deadlift`, `cable_pull_through` |
| `leg_curl_machine` | `db_romanian_deadlift` (if not already done), `cable_standing_leg_curl` (needs an ankle strap), `db_single_leg_romanian_deadlift` |
| `leg_extension` | `db_goblet_squat_heels_elevated`, `smith_machine_squat`, `cable_leg_extension` (needs an ankle strap) |
| Calves | `leg_press_calf_raise`, `smith_machine_calf_raise`, `db_single_leg_calf_raise`, `machine_calf_raise` (only if the ankle machine is a calf machine) |
| Cardio | `incline_treadmill_walk`, `stationary_bike`, `treadmill_walk` |

**Timing tip for the app:** campus gyms are usually busiest in the late afternoon and early evening on weekdays. If the user logs "busy" often at a certain time, the app should suggest early morning, which in Accra is also cooler.

**The "ankle machine" (flagged):** no default exercise depends on it. Onboarding should ask what it is (with pictures):

| Answer | What the app unlocks |
|---|---|
| Ankle-strap cable cuff | `cable_standing_leg_curl`, `cable_kickback`, `cable_hip_abduction` |
| Standing or seated calf machine | `machine_calf_raise` replaces `leg_press_calf_raise` |
| Hip abductor/adductor machine | Optional glute accessory |
| Unknown | Nothing changes |

## 5. Coaching content for the app

### 5.1 Rest timer defaults

| Role | Default | Notes |
|---|---|---|
| Primary compound (Phase 1-2) | 120-150 s | Leg press and Smith squat get 150 s |
| Primary heavy (Phase 3, 5-8 reps) | 180 s | |
| Secondary compound | 90-120 s | |
| Isolation | 60-75 s | |
| Superset | 0 s between the pair, 60 s per round | |
| Warm-up sets | 45-60 s | |
| Heat adjustment | +30 s | Applied automatically if the user turns on "hot today" or the in-app heart-rate prompt says "still breathing hard" |

Evidence: longer rests (about 2-3 min) on compounds supported more strength and hypertrophy than 1 min in trained men (Schoenfeld et al. 2016, JSCR). More recent meta-analytic work suggests the benefit levels off past about 90 s for many exercises. The app should let the user start the next set early (a "Ready" button) or extend the rest by +30 s.

**Timer behaviour:** it starts automatically when a set is logged, vibrates and plays a sound at 10 s remaining and at 0, and keeps running with the screen off (foreground service on Android). It must work offline.

### 5.2 RIR and RPE in beginner language

> **RIR = "Reps In Reserve": how many more good reps you could have done before you'd have to stop.**
> After each set, ask yourself: "If someone paid me, how many more clean reps could I do?"

| RIR | RPE | Feels like | When we use it |
|---|---|---|---|
| 4+ | 6 or less | Comfortable, could chat | Warm-ups, week 1, deload |
| 3 | 7 | Getting hard, form perfect, clearly more in the tank | Phase 1 |
| 2 | 8 | Hard, the last rep slowed down a bit | Phase 2 |
| 1 | 9 | Very hard, maybe one more | Phase 3 main lifts |
| 0 | 10 | Couldn't do another rep with good form | Only on machine isolation in Phase 3 |

RPE is 10 minus RIR (the RIR-based RPE scale from Zourdos et al. 2016 and Helms et al. 2016). The app should **only show RIR**, as one tap of 0 / 1 / 2 / 3 / 4+.

**Tip to show in the app:** beginners usually think they are closer to failure than they really are. Once every 4 weeks from Phase 2 on, the app can run a **calibration set**: on the last set of a machine or cable isolation exercise only (for example `leg_extension` or `cable_triceps_pushdown`), the user predicts RIR, then keeps going to failure with good form. The app shows "You predicted 2, you actually had 4", which teaches the scale. Never do this on Smith, barbell or dumbbell pressing, or on squat or RDL patterns.

### 5.3 What and how to track

| What | When |
|---|---|
| Weight, reps and RIR for each set | Pre-filled from last time, one tap to confirm, tap to edit |
| Body weight | Weekly, same conditions (morning, after the toilet, before eating). The app shows a 7-day average trend |
| Waist at the navel | Every 2 weeks |
| Photos | Every 4 weeks |
| Readiness | Optional 3-tap check-in before each session: sleep, soreness, energy |
| Steps | If the phone counts them. Target 7k a day at first, rising toward 10k |

**Recomposition success** means the 4-week average shows the waist going down while the main lifts go up. Weight can stay flat or fall slowly; about 0.25-0.5 kg a week is a sensible ceiling.

### 5.4 Stop signs: pain versus effort

**Normal effort (keep going):**
- Burning in the working muscle
- Heavy breathing that settles during rest
- Shaky last reps
- Muscle soreness 24-72 h later (DOMS), worst after the first 1-2 weeks

**Stop the exercise and tap "hurts" if you feel:**
- Sharp, stabbing or pinching pain, especially in a joint (shoulder, knee, lower back, elbow)
- Pain that gets worse with each rep
- Pain on one side only that wasn't there before
- Numbness, tingling, or pain shooting down an arm or leg

**Stop the session and get help if you have:**
- Chest pain, pressure or tightness, or pain spreading to the arm or jaw
- Fainting or near-fainting, or severe dizziness
- Shortness of breath that doesn't settle with rest
- Irregular heartbeat
- Signs of heat illness (section 5.5)

**The 3/10 rule (app text):** mild discomfort up to 3/10 that does not get worse during the set and is gone by the next day is usually fine. If it is above 3/10 or getting worse, use the substitute exercise, lighten the load, and see a clinician if it persists for more than a week.

### 5.5 Heat and hydration in Accra

Accra is hot and humid year-round, around 24-32 °C with high humidity, and campus gyms are often only fan-cooled. Humidity stops sweat from evaporating, so the body cools itself less well. ACSM notes that heat stress and dehydration together hurt performance more than either alone.

**Before:**
- Drink about 500 ml roughly 2 h before training (ACSM 2007 fluid replacement stand).
- Arrive with pale-yellow urine.
- Train early morning (before about 9:00) or in the evening if possible.

**During:**
- Bring at least a 1-1.5 L bottle and sip 150-250 ml every 15-20 min. Rest periods are natural drink breaks, and the app can prompt "drink" after every exercise.
- Wear light, loose clothes and bring a towel.
- In heavy-sweat sessions, or sessions over about 60 min including cardio, add electrolytes (an ORS sachet diluted as directed, or a sports drink) or salt with meals.

**After:**
- Optionally, weigh yourself before and after a session occasionally. Each kg lost is roughly 1.25-1.5 L to drink back over the next few hours.

**Heat warning signs:** stop, cool down and drink if you notice:
- Headache
- Nausea
- Dizziness
- Unusual fatigue
- Goosebumps or chills while hot
- Confusion
- Stopping sweating

Confusion or collapse is an emergency, so call for help. The cooling first aid is cold water or ice on the body (Roberts et al. 2023 ACSM exertional heat illness consensus).

**App behaviour:** a "Hot day" toggle (or ask "How hot is the gym?" at session start) adds 30 s to rest, caps the finisher at Zone 2 and shortens it by 3-5 min, and shows hydration reminders.

### 5.6 Cardio for fat loss (95 kg, low impact)

| Phase | Finisher on Push/Pull days |
|---|---|
| Phase 1 | 8 min |
| Phase 2 | 8-10 min |
| Phase 3 | 8 min, if time allows |

**Format:** `incline_treadmill_walk` at 4.5-5.5 km/h and 5-12% incline (progress the incline before the speed, and use the rails only for balance), or `stationary_bike` in Zone 2 (talk test).

**Intervals:** in Phase 3, on the bike only, on non-leg days, and only if not hot: 6 x 30 s harder / 90 s easy.

**Rest-day cardio:** 30-40 min brisk walks, which suit campus life. Total weekly target is about 150 min moderate activity (WHO/ACSM).

**Avoid running at first.** Impact loading at 95 kg plus heat adds risk without much benefit for this goal. Most fat loss comes from diet anyway; the cardio supports the deficit and heart health.

## 6. Onboarding questions this program needs

1. Age, sex, height, weight, and optionally waist. The default is a male in his 20s.
2. Days a week (2 / 3 / 4) and split choice (default PPL; Upper/Lower; Chest+Back / Legs / Arms+Shoulders; custom).
3. Session length (45 / 60 min). At 45 min, the app drops optional items and the finisher.
4. Equipment check with pictures:
   - What the "ankle machine" is
   - Whether there is a squat rack or a bench with uprights (unlocks barbell squat and bench)
   - Dumbbell sizes available
   - Units: kg or lb plates
5. Injuries or pain areas. The app avoids those exercises (for example, lower back: keep `db_chest_supported_row` and machines, delay barbell rows).
6. Health screen (PAR-Q+ style): heart conditions, chest pain, dizziness, uncontrolled blood pressure, and so on. Any "yes" leads to "Please check with a doctor before starting." Relevant because BMI is about 32.

## 7. Nutrition pointers (for the app's recomposition context; defer to the nutrition agent)

| Area | Guidance |
|---|---|
| Protein | About 1.6-2.2 g/kg of target or lean-adjusted body weight a day (Morton et al. 2018 meta-analysis: gains plateau around 1.6 g/kg). For about 95 kg at roughly 170 cm, a practical target is **140-170 g/day**. Ghanaian options include eggs, fish (tilapia, sardines, mackerel), chicken, beans (red-red), groundnuts, soy/tofu ("wagashi" cheese), milk and yoghurt |
| Energy | Modest deficit of about 300-500 kcal a day. Do not crash diet, because training quality and muscle gain suffer |
| Sleep | 7-9 h. Student schedules and exams matter here, and the readiness check-in captures them |

## 8. Exercise ids used (for library reconciliation)

**Main program:**

```
machine_chest_press, smith_machine_bench_press, barbell_bench_press, db_incline_bench_press, db_bench_press,
machine_shoulder_press, db_seated_shoulder_press, db_lateral_raise, cable_fly, cable_triceps_pushdown,
db_overhead_triceps_extension, lat_pulldown_wide, lat_pulldown_close_grip, seated_cable_row, db_chest_supported_row,
db_one_arm_row, barbell_bent_over_row, cable_face_pull, db_biceps_curl, db_hammer_curl, db_incline_curl,
leg_press, smith_machine_squat, barbell_back_squat, db_goblet_squat, db_romanian_deadlift, barbell_romanian_deadlift,
leg_curl_machine, leg_extension, leg_press_calf_raise, db_hip_thrust, dead_bug, cable_pallof_press,
incline_treadmill_walk, stationary_bike, treadmill_walk
```

**Warm-up and cool-down:**

```
arm_circles, incline_push_up, cat_cow, scapular_pulldown, leg_swings, bodyweight_good_morning,
static_stretch_push / _pull / _legs / _upper (placeholders: the library should map these to concrete stretches)
```

**Substitutes only:**

```
cable_chest_press_standing, smith_machine_incline_press, smith_machine_seated_overhead_press, cable_lateral_raise,
db_seated_lateral_raise, db_flat_fly, db_incline_fly, db_lying_triceps_extension, bench_dip_feet_on_floor,
half_kneeling_cable_pulldown, cable_straight_arm_pulldown, db_pullover, smith_machine_row, cable_single_arm_row,
db_rear_delt_fly, cable_reverse_fly, cable_biceps_curl, barbell_curl, cable_rope_hammer_curl, smith_machine_split_squat,
db_split_squat, bodyweight_box_squat, smith_machine_romanian_deadlift, cable_pull_through, cable_standing_leg_curl,
db_single_leg_romanian_deadlift, db_goblet_squat_heels_elevated, cable_leg_extension, smith_machine_calf_raise,
db_single_leg_calf_raise, machine_calf_raise, smith_machine_hip_thrust, glute_bridge, plank
```

**Gated on the ankle machine:**

```
cable_kickback, cable_hip_abduction
```

### 8.1 Proposed id aliases to the parallel library files

At 08:37 the library files `exercises_push.json`, `exercises_pull.json` and `exercises_cardio_warmup.json` existed. The table maps the ids in this program (left) to the library's ids (right). Leg exercises had no library file yet.

| program id | library id |
|---|---|
| `stationary_bike` | `bike_steady_state` (finisher intervals: `bike_intervals`) |
| `incline_treadmill_walk` | `treadmill_incline_walk` |
| `treadmill_walk` | `treadmill_brisk_walk` |
| `lat_pulldown_close_grip` | `lat_pulldown_close_neutral` |
| `cable_straight_arm_pulldown` | `straight_arm_cable_pulldown` |
| `db_chest_supported_row` | `chest_supported_db_row` |
| `db_one_arm_row` | `one_arm_db_row` |
| `smith_machine_row` | `smith_machine_bent_over_row` |
| `db_rear_delt_fly` | `incline_reverse_db_fly` |
| `cable_reverse_fly` | `cable_rear_delt_fly` |
| `db_biceps_curl` | `db_bicep_curl` |
| `cable_biceps_curl` | `cable_bicep_curl` |
| `db_incline_curl` | `incline_db_curl` |
| `db_bench_press` | `dumbbell_bench_press` |
| `db_incline_bench_press` | `incline_dumbbell_press` |
| `db_flat_fly` | `dumbbell_fly` |
| `db_incline_fly` | `incline_dumbbell_fly` |
| `cable_fly` | `high_to_low_cable_fly` (or `low_to_high_cable_fly`) |
| `db_seated_shoulder_press` | `seated_dumbbell_shoulder_press` |
| `smith_machine_seated_overhead_press` | `smith_machine_shoulder_press` |
| `db_lateral_raise` | `dumbbell_lateral_raise` |
| `cable_triceps_pushdown` | `triceps_rope_pushdown` (or `triceps_bar_pushdown`) |
| `db_overhead_triceps_extension` | `seated_dumbbell_overhead_triceps_extension` |
| `static_stretch_push` | `chest_doorway_stretch` |
| `static_stretch_pull` | `bench_lat_stretch`, `childs_pose` |
| `static_stretch_legs` | `lying_hamstring_stretch_towel`, `bench_quad_stretch`, `half_kneeling_hip_flexor_stretch`, `calf_stretch_wall` |
| `static_stretch_upper` | `chest_doorway_stretch`, `bench_lat_stretch` |

These ids match the library exactly: `machine_chest_press`, `smith_machine_bench_press`, `smith_machine_incline_press`, `barbell_bench_press`, `incline_push_up`, `machine_shoulder_press`, `cable_lateral_raise`, `lat_pulldown_wide`, `seated_cable_row`, `barbell_bent_over_row`, `cable_face_pull`, `barbell_curl`, `db_hammer_curl`, `db_romanian_deadlift`, `cable_pull_through`, `arm_circles`, `cat_cow`, `leg_swings`, `bodyweight_box_squat` and `glute_bridge`.

These were not yet in any library: `scapular_pulldown` (could fall back to `scapular_wall_slides`), `bodyweight_good_morning`, all leg machine and Smith leg ids, `dead_bug`, `plank`, `cable_pallof_press`, `db_hip_thrust`, `db_lying_triceps_extension` and `bench_dip_feet_on_floor`.

## 9. JSON draft format (`program_draft.json`)

```
[ Program {
    programId, name, default, splitType, daysPerWeek, dayOrder[], description, targetUser,
    scheduling: "rotating_pointer", schedulingNotes, progressionDefaults{...}, equipmentAssumptions{...},
    phases: [ Phase {
        phaseId, name, weeks[], goal, rirWeekOffsets{week: delta}, rirFloorByRole?, loadMultiplier?, unlocks[],
        approxWeeklyDirectSetsPerMuscle?, laterPhasesRule?,
        days: [ Day {
            dayId, name, focus[], notes, estimatedMinutes{core, withOptionalExercises, withFinisher},
            blocks: [ Block {
                blockType: warmup|main|superset|finisher|cooldown, name, optional?, supersetGroup?, restBetweenRoundsSeconds?,
                items: [ Item {
                    exerciseId, sets, repRange[min,max] | durationSeconds, rir (int|null), restSeconds,
                    role: primary|secondary|accessory|core|warmup|cardio|cooldown|stretch,
                    warmupSets: "auto"|0|1, weightIncrementKg?, perSide?, optional?, test?, substitutions[], notes
                } ] } ] } ] } ] } ]
```

Programs included:

| programId | Coverage |
|---|---|
| `ppl_3day` (default) | Phases 1-3, deload, re-test |
| `upper_lower_rotating_3day` | Phase 1 |
| `chest_back_legs_arms_3day` | Phase 1 |
| `upper_lower_2day` | Phase 1 |
| `upper_lower_4day` | Phase 1 |

The effective RIR is `item.rir + phase.rirWeekOffsets[week]`, clamped to `rirFloorByRole`.

## 10. Sources

Sources marked "web-verified" were found in searches during this research. The rest are well-established references cited from the literature, and the exact figures should be checked before quoting them in the app.

| Area | Source |
|---|---|
| Novice programming | American College of Sports Medicine (2009). Progression models in resistance training for healthy adults. *Med Sci Sports Exerc* 41(3):687-708. Novices: 8-12 RM, 1-3 sets, 2-3 d/wk; 2-10% load increase when target reps are exceeded by 1-2. https://pubmed.ncbi.nlm.nih.gov/19204579/ (web-verified) |
| Volume | Schoenfeld, Ogborn & Krieger (2017). Dose-response relationship between weekly resistance training volume and increases in muscle mass. *J Sports Sci* 35(11):1073-1082. (web-verified) |
| Volume and frequency | Pelland, Remmert, Robinson, Hinson, Zourdos et al. (2024). The resistance training dose-response: meta-regressions exploring the effects of weekly volume and frequency on muscle hypertrophy and strength gain. SportRxiv preprint. https://sportrxiv.org/index.php/server/preprint/view/460 (web-verified; check for the peer-reviewed version) |
| Proximity to failure | Refalo, Helms, Trexler, Hamilton & Fyfe (2023). Influence of resistance training proximity-to-failure on skeletal muscle hypertrophy. *Sports Med* 53(3):649-665. (web-verified) |
| Proximity to failure | Robinson et al. (2024). Exploring the dose-response relationship between estimated resistance training proximity to failure, strength gain, and muscle hypertrophy. *Sports Med*. (web-verified) |
| Volume | Stronger By Science, "The Volume Debate". https://www.strongerbyscience.com/volume/ (web-verified) |
| RIR and RPE | Zourdos et al. (2016). Novel resistance training-specific RPE scale measuring repetitions in reserve. *JSCR* 30(1):267-275. |
| RIR and RPE | Helms et al. (2016). Application of the repetitions in reserve-based rating of perceived exertion scale for resistance training. *Strength Cond J* 38(4):42-49. |
| Rest intervals | Schoenfeld et al. (2016). Longer interset rest periods enhance muscle strength and hypertrophy in resistance-trained men. *JSCR* 30(7):1805-1812. |
| Recomposition | Barakat, Pearson, Escalante, Campbell & De Souza (2020). Body recomposition: can trained individuals build muscle and lose fat at the same time? *Strength Cond J* 42(5):7-21. (web-verified via secondary summaries) |
| Protein | Morton et al. (2018). A systematic review, meta-analysis and meta-regression of the effect of protein supplementation on resistance training-induced gains in muscle mass and strength. *Br J Sports Med* 52:376-384. |
| Beginner programs | Jeff Nippard, Fundamentals Hypertrophy Program: simple linear progression and RPE-based sets for beginners. https://jeffnippard.com/products/fundamentals-hypertrophy-program (web-verified) |
| Beginner programs | r/Fitness wiki: Basic Beginner Routine, GZCLP, recommended routines. https://thefitness.wiki/routines/strength-training-muscle-building/ and https://thefitness.wiki/routines/gzclp/ (web-verified). Also Metallicadpa's Reddit PPL (linear-progression PPL template) |
| Volume landmarks | Renaissance Periodization (Israetel), training volume landmarks (MEV/MAV/MRV). Used only to frame "start near the minimum effective volume and add sets over the mesocycle" |
| Hydration | ACSM (2007). Exercise and fluid replacement. *Med Sci Sports Exerc* 39(2):377-390. https://pubmed.ncbi.nlm.nih.gov/17277604/ (web-verified) |
| Heat illness | Roberts, Armstrong et al. (2023). ACSM expert consensus statement on exertional heat illness. *Curr Sports Med Rep* 22(4):134-149. (web-verified) |
| Physical activity | WHO (2020). Guidelines on physical activity and sedentary behaviour (150-300 min a week of moderate activity). |
