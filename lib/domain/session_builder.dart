// Owner: WS2. Builds today's session plan (SPEC 6.8): picks the day and phase, resolves every
// exercise (program overrides, leg curl type, equipment, limitations, cardio machines off),
// fits the session into the user's time budget, and prescribes every exercise.
import 'dart:math' as math;

import '../data/models/models.dart';
import 'api.dart';

/// Warm-up cardio is never trimmed below this (SPEC 6.8 ladder step a).
const int minWarmupCardioSeconds = 180;

/// Hot-day finisher: 3 minutes shorter, never under 5 minutes (SPEC 6.8).
const int hotFinisherCutSeconds = 180;
const int minHotFinisherSeconds = 300;

/// The ladder never trims sets below this (SPEC 6.8 steps b and d).
const int minTrimmedSets = 2;

/// Reactive deload transform (SPEC 6.7).
const double reactiveDeloadLoadMultiplier = 0.9;

/// Training weeks with a calibration set (SPEC 6.6).
const Set<int> calibrationWeeks = {6, 10};

const String _lyingLegCurlId = 'lying_leg_curl';
const String _seatedLegCurlId = 'seated_leg_curl';

/// Notice copy (plain language, shown before the session).
const String week1Notice =
    "This week's sessions take ~5 min longer while we find your weights; the cardio finisher is skipped.";
const String cardioOffFinisherNotice = 'Walk 10 min later (not in the midday heat)';
const String reactiveDeloadNotice = 'Easy week: fewer sets, lighter weights, plenty left in the tank';

/// Builds today's session plan (SPEC 6.8).
///
/// The plan's steps run: warm-up cardio, warm-up drills, the main exercises and supersets,
/// "Extras if you have time", the cardio finisher, the cool-down. The time budget is
/// `profile.sessionMinutes`; the duration model is [estimateSeconds].
SessionPlan buildSession(BuildSessionInput input) => _SessionBuilder(input).build();

class _SessionBuilder {
  _SessionBuilder(this.input)
      : eq = input.settings.equipment,
        rules = input.limitationRules.isNotEmpty ? input.limitationRules : input.catalog.personalization.limitationRules,
        limitations = input.profile.limitations;

  final BuildSessionInput input;
  final EquipmentProfile eq;
  final Map<String, dynamic> rules;
  final List<String> limitations;

  late final ProgramTemplate template = input.template;
  late final int rawWeek = rawTrainingWeek(template, input.active, input.completedNonDeload);
  late final int week = wrapTrainingWeek(template, rawWeek);
  late final GapRule gap = gapRule(input.lastCompletedAt, input.now, recentIllness: input.recentIllness);
  late Phase phase = phaseFor(template, week);
  late Set<String> unlocks;
  late Set<String> lockedByLimitation;

  final List<String> equipmentNotices = [];
  final Set<String> usedWorkIds = {};

