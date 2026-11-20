#!/usr/bin/env python3
"""Build the app's bundled data files from the research inputs.

Inputs  (docs/research/):
  exercises_push.json, exercises_pull.json, exercises_legs_core.json,
  exercises_cardio_warmup.json, exercises_added.json, program_draft.json,
  personalization.json
Outputs (assets/data/):
  exercises.json, programs.json, personalization.json

Run:  python3 -I tool/build_data.py            (from the project root)
Then: python3 -I tool/fetch_images.py          (downloads + compresses images)
      python3 -I tool/validate_data.py
The script is deterministic: running it twice produces identical files.
"""
import copy
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "docs", "research")
OUT = os.path.join(ROOT, "assets", "data")

SLICES = [
    "exercises_push.json",
    "exercises_pull.json",
    "exercises_legs_core.json",
    "exercises_cardio_warmup.json",
    "exercises_added.json",
]

# --------------------------------------------------------------------------
# 1. Exercises
# --------------------------------------------------------------------------

# Duplicate ids across slices: id -> slice whose version we keep.
DUPLICATE_KEEP = {
    "glute_bridge": "exercises_legs_core.json",
    "cable_pull_through": "exercises_legs_core.json",
}
# Same exercise under two ids: dropped id -> kept id.
MERGE_IDS = {
    "db_romanian_deadlift": "dumbbell_romanian_deadlift",
}

PATTERN = {
    # push
    "machine_chest_press": "horizontal_push", "dumbbell_bench_press": "horizontal_push",
    "incline_dumbbell_press": "incline_push", "smith_machine_bench_press": "horizontal_push",
    "smith_machine_incline_press": "incline_push", "barbell_bench_press": "horizontal_push",
    "dumbbell_fly": "chest_fly", "incline_dumbbell_fly": "chest_fly",
    "high_to_low_cable_fly": "chest_fly", "low_to_high_cable_fly": "chest_fly",
    "incline_push_up": "horizontal_push", "machine_shoulder_press": "vertical_push",
    "seated_dumbbell_shoulder_press": "vertical_push", "smith_machine_shoulder_press": "vertical_push",
    "dumbbell_lateral_raise": "lateral_raise", "cable_lateral_raise": "lateral_raise",
    "seated_dumbbell_lateral_raise": "lateral_raise", "head_supported_db_rear_delt_raise": "rear_delt",
    "dumbbell_front_raise": "front_raise", "triceps_rope_pushdown": "elbow_extension",
    "triceps_bar_pushdown": "elbow_extension", "overhead_cable_triceps_extension": "elbow_extension",
    "seated_dumbbell_overhead_triceps_extension": "elbow_extension",
    "smith_machine_close_grip_bench_press": "horizontal_push",
    # pull
    "lat_pulldown_wide": "vertical_pull", "lat_pulldown_close_neutral": "vertical_pull",
    "lat_pulldown_underhand": "vertical_pull", "straight_arm_cable_pulldown": "straight_arm_pull",
    "seated_cable_row": "horizontal_pull", "chest_supported_db_row": "horizontal_pull",
    "one_arm_db_row": "horizontal_pull", "smith_machine_bent_over_row": "horizontal_pull",
    "barbell_bent_over_row": "horizontal_pull", "cable_face_pull": "rear_delt",
    "incline_reverse_db_fly": "rear_delt", "cable_rear_delt_fly": "rear_delt",
    "db_bicep_curl": "elbow_flexion", "cable_bicep_curl": "elbow_flexion",
    "barbell_curl": "elbow_flexion", "db_hammer_curl": "elbow_flexion",
    "incline_db_curl": "elbow_flexion", "db_shrug": "shrug", "smith_machine_shrug": "shrug",
    "prone_superman_back_extension": "back_extension",
    # legs
    "leg_press": "squat", "leg_extension": "knee_extension", "seated_leg_curl": "knee_flexion",
    "lying_leg_curl": "knee_flexion", "dumbbell_goblet_squat": "squat", "goblet_box_squat": "squat",
    "smith_machine_squat": "squat", "supported_split_squat": "lunge", "dumbbell_step_up": "lunge",
    "dumbbell_romanian_deadlift": "hinge", "barbell_romanian_deadlift": "hinge",
    "cable_pull_through": "hinge", "smith_machine_hip_thrust": "hip_thrust",
    "dumbbell_hip_thrust": "hip_thrust", "glute_bridge": "hip_thrust",
    "cable_glute_kickback": "glute_isolation", "leg_press_calf_raise": "calf_raise",
    "smith_machine_calf_raise": "calf_raise", "dumbbell_standing_calf_raise": "calf_raise",
    "machine_calf_raise": "calf_raise",
    # core
    "dead_bug": "core", "plank": "core", "incline_plank": "core", "side_plank": "core",
    "cable_crunch": "core", "pallof_press": "core", "cable_woodchop": "core", "bench_leg_raise": "core",
    # cardio
    "general_warmup_cardio": "cardio", "bike_steady_state": "cardio", "treadmill_incline_walk": "cardio",
    "treadmill_brisk_walk": "cardio", "bike_intervals": "cardio",
}
# Number of dumbbells the logged weight refers to (weight is always PER dumbbell).
DUMBBELL_COUNT = {
    "dumbbell_bench_press": 2, "incline_dumbbell_press": 2, "dumbbell_fly": 2, "incline_dumbbell_fly": 2,
    "seated_dumbbell_shoulder_press": 2, "dumbbell_lateral_raise": 2, "dumbbell_front_raise": 2,
    "chest_supported_db_row": 2, "incline_reverse_db_fly": 2, "db_bicep_curl": 2, "db_hammer_curl": 2,
    "incline_db_curl": 2, "db_shrug": 2, "dumbbell_romanian_deadlift": 2, "dumbbell_step_up": 2,
    "seated_dumbbell_overhead_triceps_extension": 1, "one_arm_db_row": 1, "dumbbell_goblet_squat": 1,
    "goblet_box_squat": 1, "dumbbell_hip_thrust": 1, "supported_split_squat": 1,
    "dumbbell_standing_calf_raise": 1, "seated_dumbbell_lateral_raise": 2, "head_supported_db_rear_delt_raise": 2,
}
# Explicit cross-slice links (both directions are added).
CROSS_LINKS = [
    ("machine_chest_press", "dumbbell_bench_press"),
    ("machine_chest_press", "smith_machine_bench_press"),
    ("smith_machine_bench_press", "dumbbell_bench_press"),
    ("incline_dumbbell_press", "smith_machine_incline_press"),
    ("machine_shoulder_press", "seated_dumbbell_shoulder_press"),
    ("leg_press", "smith_machine_squat"),
    ("leg_press", "dumbbell_goblet_squat"),
    ("smith_machine_squat", "goblet_box_squat"),
    ("dumbbell_romanian_deadlift", "barbell_romanian_deadlift"),
    ("dumbbell_romanian_deadlift", "cable_pull_through"),
    ("seated_leg_curl", "lying_leg_curl"),
    ("machine_calf_raise", "leg_press_calf_raise"),
    ("machine_calf_raise", "smith_machine_calf_raise"),
    ("machine_calf_raise", "dumbbell_standing_calf_raise"),
    ("scapular_pulldown", "scapular_wall_slides"),
    ("lat_pulldown_wide", "lat_pulldown_close_neutral"),
    ("seated_cable_row", "chest_supported_db_row"),
    ("seated_cable_row", "one_arm_db_row"),
    ("cable_face_pull", "incline_reverse_db_fly"),
    ("glute_bridge", "dumbbell_hip_thrust"),
    ("bike_steady_state", "treadmill_incline_walk"),
    ("bike_steady_state", "treadmill_brisk_walk"),
    ("treadmill_incline_walk", "treadmill_brisk_walk"),
    ("pallof_press", "dead_bug"),
    # critic review: second beginner option for side and rear delts
    ("dumbbell_lateral_raise", "seated_dumbbell_lateral_raise"),
    ("cable_lateral_raise", "seated_dumbbell_lateral_raise"),
    ("incline_reverse_db_fly", "head_supported_db_rear_delt_raise"),
    ("cable_face_pull", "head_supported_db_rear_delt_raise"),
]
MAX_SUBS = 6
STRENGTH_CATS = {"push", "pull", "legs", "core"}

