#!/usr/bin/env python3
"""Generates docs/research/program_draft.json (usage: python3 program_draft_gen.py program_draft.json) for Legon Lift.

Time model (seconds): each working set = WORK_S of effort + its rest; the last set of an
exercise is followed by TRANSITION_S instead of rest. Auto warm-up sets cost WARMUP_SET_S each.
Superset round = sum(WORK_S per item) + 20s to move + group rest.
"""
import json, math, sys, copy

WORK_S = 40
PER_SIDE_WORK_S = 70
TRANSITION_S = 90
WARMUP_SET_S = 75

# Default weight increments (kg). App must let the user override per machine / per gym.
INC = {
    "machine_chest_press": 5, "machine_shoulder_press": 5, "lat_pulldown_wide": 5,
    "lat_pulldown_close_grip": 5, "seated_cable_row": 5, "leg_press": 10,
    "leg_curl_machine": 5, "leg_extension": 5, "cable_triceps_pushdown": 2.5,
    "cable_face_pull": 2.5, "cable_fly": 2.5, "cable_biceps_curl": 2.5,
    "cable_overhead_triceps_extension": 2.5, "cable_pallof_press": 2.5,
    "cable_straight_arm_pulldown": 2.5, "half_kneeling_cable_pulldown": 2.5,
    "db_incline_bench_press": 2, "db_bench_press": 2, "db_seated_shoulder_press": 2,
    "db_lateral_raise": 1, "db_chest_supported_row": 2, "db_one_arm_row": 2,
    "db_biceps_curl": 1, "db_hammer_curl": 1, "db_incline_curl": 1,
    "db_romanian_deadlift": 2, "db_goblet_squat": 2, "db_hip_thrust": 2,
    "db_rear_delt_fly": 1, "db_overhead_triceps_extension": 1,
    "smith_machine_bench_press": 2.5, "smith_machine_squat": 5,
    "smith_machine_calf_raise": 5, "leg_press_calf_raise": 10,
    "barbell_bench_press": 2.5, "barbell_bent_over_row": 2.5,
    "barbell_romanian_deadlift": 5, "barbell_back_squat": 5,
}

# Ordered substitutions (most similar first). Only listed equipment. Filter by phase unlocks in app.
SUBS = {
    "machine_chest_press": ["db_bench_press", "smith_machine_bench_press", "cable_chest_press_standing", "incline_push_up"],
    "smith_machine_bench_press": ["db_bench_press", "machine_chest_press", "barbell_bench_press"],
    "barbell_bench_press": ["smith_machine_bench_press", "db_bench_press", "machine_chest_press"],
    "db_incline_bench_press": ["smith_machine_incline_press", "machine_chest_press", "cable_chest_press_standing"],
    "machine_shoulder_press": ["db_seated_shoulder_press", "smith_machine_seated_overhead_press"],
    "db_seated_shoulder_press": ["machine_shoulder_press", "smith_machine_seated_overhead_press"],
    "db_lateral_raise": ["cable_lateral_raise", "db_seated_lateral_raise"],
    "cable_fly": ["db_flat_fly", "db_incline_fly"],
    "cable_triceps_pushdown": ["db_overhead_triceps_extension", "db_lying_triceps_extension", "bench_dip_feet_on_floor"],
    "cable_overhead_triceps_extension": ["db_overhead_triceps_extension", "db_lying_triceps_extension"],
    "lat_pulldown_wide": ["lat_pulldown_close_grip", "half_kneeling_cable_pulldown", "cable_straight_arm_pulldown", "db_pullover"],
    "lat_pulldown_close_grip": ["lat_pulldown_wide", "half_kneeling_cable_pulldown", "db_pullover"],
    "seated_cable_row": ["db_chest_supported_row", "db_one_arm_row", "smith_machine_row", "barbell_bent_over_row"],
    "db_chest_supported_row": ["seated_cable_row", "db_one_arm_row", "smith_machine_row"],
    "db_one_arm_row": ["db_chest_supported_row", "seated_cable_row", "cable_single_arm_row"],
    "barbell_bent_over_row": ["smith_machine_row", "db_chest_supported_row", "seated_cable_row"],
    "cable_face_pull": ["db_rear_delt_fly", "cable_reverse_fly"],
    "db_biceps_curl": ["cable_biceps_curl", "barbell_curl", "db_hammer_curl"],
    "db_hammer_curl": ["cable_rope_hammer_curl", "db_biceps_curl"],
    "db_incline_curl": ["db_biceps_curl", "cable_biceps_curl"],
    "cable_biceps_curl": ["db_biceps_curl", "barbell_curl"],
    "leg_press": ["db_goblet_squat", "smith_machine_squat", "smith_machine_split_squat", "db_split_squat"],
    "smith_machine_squat": ["leg_press", "db_goblet_squat", "barbell_back_squat"],
    "barbell_back_squat": ["smith_machine_squat", "leg_press"],
    "db_goblet_squat": ["leg_press", "smith_machine_squat", "bodyweight_box_squat"],
    "db_romanian_deadlift": ["barbell_romanian_deadlift", "smith_machine_romanian_deadlift", "cable_pull_through"],
    "barbell_romanian_deadlift": ["db_romanian_deadlift", "smith_machine_romanian_deadlift"],
    "leg_curl_machine": ["db_romanian_deadlift", "cable_standing_leg_curl", "db_single_leg_romanian_deadlift"],
    "leg_extension": ["db_goblet_squat_heels_elevated", "smith_machine_squat", "cable_leg_extension"],
    "leg_press_calf_raise": ["smith_machine_calf_raise", "db_single_leg_calf_raise", "machine_calf_raise"],
    "smith_machine_calf_raise": ["leg_press_calf_raise", "db_single_leg_calf_raise", "machine_calf_raise"],
    "db_hip_thrust": ["smith_machine_hip_thrust", "glute_bridge", "cable_pull_through"],
    "cable_pallof_press": ["dead_bug", "plank"],
    "dead_bug": ["plank", "cable_pallof_press"],
    "incline_treadmill_walk": ["stationary_bike", "treadmill_walk"],
    "stationary_bike": ["incline_treadmill_walk", "treadmill_walk"],
}


