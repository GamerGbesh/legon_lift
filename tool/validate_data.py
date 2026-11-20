#!/usr/bin/env python3
"""Validate the bundled data files of Legon Lift.

  python3 -I tool/validate_data.py [--require-images]

Checks
  * assets/data/{exercises,programs,personalization}.json parse
  * exercise ids unique snake_case, exact field list, enum values, vocabularies
  * substitutions resolve (no self links, no dangling ids)
  * every exerciseId / substitution referenced by any program exists
  * program structure: phases cover weeks 1..totalWeeks, dayOrder matches days,
    item shapes (repRange XOR durationSeconds), roles, superset groups
  * every exercise used by a program (not substitutes) only needs default gym equipment (ALL of it,
    bike/treadmill = either) and has pictures or a video
  * time budget: core <= 55 min and core + finisher <= 60 min per day
  * limitation_rules cover every onboarding limitation and leave a replacement for every working slot
  * personalization: milestone / anchor exercise ids exist, program selection ids exist
  * localImages exist on disk (if assets/exercises/ exists, or always with --require-images)
    and total image size stays under 15 MB
Exit code 0 = all good, 1 = errors (printed).
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "assets", "data")
IMG_DIR = os.path.join(ROOT, "assets", "exercises")
IMG_BUDGET_BYTES = 15 * 1024 * 1024

EXERCISE_FIELDS = [
    "id", "name", "aliases", "category", "primaryMuscles", "secondaryMuscles", "equipment", "mechanic",
    "difficulty", "unilateral", "loadType", "weightIncrementKg", "startingWeightKg", "defaultSets", "repRange",
    "restSeconds", "durationSeconds", "setup", "cues", "mistakes", "breathing", "safety", "substitutions",
    "freeExerciseDbId", "images", "video", "sources",
    # added by tool/build_data.py
    "movementPattern", "tracking", "dumbbellCount", "localImages",
]
CATEGORIES = {"push", "pull", "legs", "core", "cardio", "warmup", "mobility"}
LOAD_TYPES = {"dumbbell", "cable", "time", "bodyweight", "stack", "smith", "barbell", "plate_loaded"}
MECHANICS = {"compound", "isolation"}
TRACKING = {"weight_reps", "reps", "time"}
PATTERNS = {
    "horizontal_push", "incline_push", "vertical_push", "chest_fly", "horizontal_pull", "vertical_pull",
    "straight_arm_pull", "rear_delt", "lateral_raise", "front_raise", "elbow_flexion", "elbow_extension", "shrug",
    "back_extension", "squat", "lunge", "hinge", "hip_thrust", "knee_extension", "knee_flexion", "calf_raise",
    "glute_isolation", "core", "cardio", "mobility", "stretch",
}
MUSCLES = {
    "chest", "front_delts", "side_delts", "rear_delts", "triceps", "biceps", "forearms", "lats", "upper_back",
    "traps", "lower_back", "abs", "obliques", "quads", "hamstrings", "glutes", "adductors", "abductors", "calves",
    "cardio",
}
EQUIPMENT = {
    "cable", "lat_pulldown_machine", "shoulder_press_machine", "chest_press_machine", "bike", "treadmill",
    "barbell", "dumbbell", "leg_press", "plates", "calf_raise_machine", "leg_curl_machine", "leg_extension_machine",
    "smith_machine", "bench", "bodyweight", "ankle_strap",
}
FORBIDDEN_EQUIPMENT = {"pull_up_bar", "kettlebell", "ez_bar", "band", "bands", "ankle_machine", "squat_rack"}
ROLES = {"primary", "secondary", "accessory", "core", "warmup", "cardio", "cooldown", "stretch"}
BLOCK_TYPES = {"warmup", "main", "superset", "finisher", "cooldown"}
ID_RE = re.compile(r"^[a-z][a-z0-9]*(_[a-z0-9]+)*$")

errors = []
warnings = []
LIMITATION_RULES = {}


def err(msg):
    errors.append(msg)


def load(name):
    path = os.path.join(DATA, name)
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception as exc:  # noqa: BLE001
        err(f"{name}: cannot parse ({exc})")
        return None


def check_exercises(exs, require_images):
    by_id = {}
    if not isinstance(exs, list):
        err("exercises.json must be a JSON array")
        return by_id
    for i, e in enumerate(exs):
        eid = e.get("id", f"#{i}")
        if list(e.keys()) != EXERCISE_FIELDS:
            missing = [k for k in EXERCISE_FIELDS if k not in e]
            extra = [k for k in e if k not in EXERCISE_FIELDS]
            err(f"{eid}: field list mismatch (missing {missing}, extra {extra}, or wrong order)")
            continue
        if not ID_RE.match(eid):
            err(f"{eid}: id is not snake_case")
        if eid in by_id:
            err(f"{eid}: duplicate id")
        by_id[eid] = e
        if e["category"] not in CATEGORIES:
            err(f"{eid}: bad category {e['category']}")
        if e["loadType"] not in LOAD_TYPES:
            err(f"{eid}: bad loadType {e['loadType']}")
        if e["mechanic"] not in MECHANICS:
            err(f"{eid}: bad mechanic")
        if e["tracking"] not in TRACKING:
            err(f"{eid}: bad tracking")
        if e["movementPattern"] not in PATTERNS:
            err(f"{eid}: bad movementPattern {e['movementPattern']}")
        if e["difficulty"] not in (1, 2, 3):
            err(f"{eid}: difficulty must be 1-3")
        for m in e["primaryMuscles"] + e["secondaryMuscles"]:
            if m not in MUSCLES:
                err(f"{eid}: unknown muscle {m}")
        if not e["primaryMuscles"]:
            err(f"{eid}: no primary muscle")
        for q in e["equipment"]:
            if q in FORBIDDEN_EQUIPMENT:
                err(f"{eid}: uses forbidden/unavailable equipment {q}")
            elif q not in EQUIPMENT:
                err(f"{eid}: unknown equipment {q}")
        if (e["repRange"] is None) == (e["durationSeconds"] is None):
            err(f"{eid}: exactly one of repRange / durationSeconds must be set")
        if e["repRange"] is not None:
            lo, hi = e["repRange"]
            if not (isinstance(lo, int) and isinstance(hi, int) and 0 < lo <= hi):
                err(f"{eid}: bad repRange {e['repRange']}")
        if e["loadType"] in ("time", "bodyweight") and e["startingWeightKg"] is not None:
            err(f"{eid}: {e['loadType']} exercise must have startingWeightKg null")
        if e["startingWeightKg"] is not None:
            sw = e["startingWeightKg"]
            if not (isinstance(sw, dict) and sw.get("low") is not None and sw["low"] <= sw["high"]):
                err(f"{eid}: bad startingWeightKg")
        if e["loadType"] == "dumbbell" and e["dumbbellCount"] not in (1, 2):
            err(f"{eid}: dumbbell exercise needs dumbbellCount 1 or 2")
        if e["loadType"] != "dumbbell" and e["dumbbellCount"] is not None:
            err(f"{eid}: dumbbellCount only for loadType dumbbell")
        expected_tracking = {"time": "time", "bodyweight": "reps"}.get(e["loadType"], "weight_reps")
        if e["tracking"] != expected_tracking:
            err(f"{eid}: tracking should be {expected_tracking}")
        for k in ("setup", "cues", "mistakes"):
            if not e[k] or not all(isinstance(s, str) and s.strip() for s in e[k]):
                err(f"{eid}: {k} must be a non-empty list of strings")
        v = e["video"]
        if v is not None and not (isinstance(v, dict) and str(v.get("url", "")).startswith("https://www.youtube.com/")):
            err(f"{eid}: bad video")
        if len(e["images"]) != len(e["localImages"]):
            err(f"{eid}: images/localImages length mismatch")
        for n, li in enumerate(e["localImages"]):
            if li != f"assets/exercises/{eid}_{n}.jpg":
                err(f"{eid}: localImages[{n}] should be assets/exercises/{eid}_{n}.jpg")
    for eid, e in by_id.items():
        for s in e["substitutions"]:
            if s == eid:
                err(f"{eid}: substitutes itself")
            elif s not in by_id:
                err(f"{eid}: substitution {s} does not exist")
        if len(set(e["substitutions"])) != len(e["substitutions"]):
            err(f"{eid}: duplicate substitutions")
        if e["category"] in ("push", "pull", "legs") and not e["substitutions"]:
            err(f"{eid}: strength exercise without substitutions")

    # images
    check_disk = require_images or os.path.isdir(IMG_DIR)
    total = 0
    if check_disk:
        for eid, e in by_id.items():
            for li in e["localImages"]:
                p = os.path.join(ROOT, li)
                if not os.path.isfile(p):
                    err(f"{eid}: missing image file {li}")
                    continue
                total += os.path.getsize(p)
                with open(p, "rb") as f:
                    if f.read(3) != b"\xff\xd8\xff":
                        err(f"{eid}: {li} is not a JPEG")
        if total > IMG_BUDGET_BYTES:
            err(f"exercise images total {total / 1e6:.1f} MB > 15 MB budget")
        known = {os.path.basename(li) for e in by_id.values() for li in e["localImages"]}
        for fn in sorted(os.listdir(IMG_DIR)):
            if fn not in known:
                warnings.append(f"orphan image assets/exercises/{fn}")
    else:
        warnings.append("assets/exercises/ not present: image files not checked (run tool/fetch_images.py)")
    no_img = [eid for eid, e in by_id.items() if not e["localImages"]]
    if no_img:
        warnings.append(f"{len(no_img)} exercises without pictures (video/text fallback): {', '.join(no_img)}")
    return by_id, total


def iter_items(program):
    for ph in program["phases"]:
        for d in ph["days"]:
            for b in d["blocks"]:
                for it in b["items"]:
                    yield ph, d, b, it


def check_programs(pj, by_id, gym_equipment):
    if not isinstance(pj, dict) or pj.get("schemaVersion") != 1:
        err("programs.json: must be an object with schemaVersion 1")
        return set()
    progs = pj.get("programs", [])
    pids = [p["programId"] for p in progs]
    if len(set(pids)) != len(pids):
        err("programs.json: duplicate programId")
    if pj.get("defaultProgramId") not in pids:
        err("programs.json: defaultProgramId not found")
    if sum(1 for p in progs if p.get("default")) != 1:
        err("programs.json: exactly one program must have default=true")
    for old, new in pj.get("idMigrations", {}).items():
        if new not in by_id:
            err(f"idMigrations: {old} -> {new} target missing")
    used = set()
    for p in progs:
        pid = p["programId"]
        weeks = sorted(w for ph in p["phases"] for w in ph["weeks"])
        if weeks != list(range(1, p["totalWeeks"] + 1)):
            err(f"{pid}: phases must cover weeks 1..{p['totalWeeks']} exactly once (got {weeks})")
        if not (1 <= p["cycleRestartWeek"] <= p["totalWeeks"]):
            err(f"{pid}: bad cycleRestartWeek")
        if len(p["dayOrder"]) != len(set(p["dayOrder"])):
            err(f"{pid}: duplicate day in dayOrder")
        for ph in p["phases"]:
            day_ids = [d["dayId"] for d in ph["days"]]
            if day_ids != p["dayOrder"]:
                err(f"{pid}/{ph['phaseId']}: days {day_ids} != dayOrder {p['dayOrder']}")
            for k in ph["rirWeekOffsets"]:
                if int(k) not in ph["weeks"]:
                    err(f"{pid}/{ph['phaseId']}: rirWeekOffsets week {k} not in phase")
            if not (0.5 <= ph["loadMultiplier"] <= 1.0):
                err(f"{pid}/{ph['phaseId']}: loadMultiplier out of range")
            for d in ph["days"]:
                em = d["estimatedMinutes"]
                if em["core"] > 60:
                    err(f"{pid}/{ph['phaseId']}/{d['dayId']}: core estimate {em['core']} min > 60")
                # 60-min default user: core must leave room for hot-day rest (+30 s per set), finisher must fit
                if em["core"] > 55:
                    err(f"{pid}/{ph['phaseId']}/{d['dayId']}: core estimate {em['core']} min > 55 (no hot-day margin)")
                if em["withFinisher"] > 60:
                    err(f"{pid}/{ph['phaseId']}/{d['dayId']}: core + finisher {em['withFinisher']} min > 60")
                for b in d["blocks"]:
                    if b["blockType"] not in BLOCK_TYPES:
                        err(f"{pid}/{d['dayId']}: bad blockType {b['blockType']}")
                    if b["blockType"] == "superset" and (not b["supersetGroup"] or len(b["items"]) < 2):
                        err(f"{pid}/{d['dayId']}: superset block needs a group and >= 2 items")
                    if not b["items"]:
                        err(f"{pid}/{d['dayId']}: empty block {b['name']}")
        for ph, d, b, it in iter_items(p):
            where = f"{pid}/{ph['phaseId']}/{d['dayId']}"
            xid = it["exerciseId"]
            used.add(xid)
            if xid not in by_id:
                err(f"{where}: exerciseId {xid} does not exist")
                continue
            ex = by_id[xid]
            for s in it["substitutions"]:
                if s not in by_id:
                    err(f"{where}: {xid} substitution {s} does not exist")
                elif s == xid:
                    err(f"{where}: {xid} substitutes itself")
            if (it["repRange"] is None) == (it["durationSeconds"] is None):
                err(f"{where}: {xid} needs exactly one of repRange / durationSeconds")
            if ex["tracking"] == "time" and it["durationSeconds"] is None:
                err(f"{where}: {xid} is a timed exercise but item has no durationSeconds")
            if it["role"] not in ROLES:
                err(f"{where}: {xid} bad role {it['role']}")
            if it["rir"] is not None and not (0 <= it["rir"] <= 4):
                err(f"{where}: {xid} rir out of range")
            if it["warmupSets"] not in ("auto", 0, 1):
                err(f"{where}: {xid} warmupSets must be 'auto', 0 or 1")
            if it["sets"] < 1:
                err(f"{where}: {xid} sets < 1")
            missing = [q for q in ex["equipment"] if q not in gym_equipment]
            # ALL listed equipment is required, except bike + treadmill on one entry means either (SPEC 2.1)
            if {"bike", "treadmill"} <= set(ex["equipment"]) and ({"bike", "treadmill"} & gym_equipment):
                missing = [q for q in missing if q not in ("bike", "treadmill")]
            if "ankle_strap" in missing:
                err(f"{where}: {xid} needs an unconfirmed ankle strap")
            elif missing:
                err(f"{where}: {xid} needs equipment not at the gym: {missing}")
            if not ex["localImages"] and not ex["video"]:
                err(f"{where}: {xid} has neither pictures nor a video")
            if xid == "barbell_bench_press":
                err(f"{where}: barbell_bench_press needs uprights, never a program default")
            # every limitation must leave a usable replacement for a non-optional working slot
            if it["role"] in ("primary", "secondary", "accessory") and not it["optional"]:
                for k, r in LIMITATION_RULES.items():
                    def ok(xx):
                        e2 = by_id.get(xx)
                        return e2 is not None and xx not in r["avoid_ids"] and \
                            e2["movementPattern"] not in r["avoid_patterns"] and \
                            all(q in gym_equipment or q in ("bike", "treadmill") for q in e2["equipment"]) and \
                            xx != "barbell_bench_press"
                    if not ok(xid) and not any(ok(x2) for x2 in it["substitutions"] + ex["substitutions"]):
                        err(f"{where}: {xid} has no replacement for limitation {k}")
    return used


def check_personalization(pz, by_id, pids):
    if not isinstance(pz, dict) or pz.get("schemaVersion") != 1:
        err("personalization.json: must be an object with schemaVersion 1")
        return set()
    for k in ("defaultProfile", "programSelection", "gym", "defaults", "onboarding", "formulas", "meal_ideas",
              "milestones", "safety", "tips"):
        if k not in pz:
            err(f"personalization.json: missing {k}")
    if pz["defaultProfile"]["programId"] not in pids:
        err("personalization.defaultProfile.programId does not exist")
    for row in pz["programSelection"]["table"]:
        if row["programId"] is not None and row["programId"] not in pids:
            err(f"programSelection: {row['programId']} does not exist")
    ms_ids = [m["id"] for m in pz["milestones"]]
    if len(set(ms_ids)) != len(ms_ids):
        err("milestones: duplicate id")
    for m in pz["milestones"]:
        r = m["rule"]
        if "exercise" in r:
            err(f"milestone {m['id']}: uses free-text 'exercise' instead of exercise_any ids")
        for x in r.get("exercise_any", []):
            if x not in by_id:
                err(f"milestone {m['id']}: exercise {x} does not exist")
        if "exercise_any" in r and not r["exercise_any"]:
            err(f"milestone {m['id']}: empty exercise_any")
    for a in pz["progress_tracking"]["strength_anchor_lifts"]:
        for x in a["exercise_any"]:
            if x not in by_id:
                err(f"anchor {a['key']}: exercise {x} does not exist")
    meal_ids = [m["id"] for m in pz["meal_ideas"]]
    if len(set(meal_ids)) != len(meal_ids):
        err("meal_ideas: duplicate id")
    q = pz["safety"]["parq"]["questions"]
    if len(q) < 7:
        err("safety.parq: expected at least 7 questions")
    gym = set(pz["gym"]["equipment"])
    for qq in gym:
        if qq not in EQUIPMENT:
            err(f"gym.equipment: unknown {qq}")
    lim_opts = set(next(f for f in pz["onboarding"]["fields"] if f["id"] == "limitations")["options"])
    rules = pz.get("limitation_rules", {})
    for k in lim_opts - set(rules):
        err(f"limitation_rules: no rule for onboarding option {k}")
    for k, r in rules.items():
        for x in r["avoid_ids"]:
            if x not in by_id:
                err(f"limitation_rules.{k}: exercise {x} does not exist")
        for pat in r["avoid_patterns"]:
            if pat not in PATTERNS:
                err(f"limitation_rules.{k}: unknown pattern {pat}")
    return gym


def main():
    require_images = "--require-images" in sys.argv
    exs = load("exercises.json")
    pj = load("programs.json")
    pz = load("personalization.json")
    if errors:
        report(0, 0, 0)
        return
    by_id, img_bytes = check_exercises(exs, require_images)
    pids = {p["programId"] for p in pj.get("programs", [])} if isinstance(pj, dict) else set()
    gym = check_personalization(pz, by_id, pids)
    LIMITATION_RULES.update(pz.get("limitation_rules", {}) if isinstance(pz, dict) else {})
    used = check_programs(pj, by_id, gym)
    report(len(by_id), len(used), img_bytes)


def report(n_ex, n_used, img_bytes):
    for w in warnings:
        print("WARN ", w)
    for e in errors:
        print("ERROR", e)
    print(f"{n_ex} exercises, {n_used} used directly by programs, images {img_bytes / 1e6:.2f} MB, "
          f"{len(errors)} errors, {len(warnings)} warnings")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