TEXT_PATCHES = {
    # id -> list of (field, index or None, old substring, new text) ; index None = whole string field
    "cable_glute_kickback": [
        ("setup", 0, None,
         "NOTE (equipment uncertain): this needs an ankle cuff/strap for the cable machine. The 'Ankle machine' "
         "on the gym list turned out to be a calf raise machine, so an ankle strap is not confirmed. Ask gym staff; "
         "if there is no strap, do glute_bridge or dumbbell_hip_thrust instead."),
    ],
}
EQUIPMENT_RENAMES = {"ankle_machine": "ankle_strap"}


def load(name):
    with open(os.path.join(RES, name), encoding="utf-8") as f:
        return json.load(f)


def build_exercises():
    merged = {}
    order = []
    for sl in SLICES:
        for e in load(sl):
            eid = e["id"]
            if eid in MERGE_IDS:
                continue
            if eid in merged:
                keep = DUPLICATE_KEEP.get(eid)
                if keep is None:
                    sys.exit(f"Unexpected duplicate id {eid} in {sl}")
                other = e
                if keep == sl:
                    other, merged[eid] = merged[eid], e
                # union aliases from the dropped copy (its substitutions belong to another category)
                base = merged[eid]
                for v in other["aliases"]:
                    if v not in base["aliases"]:
                        base["aliases"].append(v)
                continue
            merged[eid] = e
            order.append(eid)

    ids = set(order)
    for e in merged.values():
        e["equipment"] = [EQUIPMENT_RENAMES.get(q, q) for q in e["equipment"]]
        subs = []
        for s in e["substitutions"]:
            s = MERGE_IDS.get(s, s)
            if s in ids and s != e["id"] and s not in subs:
                subs.append(s)
        e["substitutions"] = subs
        for field, idx, _old, new in TEXT_PATCHES.get(e["id"], []):
            if idx is None:
                e[field] = new
            else:
                e[field][idx] = new

    def link(a, b):
        ea, eb = merged[a], merged[b]
        if b not in ea["substitutions"]:
            ea["substitutions"].append(b)
        if a not in eb["substitutions"]:
            eb["substitutions"].append(a)

    for a, b in CROSS_LINKS:
        link(a, b)

    # symmetric closure for strength exercises that share a primary muscle
    for e in [merged[i] for i in order]:
        for s in list(e["substitutions"]):
            t = merged[s]
            if e["id"] in t["substitutions"] or len(t["substitutions"]) >= MAX_SUBS:
                continue
            if e["category"] in STRENGTH_CATS and t["category"] in STRENGTH_CATS and \
                    set(e["primaryMuscles"]) & set(t["primaryMuscles"]):
                t["substitutions"].append(e["id"])

    out = []
    for eid in order:
        e = merged[eid]
        cat = e["category"]
        if eid in PATTERN:
            pattern = PATTERN[eid]
        elif cat == "mobility":
            pattern = "stretch"
        elif cat == "warmup":
            pattern = "mobility"
        else:
            sys.exit(f"No movementPattern for {eid}")
        if e["loadType"] == "time":
            tracking = "time"
        elif e["loadType"] == "bodyweight":
            tracking = "reps"
        else:
            tracking = "weight_reps"
        rec = {k: v for k, v in e.items() if not k.startswith("_")}
        rec["movementPattern"] = pattern
        rec["tracking"] = tracking
        rec["dumbbellCount"] = DUMBBELL_COUNT.get(eid) if e["loadType"] == "dumbbell" else None
        rec["localImages"] = [f"assets/exercises/{eid}_{i}.jpg" for i in range(len(e["images"]))]
        out.append(rec)
    return out


# --------------------------------------------------------------------------
# 2. Programs
# --------------------------------------------------------------------------