def ex(eid, sets, reps, rir, rest, role="accessory", notes="", warmup=None, per_side=False, optional=False):
    it = {"exerciseId": eid, "sets": sets, "repRange": list(reps), "rir": rir, "restSeconds": rest, "role": role}
    if per_side:
        it["perSide"] = True
    if warmup is None:
        warmup = "auto" if role == "primary" else (1 if role == "secondary" else 0)
    it["warmupSets"] = warmup
    if eid in INC:
        it["weightIncrementKg"] = INC[eid]
    if optional:
        it["optional"] = True
    if eid in SUBS:
        it["substitutions"] = SUBS[eid]
    it["notes"] = notes
    return it


def timed(eid, seconds, notes="", sets=1, rest=0, role="cardio", reps=None, per_side=False):
    it = {"exerciseId": eid, "sets": sets}
    if reps:
        it["repRange"] = list(reps)
    else:
        it["durationSeconds"] = seconds
    it.update({"rir": None, "restSeconds": rest, "role": role})
    if per_side:
        it["perSide"] = True
    if eid in SUBS:
        it["substitutions"] = SUBS[eid]
    it["notes"] = notes
    return it


def block(btype, items, name=None, optional=False, group=None, round_rest=None):
    b = {"blockType": btype, "name": name or btype.capitalize()}
    if optional:
        b["optional"] = True
    if group:
        b["supersetGroup"] = group
        b["restBetweenRoundsSeconds"] = round_rest
    b["items"] = items
    return b

# ---------- shared warm-ups / finishers / cooldowns ----------

def wu_cardio():
    return timed("stationary_bike", 300, "Easy pace (RPE 3-4, can talk in full sentences). Alternative: incline_treadmill_walk 3-5% incline. In the heat keep it EASY - the goal is warm, not sweaty-exhausted.", role="warmup")

def warmup_push():
    return block("warmup", [wu_cardio(),
        timed("arm_circles", 0, "10 forward + 10 backward, small to big circles.", reps=(10, 10), role="warmup"),
        timed("incline_push_up", 0, "Hands on a bench, slow and controlled; warms chest/shoulders/triceps.", reps=(8, 10), role="warmup"),
        timed("cable_face_pull", 0, "Very light (1-2 plates), 15 reps, squeeze shoulder blades. Primes shoulders for pressing.", reps=(15, 15), role="warmup")], "Warm-up (~7 min)")

def warmup_pull():
    return block("warmup", [wu_cardio(),
        timed("arm_circles", 0, "10 forward + 10 backward.", reps=(10, 10), role="warmup"),
        timed("cat_cow", 0, "On hands and knees, slow spine flex/extend x8.", reps=(8, 8), role="warmup"),
        timed("scapular_pulldown", 0, "On lat pulldown, light weight, arms straight - pull shoulder blades down only, 10 reps.", reps=(10, 10), role="warmup")], "Warm-up (~7 min)")

def warmup_legs():
    return block("warmup", [wu_cardio(),
        timed("leg_swings", 0, "Hold the rack/machine, 10 front-back + 10 side-side each leg.", reps=(10, 10), per_side=True, role="warmup"),
        timed("bodyweight_good_morning", 0, "Hands on hips, push hips back with soft knees, flat back - this is the hip hinge used in RDLs. 10 reps.", reps=(10, 10), role="warmup"),
        timed("db_goblet_squat", 0, "2 x 8 with a LIGHT dumbbell (8-12 kg) to a bench/box behind you. Skill practice: chest up, knees track over toes, sit between the hips.", sets=2, rest=30, reps=(8, 8), role="warmup")], "Warm-up (~8 min)")

def warmup_upper():
    return block("warmup", [wu_cardio(),
        timed("arm_circles", 0, "10 forward + 10 backward.", reps=(10, 10), role="warmup"),
        timed("incline_push_up", 0, "Hands on bench, x8-10.", reps=(8, 10), role="warmup"),
        timed("scapular_pulldown", 0, "Light, arms straight, x10.", reps=(10, 10), role="warmup")], "Warm-up (~7 min)")