  SessionPlan build() {
    final scheduledDeload = phase.phaseId == PhaseId.deload;
    final reactive = !scheduledDeload && (input.active.reactiveDeloadRemaining > 0 || gap.treatAsDeload);
    final isDeload = scheduledDeload || reactive;
    final noTrim = isDeload || phase.phaseId == PhaseId.retest;

    var day = _pickDay();
    if (reactive) {
      day = _deloadTransform(day);
      phase = phase.copyWith(loadMultiplier: reactiveDeloadLoadMultiplier);
    }
    unlocks = effectiveUnlocks(phase, limitations, rules);
    lockedByLimitation = phase.unlocks.difference(unlocks);
    final overrides = {
      for (final o in input.overrides)
        if (o.dayId == day.dayId) o.slotKey: o,
    };

    // ---- Resolve every block ----------------------------------------------------------------
    for (final b in day.blocks) {
      if (b.blockType == BlockType.main || b.blockType == BlockType.superset) {
        for (final i in b.items) {
          usedWorkIds.add(overrides[i.slotKey()]?.exerciseId ?? i.exerciseId);
        }
      }
    }

    ProgramItem? cardio;
    var drills = <ProgramItem>[];
    var drillsTwice = false;
    final work = <_Block>[];
    ProgramItem? finisher;
    var finisherSeconds = 0;
    ProgramItem? cooldownWalk;
    final stretches = <ProgramItem>[];
    String? finisherBlockName;

    for (final b in day.blocks) {
      switch (b.blockType) {
        case BlockType.warmup:
          for (final item in b.items) {
            if (cardio == null && isWarmupCardio(item)) {
              final resolved = input.cardioOff ? null : _resolve(item, overrides, quiet: true);
              if (resolved == null) {
                drillsTwice = true; // no bike/treadmill: run the drills twice instead (est. +0 s)
              } else {
                cardio = resolved.$1;
              }
            } else if (input.settings.warmupBlock) {
              final resolved = _resolve(item, overrides);
              if (resolved != null) drills.add(resolved.$1);
            }
          }
          if (!input.settings.warmupBlock) drillsTwice = false;
        case BlockType.main || BlockType.superset:
          final slots = <_Slot>[];
          for (final item in b.items) {
            final o = overrides[item.slotKey()];
            if (o?.optionalEnabled == false && (item.optional || b.optional)) continue; // switched off
            final resolved = _resolve(item, overrides, work: true);
            if (resolved == null) continue;
            final (resolvedItem, ex) = resolved;
            final optional = (item.optional || b.optional) && o?.optionalEnabled != true;
            slots.add(_Slot(item, resolvedItem, ex, optional: optional));
          }
          if (slots.isNotEmpty) work.add(_Block(b, slots));
        case BlockType.finisher:
          final item = b.items.firstOrNull;
          if (item == null) break;
          if (overrides[item.slotKey()]?.optionalEnabled == false) break; // switched off
          if (input.cardioOff) {
            equipmentNotices.add(cardioOffFinisherNotice);
            break;
          }
          final resolved = _resolve(item, overrides);
          if (resolved == null) break;
          finisher = resolved.$1;
          finisherBlockName = b.name;
          final d = finisher.durationSeconds ?? resolved.$2.durationSeconds ?? 0;
          finisherSeconds = input.hotDay ? math.max(minHotFinisherSeconds, d - hotFinisherCutSeconds) : d;
          if (finisherSeconds <= 0) finisher = null;
        case BlockType.cooldown:
          for (final item in b.items) {
            if (overrides[item.slotKey()]?.optionalEnabled == false && (item.optional || b.optional)) continue;
            if (item.role == ItemRole.stretch) {
              if (!input.settings.cooldownBlock) continue;
              final resolved = _resolve(item, overrides);
              if (resolved != null) stretches.add(resolved.$1);
            } else {
              if (input.cardioOff && cooldownWalk == null && _isCardioItem(item)) continue;
              final resolved = _resolve(item, overrides, quiet: true);
              if (resolved == null) continue;
              if (cooldownWalk == null && _isCardioItem(item)) {
                cooldownWalk = resolved.$1;
              } else {
                stretches.add(resolved.$1);
              }
            }
          }
      }
    }
    if (!input.settings.warmupBlock) drills = const [];

    // ---- Prescriptions (find-weight flags drive the time estimate) ----------------------------
    for (final block in work) {
      for (final s in block.slots) {
        s.rx = _prescribe(s.ex, s.item, isDeload);
      }
    }
    Set<String> findWeightIds() => {
          for (final block in work)
            for (final s in block.slots)
              if (s.included && s.rx.findWeight) s.ex.id,
        };

    // ---- Time budget (SPEC 6.8) ---------------------------------------------------------------
    final budget = input.profile.sessionMinutes * 60;
    var cardioSeconds = cardio?.durationSeconds ?? 0;
    var includeFinisher = false;

    int estimate() => estimateSeconds(
          _estimationDay(day, cardio?.copyWith(durationSeconds: () => cardioSeconds), drills, work,
              includeFinisher ? finisher?.copyWith(durationSeconds: () => finisherSeconds) : null, finisherBlockName,
              cooldownWalk, stretches),
          includeFinisher: includeFinisher,
          hotDay: input.hotDay,
          findWeightIds: findWeightIds(),
        );
    bool fits() => estimate() <= budget;

    for (final block in work) {
      for (final s in block.slots) {
        s.included = !s.optional;
      }
    }
    final notices = <String>[];
    final ordered = [for (final block in work) ...block.slots];
    final reversed = ordered.reversed.toList();

    void overBudgetNotice() {
      final minutes = secondsToMinutes(estimate());
      final pick = input.profile.sessionMinutes < 60 ? 'Pick 60 min' : 'Pick a longer session';
      notices.add('This day needs about $minutes min. $pick in Settings or use '
          "'End workout' when you are out of time: finished exercises still count.");
    }

    if (noTrim) {
      // Deload and retest days are never trimmed; say so when they run long.
      if (!fits()) overBudgetNotice();
    } else if (!fits()) {
      var done = false;
      // a. warm-up cardio 300 -> 180 s.
      if (cardio != null && cardioSeconds > minWarmupCardioSeconds) {
        cardioSeconds = minWarmupCardioSeconds;
        done = fits();
      }
      // b. accessory sets - 1, from the last block backwards (never below 2).
      for (final s in reversed) {
        if (done) break;
        if (!s.included || s.original.role != ItemRole.accessory || s.sets <= minTrimmedSets) continue;
        s.sets -= 1;
        done = fits();
      }
      // c. accessory items removed (each becomes an extra), same order.
      for (final s in reversed) {
        if (done) break;
        if (!s.included || s.original.role != ItemRole.accessory) continue;
        s.included = false;
        done = fits();
      }
      // d. secondary sets - 1, from last to first (never below 2).
      for (final s in reversed) {
        if (done) break;
        if (!s.included || s.original.role != ItemRole.secondary || s.sets <= minTrimmedSets) continue;
        s.sets -= 1;
        done = fits();
      }
      // e. still over: keep the plan and say so.
      if (!done) overBudgetNotice();
    }

    bool tryFinisher() {
      if (finisher == null || rawWeek <= 1 || isDeload) return false;
      includeFinisher = true;
      if (fits()) return true;
      includeFinisher = false;
      return false;
    }

    void tryOptionals() {
      for (final s in ordered) {
        if (s.included || !s.optional) continue;
        s.included = true;
        if (!fits()) s.included = false;
      }
    }

    // Recomp and fat loss: the finisher outranks the optional extras.
    final finisherFirst = input.profile.goal == Goal.recomp || input.profile.goal == Goal.fatLoss;
    if (finisherFirst) {
      tryFinisher();
      tryOptionals();
    } else {
      tryOptionals();
      tryFinisher();
    }

    // ---- Steps --------------------------------------------------------------------------------
    for (final s in ordered) {
      if (s.included) s.rx = _prescribe(s.ex, s.item, isDeload);
    }
    _markCalibrationSet(work, isDeload);

    final steps = <SessionStep>[];
    if (cardio != null) {
      steps.add(WarmupCardioStep(index: steps.length, item: cardio.copyWith(durationSeconds: () => cardioSeconds)));
    }
    if (drills.isNotEmpty) {
      steps.add(MobilityStep(index: steps.length, items: drillsTwice ? [...drills, ...drills] : drills));
    }
    for (final block in work) {
      final members = [for (final s in block.slots) if (s.included) s];
      if (members.isEmpty) continue;
      if (block.block.blockType == BlockType.superset && members.length > 1) {
        final index = steps.length;
        steps.add(SupersetStep(
          index: index,
          group: block.block.supersetGroup ?? 'A',
          members: [for (final s in members) _step(index, s)],
          roundRestSec: _roundRest(block.block) + (input.hotDay ? hotExtraRestSeconds : 0),
        ));
      } else {
        for (final s in members) {
          steps.add(_step(steps.length, s, soloFrom: block.block));
        }
      }
    }
    final extras = [for (final s in ordered) if (!s.included) s];
    if (extras.isNotEmpty) {
      final index = steps.length;
      steps.add(ExtrasStep(index: index, extras: [
        for (final s in extras) _step(index, s.restoredForExtra(_prescribe(s.ex, s.restoredItem, isDeload)), soloFrom: null),
      ]));
    }
    if (includeFinisher && finisher != null) {
      steps.add(FinisherStep(index: steps.length, item: finisher, durationSec: finisherSeconds));
    }
    final cool = [?cooldownWalk, ...stretches];
    if (cool.isNotEmpty) steps.add(CooldownStep(index: steps.length, items: cool));

    // ---- Notices ------------------------------------------------------------------------------
    final allNotices = <String>[
      if (rawWeek == 1 && !isDeload) week1Notice,
      if (gap.notice != null) gap.notice!,
      if (reactive && !gap.treatAsDeload) reactiveDeloadNotice,
      ...equipmentNotices,
      ?_phaseStartNotice(day, work),
      ...limitationCues(limitations, rules),
      ...notices,
    ];

    return SessionPlan(
      programId: input.active.id,
      templateId: input.active.templateId,
      phaseId: phase.phaseId,
      trainingWeek: week,
      dayId: day.dayId,
      dayName: day.name,
      isDeload: isDeload,
      hotDay: input.hotDay,
      includesFinisher: includeFinisher && finisher != null,
      estimatedMinutes: secondsToMinutes(estimate()),
      steps: steps,
      notices: [
        for (final (i, n) in allNotices.indexed)
          if (allNotices.indexOf(n) == i) n,
      ],
    );
  }