# program draft id -> library id (context-free renames)
RENAME = {
    "cable_fly": "high_to_low_cable_fly",
    "cable_pallof_press": "pallof_press",
    "cable_triceps_pushdown": "triceps_rope_pushdown",
    "db_biceps_curl": "db_bicep_curl",
    "db_chest_supported_row": "chest_supported_db_row",
    "db_hip_thrust": "dumbbell_hip_thrust",
    "db_incline_bench_press": "incline_dumbbell_press",
    "db_incline_curl": "incline_db_curl",
    "db_lateral_raise": "dumbbell_lateral_raise",
    "db_one_arm_row": "one_arm_db_row",
    "db_overhead_triceps_extension": "seated_dumbbell_overhead_triceps_extension",
    "db_seated_shoulder_press": "seated_dumbbell_shoulder_press",
    "incline_treadmill_walk": "treadmill_incline_walk",
    "lat_pulldown_close_grip": "lat_pulldown_close_neutral",
    "leg_curl_machine": "seated_leg_curl",
    "db_romanian_deadlift": "dumbbell_romanian_deadlift",
    "db_goblet_squat": "dumbbell_goblet_squat",
    "leg_press_calf_raise": "machine_calf_raise",  # USER_NOTES: ankle machine = calf raise machine
    # substitutes only
    "cable_biceps_curl": "cable_bicep_curl",
    "cable_reverse_fly": "cable_rear_delt_fly",
    "cable_straight_arm_pulldown": "straight_arm_cable_pulldown",
    "db_bench_press": "dumbbell_bench_press",
    "db_flat_fly": "dumbbell_fly",
    "db_incline_fly": "incline_dumbbell_fly",
    "db_goblet_squat_heels_elevated": "dumbbell_goblet_squat",
    "db_rear_delt_fly": "incline_reverse_db_fly",
    "db_seated_lateral_raise": "cable_lateral_raise",
    "db_single_leg_calf_raise": "dumbbell_standing_calf_raise",
    "db_split_squat": "supported_split_squat",
    "smith_machine_split_squat": "supported_split_squat",
    "smith_machine_row": "smith_machine_bent_over_row",
    "smith_machine_seated_overhead_press": "smith_machine_shoulder_press",
    "cable_rope_hammer_curl": "db_hammer_curl",
    "cable_single_arm_row": "one_arm_db_row",
    "half_kneeling_cable_pulldown": "lat_pulldown_close_neutral",
    "db_pullover": "straight_arm_cable_pulldown",
    "db_lying_triceps_extension": "seated_dumbbell_overhead_triceps_extension",
    "db_single_leg_romanian_deadlift": "dumbbell_romanian_deadlift",
    "smith_machine_romanian_deadlift": "cable_pull_through",
}
# substitutes that need equipment the gym does not have -> dropped
DROP_SUBS = {"barbell_back_squat", "bench_dip_feet_on_floor", "cable_chest_press_standing",
             "cable_leg_extension", "cable_standing_leg_curl"}

STRETCHES = {
    "push": ["chest_doorway_stretch", "childs_pose"],
    "pull": ["bench_lat_stretch", "childs_pose"],
    "legs": ["lying_hamstring_stretch_towel", "bench_quad_stretch", "half_kneeling_hip_flexor_stretch",
             "calf_stretch_wall"],
    "upper": ["chest_doorway_stretch", "bench_lat_stretch"],
}

WORK_S, PER_SIDE_WORK_S, TRANSITION_S, WARMUP_SET_S = 40, 70, 90, 75
CARDIO_WARMUP_IDS = {"general_warmup_cardio", "bike_steady_state", "treadmill_brisk_walk", "treadmill_incline_walk"}
MAX_ITEM_SUBS = 4


def est_block_seconds(b):
    t = b["blockType"]
    if t == "warmup":
        # cardio item duration + mobility/ramp drills (120 s, or 180 s for the "~8 min" leg warm-up).
        # Keeps the old 420/480 s numbers for the shipped 300 s cardio, and lets the session builder
        # shorten the cardio (SPEC 6.8 trim ladder) with an honest estimate.
        cardio = sum(i["durationSeconds"] or 0 for i in b["items"]
                     if i["role"] == "warmup" and i["durationSeconds"] and i["repRange"] is None
                     and i["exerciseId"] in CARDIO_WARMUP_IDS)
        return cardio + (180 if "8 min" in b["name"] else 120)
    if t == "cooldown":
        return 240
    if t == "finisher":
        return sum(i["durationSeconds"] or 0 for i in b["items"])
    if t == "superset":
        rounds = max(i["sets"] for i in b["items"])
        rr = b["restBetweenRoundsSeconds"] or 60
        return rounds * (WORK_S * len(b["items"]) + 20 + rr) - rr + TRANSITION_S
    total = 0
    for i in b["items"]:
        work = PER_SIDE_WORK_S if i["perSide"] else WORK_S
        total += i["sets"] * (work + i["restSeconds"]) - i["restSeconds"] + TRANSITION_S
        w = i["warmupSets"]
        total += (2 if w == "auto" else (w or 0)) * WARMUP_SET_S
    return total


def estimate(day):
    core = opt = fin = 0
    for b in day["blocks"]:
        if b["blockType"] == "finisher":
            fin += est_block_seconds(b)
            continue
        if b["optional"] or all(i["optional"] for i in b["items"]) and b["blockType"] in ("main", "superset"):
            opt += est_block_seconds(b)
            continue
        if b["blockType"] in ("main",):
            for i in b["items"]:
                s = est_block_seconds({"blockType": "main", "items": [i]})
                if i["optional"]:
                    opt += s
                else:
                    core += s
        else:
            core += est_block_seconds(b)
    return {"core": round(core / 60), "withOptionalExercises": round((core + opt) / 60),
            "withFinisher": round((core + fin) / 60)}


def rename_text(text):
    def rep(m):
        w = m.group(0)
        return RENAME.get(w, w)
    return re.sub(r"\b[a-z][a-z0-9_]+\b", rep, text)