def finisher(minutes, phase):
    notes = {
        1: "Zone 2 (talk test: can speak in sentences, not sing). Treadmill 4.5-5.5 km/h at 5-10% incline, hold rails only for balance. At 95 kg this is far kinder to knees than jogging.",
        2: "Zone 2 steady. Progress by adding incline (up to 12%) before speed. Bike is fine on hot days.",
        3: "Zone 2 steady OR (bike only, non-leg days, if recovered) 6 x 30 s harder / 90 s easy. Skip intervals if the gym is very hot.",
    }[phase]
    return block("finisher", [timed("incline_treadmill_walk", minutes * 60, notes)], f"Fat-loss finisher ({minutes} min, optional)", optional=True)

def cooldown(focus):
    return block("cooldown", [
        timed("treadmill_walk", 120, "Slow walk / easy pedal until breathing settles; drink water.", role="cooldown"),
        timed("static_stretch_" + focus, 120, "Optional: 2-3 stretches for today's muscles, ~30 s each, gentle. Stretching is for comfort/mobility, not required for growth.", role="stretch")], "Cool-down (~4 min)")

# ---------- time estimator ----------

def est_block_seconds(b):
    t = b["blockType"]
    if t in ("warmup", "cooldown", "finisher"):
        if t == "warmup":
            return 420 if "8 min" not in b["name"] else 480
        if t == "cooldown":
            return 240
        return sum(i.get("durationSeconds", 0) for i in b["items"])
    if t == "superset":
        rounds = max(i["sets"] for i in b["items"])
        per_round = sum(WORK_S for _ in b["items"]) + 20 + b["restBetweenRoundsSeconds"]
        return rounds * per_round - b["restBetweenRoundsSeconds"] + TRANSITION_S
    total = 0
    for i in b["items"]:
        work = PER_SIDE_WORK_S if i.get("perSide") else WORK_S
        total += i["sets"] * (work + i["restSeconds"]) - i["restSeconds"] + TRANSITION_S
        w = i.get("warmupSets", 0)
        total += (2 if w == "auto" else w) * WARMUP_SET_S
    return total

def estimate(day):
    core = sum(est_block_seconds(b) for b in day["blocks"] if not b.get("optional") and b["blockType"] != "finisher"
               and not all(i.get("optional") for i in b["items"]))
    # subtract optional items within required blocks
    for b in day["blocks"]:
        if b["blockType"] == "main" and not b.get("optional"):
            for i in b["items"]:
                if i.get("optional"):
                    one = {"blockType": "main", "items": [i]}
                    core -= est_block_seconds(one)
    opt_items = 0
    for b in day["blocks"]:
        if b["blockType"] == "finisher":
            continue
        if b.get("optional"):
            opt_items += est_block_seconds(b)
        elif b["blockType"] == "main":
            for i in b["items"]:
                if i.get("optional"):
                    opt_items += est_block_seconds({"blockType": "main", "items": [i]})
    fin = sum(est_block_seconds(b) for b in day["blocks"] if b["blockType"] == "finisher")
    return {"core": round(core / 60), "withOptionalExercises": round((core + opt_items) / 60),
            "withFinisher": round((core + fin) / 60)}

def day(day_id, name, focus, blocks, notes=""):
    d = {"dayId": day_id, "name": name, "focus": focus, "blocks": blocks, "notes": notes}
    d["estimatedMinutes"] = estimate(d)
    return d

# ===================== PPL =====================

P1_NOTE = "Phase 1: learn the movement, find your weights. Stop every set with 3-4 good reps left (week 1: 4+)."