  // ---- Day and transforms -------------------------------------------------------------------

  ProgramDay _pickDay() {
    final wanted = input.dayId ?? (input.active.dayOrder.isEmpty ? null : input.active.nextDayId);
    if (wanted != null) {
      final d = phase.day(wanted);
      if (d != null) return d;
    }
    if (phase.days.isEmpty) {
      throw StateError('Program "${template.programId}" has no days in phase ${phase.phaseId.wire}');
    }
    return phase.days.first;
  }

  /// Reactive deload (SPEC 6.7): non-optional blocks only, no finisher, half the sets (rounded
  /// up), 4 reps in reserve. Cool-down stretches stay.
  ProgramDay _deloadTransform(ProgramDay day) {
    final blocks = <ProgramBlock>[];
    for (final b in day.blocks) {
      if (b.optional || b.blockType == BlockType.finisher) continue;
      if (b.blockType == BlockType.main || b.blockType == BlockType.superset) {
        final items = [
          for (final i in b.items)
            if (!i.optional) i.copyWith(sets: (i.sets + 1) ~/ 2, rir: i.rir == null ? null : () => maxRir),
        ];
        if (items.isNotEmpty) blocks.add(b.copyWith(items: items));
      } else {
        blocks.add(b);
      }
    }
    return day.copyWith(blocks: blocks);
  }