class ProgramBuilder:
    def __init__(self, exercises):
        self.ex = {e["id"]: e for e in exercises}

    def norm_item(self, it, block_type):
        old = it["exerciseId"]
        if block_type == "warmup" and old == "stationary_bike":
            new, subs = "general_warmup_cardio", []
        elif block_type == "cooldown" and old == "treadmill_walk":
            new, subs = "general_warmup_cardio", []
        elif old == "stationary_bike":
            new, subs = "bike_steady_state", ["treadmill_incline_walk", "treadmill_brisk_walk"]
        elif block_type == "warmup" and old == "db_goblet_squat":
            new, subs = "goblet_box_squat", ["bodyweight_box_squat"]
        else:
            new = RENAME.get(old, old)
            subs = it.get("substitutions") or []
        notes = rename_text(it.get("notes", ""))
        notes = notes.replace(" If a squat rack is available and form is solid, app may offer barbell_back_squat "
                              "(user toggle).", "")
        if old == "leg_curl_machine":
            subs = ["lying_leg_curl"] + list(subs)
        if old == "leg_press_calf_raise":
            subs = ["leg_press_calf_raise", "smith_machine_calf_raise", "dumbbell_standing_calf_raise"]
            notes = ("Calf raise machine (the gym's 'ankle machine'): full stretch at the bottom, 1 s squeeze at the top. "
                     "Busy or broken: calf raise on the leg press. " + notes.replace(
                         "On the leg press with the safety catches set: balls of feet on the bottom edge, knees soft, "
                         "full stretch then up. Avoids the uncertain 'ankle machine'.", "")).strip()
        if old == "cable_fly":
            notes = notes.replace("Cables at shoulder height, hug a big tree.",
                                  "Pulleys set high, hands meet in front of the lower chest, hug a big tree.")
        if old == "incline_treadmill_walk" and block_type == "warmup":
            notes = notes
        out_subs = []
        # Calf slot: subs are already library ids. Do not pass them through RENAME, which maps
        # leg_press_calf_raise -> machine_calf_raise (the slot itself) and silently dropped the
        # first (most similar, no extra machine) fallback.
        keep_ids = old == "leg_press_calf_raise"
        for s in subs:
            s = s if keep_ids else RENAME.get(s, s)
            if s in DROP_SUBS or s == new or s not in self.ex or s in out_subs:
                continue
            out_subs.append(s)
        for s in self.ex[new]["substitutions"]:
            if len(out_subs) >= MAX_ITEM_SUBS:
                break
            if s != new and s not in out_subs:
                out_subs.append(s)
        out_subs = out_subs[:MAX_ITEM_SUBS]
        notes = self.humanize(notes)
        ex = self.ex[new]
        if ex["loadType"] in ("time", "bodyweight"):
            inc = None
        elif old == "leg_press_calf_raise":
            inc = 5
        else:
            inc = it.get("weightIncrementKg", ex["weightIncrementKg"])
        dur = it.get("durationSeconds")
        if new == "general_warmup_cardio" and dur is None:
            dur = 300
        return {
            "exerciseId": new,
            "sets": it["sets"],
            "repRange": it.get("repRange") if dur is None else None,
            "durationSeconds": dur,
            "rir": it["rir"],
            "restSeconds": it["restSeconds"],
            "role": it["role"],
            "warmupSets": it.get("warmupSets", 0),
            "weightIncrementKg": inc,
            "perSide": bool(it.get("perSide", False)),
            "optional": bool(it.get("optional", False)),
            "test": it.get("test"),
            "substitutions": out_subs,
            "notes": notes,
        }

    def humanize(self, text):
        """Replace exercise ids that leaked into user-facing notes with display names."""
        def rep(m):
            w = m.group(0)
            return self.ex[w]["name"] if w in self.ex else w
        return re.sub(r"\b[a-z][a-z0-9]*(?:_[a-z0-9]+)+\b", rep, text)

    def stretch_items(self, focus):
        items = []
        for sid in STRETCHES[focus]:
            e = self.ex[sid]
            items.append({
                "exerciseId": sid, "sets": 1, "repRange": None, "durationSeconds": e["durationSeconds"],
                "rir": None, "restSeconds": 0, "role": "stretch", "warmupSets": 0, "weightIncrementKg": None,
                "perSide": bool(e["unilateral"]), "optional": True, "test": None,
                "substitutions": [s for s in e["substitutions"] if s in self.ex][:2],
                "notes": "Gentle, about 30 s" + (" each side" if e["unilateral"] else "") +
                         ". For comfort and mobility; skip if short on time.",
            })
        return items

    def norm_block(self, b):
        items = []
        for it in b["items"]:
            if it["exerciseId"].startswith("static_stretch_"):
                items.extend(self.stretch_items(it["exerciseId"][len("static_stretch_"):]))
            else:
                items.append(self.norm_item(it, b["blockType"]))
        return {
            "blockType": b["blockType"],
            "name": b.get("name") or b["blockType"].title(),
            "optional": bool(b.get("optional", False)),
            "supersetGroup": b.get("supersetGroup"),
            "restBetweenRoundsSeconds": b.get("restBetweenRoundsSeconds"),
            "items": items,
        }

    def norm_day(self, d):
        day = {
            "dayId": d["dayId"], "name": d["name"], "focus": d["focus"],
            "notes": self.humanize(rename_text(d.get("notes", ""))),
            "blocks": [self.norm_block(b) for b in d["blocks"]],
        }
        day["estimatedMinutes"] = estimate(day)
        return day

    def norm_phase(self, ph):
        return {
            "phaseId": ph["phaseId"], "name": ph["name"], "weeks": ph["weeks"], "goal": self.humanize(rename_text(ph["goal"])),
            "rirWeekOffsets": ph.get("rirWeekOffsets", {}),
            "rirFloorByRole": ph.get("rirFloorByRole"),
            "loadMultiplier": ph.get("loadMultiplier", 1.0),
            "unlocks": ph.get("unlocks", []),
            "approxWeeklyDirectSetsPerMuscle": ph.get("approxWeeklyDirectSetsPerMuscle"),
            "days": [self.norm_day(d) for d in ph["days"]],
        }


# ---- phase generators for the alternative programs (apply PPL phase rules) ----

def _main_items(day):
    for b in day["blocks"]:
        if b["blockType"] in ("main", "superset"):
            for i in b["items"]:
                yield b, i


def _set_item(i, **kw):
    i.update(kw)