def ppl_p1():
    push = day("push", "Push (chest, shoulders, triceps)", ["chest", "front_delts", "side_delts", "triceps"], [
        warmup_push(),
        block("main", [
            ex("machine_chest_press", 3, (8, 12), 3, 120, "primary", "Seat so handles line up with mid-chest. Shoulder blades back, feet flat. 2 s down, controlled push."),
            ex("machine_shoulder_press", 3, (8, 12), 3, 120, "secondary", "Handles start around chin/shoulder height. Don't arch the lower back off the pad."),
            ex("db_incline_bench_press", 2, (10, 12), 3, 90, "secondary", "Bench at ~30 degrees (2nd-3rd notch). Kick DBs up from the knees; lower to upper chest."),
            ex("db_lateral_raise", 2, (12, 15), 3, 60, "accessory", "Light! Raise out to the side to shoulder height, slight bend in elbows, no swinging."),
            ex("cable_triceps_pushdown", 2, (10, 15), 3, 60, "accessory", "Rope or bar. Elbows pinned to your sides; only forearms move."),
        ], "Main lifts"),
        finisher(8, 1), cooldown("push")], P1_NOTE)
    pull = day("pull", "Pull (back, rear delts, biceps)", ["lats", "upper_back", "rear_delts", "biceps"], [
        warmup_pull(),
        block("main", [
            ex("lat_pulldown_wide", 3, (8, 12), 3, 120, "primary", "Grip just wider than shoulders, thighs locked under pad. Pull bar to upper chest, lead with elbows, lean back only slightly."),
            ex("seated_cable_row", 3, (8, 12), 3, 120, "secondary", "V-handle. Sit tall, pull to belly button, squeeze shoulder blades, let them stretch forward on the way back."),
            ex("db_chest_supported_row", 2, (10, 12), 3, 90, "secondary", "Lie chest-down on a 30-45 degree incline bench; row DBs toward hips. Protects the lower back."),
            ex("cable_face_pull", 2, (12, 15), 3, 60, "accessory", "Rope at face height, pull toward eyes with elbows high, thumbs pointing back."),
            ex("db_biceps_curl", 2, (10, 15), 3, 60, "accessory", "Standing or seated, palms up, no swinging; full stretch at the bottom."),
            timed("dead_bug", 0, "Core, optional: 2 x 8 per side, lower back pressed to bench/floor, slow.", sets=2, rest=45, reps=(8, 8), role="core", per_side=True) | {"optional": True, "substitutions": SUBS["dead_bug"]},
        ], "Main lifts"),
        finisher(8, 1), cooldown("pull")], P1_NOTE)
    legs = day("legs", "Legs (quads, hamstrings, glutes, calves)", ["quads", "hamstrings", "glutes", "calves", "core"], [
        warmup_legs(),
        block("main", [
            ex("leg_press", 3, (10, 12), 3, 150, "primary", "Feet shoulder-width, mid-platform. Lower until knees ~90 degrees without your lower back rolling off the pad. Never lock knees hard at the top. Learn where the safety handles are."),
            ex("db_romanian_deadlift", 3, (8, 12), 3, 120, "secondary", "Soft knees, push hips BACK, DBs slide down the thighs to just below the knee, flat back. Feel hamstrings stretch. Stand by squeezing glutes."),
            ex("leg_curl_machine", 2, (10, 15), 3, 90, "accessory", "Pad just above the heels, knee joint lined up with machine pivot. Control the way back."),
            ex("leg_extension", 2, (12, 15), 3, 90, "accessory", "Knee lined up with pivot, pad on lower shin. Pause 1 s at the top."),
            ex("leg_press_calf_raise", 2, (12, 20), 3, 60, "accessory", "On the leg press with the safety catches set: balls of feet on the bottom edge, knees soft, full stretch then up. Avoids the uncertain 'ankle machine'.", optional=True),
        ], "Main lifts"),
        block("finisher", [timed("stationary_bike", 300, "Optional easy spin 5 min - helps legs recover. Skip if short on time.")], "Easy spin (5 min, optional)", optional=True),
        cooldown("legs")], P1_NOTE + " The goblet squats in the warm-up are skill practice for the Smith squat in Phase 2.")
    return {"phaseId": "foundation", "name": "Phase 1 - Foundation", "weeks": [1, 2, 3, 4],
            "goal": "Learn every machine and movement, set safe starting weights, build the habit. Machines + dumbbells only.",
            "rirWeekOffsets": {"1": 1, "2": 0, "3": 0, "4": 0},
            "unlocks": ["machines", "dumbbells", "cables"],
            "approxWeeklyDirectSetsPerMuscle": {"chest": 5, "back": 8, "shoulders_side": 2, "quads": 5, "hamstrings": 5, "biceps": 2, "triceps": 2},
            "days": [push, pull, legs]}


def ppl_p2():
    push = day("push", "Push (chest, shoulders, triceps)", ["chest", "front_delts", "side_delts", "triceps"], [
        warmup_push(),
        block("main", [
            ex("smith_machine_bench_press", 3, (6, 10), 2, 150, "primary", "NEW. Flat bench under the Smith so the bar touches lower chest. Set the safety stops just below chest height. Unrack by twisting the bar; lower 2 s, touch, press."),
            ex("machine_shoulder_press", 3, (8, 12), 2, 90, "secondary", "Same as Phase 1, now a bit closer to failure."),
            ex("db_incline_bench_press", 3, (8, 12), 2, 90, "secondary", "30 degree bench."),
        ], "Main lifts"),
        block("superset", [
            ex("db_lateral_raise", 3, (12, 20), 2, 0, "accessory", "Do a set, then go straight to pushdowns."),
            ex("cable_triceps_pushdown", 3, (10, 15), 2, 60, "accessory", "Then rest 60 s and repeat the pair."),
        ], "Superset A (saves time)", group="A", round_rest=60),
        finisher(8, 2), cooldown("push")], "Phase 2: Smith bench replaces the chest press as the first lift. Machine chest press stays as the go-to substitute.")
    pull = day("pull", "Pull (back, rear delts, biceps)", ["lats", "upper_back", "rear_delts", "biceps"], [
        warmup_pull(),
        block("main", [
            ex("lat_pulldown_wide", 3, (8, 12), 2, 120, "primary", ""),
            ex("db_one_arm_row", 3, (8, 12), 2, 90, "secondary", "NEW. One knee and hand on a flat bench, back flat; row DB to hip. Each set = both arms.", per_side=True),
            ex("seated_cable_row", 2, (10, 12), 2, 90, "secondary", ""),
        ], "Main lifts"),
        block("superset", [
            ex("cable_face_pull", 3, (12, 15), 2, 0, "accessory", ""),
            ex("db_biceps_curl", 3, (10, 15), 2, 60, "accessory", ""),
        ], "Superset A", group="A", round_rest=60),
        block("main", [
            ex("db_hammer_curl", 2, (10, 15), 2, 60, "accessory", "Optional: palms facing each other."),
            ex("cable_pallof_press", 2, (10, 12), 2, 45, "accessory", "Optional core: stand side-on to the cable at chest height, press handle straight out and resist the twist.", per_side=True, warmup=0),
        ], "Optional extras", optional=True),
        finisher(8, 2), cooldown("pull")], "")
    for it in pull["blocks"][3]["items"]:
        it["optional"] = True
    pull["estimatedMinutes"] = estimate(pull)
    legs = day("legs", "Legs (quads, hamstrings, glutes, calves)", ["quads", "hamstrings", "glutes", "calves"], [
        warmup_legs(),
        block("main", [
            ex("smith_machine_squat", 3, (6, 10), 2, 150, "primary", "NEW. Feet slightly in front of the bar, shoulder-width. Set safety stops just below your lowest depth. Squat to a depth you control with a flat back (aim thighs ~parallel)."),
            ex("db_romanian_deadlift", 3, (8, 12), 2, 120, "secondary", ""),
            ex("leg_press", 2, (10, 15), 2, 120, "secondary", "Now a back-off quad movement after squats."),
            ex("leg_curl_machine", 3, (10, 15), 2, 75, "accessory", ""),
            ex("leg_extension", 2, (12, 15), 2, 75, "accessory", ""),
            ex("leg_press_calf_raise", 3, (12, 20), 2, 60, "accessory", "Optional if time.", optional=True),
        ], "Main lifts"),
        cooldown("legs")], "No finisher on leg day in Phase 2+: the legs session is already ~55 min. Do cardio on a rest day instead (walk 30-40 min).")
    return {"phaseId": "build", "name": "Phase 2 - Build", "weeks": [5, 6, 7, 8],
            "goal": "Add volume (more 3-set exercises), introduce Smith machine squat & bench, train a bit closer to failure.",
            "rirWeekOffsets": {"5": 1, "6": 0, "7": 0, "8": 0},
            "unlocks": ["machines", "dumbbells", "cables", "smith_machine"],
            "approxWeeklyDirectSetsPerMuscle": {"chest": 6, "back": 8, "shoulders_side": 3, "quads": 7, "hamstrings": 6, "biceps": 3, "triceps": 3},
            "days": [push, pull, legs]}


