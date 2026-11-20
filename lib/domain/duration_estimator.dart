// Owner: WS2. Session duration model (SPEC 6.10). Keep identical to `est_block_seconds` /
// `estimate` in tool/build_data.py: for every shipped day, the rounded estimates equal the
// `estimatedMinutes` stored in programs.json (checked by test/domain/duration_estimator_test.dart).
import 'dart:math' as math;

import '../data/models/models.dart';

/// Seconds of work per set (SPEC 6 constants).
const int workSeconds = 40;

/// Seconds of work per set when reps are done per side.
const int perSideWorkSeconds = 70;

/// Moving to the next exercise and setting up.
const int transitionSeconds = 90;

/// One warm-up set including its short rest.
const int warmupSetSeconds = 75;

/// Extra rest per working set on a hot day.
const int hotExtraRestSeconds = 30;

/// Ramp sets assumed for a "find your weight" exercise (the ramp allows up to 4).
const int plannedRampSets = 3;

/// Cool-down block (walk + stretches).
const int cooldownBlockSeconds = 240;

/// Superset: seconds between the members of a round.
const int supersetChangeSeconds = 20;

/// Round rest used when a superset block has none.
const int defaultRoundRestSeconds = 60;

/// Cardio items that count as the warm-up's timed part (same list as build_data.py).
const Set<String> cardioWarmupIds = {
  'general_warmup_cardio',
  'bike_steady_state',
  'treadmill_brisk_walk',
  'treadmill_incline_walk',
};

/// Whether [item] is the timed cardio part of a warm-up block.
bool isWarmupCardio(ProgramItem item) =>
    item.role == ItemRole.warmup &&
    (item.durationSeconds ?? 0) > 0 &&
    item.repRange == null &&
    cardioWarmupIds.contains(item.exerciseId);

/// Estimated duration of [day] in seconds (SPEC 6.10).
///
/// - [includeOptional]: optional main/superset items and optional blocks (other than the
///   finisher) are counted;
/// - [includeFinisher]: the finisher block is counted;
/// - [hotDay]: +30 s per working set of main and superset items;
/// - [findWeightIds]: exercises that "find their weight" this session: their sets become
///   `max(1, sets - 1)`, they have no warm-up sets, and 3 ramp sets of `work + 75` s are added.
///
/// The session builder passes days whose items are already resolved and trimmed.
int estimateSeconds(ProgramDay day,
    {bool includeOptional = false,
    bool includeFinisher = false,
    bool hotDay = false,
    Set<String> findWeightIds = const {}}) {
  var total = 0;
  for (final b in day.blocks) {
    if (b.blockType == BlockType.finisher) {
      if (includeFinisher) total += _blockSeconds(b, b.items, hotDay, findWeightIds);
      continue;
    }
    final optionalBlock =
        b.optional || (_isWorkBlock(b) && b.items.isNotEmpty && b.items.every((i) => i.optional));
    if (optionalBlock) {
      if (includeOptional) total += _blockSeconds(b, b.items, hotDay, findWeightIds);
      continue;
    }
    if (b.blockType == BlockType.main) {
      final items = [for (final i in b.items) if (!i.optional || includeOptional) i];
      total += _blockSeconds(b, items, hotDay, findWeightIds);
    } else {
      total += _blockSeconds(b, b.items, hotDay, findWeightIds);
    }
  }
  return total;
}

bool _isWorkBlock(ProgramBlock b) => b.blockType == BlockType.main || b.blockType == BlockType.superset;

int _blockSeconds(ProgramBlock b, List<ProgramItem> items, bool hotDay, Set<String> findWeightIds) {
  if (items.isEmpty) return 0;
  switch (b.blockType) {
    case BlockType.warmup:
      final cardio = items.where(isWarmupCardio).fold<int>(0, (a, i) => a + (i.durationSeconds ?? 0));
      final hasDrills = items.any((i) => !isWarmupCardio(i));
      // Drills: 120 s, or 180 s for the "~8 min" leg warm-up.
      return cardio + (hasDrills ? (b.name.contains('8 min') ? 180 : 120) : 0);
    case BlockType.cooldown:
      return cooldownBlockSeconds;
    case BlockType.finisher:
      return items.fold<int>(0, (a, i) => a + (i.durationSeconds ?? 0));
    case BlockType.superset:
      final rr = (b.restBetweenRoundsSeconds ?? 0) == 0 ? defaultRoundRestSeconds : b.restBetweenRoundsSeconds!;
      var rounds = 0;
      var ramp = 0;
      var workingSets = 0;
      for (final i in items) {
        final finding = findWeightIds.contains(i.exerciseId);
        final sets = finding ? math.max(1, i.sets - 1) : i.sets;
        rounds = math.max(rounds, sets);
        workingSets += sets;
        if (finding) ramp += plannedRampSets * (_work(i) + warmupSetSeconds);
      }
      return rounds * (workSeconds * items.length + supersetChangeSeconds + rr) -
          rr +
          transitionSeconds +
          ramp +
          (hotDay ? hotExtraRestSeconds * workingSets : 0);
    case BlockType.main:
      var total = 0;
      for (final i in items) {
        final finding = findWeightIds.contains(i.exerciseId);
        final sets = finding ? math.max(1, i.sets - 1) : i.sets;
        final work = _work(i);
        total += sets * (work + i.restSeconds) - i.restSeconds + transitionSeconds;
        total += finding ? plannedRampSets * (work + warmupSetSeconds) : i.warmupSetCount * warmupSetSeconds;
        if (hotDay) total += hotExtraRestSeconds * sets;
      }
      return total;
  }
}

int _work(ProgramItem i) => i.perSide ? perSideWorkSeconds : workSeconds;

/// Seconds rounded to whole minutes, the way the app shows them.
int secondsToMinutes(int seconds) => (seconds / 60).round();
