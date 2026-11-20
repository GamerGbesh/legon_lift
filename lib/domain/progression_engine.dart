// Owner: WS2. In-session suggestions (SPEC 6.4), double progression after a session (SPEC 6.5)
// and today's prescription for one item (SPEC 6.5 `prescribe`, 6.6 retest).
import 'dart:math' as math;

import '../core/format.dart';
import '../data/models/models.dart';
import 'api.dart';

/// Default rep range for a loaded item that has none (never the case in the shipped data).
const (int, int) fallbackRepRange = (8, 12);

/// Retest back-off set (SPEC 6.6): 80% x 8 with 3 left in the tank.
const double retestBackoffFactor = 0.8;
const int retestBackoffReps = 8;
const int retestBackoffRir = 3;

/// Long-break find-weight seed (SPEC 6.8): 80% of the old working weight.
const double longBreakSeedFactor = 0.8;

// Plain-language reasons shown in "Next time" and on the exercise card.
const String reasonFirstTime = "First time: we'll find your weight";
const String reasonQuickStart = 'First time: start light, we adjust after every set';
const String reasonLongBreak = "Long break: we'll find your weight again";
const String reasonUnfinished = 'Unfinished last time: same target';
const String reasonTooHeavy = 'Too heavy last time';
const String reasonPain = 'Lighter after the pain flag';
const String reasonStallReset = '3 sessions without progress: -10% to build back up';
const String reasonOneMoreRep = 'Same weight, aim for one more rep';
const String reasonDeload = 'Easy week: lighter, with plenty left in the tank';
const String reasonBreak = 'Lighter today after your break';
const String reasonNewRange = 'New rep range: weight adjusted to match';
const String reasonRetest = 'Re-test: as many good reps as you can, stop with about 1 left';

/// The in-session message for an automatic weight drop (SPEC 6.4 rules 2 and 3).
const String hintTooHeavy = 'Lighter for the next set: that was too heavy.';

// ---------------------------------------------------------------------------------------------
// 6.4 In-session autoregulation
// ---------------------------------------------------------------------------------------------

/// In-session suggestion after working set number [setNumber] (1-based) of a loaded exercise
/// (SPEC 6.4), or null for none. [targetRir] is the prescription's target.
///
/// - Rules 2 and 3 (too heavy) are [InSessionHint.automatic]: the player lowers the next sets'
///   target to [InSessionHint.suggestedKg] by itself.
/// - Rule 1 (too light) is a one-tap chip with the heavier [InSessionHint.suggestedKg]. It applies
///   after set 1, or after every set while the exercise is in quick start ([quickStart]: loaded
///   accessory or core item without history, SPEC 6.2).
/// - A pain flag (rule 4) never suggests a heavier load: the hint has no weight and tells the
///   player to offer swap / skip. A hint without [InSessionHint.suggestedKg] is message-only.
///
/// [state] enables the post-jump grace of rule 2 (first session after a jump of more than 10%);
/// [prefs] supplies the user's own increment.
InSessionHint? inSessionHint(SetLog last, int setNumber, ProgramItem item, int? targetRir, Exercise ex,
    EquipmentProfile eq,
    {bool quickStart = false, ExerciseState? state, ExercisePrefs? prefs}) {
  if (ex.tracking != Tracking.weightReps) return null;
  if (last.kind != SetKind.working && last.kind != SetKind.calibration) return null;
  if (last.painFlag) {
    return const InSessionHint(message: 'It hurts? Swap or skip this exercise. Never push through pain.');
  }
  final (lo, hi) = item.repRange ?? ex.repRange ?? fallbackRepRange;
  final load = last.weightKg;
  final reps = last.reps;
  final inc = increment(ex, item, prefs);

  // Rules 2 and 3: too heavy, lighter next set (automatic).
  final grace = _inGrace(state);
  final drops = <double>[
    if (reps < lo - (grace ? 4 : 2)) roundDown(load - inc, ex, eq, prefs),
    if (last.rir == 0 && reps < lo) roundDown(load * 0.9, ex, eq, prefs),
  ];
  if (drops.isNotEmpty) {
    final lighter = drops.reduce(math.min);
    if (lighter < load - loadEpsilon) {
      return InSessionHint(message: hintTooHeavy, suggestedKg: lighter, automatic: true);
    }
    return const InSessionHint(
        message: 'That was too heavy, and this is the lightest setting: do the reps you can with good form.');
  }

  // Rule 1: far too light, suggest one step up (one tap).
  final t = targetRir;
  final rirOk = t == null || (last.rir ?? t) >= t;
  if ((setNumber == 1 || quickStart) && reps >= hi + 3 && rirOk) {
    var heavier = roundToAvailable(load + inc, ex, eq, prefs);
    if (heavier <= load + loadEpsilon) heavier = nextUp(load, ex, eq, prefs);
    if (heavier <= load + loadEpsilon) return null; // already the heaviest load
    final each = ex.loadType == LoadType.dumbbell && (ex.dumbbellCount ?? 1) > 1 ? ' (each dumbbell)' : '';
    return InSessionHint(message: 'Add ${Fmt.number(heavier - load)} kg$each for the next set', suggestedKg: heavier);
  }
  return null;
}