def ppl_p3():
    push = day("push", "Push (chest, shoulders, triceps)", ["chest", "front_delts", "side_delts", "triceps"], [
        warmup_push(),
        block("main", [
            ex("smith_machine_bench_press", 3, (5, 8), 2, 180, "primary", "Heavier rep range now. If the gym has a bench with uprights AND you have a spotter, the app can swap to barbell_bench_press (user toggle)."),
            ex("db_seated_shoulder_press", 3, (8, 12), 2, 120, "secondary", "NEW free-weight press. Bench upright (one notch back from vertical), back on the pad."),
            ex("db_incline_bench_press", 3, (8, 12), 1, 90, "secondary", ""),
        ], "Main lifts"),
        block("superset", [
            ex("db_lateral_raise", 3, (12, 20), 1, 0, "accessory", ""),
            ex("cable_triceps_pushdown", 3, (10, 15), 1, 60, "accessory", ""),
        ], "Superset A", group="A", round_rest=60),
        block("main", [ex("cable_fly", 2, (12, 15), 1, 60, "accessory", "Optional. Cables at shoulder height, hug a big tree.", optional=True)], "Optional extra", optional=True),
        finisher(8, 3), cooldown("push")], "Session is ~55 min without the finisher; do the finisher if time allows, otherwise walk on a rest day.")
    pull = day("pull", "Pull (back, rear delts, biceps)", ["lats", "upper_back", "rear_delts", "biceps"], [
        warmup_pull(),
        block("main", [
            ex("lat_pulldown_wide", 3, (6, 10), 2, 150, "primary", ""),
            ex("barbell_bent_over_row", 3, (6, 10), 2, 120, "secondary", "NEW. Deadlift the bar up from the floor, hinge to ~45 degrees, flat back, row to lower ribs. If the lower back is tired from leg day, use smith_machine_row or db_chest_supported_row."),
            ex("seated_cable_row", 2, (10, 12), 1, 90, "secondary", ""),
        ], "Main lifts"),
        block("superset", [
            ex("cable_face_pull", 3, (12, 15), 1, 0, "accessory", ""),
            ex("db_incline_curl", 3, (8, 12), 1, 60, "accessory", "Bench at 45-60 degrees, arms hang straight down - big stretch."),
        ], "Superset A", group="A", round_rest=60),
        block("main", [ex("db_hammer_curl", 2, (10, 15), 1, 60, "accessory", "Optional.", optional=True)], "Optional extra", optional=True),
        finisher(8, 3), cooldown("pull")], "")
    legs = day("legs", "Legs (quads, hamstrings, glutes, calves)", ["quads", "hamstrings", "glutes", "calves"], [
        warmup_legs(),
        block("main", [
            ex("smith_machine_squat", 3, (5, 8), 2, 180, "primary", "Heavier. If a squat rack is available and form is solid, app may offer barbell_back_squat (user toggle)."),
            ex("barbell_romanian_deadlift", 3, (6, 10), 2, 150, "secondary", "NEW. Same hinge as DB RDL; bar stays touching the thighs. Start with the DB RDL weight x2 or a bit less."),
            ex("leg_press", 2, (10, 15), 1, 120, "secondary", ""),
            ex("leg_curl_machine", 3, (10, 15), 1, 75, "accessory", ""),
            ex("leg_extension", 2, (12, 15), 1, 75, "accessory", ""),
            ex("leg_press_calf_raise", 3, (12, 20), 1, 60, "accessory", "Optional.", optional=True),
        ], "Main lifts"),
        cooldown("legs")], "")
    return {"phaseId": "progress", "name": "Phase 3 - Progress", "weeks": [9, 10, 11, 12],
            "goal": "Free-weight barbell work (RDL, row), heavier main lifts (5-8 reps), push close to failure on safe exercises.",
            "rirWeekOffsets": {"9": 0, "10": 0, "11": -1, "12": -1},
            "rirFloorByRole": {"primary": 1, "secondary": 1, "accessory": 0},
            "unlocks": ["machines", "dumbbells", "cables", "smith_machine", "barbell_floor_lifts"],
            "approxWeeklyDirectSetsPerMuscle": {"chest": 6, "back": 8, "shoulders_side": 3, "quads": 7, "hamstrings": 6, "biceps": 3, "triceps": 3},
            "days": [push, pull, legs]}


