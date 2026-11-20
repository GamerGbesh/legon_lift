import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/domain/api.dart';

import 'engine_fixtures.dart';

void main() {
  const chestId = 'machine_chest_press'; // stack, 5 kg steps
  final chest = ex(chestId);
  final chestItem = item(chestId, sets: 3, reps: (8, 12), rir: 2, inc: 5);

  ExerciseState after(
    List<SetLog> working, {
    ExerciseState? st,
    List<SetLog> last = const [],
    Exercise? e,
    ProgramItem? it,
    int? t = 2,
    int? plannedSets,
    bool recordOnly = false,
  }) =>
      afterSession(st ?? state(chestId, workingKg: 50), e ?? chest, it ?? chestItem, t, working, last, gymEq, null, t0,
          plannedSets: plannedSets, recordOnly: recordOnly);

  group('afterSession: double progression (SPEC 6.5)', () {
    test('all sets at the top with RIR ok -> +1 step, reps back to the bottom', () {
      final s = after(sets(chestId, 50, [12, 12, 12], rirs: [2, 1, 2]));
      expect(s.workingKg, 55);
      expect(s.repTargets, [8, 8, 8]);
      expect(s.lastTrend, Trend.up);
      expect(s.stallCount, 0);
      expect(s.lastReason, 'You hit 12, 12, 12 last time: +5 kg');
      expect(s.lastJumpPct, closeTo(0.1, 1e-9));
      expect(s.lastRepRange, (8, 12));
      expect(s.lastSessionId, 'session-1');
    });

    test('bonus: every set at top + 2 with RIR >= target + 1 -> two steps', () {
      final s = after(sets(chestId, 50, [14, 14, 14], rirs: [3, 3, 4]));
      expect(s.workingKg, 60);
      expect(s.lastTrend, Trend.up);
    });

    test('no bonus when one set had less in the tank', () {
      expect(after(sets(chestId, 50, [14, 14, 14], rirs: [3, 2, 3])).workingKg, 55);
    });

    test('grinding (RIR below target - 1) blocks the increase', () {
      final s = after(sets(chestId, 50, [12, 12, 12], rirs: [0, 1, 1]));
      expect(s.workingKg, 50);
      expect(s.lastTrend, Trend.same);
      expect(s.repTargets, [12, 12, 12]); // capped at the top
    });

    test('unanswered RIR counts as ok', () {
      expect(after(sets(chestId, 50, [12, 12, 12])).workingKg, 55);
    });

    test('no RIR target: reps alone decide', () {
      expect(after(sets(chestId, 50, [12, 12, 12], rirs: [0, 0, 0]), t: null).workingKg, 55);
    });

    test('progress (more total reps) -> same weight, +1 rep per set', () {
      final s = after(sets(chestId, 50, [12, 11, 10]), last: sets(chestId, 50, [11, 10, 9], sessionId: 'old'));
      expect(s.workingKg, 50);
      expect(s.repTargets, [12, 12, 11]);
      expect(s.stallCount, 0);
      expect(s.lastTrend, Trend.same);
      expect(s.lastReason, 'Same weight: beat 10 reps on your weakest set');
    });

    test('progress (heavier than last time) also counts', () {
      final s = after(sets(chestId, 50, [9, 8, 8]),
          st: state(chestId, workingKg: 50, stallCount: 2), last: sets(chestId, 45, [12, 12, 12], sessionId: 'old'));
      expect(s.stallCount, 0);
      expect(s.workingKg, 50);
    });

    test('first session (no last exposure) is progress', () {
      final s = after(sets(chestId, 50, [10, 9, 9]), st: state(chestId, workingKg: 50, stallCount: 1));
      expect(s.stallCount, 0);
    });

    test('no progress -> stall + 1, aim for one more rep', () {
      final s = after(sets(chestId, 50, [10, 9, 9]), last: sets(chestId, 50, [10, 9, 9], sessionId: 'old'));
      expect(s.stallCount, 1);
      expect(s.workingKg, 50);
      expect(s.repTargets, [11, 10, 10]);
      expect(s.lastReason, 'Same weight, aim for one more rep');
    });

    test('third stall -> -10% and reps reset, reset count + 1', () {
      final s = after(sets(chestId, 50, [10, 9, 9]),
          st: state(chestId, workingKg: 50, stallCount: 2), last: sets(chestId, 50, [10, 9, 9], sessionId: 'old'));
      expect(s.workingKg, 45);
      expect(s.repTargets, [8, 8, 8]);
      expect(s.stallCount, 0);
      expect(s.resetCount, 1);
      expect(s.lastTrend, Trend.down);
      expect(s.lastReason, '3 sessions without progress: -10% to build back up');
      expect(s.suggestSubstitution, isFalse);
    });

    test('second reset suggests a variation', () {
      final s = after(sets(chestId, 50, [10, 9, 9]),
          st: state(chestId, workingKg: 50, stallCount: 2, resetCount: 1),
          last: sets(chestId, 50, [10, 9, 9], sessionId: 'old'));
      expect(s.resetCount, 2);
      expect(s.suggestSubstitution, isTrue);
    });

    test('the most common weight is the load (ties -> heavier)', () {
      expect(modeWeight([setLog(chestId, 50, 10), setLog(chestId, 55, 10)]), 55);
      expect(modeWeight([setLog(chestId, 50, 10), setLog(chestId, 50, 10), setLog(chestId, 55, 10)]), 50);
      final s = after([setLog(chestId, 50, 12), setLog(chestId, 55, 12), setLog(chestId, 55, 12)]);
      expect(s.workingKg, 60); // load 55 -> +5
    });
  });

  group('afterSession: small-load guard', () {
    const raiseId = 'dumbbell_lateral_raise';
    final raise = ex(raiseId);
    final raiseItem = item(raiseId, sets: 2, reps: (12, 15), rir: 3, role: ItemRole.accessory, inc: 1, warmupSets: 0);

    test('4 -> 6 kg is +50%: the rep top grows by 3 (15 -> 18)', () {
      expect(effectiveTopReps(15, 4, raise, gymEq, null), 18);
      final notYet = afterSession(state(raiseId, workingKg: 4), raise, raiseItem, 3, sets(raiseId, 4, [15, 15]), const [],
          gymEq, null, t0);
      expect(notYet.workingKg, 4);
      expect(notYet.repTargets, [16, 16]);
      final up = afterSession(state(raiseId, workingKg: 4), raise, raiseItem, 3, sets(raiseId, 4, [18, 18]), const [],
          gymEq, null, t0);
      expect(up.workingKg, 6);
      expect(up.lastTrend, Trend.up);
      expect(up.lastJumpPct, closeTo(0.5, 1e-9));
    });

    test('a 10-20% jump extends the top by 2', () {
      expect(effectiveTopReps(12, 30, chest, gymEq, null), 14); // 30 -> 35 is +16.7%
      final s = afterSession(state(chestId, workingKg: 30), chest, chestItem, 2, sets(chestId, 30, [12, 12, 12]),
          const [], gymEq, null, t0);
      expect(s.workingKg, 30);
      final up = afterSession(state(chestId, workingKg: 30), chest, chestItem, 2, sets(chestId, 30, [14, 14, 14]),
          const [], gymEq, null, t0);
      expect(up.workingKg, 35);
    });

    test('a jump of 10% or less: normal top', () {
      expect(effectiveTopReps(12, 50, chest, gymEq, null), 12);
    });
  });

  group('afterSession: too heavy and the post-jump grace', () {
    test('first set below min - 2 -> one step lighter', () {
      final s = after(sets(chestId, 50, [5, 8, 8]), last: sets(chestId, 50, [8, 8, 8], sessionId: 'old'));
      expect(s.workingKg, 45);
      expect(s.lastTrend, Trend.down);
      expect(s.lastReason, 'Too heavy last time');
      expect(s.lastJumpPct, isNull);
    });

    test('min - 2 itself is not too heavy', () {
      final s = after(sets(chestId, 50, [6, 8, 8]), last: sets(chestId, 50, [6, 7, 7], sessionId: 'old'));
      expect(s.workingKg, 50);
    });

    const raiseId = 'dumbbell_lateral_raise';
    final raise = ex(raiseId);
    final raiseItem = item(raiseId, sets: 3, reps: (12, 15), rir: 3, role: ItemRole.accessory, inc: 1, warmupSets: 0);
    final lastAt4 = sets(raiseId, 4, [18, 18, 18], sessionId: 'old');

    test('after a big jump (4 -> 6 kg), 9 reps is accepted as a start', () {
      final s = afterSession(state(raiseId, workingKg: 6, lastTrend: Trend.up, lastJumpPct: 0.5, lastRepRange: (12, 15)),
          raise, raiseItem, 3, sets(raiseId, 6, [9, 9, 8]), lastAt4, gymEq, null, t0);
      expect(s.workingKg, 6);
      expect(s.lastTrend, Trend.same);
      expect(s.repTargets, [10, 10, 9]);
    });

    test('without the grace, 9 of 12 sends him back down', () {
      final s = afterSession(state(raiseId, workingKg: 6, lastTrend: Trend.same, lastRepRange: (12, 15)), raise,
          raiseItem, 3, sets(raiseId, 6, [9, 9, 8]), lastAt4, gymEq, null, t0);
      expect(s.workingKg, 4);
      expect(s.lastTrend, Trend.down);
    });

    test('even with the grace, min - 4 is too heavy', () {
      final s = afterSession(state(raiseId, workingKg: 6, lastTrend: Trend.up, lastJumpPct: 0.5, lastRepRange: (12, 15)),
          raise, raiseItem, 3, sets(raiseId, 6, [7, 8, 8]), lastAt4, gymEq, null, t0);
      expect(s.workingKg, 4);
    });

    test('a small jump (<= 10%) gets no grace', () {
      final s = after(sets(chestId, 55, [5, 8, 8]),
          st: state(chestId, workingKg: 55, lastTrend: Trend.up, lastJumpPct: 0.1),
          last: sets(chestId, 50, [12, 12, 12], sessionId: 'old'));
      expect(s.workingKg, 50);
    });
  });

  group('afterSession: unfinished sessions give no verdict', () {
    test('a skipped set: state unchanged, same target', () {
      final st = state(chestId, workingKg: 50, repTargets: [11, 10, 10], stallCount: 2);
      final s = after(sets(chestId, 50, [9, 9]), st: st, last: sets(chestId, 50, [10, 9, 9], sessionId: 'old'));
      expect(s.workingKg, 50);
      expect(s.repTargets, [11, 10, 10]);
      expect(s.stallCount, 2); // not a third stall
      expect(s.lastTrend, Trend.same);
      expect(s.lastReason, 'Unfinished last time: same target');
    });

    test('plannedSets counts added sets', () {
      final s = after(sets(chestId, 50, [12, 12, 12]), plannedSets: 4);
      expect(s.workingKg, 50);
      expect(s.lastReason, 'Unfinished last time: same target');
    });

    test('the pain rule still applies', () {
      final working = [setLog(chestId, 50, 10, pain: true)];
      final s = after(working, plannedSets: 3);
      expect(s.workingKg, 45);
      expect(s.lastTrend, Trend.down);
      expect(s.lastReason, 'Lighter after the pain flag');
    });

    test('find-weight session: planned = sets - 1, the found weight becomes the working weight', () {
      final s = afterSession(null, chest, chestItem, 3, sets(chestId, 35, [10, 10]), const [], gymEq, null, t0);
      expect(s.workingKg, 35);
      expect(s.lastTrend, Trend.same);
      expect(s.repTargets, [11, 11, 8]);
      expect(s.lastRepRange, (8, 12));
    });

    test('find-weight session ended after one set: still keeps the found weight', () {
      final s = afterSession(null, chest, chestItem, 3, sets(chestId, 35, [10]), const [], gymEq, null, t0);
      expect(s.workingKg, 35);
      expect(s.lastReason, 'Unfinished last time: same target');
      expect(s.lastRepRange, (8, 12));
    });

    test('quick start (accessory, no history) plans every set', () {
      const pushdownId = 'triceps_rope_pushdown';
      final it = item(pushdownId, sets: 2, reps: (10, 15), rir: 3, role: ItemRole.accessory, warmupSets: 0);
      final one = afterSession(null, ex(pushdownId), it, 3, sets(pushdownId, 10, [15]), const [], gymEq, null, t0);
      expect(one.lastReason, 'Unfinished last time: same target');
      final both = afterSession(null, ex(pushdownId), it, 3, sets(pushdownId, 10, [15, 15]), const [], gymEq, null, t0);
      expect(both.lastReason, isNot('Unfinished last time: same target'));
      expect(both.workingKg, 10); // 10 -> 12.5 kg is +25%: the top becomes 18 reps first
      expect(both.repTargets, [16, 16]);
    });
  });

  group('afterSession: pain, records, sessions that do not progress', () {
    test('pain caps the next weight at 90% of the load', () {
      final working = [setLog(chestId, 50, 12), setLog(chestId, 50, 12), setLog(chestId, 50, 12, pain: true)];
      final s = after(working);
      expect(s.workingKg, 45);
      expect(s.lastTrend, Trend.down);
      expect(s.lastReason, 'Lighter after the pain flag');
      expect(s.lastJumpPct, isNull);
    });

    test('estimated best single on the total load, reps <= 12 only', () {
      const dbId = 'incline_dumbbell_press'; // 2 dumbbells
      final it = item(dbId, sets: 2, reps: (8, 12), rir: 2, role: ItemRole.secondary);
      final s = afterSession(state(dbId, workingKg: 12), ex(dbId), it, 2,
          [setLog(dbId, 12, 10), setLog(dbId, 12, 15)], const [], gymEq, null, t0);
      expect(s.bestE1rm, closeTo(24 * (1 + 10 / 30), 1e-9));
      expect(s.firstE1rm, s.bestE1rm);
    });

    test('bestE1rm only grows; firstE1rm is kept', () {
      final s = after(sets(chestId, 50, [8, 8, 8]), st: state(chestId, workingKg: 50, bestE1rm: 100, firstE1rm: 60));
      expect(s.bestE1rm, 100);
      expect(s.firstE1rm, 60);
    });

    test('deload/retest sessions (recordOnly): only the estimated best changes', () {
      final st = state(chestId, workingKg: 50, repTargets: [10, 10, 10], bestE1rm: 60);
      final s = after(sets(chestId, 45, [12, 12]), st: st, recordOnly: true);
      expect(s.workingKg, 50);
      expect(s.repTargets, [10, 10, 10]);
      expect(s.lastTrend, st.lastTrend);
      expect(s.bestE1rm, closeTo(45 * 1.4, 1e-9));
    });

    test('retest item: the test set counts reps + 1', () {
      final it = item(chestId, sets: 1, reps: (3, 15), rir: 1, test: 'rir1_rep_test');
      final st = state(chestId, workingKg: 60, bestE1rm: 70);
      final s = afterSession(st, chest, it, 1,
          [setLog(chestId, 60, 10, kind: SetKind.test), setLog(chestId, 45, 8)], const [], gymEq, null, t0);
      expect(s.workingKg, 60);
      expect(s.bestE1rm, closeTo(60 * (1 + 11 / 30), 1e-9));
    });

    test('bodyweight and timed exercises keep their state', () {
      final s = afterSession(null, ex('dead_bug'), item('dead_bug', reps: (6, 10)), null,
          sets('dead_bug', 0, [10, 10]), const [], gymEq, null, t0);
      expect(s.workingKg, isNull);
    });

    test('warm-up and ramp sets are ignored', () {
      final working = [
        setLog(chestId, 25, 8, kind: SetKind.warmup),
        setLog(chestId, 35, 5, kind: SetKind.ramp),
        ...sets(chestId, 50, [12, 12, 12]),
      ];
      expect(after(working).workingKg, 55);
    });
  });

  group('inSessionHint (SPEC 6.4)', () {
    InSessionHint? hint(SetLog last, int n, {int? t = 2, bool quickStart = false, ExerciseState? st}) =>
        inSessionHint(last, n, chestItem, t, chest, gymEq, quickStart: quickStart, state: st);

    test('rule 1: set 1 at max + 3 with RIR at target -> one-tap "Add 5 kg"', () {
      final h = hint(setLog(chestId, 50, 15, rir: 2), 1)!;
      expect(h.suggestedKg, 55);
      expect(h.automatic, isFalse);
      expect(h.message, 'Add 5 kg for the next set');
    });
    test('rule 1 only after set 1 ...', () => expect(hint(setLog(chestId, 50, 15, rir: 2), 2), isNull));
    test('... or any set in quick start', () {
      expect(hint(setLog(chestId, 50, 15, rir: 3), 2, quickStart: true)?.suggestedKg, 55);
    });
    test('rule 1 needs RIR >= target (unanswered = ok)', () {
      expect(hint(setLog(chestId, 50, 15, rir: 1), 1), isNull);
      expect(hint(setLog(chestId, 50, 15), 1)?.suggestedKg, 55);
      expect(hint(setLog(chestId, 50, 14, rir: 4), 1), isNull); // max + 2 is not enough
    });
    test('rule 1 for dumbbells names the per-dumbbell step', () {
      const id = 'incline_dumbbell_press';
      final h = inSessionHint(setLog(id, 10, 15, rir: 3), 1, item(id, reps: (8, 12), inc: 2), 2, ex(id), gymEq)!;
      expect(h.suggestedKg, 12);
      expect(h.message, 'Add 2 kg (each dumbbell) for the next set');
    });
    test('rule 2: reps < min - 2 -> automatic, one step lighter', () {
      final h = hint(setLog(chestId, 50, 5, rir: 2), 2)!;
      expect(h.automatic, isTrue);
      expect(h.suggestedKg, 45);
      expect(h.message, 'Lighter for the next set: that was too heavy.');
    });
    test('rule 2 with the post-jump grace: min - 4', () {
      final st = state(chestId, workingKg: 50, lastTrend: Trend.up, lastJumpPct: 0.2);
      expect(hint(setLog(chestId, 50, 5, rir: 2), 2, st: st), isNull);
      expect(hint(setLog(chestId, 50, 3, rir: 2), 2, st: st)?.suggestedKg, 45);
    });
    test('rule 3: no reps left and below the range -> 90%, automatic', () {
      final h = hint(setLog(chestId, 60, 7, rir: 0), 1)!;
      expect(h.automatic, isTrue);
      expect(h.suggestedKg, 50); // 54 rounded down
    });
    test('rules 2 and 3 together: the lighter wins', () {
      expect(hint(setLog(chestId, 60, 5, rir: 0), 1)?.suggestedKg, 50);
    });
    test('already at the lightest setting: message only', () {
      final h = hint(setLog(chestId, 5, 3, rir: 0), 1)!;
      expect(h.suggestedKg, isNull);
      expect(h.automatic, isFalse);
    });
    test('rule 4: pain never suggests heavier', () {
      final h = hint(setLog(chestId, 50, 15, rir: 4, pain: true), 1)!;
      expect(h.suggestedKg, isNull);
      expect(h.automatic, isFalse);
    });
    test('in range: nothing to say', () => expect(hint(setLog(chestId, 50, 10, rir: 2), 1), isNull));
    test('warm-up sets and bodyweight exercises: none', () {
      expect(hint(setLog(chestId, 25, 30, kind: SetKind.warmup), 1), isNull);
      expect(inSessionHint(setLog('dead_bug', 0, 2), 1, item('dead_bug', reps: (6, 10)), 2, ex('dead_bug'), gymEq),
          isNull);
    });
  });

  group('prescribe (SPEC 6.5)', () {
    final foundation = phase(offsets: const {1: 1});
    Prescription rx(ProgramItem it, ExerciseState? st,
            {Exercise? e,
            Phase? p,
            int week = 2,
            GapRule gap = GapRule.none,
            bool deload = false,
            bool hot = false,
            double? seed}) =>
        prescribe(e ?? ex(it.exerciseId), it, p ?? foundation, week, st, gymEq, null, gap,
            isDeload: deload, hotDay: hot, seedKg: seed);

    test('timed item: sets x duration', () {
      final r = rx(item('plank', sets: 2, reps: null, durationSeconds: 40, rir: null, role: ItemRole.core), null);
      expect(r.working, [
        for (var i = 0; i < 2; i++) const PlannedSet(kind: SetKind.working, weightKg: 0, reps: 0, durationSec: 40),
      ]);
      expect(r.findWeight, isFalse);
    });

    test('bodyweight reps item: the top of the range', () {
      final r = rx(item('dead_bug', sets: 2, reps: (6, 10), rir: null, role: ItemRole.core), null);
      expect(r.working.map((s) => s.reps), [10, 10]);
      expect(r.working.every((s) => s.weightKg == 0), isTrue);
    });

    test('first time, primary: find your weight (sets - 1 at the seed, no warm-ups)', () {
      final r = rx(chestItem, null);
      expect(r.findWeight, isTrue);
      expect(r.trend, Trend.calibrate);
      expect(r.reason, "First time: we'll find your weight");
      expect(r.working, hasLength(2));
      expect(r.working.first.weightKg, 20);
      expect(r.working.first.reps, 10); // min + 2
      expect(r.warmups, isEmpty);
      expect(r.targetRir, 2);
    });

    test('first time, secondary also ramps', () {
      expect(rx(item('machine_shoulder_press', role: ItemRole.secondary), null).findWeight, isTrue);
    });

    test('first time, accessory: quick start (every set at the seed, no ramp)', () {
      final it = item('triceps_rope_pushdown', sets: 2, reps: (10, 15), rir: 3, role: ItemRole.accessory, warmupSets: 0);
      final r = rx(it, null);
      expect(r.findWeight, isFalse);
      expect(r.trend, Trend.calibrate);
      expect(r.working.map((s) => (s.weightKg, s.reps)), [(10.0, 10), (10.0, 10)]);
    });

    test('SEED_TRANSFER seeds the ramp', () {
      final it = item('smith_machine_bench_press', reps: (6, 10));
      final seed = transferSeed('smith_machine_bench_press', {chestId: state(chestId, workingKg: 52.5)}, gymEq);
      final r = rx(it, null, seed: seed); // 0.8 x 52.5 = 42 -> 40
      expect(r.findWeight, isTrue);
      expect(r.working.first.weightKg, 40);
    });

    test('established: working weight, rep targets padded with min, warm-ups, hot-day rest', () {
      final r = rx(chestItem.copyWith(restSeconds: 120), state(chestId, workingKg: 50, repTargets: [10, 9]), hot: true);
      expect(r.findWeight, isFalse);
      expect(r.working.map((s) => (s.weightKg, s.reps, s.targetRir)), [(50.0, 10, 2), (50.0, 9, 2), (50.0, 8, 2)]);
      expect(r.warmups.map((s) => (s.kind, s.weightKg, s.reps)), [(SetKind.warmup, 25.0, 8), (SetKind.warmup, 35.0, 5)]);
      expect(r.restSec, 150);
      expect(r.incrementKg, 5);
    });

    test('rep targets are clamped to [min, effective top]', () {
      final r = rx(chestItem, state(chestId, workingKg: 50, repTargets: [15, 3, 12, 12]));
      expect(r.working.map((s) => s.reps), [12, 8, 12]);
    });

    test('week offset: week 1 of foundation is +1 RIR', () {
      expect(rx(chestItem, state(chestId, workingKg: 50), week: 1).targetRir, 3);
    });

    test('phase transition: re-derived from the estimated best for the new range', () {
      // best 70 kg -> mid 6.5 reps @ 2: 70 / (1 + 8.5/30) = 54.5 -> 50 kg
      final it = item(chestId, reps: (5, 8), rir: 2);
      final r = rx(it, state(chestId, workingKg: 40, repTargets: [12, 12, 12], bestE1rm: 70, lastRepRange: (8, 12)));
      expect(r.working.map((s) => (s.weightKg, s.reps)), [(50.0, 5), (50.0, 5), (50.0, 5)]);
      expect(r.reason, 'New rep range: weight adjusted to match');
    });

    test('phase transition on dumbbells converts the total back to one dumbbell', () {
      const id = 'incline_dumbbell_press';
      final it = item(id, sets: 2, reps: (8, 12), rir: 2, role: ItemRole.secondary, warmupSets: 1);
      // total best 40 kg -> 40 / (1 + 12/30) = 28.6 total = 14.3 per dumbbell -> 14
      final r = rx(it, state(id, workingKg: 12, bestE1rm: 40, lastRepRange: (10, 12)));
      expect(r.working.first.weightKg, 14);
    });

    test('phase transition without an estimated best uses the working weight and first rep target', () {
      final it = item(chestId, reps: (5, 8), rir: 2);
      // 50 x (1 + (10 + 2)/30) = 70 -> same as above
      final r = rx(it, state(chestId, workingKg: 50, repTargets: [10, 10, 10], lastRepRange: (8, 12)));
      expect(r.working.first.weightKg, 50);
    });

    test('deload: 4 in the tank, phase load multiplier 0.9', () {
      final p = phase(id: PhaseId.deload, weeks: const [13], loadMultiplier: 0.9);
      final r = rx(chestItem, state(chestId, workingKg: 50), p: p, week: 13, deload: true);
      expect(r.targetRir, 4);
      expect(r.working.first.weightKg, 45);
      expect(r.trend, Trend.deload);
    });

    test('back after 10-21 days: 10% lighter, +1 RIR', () {
      final gap = gapRule(t0.subtract(const Duration(days: 14)), t0);
      final r = rx(chestItem, state(chestId, workingKg: 50), gap: gap);
      expect(r.working.first.weightKg, 45);
      expect(r.targetRir, 3);
      expect(r.trend, Trend.down);
    });

    test('back after > 21 days: primaries find their weight from 80%, others 20% lighter at RIR 4', () {
      final gap = gapRule(t0.subtract(const Duration(days: 30)), t0);
      final primary = rx(chestItem, state(chestId, workingKg: 50), gap: gap);
      expect(primary.findWeight, isTrue);
      expect(primary.working.first.weightKg, 40);
      expect(primary.reason, "Long break: we'll find your weight again");
      expect(primary.targetRir, 4);
      final secondary = rx(item('machine_shoulder_press', role: ItemRole.secondary),
          state('machine_shoulder_press', workingKg: 50),
          gap: gap);
      expect(secondary.findWeight, isFalse);
      expect(secondary.working.first.weightKg, 40);
      expect(secondary.targetRir, 4);
    });

    test('retest: one test set at the working weight, then 80% x 8 @ 3', () {
      final it = item(chestId, sets: 1, reps: (3, 15), rir: 1, test: 'rir1_rep_test', rest: 180);
      final r = rx(it, state(chestId, workingKg: 60, lastRepRange: (5, 8)), p: phase(id: PhaseId.retest, weeks: const [14]),
          week: 14);
      expect(r.working, [
        const PlannedSet(kind: SetKind.test, weightKg: 60, reps: 15, targetRir: 1),
        const PlannedSet(kind: SetKind.working, weightKg: 45, reps: 8, targetRir: 3),
      ]);
      expect(r.warmups, isNotEmpty);
    });
  });
}