// ---------------------------------------------------------------------------------------------
// 6.5 Double progression after a session
// ---------------------------------------------------------------------------------------------

/// Double progression after a session (SPEC 6.5): the exercise's state for next time.
///
/// [working] are this session's working sets of the exercise in order (sets of kind `working`
/// and `calibration` are used; `test` sets only feed the estimated best single; warm-up and
/// ramp sets are ignored). [lastExposure] are the sets of the previous session of this exercise.
/// [targetRir] is the session's target (null = no reps-in-reserve check).
///
/// [plannedSets] is the number of working sets planned in this session after add/remove set.
/// When null it is `item.sets`, or `max(1, item.sets - 1)` for a first-time primary/secondary
/// lift (the "find your weight" session). Pass it explicitly for a find-weight forced by a long
/// break. Fewer logged sets than planned gives "no verdict" (skipped sets or ended early).
///
/// [recordOnly]: deload and retest sessions leave the state unchanged except the estimated best
/// single (also implied by a retest item).
///
/// A pain flag lowers the weight; the caller also stamps `ExercisePrefs.lastPainAt = now`
/// (the state cannot carry it). Estimated bests (`firstE1rm`, `bestE1rm`) use the total load
/// of SPEC 0.4, like the PR records.
ExerciseState afterSession(ExerciseState? state, Exercise ex, ProgramItem item, int? targetRir, List<SetLog> working,
    List<SetLog> lastExposure, EquipmentProfile eq, ExercisePrefs? prefs, DateTime now,
    {int? plannedSets, bool recordOnly = false}) {
  final base = state ?? ExerciseState(exerciseId: ex.id, updatedAt: now);
  if (ex.tracking != Tracking.weightReps) return base;

  final sets = [for (final s in working) if (s.kind == SetKind.working || s.kind == SetKind.calibration) s];
  final measured = [for (final s in working) if (s.countsAsWork) s];
  ExerciseState withBests(ExerciseState s) => _withE1rm(s, measured, ex, eq);

  if (recordOnly || item.isRetest || sets.isEmpty) {
    return withBests(base).copyWith(updatedAt: now);
  }

  final (lo, top) = item.repRange ?? ex.repRange ?? fallbackRepRange;
  final n = math.max(1, item.sets);
  final load = modeWeight(sets);
  final sessionId = sets.last.sessionId;
  final firstTime = base.workingKg == null;
  final planned = plannedSets ??
      (firstTime && (item.role == ItemRole.primary || item.role == ItemRole.secondary)
          ? math.max(1, item.sets - 1)
          : item.sets);

  final anyPain = sets.any((s) => s.painFlag);
  double painCap(double w) => math.min(w, roundDown(load * 0.9, ex, eq, prefs));

  // No verdict: skipped sets or ended early.
  if (sets.length < planned) {
    var next = base.copyWith(
      lastTrend: Trend.same,
      lastReason: reasonUnfinished,
      lastSessionId: () => sessionId,
      lastJumpPct: () => null,
      updatedAt: now,
    );
    if (firstTime) {
      // The weight he found (or started at) still becomes the working weight.
      next = next.copyWith(workingKg: () => load, repTargets: const [], lastRepRange: () => (lo, top));
    }
    if (anyPain) {
      next = next.copyWith(
        workingKg: () => painCap(next.workingKg ?? load),
        lastTrend: Trend.down,
        lastReason: reasonPain,
      );
    }
    return withBests(next);
  }

  final inc = increment(ex, item, prefs);
  final effTop = effectiveTopReps(top, load, ex, eq, prefs);
  final t = targetRir;
  final rirOk = t == null || sets.every((s) => s.rir == null || s.rir! >= t - 1);

  double workingKg;
  List<int> repTargets;
  var stall = base.stallCount;
  var resets = base.resetCount;
  Trend trend;
  String reason;

  if (sets.every((s) => s.reps >= effTop) && rirOk) {
    final bonus = sets.every((s) => s.reps >= effTop + 2 && (t == null || (s.rir ?? 0) >= t + 1));
    final up = nextUp(load, ex, eq, prefs);
    workingKg = bonus ? nextUp(up, ex, eq, prefs) : up;
    repTargets = List.filled(n, lo);
    stall = 0;
    trend = workingKg > load + loadEpsilon ? Trend.up : Trend.same;
    reason = trend == Trend.up
        ? 'You hit ${sets.map((s) => s.reps).join(', ')} last time: +${Fmt.number(workingKg - load)} kg'
        : 'Top of the range at the heaviest weight: keep it up';
  } else {
    final lastSets = [for (final s in lastExposure) if (s.kind == SetKind.working || s.kind == SetKind.calibration) s];
    final progressed = lastSets.isEmpty ||
        _sumReps(sets) > _sumReps(lastSets) ||
        load > modeWeight(lastSets) + loadEpsilon;
    if (progressed) {
      workingKg = load;
      repTargets = _padded([for (final s in sets) math.min(s.reps + 1, effTop)], n, lo);
      stall = 0;
      trend = Trend.same;
      final weakest = sets.map((s) => s.reps).reduce(math.min);
      reason = 'Same weight: beat $weakest reps on your weakest set';
    } else {
      stall = base.stallCount + 1;
      if (stall >= 3) {
        workingKg = roundDown(load * 0.90, ex, eq, prefs);
        repTargets = List.filled(n, lo);
        stall = 0;
        resets = base.resetCount + 1;
        trend = Trend.down;
        reason = reasonStallReset;
      } else {
        workingKg = load;
        repTargets = _padded([for (final s in sets) math.min(s.reps + 1, effTop)], n, lo);
        trend = Trend.same;
        reason = reasonOneMoreRep;
      }
    }
  }

  // Too heavy (with the post-jump grace).
  if (sets.first.reps < lo - (_inGrace(base) ? 4 : 2)) {
    workingKg = roundDown(load - inc, ex, eq, prefs);
    trend = Trend.down;
    reason = reasonTooHeavy;
  }
  final jumpPct = trend == Trend.up ? (workingKg - load) / math.max(load, 1) : null;
  if (anyPain) {
    workingKg = painCap(workingKg);
    trend = Trend.down;
    reason = reasonPain;
  }

  return withBests(base.copyWith(
    workingKg: () => workingKg,
    repTargets: repTargets,
    stallCount: stall,
    resetCount: resets,
    lastTrend: trend,
    lastReason: reason,
    lastSessionId: () => sessionId,
    lastRepRange: () => (lo, top),
    lastJumpPct: () => anyPain ? null : jumpPct,
    updatedAt: now,
  ));
}