def build_phase2(p1, ex_lookup, builder):
    ph = copy.deepcopy(p1)
    ph.update({"phaseId": "build", "name": "Phase 2 - Build", "weeks": [5, 6, 7, 8],
               "goal": "Add the Smith machine squat and bench, slightly harder sets (stop about 2 reps short).",
               "rirWeekOffsets": {"5": 1, "6": 0, "7": 0, "8": 0}, "rirFloorByRole": None, "loadMultiplier": 1.0,
               "unlocks": ["machines", "dumbbells", "cables", "smith_machine"],
               "approxWeeklyDirectSetsPerMuscle": None})
    for d in ph["days"]:
        is_lower = any(i["exerciseId"] == "leg_press" and i["role"] == "primary" for _, i in _main_items(d)) or \
            d["dayId"].startswith("lower")
        for b in d["blocks"]:
            if b["blockType"] not in ("main", "superset"):
                continue
            new_items = []
            for i in b["items"]:
                if i["rir"] is not None:
                    i["rir"] = max(2, i["rir"] - 1)
                if b["blockType"] == "superset" and i["sets"] == 2:
                    i["sets"] = 3
                if i["exerciseId"] == "machine_chest_press" and i["role"] == "primary":
                    old_notes = i["notes"]
                    i.update(builder.norm_item({"exerciseId": "smith_machine_bench_press", "sets": 3, "repRange": [6, 10],
                                                "rir": 2, "restSeconds": 150, "role": "primary", "warmupSets": "auto",
                                                "weightIncrementKg": 2.5,
                                                "substitutions": ["dumbbell_bench_press", "machine_chest_press"],
                                                "notes": "NEW in Phase 2. Set the safety stops just below chest height. "
                                                         "Start around your machine chest press weight minus 20%."},
                                               "main"))
                if i["exerciseId"] == "leg_press" and i["role"] == "primary":
                    i.update(builder.norm_item({"exerciseId": "smith_machine_squat", "sets": 3, "repRange": [6, 10],
                                                "rir": 2, "restSeconds": 150, "role": "primary", "warmupSets": "auto",
                                                "weightIncrementKg": 5,
                                                "substitutions": ["leg_press", "dumbbell_goblet_squat"],
                                                "notes": "NEW in Phase 2. Safety stops just below your lowest squat "
                                                         "depth. Start with the bar plus small plates."}, "main"))
                    new_items.append(i)
                    new_items.append(builder.norm_item({"exerciseId": "leg_press", "sets": 2, "repRange": [10, 15],
                                                        "rir": 2, "restSeconds": 120, "role": "secondary",
                                                        "warmupSets": 0, "weightIncrementKg": 10,
                                                        "substitutions": ["dumbbell_goblet_squat"],
                                                        "notes": "After the squat: lighter, higher reps."}, "main"))
                    continue
                new_items.append(i)
            b["items"] = new_items
        if is_lower:
            d["blocks"] = [b for b in d["blocks"] if b["blockType"] != "finisher"]
        d["notes"] = "Phase 2: stop sets with about 2 good reps left (week 5: 3)."
        d["estimatedMinutes"] = estimate(d)
    return ph


def build_phase3(p2, builder):
    ph = copy.deepcopy(p2)
    ph.update({"phaseId": "progress", "name": "Phase 3 - Progress", "weeks": [9, 10, 11, 12],
               "goal": "Heavier main lifts (5-8 reps), floor-started barbell RDL and row, effort close to 1-2 reps short.",
               "rirWeekOffsets": {"9": 0, "10": 0, "11": -1, "12": -1},
               "rirFloorByRole": {"primary": 1, "secondary": 1, "accessory": 0},
               "unlocks": ["machines", "dumbbells", "cables", "smith_machine", "barbell_floor_lifts"]})
    for d in ph["days"]:
        row_swapped = False
        for b, i in list(_main_items(d)):
            eid = i["exerciseId"]
            if i["role"] == "primary":
                if builder.ex[eid]["loadType"] in ("smith", "barbell"):
                    i.update({"repRange": [5, 8], "restSeconds": 180, "rir": 2})
                else:
                    i.update({"repRange": [6, 10], "rir": 2})
            elif i["role"] == "secondary":
                i["rir"] = 2 if i["rir"] is not None else None
            elif i["rir"] is not None:
                i["rir"] = 1
            if eid == "dumbbell_romanian_deadlift":
                i.update(builder.norm_item({"exerciseId": "barbell_romanian_deadlift", "sets": 3, "repRange": [6, 10],
                                            "rir": 2, "restSeconds": 150, "role": i["role"], "warmupSets": 1,
                                            "weightIncrementKg": 5,
                                            "substitutions": ["dumbbell_romanian_deadlift", "cable_pull_through"],
                                            "notes": "NEW in Phase 3. Same hinge as the dumbbell RDL; bar stays "
                                                     "touching the thighs. Start around 1.6-1.8x your per-hand "
                                                     "dumbbell RDL weight."}, "main"))
            elif not row_swapped and eid in ("seated_cable_row", "chest_supported_db_row") and b["blockType"] == "main":
                row_swapped = True
                role = i["role"]
                i.update(builder.norm_item({"exerciseId": "barbell_bent_over_row", "sets": i["sets"],
                                            "repRange": [6, 10], "rir": 2,
                                            "restSeconds": 150 if role == "primary" else 120, "role": role,
                                            "warmupSets": 1,
                                            "weightIncrementKg": 2.5,
                                            "substitutions": ["smith_machine_bent_over_row", "chest_supported_db_row",
                                                              "seated_cable_row"],
                                            "notes": "NEW in Phase 3. Pick the bar up from the floor with a flat back. "
                                                     "Torso about 45 degrees, pull to the lower ribs."}, "main"))
        d["notes"] = "Phase 3: main lifts 5-8 reps, stop 1-2 reps short (weeks 11-12: about 1)."
        d["estimatedMinutes"] = estimate(d)
    return ph


def build_deload(p3):
    ph = copy.deepcopy(p3)
    ph.update({"phaseId": "deload", "name": "Deload (week 13)", "weeks": [13],
               "goal": "Recover: same exercises, half the sets, about 10% lighter, easy effort.",
               "rirWeekOffsets": {"13": 0}, "rirFloorByRole": None, "loadMultiplier": 0.9})
    for d in ph["days"]:
        d["blocks"] = [b for b in d["blocks"] if not b["optional"]]
        for b in d["blocks"]:
            if b["blockType"] in ("main", "superset"):
                b["items"] = [i for i in b["items"] if not i["optional"]]
                for i in b["items"]:
                    i["sets"] = max(1, math.ceil(i["sets"] / 2))
                    if i["rir"] is not None:
                        i["rir"] = 4
                    i["notes"] = "DELOAD: ~90% of last working weight, stop with 4+ reps left. " + i["notes"]
        d["blocks"] = [b for b in d["blocks"] if b["blockType"] != "finisher"]
        d["notes"] = "Deload week. Should feel easy. Use spare time for a longer walk if you want."
        d["estimatedMinutes"] = estimate(d)
    return ph