def deload_from(phase):
    p = copy.deepcopy(phase)
    p.update({"phaseId": "deload", "name": "Deload (week 13)", "weeks": [13],
              "goal": "Recover: let fatigue drop so you feel fresh for re-testing. Same exercises, half the sets, ~10% lighter, easy effort.",
              "rirWeekOffsets": {"13": 0}, "loadMultiplier": 0.9})
    p.pop("rirFloorByRole", None)
    for d in p["days"]:
        d["blocks"] = [b for b in d["blocks"] if not b.get("optional")]
        for b in d["blocks"]:
            if b["blockType"] in ("main", "superset"):
                b["items"] = [i for i in b["items"] if not i.get("optional")]
                for i in b["items"]:
                    i["sets"] = max(1, math.ceil(i["sets"] / 2))
                    i["rir"] = 4
                    i["notes"] = "DELOAD: ~90% of last working weight, stop with 4+ reps left. " + i["notes"]
            if b["blockType"] == "finisher":
                for i in b["items"]:
                    i["notes"] = "Easy Zone 2 only."
        d["notes"] = "Deload week. Should feel easy. Use spare time for a longer walk if you want."
        d["estimatedMinutes"] = estimate(d)
    return p


def retest_from(phase):
    p = copy.deepcopy(phase)
    p.update({"phaseId": "retest", "name": "Re-test (week 14)", "weeks": [14],
              "goal": "Measure progress: one RIR-1 rep test on each day's primary + first secondary lift, then light accessories. Take body measurements.",
              "rirWeekOffsets": {"14": 0}})
    p.pop("rirFloorByRole", None)
    for d in p["days"]:
        d["blocks"] = [b for b in d["blocks"] if not b.get("optional") and b["blockType"] != "finisher"]
        n_tests = 0
        for b in d["blocks"]:
            if b["blockType"] in ("main", "superset"):
                b["items"] = [i for i in b["items"] if not i.get("optional")]
                for i in b["items"]:
                    if i["role"] in ("primary", "secondary") and n_tests < 2 and b["blockType"] == "main":
                        n_tests += 1
                        i.update({"sets": 1, "repRange": [3, 15], "rir": 1, "restSeconds": 180, "test": "rir1_rep_test",
                                  "notes": "TEST: after normal warm-up sets, use your last Phase-3 working weight and do as many good reps as possible, stopping when you have ~1 left. App computes e1RM = w * (1 + (reps + 1)/30) and compares to your week-1 numbers. Then 1 back-off set of 8 at 80% (RIR 3)."})
                    else:
                        i["sets"] = 2
                        i["rir"] = 2
        d["notes"] = "Re-test day. Also (once this week, morning, before eating): body weight, waist at navel, progress photos."
        d["estimatedMinutes"] = estimate(d)
    return p


PROGRESSION_DEFAULTS = {
    "model": "double_progression",
    "successRule": "all working sets reach repRange.max with reported RIR >= target RIR - 1 (i.e. not grinding harder than planned)",
    "onSuccess": "increase load by weightIncrementKg next session (2x increment if every set hit max+2 reps at RIR >= target+1)",
    "onPartial": "keep load; aim for +1 rep on the weakest set",
    "stallDefinition": "no increase in total reps or load vs. the last exposure of the same exercise",
    "onStall": {"stallsBeforeReduction": 3, "reductionPercent": 10, "secondReductionAction": "suggest substitution / variation change"},
    "tooHeavyRule": "if first set reps < repRange.min - 2, drop load by one increment immediately for the remaining sets",
    "smallIncrementGuard": "if increment > 10% of current load, extend the rep target to repRange.max + up to 3 reps before adding weight",
    "missedTrainingRules": {"daysOff_10_to_21": "-10% load, RIR +1 for one session", "daysOff_over_21": "-20% load, RIR 4, re-run find-weight on primaries"},
    "startingWeight": "find_your_weight_ramp (see program.md section 3.2)",
    "warmupSetCalculator": "auto for role=primary (see program.md section 3.3)",
    "defaultRestSeconds": {"primary": 120, "primary_heavy_phase3": 180, "secondary": 90, "accessory": 60, "supersetRound": 60, "heatExtraSeconds": 30},
}