  // ---- Exercise resolution (SPEC 6.8) -------------------------------------------------------

  bool _hidden(Exercise ex) => input.prefs[ex.id]?.hidden ?? false;

  bool _usable(Exercise ex) =>
      exerciseAvailable(ex, eq) &&
      !exerciseAvoided(ex, limitations, rules) &&
      !(input.cardioOff && usesCardioMachine(ex)) &&
      !_hidden(ex) &&
      !lockedByLimitation.contains(ex.unlockKey);

  /// The exercise for [item] today and the item rewritten for it, or null when the item is
  /// dropped (with a notice unless [quiet]). [work] items avoid exercises already in the day.
  (ProgramItem, Exercise)? _resolve(ProgramItem item, Map<String, ProgramOverride> overrides,
      {bool work = false, bool quiet = false}) {
    final catalog = input.catalog;
    final overrideId = overrides[item.slotKey()]?.exerciseId;
    var ex = (overrideId == null ? null : catalog.tryExercise(overrideId)) ?? catalog.tryExercise(item.exerciseId);
    if (ex == null) return null;
    if (eq.legCurlType == LegCurlType.lying && ex.id == _seatedLegCurlId) {
      ex = catalog.tryExercise(_lyingLegCurlId) ?? ex;
    }
    if (!_usable(ex)) {
      final original = ex;
      Exercise? replacement;
      for (final id in [...item.substitutions, ...original.substitutions]) {
        final c = catalog.tryExercise(id);
        if (c == null || c.id == original.id) continue;
        if (work && usedWorkIds.contains(c.id)) continue;
        if (!_usable(c) || !exerciseUnlocked(c, unlocks)) continue;
        replacement = c;
        break;
      }
      if (replacement == null) {
        if (!quiet) equipmentNotices.add(_skipNotice(original));
        return null;
      }
      ex = replacement;
    }
    if (work) usedWorkIds.add(ex.id);
    return (_fitItem(item, ex), ex);
  }