/// The most common weight among [sets] (ties -> the heavier weight); 0 for no sets.
double modeWeight(List<SetLog> sets) {
  final counts = <int, int>{};
  for (final s in sets) {
    final key = (s.weightKg * 1000).round();
    counts[key] = (counts[key] ?? 0) + 1;
  }
  if (counts.isEmpty) return 0;
  var bestKey = counts.keys.first;
  for (final e in counts.entries) {
    final best = counts[bestKey]!;
    if (e.value > best || (e.value == best && e.key > bestKey)) bestKey = e.key;
  }
  return bestKey / 1000;
}

/// The top of the rep range, extended when the next load step is a big relative jump
/// (SPEC 6.5 small-load guard): +3 reps above a 20% jump, +2 above 10%.
int effectiveTopReps(int top, double load, Exercise ex, EquipmentProfile eq, ExercisePrefs? prefs) {
  final jump = (nextUp(load, ex, eq, prefs) - load) / math.max(load, 1);
  return top + (jump > 0.20 ? 3 : (jump > 0.10 ? 2 : 0));
}

/// First session after a jump of more than 10% (SPEC 6.5 `grace`).
bool _inGrace(ExerciseState? s) => s != null && s.lastTrend == Trend.up && (s.lastJumpPct ?? 0) > 0.10;