COMMON = {
    "targetUser": "Beginner, body recomposition, 45-60 min sessions, UG Legon campus gym equipment only",
    "scheduling": "rotating_pointer",
    "schedulingNotes": "App tracks the NEXT day in the rotation, not weekdays. Missing a day never skips a workout. Recommend >= 1 rest day between sessions when possible (e.g. Mon/Wed/Fri or Tue/Thu/Sat).",
    "progressionDefaults": PROGRESSION_DEFAULTS,
    "equipmentAssumptions": {
        "noRack": "No squat rack / bench uprights listed: barbell squat & bench default to Smith machine. Barbell lifts used are floor-started (RDL, bent-over row).",
        "ankleMachine": "Ambiguous - not used in any default. Onboarding asks: ankle-strap cable attachment / calf machine / hip machine / unknown. If ankle strap: unlocks cable_standing_leg_curl, cable_kickback. If calf machine: machine_calf_raise replaces leg_press_calf_raise.",
        "noPullupBarKettlebellEzBarBands": True,
    },
}


def program(pid, name, split, days_per_week, day_order, phases, desc, default=False):
    out = {"programId": pid, "name": name, "default": default, "splitType": split, "daysPerWeek": days_per_week,
           "dayOrder": day_order, "description": desc}
    out.update(copy.deepcopy(COMMON))
    out["phases"] = phases
    return out

# ===================== Alternatives (Phase 1) =====================

def ul_days(p1_rir=3):
    upper_a = day("upper_a", "Upper A", ["chest", "back", "shoulders", "arms"], [
        warmup_upper(),
        block("main", [
            ex("machine_chest_press", 3, (8, 12), p1_rir, 120, "primary", "See PPL notes."),
            ex("lat_pulldown_wide", 3, (8, 12), p1_rir, 120, "primary", "", warmup=1),
            ex("machine_shoulder_press", 2, (10, 12), p1_rir, 90, "secondary", ""),
            ex("seated_cable_row", 2, (10, 12), p1_rir, 90, "secondary", ""),
        ], "Main lifts"),
        block("superset", [
            ex("db_biceps_curl", 2, (10, 15), p1_rir, 0, "accessory", ""),
            ex("cable_triceps_pushdown", 2, (10, 15), p1_rir, 60, "accessory", ""),
        ], "Superset A", group="A", round_rest=60),
        finisher(8, 1), cooldown("upper")])
    lower_a = day("lower_a", "Lower A (quad focus)", ["quads", "hamstrings", "glutes", "core"], [
        warmup_legs(),
        block("main", [
            ex("leg_press", 3, (10, 12), p1_rir, 150, "primary", ""),
            ex("db_romanian_deadlift", 3, (8, 12), p1_rir, 120, "secondary", ""),
            ex("leg_extension", 2, (12, 15), p1_rir, 75, "accessory", ""),
            ex("leg_curl_machine", 2, (10, 15), p1_rir, 75, "accessory", ""),
            timed("dead_bug", 0, "2 x 8/side.", sets=2, rest=45, reps=(8, 8), role="core", per_side=True),
        ], "Main lifts"),
        finisher(5, 1), cooldown("legs")])
    upper_b = day("upper_b", "Upper B", ["chest", "back", "shoulders"], [
        warmup_upper(),
        block("main", [
            ex("db_incline_bench_press", 3, (8, 12), p1_rir, 120, "primary", "30 degree bench."),
            ex("db_chest_supported_row", 3, (8, 12), p1_rir, 120, "primary", "", warmup=1),
            ex("lat_pulldown_close_grip", 2, (10, 12), p1_rir, 90, "secondary", "Close neutral (V) handle if available, else underhand shoulder-width."),
            ex("machine_chest_press", 2, (10, 12), p1_rir, 90, "secondary", ""),
        ], "Main lifts"),
        block("superset", [
            ex("db_lateral_raise", 2, (12, 15), p1_rir, 0, "accessory", ""),
            ex("cable_face_pull", 2, (12, 15), p1_rir, 60, "accessory", ""),
        ], "Superset A", group="A", round_rest=60),
        finisher(8, 1), cooldown("upper")])
    lower_b = day("lower_b", "Lower B (hinge/glute focus)", ["hamstrings", "glutes", "quads", "calves"], [
        warmup_legs(),
        block("main", [
            ex("db_romanian_deadlift", 3, (8, 12), p1_rir, 120, "primary", ""),
            ex("db_goblet_squat", 3, (8, 12), p1_rir, 90, "secondary", "To a bench/box at first."),
            ex("leg_curl_machine", 3, (10, 15), p1_rir, 75, "accessory", ""),
            ex("db_hip_thrust", 2, (10, 15), p1_rir, 90, "accessory", "Upper back on a flat bench, DB on hips (use a towel), drive through heels, chin tucked."),
            ex("leg_press_calf_raise", 2, (12, 20), p1_rir, 60, "accessory", ""),
        ], "Main lifts"),
        finisher(5, 1), cooldown("legs")])
    return upper_a, lower_a, upper_b, lower_b


def phase1_wrapper(pid, days, extra=""):
    return {"phaseId": pid, "name": "Phase 1 - Foundation", "weeks": [1, 2, 3, 4],
            "goal": "Same rules as PPL Phase 1. " + extra, "rirWeekOffsets": {"1": 1, "2": 0, "3": 0, "4": 0},
            "unlocks": ["machines", "dumbbells", "cables"], "days": days,
            "laterPhasesRule": "Apply the PPL Phase 2/3 transformations: Phase 2 RIR 2, +1 set on primaries and some accessories, chest press->smith_machine_bench_press, leg_press first->smith_machine_squat first; Phase 3 RIR 1-2, primaries 5-8 reps, add barbell_romanian_deadlift and barbell_bent_over_row."}