def build_retest(p3):
    ph = copy.deepcopy(p3)
    ph.update({"phaseId": "retest", "name": "Re-test (week 14)", "weeks": [14],
               "goal": "Measure progress: one test set (stop with ~1 rep left) on each day's first two main lifts, "
                       "then light accessories. Take body measurements.",
               "rirWeekOffsets": {"14": 0}, "rirFloorByRole": None, "loadMultiplier": 1.0})
    for d in ph["days"]:
        d["blocks"] = [b for b in d["blocks"] if not b["optional"] and b["blockType"] != "finisher"]
        n = 0
        for b in d["blocks"]:
            if b["blockType"] in ("main", "superset"):
                b["items"] = [i for i in b["items"] if not i["optional"]]
                for i in b["items"]:
                    if i["role"] in ("primary", "secondary") and n < 2 and b["blockType"] == "main" \
                            and i["repRange"] is not None:
                        n += 1
                        i.update({"sets": 1, "repRange": [3, 15], "rir": 1, "restSeconds": 180, "test": "rir1_rep_test",
                                  "notes": "TEST: after normal warm-up sets, use your last Phase-3 working weight and do "
                                           "as many good reps as possible, stopping when you have about 1 left. Then 1 "
                                           "back-off set of 8 at 80% (stop 3 short)."})
                    elif i["rir"] is not None:
                        i["sets"] = 2
                        i["rir"] = 2
        d["notes"] = "Re-test day. Also (once this week, morning, before eating): body weight, waist at navel, photos."
        d["estimatedMinutes"] = estimate(d)
    return ph


PROGRAM_META = {
    "ppl_3day": {"recommendedWeekdays": [1, 3, 5], "splitKey": "push_pull_legs"},
    "upper_lower_rotating_3day": {"recommendedWeekdays": [1, 3, 5], "splitKey": "upper_lower"},
    "chest_back_legs_arms_3day": {"recommendedWeekdays": [1, 3, 5], "splitKey": "chestback_legs_armsshoulders"},
    "upper_lower_2day": {"recommendedWeekdays": [2, 5], "splitKey": "upper_lower"},
    "upper_lower_4day": {"recommendedWeekdays": [1, 2, 4, 5], "splitKey": "upper_lower"},
}


# What the split picker shows. The draft's descriptions are research notes, not app text.
PROGRAM_DESCRIPTIONS = {
    "ppl_3day": "Push, pull and legs on separate days. Each muscle gets one hard session a week, "
                "with shoulders and arms helping on the other days. 12 weeks, then an easy week and a re-test.",
    "upper_lower_rotating_3day": "Upper body, lower body, repeat. Each muscle is trained about 1.5 times a "
                                 "week, so you practise every lift more often. A strong choice if you like it.",
    "chest_back_legs_arms_3day": "Chest and back together, then legs, then arms and shoulders. "
                                 "Fine for beginners, with extra work for your arms.",
    "upper_lower_2day": "Two full sessions a week: upper body and lower body. "
                        "Good for busy weeks such as exams: you keep your progress on less time.",
    "upper_lower_4day": "Upper, lower, upper, lower. For when you can train 4 days a week.",
}


_FOUNDATION = ("Learn every machine and movement, set safe starting weights, build the habit. "
               "Machines + dumbbells only.")

# Phase blurbs on the Program tab that the draft wrote as notes to itself.
PHASE_GOALS = {
    ("ppl_3day", "retest"): "Measure progress: one test set (stop with ~1 rep left) on each day's first two "
                            "main lifts, then light accessories. Take body measurements.",
    ("upper_lower_rotating_3day", "foundation"): _FOUNDATION + " Each muscle is trained about 1.5 times a week.",
    ("chest_back_legs_arms_3day", "foundation"): _FOUNDATION,
    ("upper_lower_2day", "foundation"): _FOUNDATION + " Every muscle is covered each week; add 2-3 brisk "
                                        "30-minute walks on other days.",
    ("upper_lower_4day", "foundation"): _FOUNDATION + " Each muscle is trained twice a week.",
}


def build_programs(exercises):
    draft = load("program_draft.json")
    b = ProgramBuilder(exercises)
    programs = []
    progression = None
    for p in draft:
        progression = progression or p["progressionDefaults"]
        phases = [b.norm_phase(ph) for ph in p["phases"]]
        if len(phases) == 1:  # alternative programs only have Phase 1 in the draft
            p1 = phases[0]
            p2 = build_phase2(p1, b.ex, b)
            p3 = build_phase3(p2, b)
            phases = [p1, p2, p3, build_deload(p3), build_retest(p3)]
        for ph in phases:
            goal = PHASE_GOALS.get((p["programId"], ph["phaseId"]))
            if goal:
                ph["goal"] = goal
        meta = PROGRAM_META[p["programId"]]
        programs.append({
            "programId": p["programId"],
            "name": p["name"],
            "default": bool(p.get("default", False)),
            "splitType": p["splitType"],
            "splitKey": meta["splitKey"],
            "daysPerWeek": p["daysPerWeek"],
            "dayOrder": p["dayOrder"],
            "description": PROGRAM_DESCRIPTIONS.get(p["programId"]) or b.humanize(rename_text(p["description"])),
            "targetUser": p["targetUser"],
            "scheduling": "rotating_pointer",
            "schedulingNotes": p["schedulingNotes"],
            "recommendedWeekdays": meta["recommendedWeekdays"],
            "totalWeeks": 14,
            "cycleRestartWeek": 5,
            "phases": phases,
        })
    prog = copy.deepcopy(progression)
    prog["startingWeight"] = "find_your_weight_ramp (SPEC.md section 6.2)"
    prog["warmupSetCalculator"] = "auto for warmupSets='auto' (SPEC.md section 6.3)"
    return {
        "schemaVersion": 1,
        "defaultProgramId": "ppl_3day",
        "progression": prog,
        "equipmentAssumptions": {
            "noRack": "No squat rack / bench uprights listed: barbell squat and bench default to the Smith machine. "
                      "Barbell lifts used are floor-started (RDL, bent-over row).",
            "ankleMachine": "Resolved by the user (docs/research/USER_NOTES.md): the 'ankle machine' is a calf raise "
                            "machine. machine_calf_raise is the default calf exercise, but every calf slot is optional "
                            "and leg_press_calf_raise is its first substitute, so nothing breaks if the machine turns "
                            "out to be something else (untick it in Settings > Equipment). No ankle strap is "
                            "confirmed, so ankle-strap exercises (cable_glute_kickback) are never defaults.",
            "legCurlType": "Unknown (seated or lying). Default seated_leg_curl; Settings > Equipment can switch every "
                           "seated_leg_curl slot to lying_leg_curl.",
            "noPullupBarKettlebellEzBarBands": True,
        },
        "idMigrations": {k: v for k, v in sorted(RENAME.items())},
        "programs": programs,
    }