  /// [item] rewritten for [ex]: the slot keeps its sets, reps and rest; the load step becomes the
  /// new exercise's own; a timed exercise gets a duration and a reps exercise a rep range.
  ProgramItem _fitItem(ProgramItem item, Exercise ex) {
    if (ex.id == item.exerciseId) return item;
    var out = item.copyWith(exerciseId: ex.id, weightIncrementKg: () => null);
    if (ex.tracking == Tracking.time && out.durationSeconds == null) {
      out = out.copyWith(durationSeconds: () => ex.durationSeconds ?? 30);
    }
    if (ex.tracking != Tracking.time && out.repRange == null) {
      out = out.copyWith(repRange: () => ex.repRange ?? fallbackRepRange);
    }
    return out;
  }

  String _skipNotice(Exercise ex) {
    final missing = missingEquipment(ex, eq);
    if (missing.isNotEmpty) {
      final gym = input.catalog.personalization.gym;
      final bothCardio = missing.contains(Equipment.bike) && missing.contains(Equipment.treadmill);
      final labels = [
        if (bothCardio) '${gym.labelFor(Equipment.bike)} or ${gym.labelFor(Equipment.treadmill)}',
        for (final e in missing)
          if (!(bothCardio && (e == Equipment.bike || e == Equipment.treadmill))) gym.labelFor(e),
      ];
      return 'Skipped ${ex.name}: needs ${labels.join(', ')}';
    }
    if (input.cardioOff && usesCardioMachine(ex)) return 'Skipped ${ex.name}: cardio machines are off';
    return 'Skipped ${ex.name}: no suitable alternative today';
  }

  bool _isCardioItem(ProgramItem item) =>
      cardioWarmupIds.contains(item.exerciseId) ||
      (input.catalog.tryExercise(item.exerciseId)?.category == ExerciseCategory.cardio);

  // ---- Prescriptions -------------------------------------------------------------------------

  Prescription _prescribe(Exercise ex, ProgramItem item, bool isDeload) {
    final state = input.states[ex.id];
    final seed = state?.workingKg == null ? transferSeed(ex.id, input.states, eq) : null;
    final rx = prescribe(ex, item, phase, week, state, eq, input.prefs[ex.id], gap,
        isDeload: isDeload, hotDay: input.hotDay, seedKg: seed);
    return input.settings.warmupSets ? rx : rx.copyWith(warmups: const []);
  }

  /// Calibration set (SPEC 6.6): weeks 6 and 10, first session of the week, the last set of the
  /// first isolation exercise on a stack or cable that has a working weight.
  void _markCalibrationSet(List<_Block> work, bool isDeload) {
    if (isDeload || template.isCustom || !calibrationWeeks.contains(week)) return;
    final perWeek = math.max(1, template.daysPerWeek);
    if (input.completedNonDeload % perWeek != 0) return;
    for (final block in work) {
      for (final s in block.slots) {
        if (!s.included) continue;
        final ex = s.ex;
        if (ex.tracking != Tracking.weightReps || ex.mechanic != Mechanic.isolation) continue;
        if (ex.loadType != LoadType.stack && ex.loadType != LoadType.cable) continue;
        if (s.rx.findWeight || s.rx.trend == Trend.calibrate || s.rx.working.isEmpty) continue;
        final working = [...s.rx.working];
        working[working.length - 1] = working.last.copyWith(kind: SetKind.calibration);
        s.rx = s.rx.copyWith(working: working);
        return;
      }
    }
  }

  ExerciseStep _step(int index, _Slot s, {ProgramBlock? soloFrom}) {
    var item = s.item;
    // A superset member left on its own rests like a normal exercise.
    if (soloFrom != null && soloFrom.blockType == BlockType.superset) {
      item = item.copyWith(restSeconds: math.max(item.restSeconds, _roundRest(soloFrom)));
    }
    var rx = s.rx;
    if (item.restSeconds != s.item.restSeconds) {
      rx = rx.copyWith(restSec: item.restSeconds + (input.hotDay ? hotExtraRestSeconds : 0));
    }
    return ExerciseStep(index: index, item: item, rx: rx, slotKey: s.original.slotKey());
  }

  int _roundRest(ProgramBlock b) =>
      (b.restBetweenRoundsSeconds ?? 0) == 0 ? defaultRoundRestSeconds : b.restBetweenRoundsSeconds!;