def main(out_path):
    p1, p2, p3 = ppl_p1(), ppl_p2(), ppl_p3()
    ppl = program("ppl_3day", "Push / Pull / Legs - 3 days", "ppl", 3, ["push", "pull", "legs"],
                  [p1, p2, p3, deload_from(p3), retest_from(p3)],
                  "DEFAULT. Each muscle trained hard once per week with some overlap (shoulders/triceps on push, biceps/rear delts on pull). 12 weeks + deload + re-test.", default=True)
    ua, la, ub, lb = ul_days()
    ul3 = program("upper_lower_rotating_3day", "Upper / Lower (rotating) - 3 days", "upper_lower", 3,
                  ["upper_a", "lower_a", "upper_b", "lower_b"], [phase1_wrapper("foundation", [ua, la, ub, lb],
                  "Rotation continues across weeks: wk1 Upper A/Lower A/Upper B, wk2 Lower B/Upper A/Lower A, ... Each muscle ~1.5x/week.")],
                  "Best evidence-based alternative: more frequent practice of each lift (~1.5x/week per muscle).")
    # Chest+Back / Legs / Arms+Shoulders
    cb = day("chest_back", "Chest + Back", ["chest", "back"], [
        warmup_upper(),
        block("main", [
            ex("machine_chest_press", 3, (8, 12), 3, 120, "primary", ""),
            ex("lat_pulldown_wide", 3, (8, 12), 3, 120, "primary", "", warmup=1),
            ex("db_incline_bench_press", 2, (10, 12), 3, 90, "secondary", ""),
            ex("seated_cable_row", 2, (10, 12), 3, 90, "secondary", ""),
            ex("cable_fly", 2, (12, 15), 3, 60, "accessory", ""),
        ], "Main lifts (alternate chest and back exercises)"),
        finisher(8, 1), cooldown("upper")])
    legs_cb = copy.deepcopy(p1["days"][2])
    arms = day("arms_shoulders", "Arms + Shoulders", ["shoulders", "biceps", "triceps", "rear_delts"], [
        warmup_push(),
        block("main", [
            ex("machine_shoulder_press", 3, (8, 12), 3, 120, "primary", ""),
            ex("db_lateral_raise", 3, (12, 15), 3, 60, "accessory", ""),
        ], "Shoulders"),
        block("superset", [
            ex("db_biceps_curl", 3, (10, 15), 3, 0, "accessory", ""),
            ex("cable_triceps_pushdown", 3, (10, 15), 3, 60, "accessory", ""),
        ], "Superset A - arms", group="A", round_rest=60),
        block("superset", [
            ex("db_hammer_curl", 2, (10, 15), 3, 0, "accessory", ""),
            ex("db_overhead_triceps_extension", 2, (10, 15), 3, 60, "accessory", "Seated, one DB held in both hands behind the head."),
        ], "Superset B - arms", group="B", round_rest=60),
        block("main", [ex("cable_face_pull", 2, (12, 15), 3, 60, "accessory", "")], "Rear delts"),
        finisher(10, 1), cooldown("upper")], "Lightest day systemically - good day for the longer cardio finisher.")
    cbla = program("chest_back_legs_arms_3day", "Chest+Back / Legs / Arms+Shoulders - 3 days", "body_part", 3,
                   ["chest_back", "legs", "arms_shoulders"], [phase1_wrapper("foundation", [cb, legs_cb, arms])],
                   "Popular 'bro-ish' layout. Fine for beginners; arms get extra volume, chest/back get trained together.")
    ul2 = program("upper_lower_2day", "Upper / Lower - 2 days", "upper_lower", 2, ["upper_a", "lower_a"],
                  [phase1_wrapper("foundation", [copy.deepcopy(ua), copy.deepcopy(la)],
                   "Use when only 2 sessions/week are realistic; covers every muscle each week. Add 2-3 walks of 30 min on other days.")],
                  "Recommended fallback when the 3-week rolling average is < 2.5 sessions/week.")
    ul4 = program("upper_lower_4day", "Upper / Lower - 4 days", "upper_lower", 4, ["upper_a", "lower_a", "upper_b", "lower_b"],
                  [phase1_wrapper("foundation", [copy.deepcopy(x) for x in (ua, la, ub, lb)],
                   "Upper A Mon, Lower A Tue, Upper B Thu, Lower B Fri. Each muscle 2x/week.")],
                  "For 4-day weeks. Alternative: keep PPL on the rotating pointer (P-Pu-L-P, Pu-L-P-Pu...).")
    progs = [ppl, ul3, cbla, ul2, ul4]
    with open(out_path, "w") as f:
        json.dump(progs, f, indent=2, ensure_ascii=False)
    # print time summary
    for p in progs:
        for ph in p["phases"]:
            for d in ph["days"]:
                print(p["programId"], ph["phaseId"], d["dayId"], d["estimatedMinutes"])

if __name__ == "__main__":
    main(sys.argv[1])