int _sumReps(List<SetLog> sets) => sets.fold(0, (a, s) => a + s.reps);

List<int> _padded(List<int> reps, int n, int lo) =>
    [for (var i = 0; i < n; i++) i < reps.length ? reps[i] : lo];

/// Updates `bestE1rm` / `firstE1rm` from the sets that count as work: Epley on the total load
/// for sets of 12 reps or fewer; a retest (`test`) set uses `w * (1 + (reps + 1) / 30)`.
ExerciseState _withE1rm(ExerciseState s, List<SetLog> sets, Exercise ex, EquipmentProfile eq) {
  double? best;
  for (final set in sets) {
    final total = totalLoadKg(set, ex, eq);
    final e = set.kind == SetKind.test
        ? retestE1rm(total, set.reps)
        : (set.reps <= maxRepsForE1rm ? epley1rm(total, set.reps) : 0.0);
    if (e > 0 && (best == null || e > best)) best = e;
  }
  if (best == null) return s;
  final value = best;
  return s.copyWith(
    bestE1rm: () => s.bestE1rm == null ? value : math.max(s.bestE1rm!, value),
    firstE1rm: () => s.firstE1rm ?? value,
  );
}

// ---------------------------------------------------------------------------------------------
// prescribe
// ---------------------------------------------------------------------------------------------