  // ---- Estimation ----------------------------------------------------------------------------

  /// The day as it will run (resolved items, trimmed sets, included items only), for the
  /// duration model.
  ProgramDay _estimationDay(ProgramDay day, ProgramItem? cardio, List<ProgramItem> drills, List<_Block> work,
      ProgramItem? finisher, String? finisherName, ProgramItem? walk, List<ProgramItem> stretches) {
    ProgramItem noWarmups(ProgramItem i) => input.settings.warmupSets ? i : i.copyWith(warmupSets: 0);
    final blocks = <ProgramBlock>[];
    final warmupBlock = day.blocks.where((b) => b.blockType == BlockType.warmup).firstOrNull;
    final warmItems = [?cardio, ...drills];
    if (warmItems.isNotEmpty) {
      blocks.add(ProgramBlock(blockType: BlockType.warmup, name: warmupBlock?.name ?? 'Warm-up', items: warmItems));
    }
    for (final block in work) {
      final included = [for (final s in block.slots) if (s.included) noWarmups(s.item.copyWith(sets: s.sets, optional: false))];
      if (included.isEmpty) continue;
      if (block.block.blockType == BlockType.superset && included.length == 1) {
        final solo = included.single;
        blocks.add(ProgramBlock(
          blockType: BlockType.main,
          name: block.block.name,
          items: [solo.copyWith(restSeconds: math.max(solo.restSeconds, _roundRest(block.block)))],
        ));
      } else {
        blocks.add(block.block.copyWith(optional: false, items: included));
      }
    }
    if (finisher != null) {
      blocks.add(ProgramBlock(
          blockType: BlockType.finisher, name: finisherName ?? 'Finisher', optional: true, items: [finisher]));
    }
    final cool = [?walk, ...stretches];
    if (cool.isNotEmpty) blocks.add(ProgramBlock(blockType: BlockType.cooldown, name: 'Cool-down', items: cool));
    return day.copyWith(blocks: blocks);
  }

  // ---- Notices -------------------------------------------------------------------------------

  /// "New this phase: Smith machine squat" on the first week of a phase that brings new lifts.
  String? _phaseStartNotice(ProgramDay day, List<_Block> work) {
    if (template.isCustom || phase.phaseId == PhaseId.deload || phase.phaseId == PhaseId.retest) return null;
    if (phase.weeks.isEmpty || week != phase.weeks.reduce(math.min)) return null;
    final index = template.phases.indexWhere((p) => p.phaseId == phase.phaseId);
    if (index <= 0) return null;
    final previous = template.phases[index - 1];
    final before = (previous.day(day.dayId)?.items ?? previous.days.expand((d) => d.items)).map((i) => i.exerciseId).toSet();
    final fresh = <String>[];
    for (final block in work) {
      for (final s in block.slots) {
        if (!before.contains(s.original.exerciseId) && !fresh.contains(s.ex.name)) fresh.add(s.ex.name);
      }
    }
    return fresh.isEmpty ? null : 'New this phase: ${fresh.join(', ')}';
  }
}

class _Block {
  _Block(this.block, this.slots);
  final ProgramBlock block;
  final List<_Slot> slots;
}

/// One main/superset item while the plan is being fitted to the time budget.
class _Slot {
  _Slot(this.original, this.resolvedItem, this.ex, {required this.optional}) : sets = resolvedItem.sets;

  /// The template item (its slot key identifies the slot).
  final ProgramItem original;

  /// The item rewritten for [ex] (before any trimming).
  final ProgramItem resolvedItem;
  final Exercise ex;
  final bool optional;

  /// Current set count (the ladder lowers it).
  int sets;

  /// In the plan (false: an optional item that did not fit, or removed by the ladder; both are
  /// listed as extras).
  bool included = true;
  Prescription rx = const Prescription(exerciseId: '', working: [], restSec: 0);

  ProgramItem get item => sets == resolvedItem.sets ? resolvedItem : resolvedItem.copyWith(sets: sets);

  /// Extras are offered with their full set count.
  ProgramItem get restoredItem => resolvedItem;

  _Slot restoredForExtra(Prescription rx) {
    final s = _Slot(original, resolvedItem, ex, optional: optional)..rx = rx;
    return s;
  }
}