# --------------------------------------------------------------------------
# 3. Personalization
# --------------------------------------------------------------------------

MILESTONE_EXERCISES = {
    "leg_press": ["leg_press"],
    "lat_pulldown": ["lat_pulldown_wide", "lat_pulldown_close_neutral", "lat_pulldown_underhand"],
    "romanian_deadlift": ["barbell_romanian_deadlift", "dumbbell_romanian_deadlift"],
    "goblet_squat": ["dumbbell_goblet_squat", "goblet_box_squat"],
    "dumbbell_row": ["one_arm_db_row"],
    "machine_chest_press": ["machine_chest_press"],
    "machine_shoulder_press": ["machine_shoulder_press"],
}
ANCHORS = {
    "leg_press": ["leg_press"],
    "chest_press_or_bench": ["machine_chest_press", "smith_machine_bench_press"],
    "lat_pulldown": ["lat_pulldown_wide"],
    "shoulder_press_machine": ["machine_shoulder_press"],
    "romanian_deadlift_or_goblet_squat": ["dumbbell_romanian_deadlift", "barbell_romanian_deadlift",
                                          "dumbbell_goblet_squat"],
}


def build_personalization(exercise_ids):
    p = load("personalization.json")
    out = {"schemaVersion": 1}
    for k in ("app", "disclaimer", "values_note"):
        out[k] = p[k]
    fields = {f["id"]: f for f in p["onboarding"]["fields"]}
    out["defaultProfile"] = {
        "sex": "male", "age_y": 22, "height_cm": 172, "weight_kg": 95, "goal_weight_kg": None, "waist_cm": None,
        "activity_level": "lightly_active", "goal": "recomp", "experience": "never", "days_per_week": 3,
        "session_minutes": 60, "split": "push_pull_legs", "limitations": [], "training_time": "evening",
        "budget": "tight", "diet_notes": [], "units": "metric", "programId": "ppl_3day",
        "reminder_weekdays": [1, 3, 5],
    }
    assert set(out["defaultProfile"]) >= {f for f in fields if f not in ("parq", "baseline_steps", "reminders")}
    out["programSelection"] = {
        "rule": "pick by (split, days_per_week); fall back to ppl_3day",
        "table": [
            {"split": "push_pull_legs", "days_per_week": [3, 4, 5, 6], "programId": "ppl_3day"},
            {"split": "push_pull_legs", "days_per_week": [2], "programId": "upper_lower_2day",
             "note": "PPL needs 3 days; with 2 days the app suggests Upper/Lower 2-day."},
            {"split": "upper_lower", "days_per_week": [2], "programId": "upper_lower_2day"},
            {"split": "upper_lower", "days_per_week": [3], "programId": "upper_lower_rotating_3day"},
            {"split": "upper_lower", "days_per_week": [4, 5, 6], "programId": "upper_lower_4day"},
            {"split": "chestback_legs_armsshoulders", "days_per_week": [2, 3, 4, 5, 6],
             "programId": "chest_back_legs_arms_3day"},
            {"split": "full_body", "days_per_week": [2, 3, 4, 5, 6], "programId": "upper_lower_rotating_3day",
             "note": "No full-body template ships; the user asked for a split. Suggest Upper/Lower."},
            {"split": "custom", "days_per_week": [2, 3, 4, 5, 6], "programId": None,
             "note": "Opens the custom program editor, pre-filled from ppl_3day Phase 1."},
        ],
    }
    out["gym"] = {
        "name": "University of Ghana campus gym (Legon)",
        "equipment": ["cable", "lat_pulldown_machine", "shoulder_press_machine", "chest_press_machine", "bike",
                      "treadmill", "barbell", "dumbbell", "leg_press", "plates", "calf_raise_machine",
                      "leg_curl_machine", "leg_extension_machine", "smith_machine", "bench", "bodyweight"],
        "equipmentLabels": {
            "cable": "Cable machine", "lat_pulldown_machine": "Lat pulldown machine",
            "shoulder_press_machine": "Shoulder press machine", "chest_press_machine": "Chest press machine",
            "bike": "Exercise bike", "treadmill": "Treadmill", "barbell": "Barbells", "dumbbell": "Dumbbells",
            "leg_press": "Leg press", "plates": "Weight plates", "calf_raise_machine": "Calf raise machine ('ankle machine')",
            "leg_curl_machine": "Leg curl machine", "leg_extension_machine": "Leg extension machine",
            "smith_machine": "Smith machine", "bench": "Adjustable benches", "bodyweight": "Floor space / bodyweight",
            "ankle_strap": "Ankle strap for the cable (not confirmed)",
        },
        "optionalEquipment": ["ankle_strap"],
        "equipmentNotes": {
            "calf_raise_machine": "Listed as 'Ankle machine' in equipments.txt; the user confirmed it is a calf raise machine.",
            "ankle_strap": "Not on the gym list. Tick it only if the gym has an ankle cuff for the cable machine.",
            "smith_machine": "Bar weight unknown (often 7-20 kg, some are counterbalanced). Ask on the first visit.",
            "leg_press": "Empty sled weight unknown. By default only added plates are logged.",
            "leg_curl_machine": "Seated or lying version unknown; Settings lets the user pick.",
        },
        "platesKg": [25, 20, 15, 10, 5, 2.5, 1.25],
        "barKg": 20,
        "smithBarKg": 10,
        "smithBarKnown": False,
        "legPressSledKg": 0,
        "legPressSledKnown": False,
        "legCurlType": "seated",
        "dumbbellStepKg": 2,
        "dumbbellMaxKg": 40,
    }
    out["defaults"] = {"restCompoundSec": 120, "restIsolationSec": 75, "warmupSetRestSec": 45,
                       "hotDayExtraRestSec": 30, "hydrationNudgeEveryMin": 15}
    out["onboarding"] = p["onboarding"]
    # Onboarding [limitations] -> what the session builder and swap suggester avoid (SPEC 6.8 step 3).
    # The replacement is the first available, unlocked, non-avoided substitution of the slot.
    out["limitation_rules"] = {
        "knee": {"avoid_ids": ["supported_split_squat", "dumbbell_step_up"], "avoid_patterns": ["lunge"],
                 "cue": "Knees: on the leg press put your feet a bit higher, lower only as deep as feels fine. "
                        "Leg extension: lighter weight, slow. Stop any exercise that hurts more than 3/10."},
        "lower_back": {"avoid_ids": ["barbell_romanian_deadlift", "barbell_bent_over_row",
                                     "smith_machine_bent_over_row", "bodyweight_good_morning",
                                     "prone_superman_back_extension"],
                       "avoid_patterns": [], "lock_unlocks": ["barbell_floor_lifts"],
                       "cue": "Lower back: rows stay chest-supported or seated; keep the dumbbell RDL light "
                              "with a flat back and stop at mid-shin."},
        "shoulder": {"avoid_ids": ["barbell_bench_press", "dumbbell_fly", "incline_dumbbell_fly",
                                   "smith_machine_shoulder_press", "seated_dumbbell_shoulder_press",
                                   "lat_pulldown_wide"],
                     "avoid_patterns": [],
                     "cue": "Shoulders: machine presses with elbows slightly in front of the body; "
                            "pull-downs with the close neutral grip."},
        "wrist_elbow": {"avoid_ids": ["barbell_curl", "smith_machine_close_grip_bench_press", "triceps_bar_pushdown"],
                        "avoid_patterns": [],
                        "cue": "Wrists/elbows: neutral grips (hammer curl, rope pushdown); wrists straight."},
        "hip": {"avoid_ids": ["supported_split_squat"], "avoid_patterns": [],
                "cue": "Hips: squat only as deep as is comfortable; widen the stance a little."},
        "ankle": {"avoid_ids": ["dumbbell_standing_calf_raise", "dumbbell_step_up"], "avoid_patterns": [],
                  "cue": "Ankles: seated or leg-press calf work only; no single-leg balance work."},
        "other": {"avoid_ids": [], "avoid_patterns": [],
                  "cue": "Use the 'It hurts' button on any exercise that causes pain; the app will offer a swap."},
    }
    for k in ("formulas", "worked_example", "protein_points", "daily_checklist", "good_day_rule", "portion_guide",
              "meal_ideas", "low_protein_foods_pair_with_protein", "pantry_protein_boosters", "progress_tracking",
              "expectations_timeline", "adherence", "safety", "milestones", "milestone_notes", "tips",
              "tips_rotation", "references"):
        out[k] = copy.deepcopy(p[k])

    # Role of each meal component, used to scale portions to the user's targets in the app
    # (protein -> protein target, carb -> calories left, fat -> never bigger, veg/fixed -> unchanged,
    # mixed -> halfway between protein and carb scaling).
    meal_roles = {
        "oats_milk_eggs": ["carb", "protein", "protein", "carb"],
        "hausa_koko_upgrade": ["carb", "protein", "fat", "protein"],
        "egg_bread": ["protein", "carb"],
        "sardine_bread": ["protein", "carb", "veg"],
        "tuna_gari_foto": ["protein", "carb", "veg"],
        "red_red_upgrade": ["mixed", "protein", "carb"],
        "waakye_smart": ["carb", "protein", "protein", "veg", "fat"],
        "kenkey_fish": ["carb", "protein", "veg"],
        "banku_tilapia": ["protein", "carb", "veg"],
        "light_soup_fish": ["fixed", "protein", "carb"],
        "groundnut_soup_smart": ["fat", "protein", "carb"],
        "kontomire_ampesi": ["protein", "fat", "carb"],
        "garden_egg_yam": ["protein", "carb"],
        "jollof_chicken": ["carb", "protein", "veg"],
        "okro_banku": ["protein", "carb"],
        "khebab": ["protein"],
        "wagashi_stew": ["protein", "carb"],
        "soya_chunks_stew": ["protein", "carb"],
        "yoghurt_groundnuts": ["protein", "fat"],
        "boiled_eggs": ["protein"],
        "milk_drink": ["protein"],
        "indomie_eggs": ["carb", "protein", "veg"],
        "whey_shake": ["protein"],
    }
    for m in out["meal_ideas"]:
        roles = meal_roles.get(m["id"])
        if roles is None or len(roles) != len(m["components"]):
            raise SystemExit(f"meal_roles missing or wrong length for {m['id']}")
        m["component_roles"] = roles

    # map milestone exercise names to real exercise ids
    for m in out["milestones"]:
        r = m["rule"]
        if "exercise" in r:
            name = r.pop("exercise")
            r["exercise_any"] = MILESTONE_EXERCISES[name]
        if "exercise_any" in r:
            mapped = []
            for x in r["exercise_any"]:
                x = {"smith_bench_press": "smith_machine_bench_press"}.get(x, x)
                if x in exercise_ids and x not in mapped:
                    mapped.append(x)
            r["exercise_any"] = mapped
    anchors = out["progress_tracking"]["strength_anchor_lifts"]
    out["progress_tracking"]["strength_anchor_lifts"] = [
        {"key": a, "exercise_any": ANCHORS[a]} for a in anchors]
    return out


def write(name, data):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1, ensure_ascii=False)
        f.write("\n")
    print(f"wrote {os.path.relpath(path, ROOT)} ({os.path.getsize(path) // 1024} KB)")


def main():
    exercises = build_exercises()
    programs = build_programs(exercises)
    pers = build_personalization({e["id"] for e in exercises})
    write("exercises.json", exercises)
    write("programs.json", programs)
    write("personalization.json", pers)


if __name__ == "__main__":
    main()