/// Today's prescription for one item (SPEC 6.5 `prescribe`, 6.6 retest).
///
/// - Timed items: `item.sets` sets of `durationSeconds`; bodyweight reps items: the top of the
///   rep range.
/// - Loaded items without a working weight: primary/secondary lifts "find their weight"
///   ([Prescription.findWeight], `max(1, sets - 1)` working sets at the seed, which the player
///   passes to `startFindWeight` as `lastKnownKg`); accessory/core lifts use quick start
///   (every set at the seed, trend `calibrate`, no ramp). [seedKg] is the SEED_TRANSFER value
///   from [transferSeed]. A long break (> 21 days) makes primaries find their weight again from
///   80% of the old working weight.
/// - Loaded items with a working weight: the working weight (re-derived from the estimated best
///   single when the rep range changed, e.g. a new phase), times the phase and break load
///   multipliers, rounded to an available load; reps from the state's rep targets.
/// - Retest items (`test == rir1_rep_test`): one `test` set at the working weight (as many good
///   reps as possible, about 1 left) and a back-off working set at 80% x 8.
///
/// Warm-up sets come from [planWarmups] (none in find-weight mode); the session builder drops
/// them when the user turned warm-up sets off. Rest gets +30 s on a hot day.
Prescription prescribe(Exercise ex, ProgramItem item, Phase phase, int week, ExerciseState? state, EquipmentProfile eq,
    ExercisePrefs? prefs, GapRule gap,
    {required bool isDeload, required bool hotDay, double? seedKg}) {
  final eff = effectiveRir(item, phase, week);
  int? t = eff == null ? null : math.min(maxRir, eff + gap.rirBonus);
  if (isDeload) t = maxRir;
  final rest = item.restSeconds + (hotDay ? hotExtraRestSeconds : 0);
  final inc = increment(ex, item, prefs);
  final sets = math.max(1, item.sets);

  Prescription rx(List<PlannedSet> working,
          {List<PlannedSet> warmups = const [],
          int? rir,
          Trend trend = Trend.same,
          String reason = '',
          bool findWeight = false}) =>
      Prescription(
        exerciseId: ex.id,
        warmups: warmups,
        working: working,
        restSec: rest,
        targetRir: rir,
        trend: trend,
        reason: reason,
        findWeight: findWeight,
        incrementKg: inc,
      );

  switch (ex.tracking) {
    case Tracking.time:
      final duration = item.durationSeconds ?? ex.durationSeconds ?? 30;
      return rx([
        for (var i = 0; i < sets; i++) PlannedSet(kind: SetKind.working, weightKg: 0, reps: 0, durationSec: duration),
      ]);
    case Tracking.reps:
      final reps = (item.repRange ?? ex.repRange ?? fallbackRepRange).$2;
      return rx([for (var i = 0; i < sets; i++) PlannedSet(kind: SetKind.working, weightKg: 0, reps: reps, targetRir: t)],
          rir: t);
    case Tracking.weightReps:
      break;
  }

  final (lo, hi) = item.repRange ?? ex.repRange ?? fallbackRepRange;
  List<PlannedSet> warmupsFor(double w) => [
        for (final s in planWarmups(w, ex, item, eq)) PlannedSet(kind: SetKind.warmup, weightKg: s.weightKg, reps: s.reps),
      ];
  final w0 = state?.workingKg;
  final forced = w0 != null && gap.forceFindWeight(item.role);

  // First exposure, or a long break on a primary lift.
  if (w0 == null || forced) {
    final ramp = forced || item.role == ItemRole.primary || item.role == ItemRole.secondary;
    final seed = forced
        ? roundDown(w0 * longBreakSeedFactor, ex, eq, prefs)
        : seedWeight(ex, eq, transferKg: seedKg, prefs: prefs);
    if (ramp) {
      final reps = math.min(lo + 2, hi);
      return rx(
        [
          for (var i = 0; i < math.max(1, sets - 1); i++)
            PlannedSet(kind: SetKind.working, weightKg: seed, reps: reps, targetRir: t),
        ],
        rir: t,
        trend: Trend.calibrate,
        reason: forced ? reasonLongBreak : reasonFirstTime,
        findWeight: true,
      );
    }
    return rx(
      [for (var i = 0; i < sets; i++) PlannedSet(kind: SetKind.working, weightKg: seed, reps: lo, targetRir: t)],
      warmups: warmupsFor(seed),
      rir: t,
      trend: Trend.calibrate,
      reason: reasonQuickStart,
    );
  }

  // Retest (SPEC 6.6): one all-out-but-1 set at the working weight, then a back-off set.
  if (item.isRetest) {
    final w = roundToAvailable(w0 * gap.loadMultiplier, ex, eq, prefs);
    return rx(
      [
        PlannedSet(kind: SetKind.test, weightKg: w, reps: hi, targetRir: t),
        PlannedSet(
          kind: SetKind.working,
          weightKg: roundDown(w * retestBackoffFactor, ex, eq, prefs),
          reps: retestBackoffReps,
          targetRir: retestBackoffRir,
        ),
      ],
      warmups: warmupsFor(w),
      rir: t,
      reason: reasonRetest,
    );
  }

  var w = w0;
  var newRange = false;
  final last = state!.lastRepRange;
  if (last != null && last != (lo, hi)) {
    // Phase transition: re-derive the load for the middle of the new range.
    final tt = t ?? 2;
    final e = state.bestE1rm ??
        totalLoadForWeight(w, ex, eq) * (1 + ((state.repTargets.isEmpty ? last.$1 : state.repTargets.first) + tt) / 30);
    final mid = (lo + hi) / 2;
    w = roundDown(weightForTotalLoad(e / (1 + (mid + tt) / 30), ex, eq), ex, eq, prefs);
    newRange = true;
  }
  w = roundToAvailable(w * phase.loadMultiplier * gap.loadMultiplier, ex, eq, prefs);
  final effTop = effectiveTopReps(hi, w, ex, eq, prefs);
  final targets = newRange ? const <int>[] : state.repTargets;
  final reps = [for (var i = 0; i < sets; i++) (i < targets.length ? targets[i] : lo).clamp(lo, effTop)];

  final Trend trend;
  final String reason;
  if (isDeload) {
    trend = Trend.deload;
    reason = reasonDeload;
  } else if (gap.loadMultiplier < 1) {
    trend = Trend.down;
    reason = reasonBreak;
  } else if (newRange) {
    trend = Trend.same;
    reason = reasonNewRange;
  } else {
    trend = state.lastTrend;
    reason = state.lastReason;
  }
  return rx(
    [for (final r in reps) PlannedSet(kind: SetKind.working, weightKg: w, reps: r, targetRir: t)],
    warmups: warmupsFor(w),
    rir: t,
    trend: trend,
    reason: reason,
  );
}
