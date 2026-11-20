import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/domain/api.dart';

import 'engine_fixtures.dart';

void main() {
  // SPEC 6.2 test table: seed 20 kg on a 5 kg stack, target 10 @ 3.
  group('findWeightStep: SPEC table (20 kg stack, target 10 @ 3)', () {
    final chest = ex('machine_chest_press');
    const s = FindWeightState(currentKg: 20, step: 1, targetReps: 10, targetRir: 3);
    final cases = <(String, int, int?, bool, RampResult)>[
      ('18 reps, 4 left -> next 25', 18, 4, false, const RampNext(25)),
      ('10 reps, 3 left -> done 20', 10, 3, false, const RampDone(20)),
      ('6 reps, 1 left -> done 15', 6, 1, false, const RampDone(15)),
      ('10 reps, not answered -> done 20', 10, null, false, const RampDone(20)),
      ('pain -> done 15 (0.8 x 20 = 16, rounded down)', 10, 3, true, const RampDone(15)),
    ];
    for (final (name, reps, rir, pain, expected) in cases) {
      test(name, () => expect(findWeightStep(s, reps, rir, pain, chest, gymEq), expected));
    }
  });

  group('findWeightStep: limits', () {
    final chest = ex('machine_chest_press');
    test('never more than 4 ramp sets: step 4 settles on the rounded-down ideal', () {
      const s = FindWeightState(currentKg: 20, previousKg: 15, step: 4, targetReps: 10, targetRir: 3);
      expect(findWeightStep(s, 18, 4, false, chest, gymEq), const RampDone(20));
    });
    test('the next weight is at most 1.5x the current one', () {
      const s = FindWeightState(currentKg: 20, step: 1, targetReps: 10, targetRir: 3);
      expect(findWeightStep(s, 30, 4, false, chest, gymEq), const RampNext(30)); // ideal 29.8 -> 30
      expect(findWeightStep(s, 40, 4, false, chest, gymEq), const RampNext(30)); // ideal 34.4, capped at 30
    });
    test('form broke or pain after the first set goes back to the previous weight', () {
      const s = FindWeightState(currentKg: 30, previousKg: 25, step: 2, targetReps: 10, targetRir: 3);
      expect(findWeightStep(s, 4, 0, true, chest, gymEq), const RampDone(25));
    });
    test('too heavy never goes below the smallest load', () {
      final press = ex('incline_dumbbell_press');
      const s = FindWeightState(currentKg: 4, step: 2, previousKg: 2, targetReps: 12, targetRir: 3);
      expect(findWeightStep(s, 2, 0, false, press, gymEq), const RampDone(2));
    });
    test('when the 1.5x cap rounds to the same weight, go one step up', () {
      final press = ex('incline_dumbbell_press');
      const s = FindWeightState(currentKg: 2, step: 1, targetReps: 12, targetRir: 3);
      expect(findWeightStep(s, 40, 4, false, press, gymEq), const RampNext(4));
    });
    test('dumbbell ramp works on the per-dumbbell weight', () {
      final press = ex('incline_dumbbell_press');
      const s = FindWeightState(currentKg: 8, step: 1, targetReps: 12, targetRir: 3);
      expect(findWeightStep(s, 20, 4, false, press, gymEq), const RampNext(10));
    });
    test('a full ramp converges and never loops', () {
      // Simulates a lifter whose true best single is 60 kg on the stack.
      var s = startFindWeight(chest, item(chest.id, reps: (8, 12)), 3, gymEq);
      RampResult r;
      var ramps = 0;
      do {
        ramps++;
        final reps = (30 * (60 / s.currentKg - 1)).floor() - 3; // reps leaving 3 in the tank
        r = findWeightStep(s, reps.clamp(1, 40), 3, false, chest, gymEq);
        if (r is RampNext) s = advanceFindWeight(s, r);
      } while (r is RampNext);
      expect(ramps, lessThanOrEqualTo(4));
      final done = (r as RampDone).workingKg;
      expect(done, inInclusiveRange(30, 45));
    });
  });

  group('seed and start', () {
    test('startFindWeight: seed = starting weight rounded down, target min + 2', () {
      final chest = ex('machine_chest_press'); // startingWeightKg.low 20
      final s = startFindWeight(chest, item(chest.id, reps: (8, 12)), 3, gymEq);
      expect(s, const FindWeightState(currentKg: 20, step: 1, targetReps: 10, targetRir: 3));
    });
    test('lastKnownKg wins (skipped ramp or prescription seed), rounded down', () {
      final chest = ex('machine_chest_press');
      final s = startFindWeight(chest, item(chest.id), 2, gymEq, lastKnownKg: 37);
      expect(s.currentKg, 35);
    });
    test('seedWeight precedence: last known, transfer, starting weight, smallest load', () {
      final chest = ex('machine_chest_press');
      expect(seedWeight(chest, gymEq, lastKnownKg: 42, transferKg: 30), 40);
      expect(seedWeight(chest, gymEq, transferKg: 33), 30);
      expect(seedWeight(chest, gymEq), 20);
      expect(seedWeight(chest.copyWith(startingWeightKg: () => null), gymEq), 5);
      // goblet box squat starts at 0 kg: the smallest dumbbell.
      expect(seedWeight(ex('goblet_box_squat'), gymEq), 2);
    });
    test('advanceFindWeight moves current to previous', () {
      const s = FindWeightState(currentKg: 20, step: 1, targetReps: 10, targetRir: 3);
      expect(advanceFindWeight(s, const RampNext(25)),
          const FindWeightState(currentKg: 25, previousKg: 20, step: 2, targetReps: 10, targetRir: 3));
    });
  });

  group('SEED_TRANSFER', () {
    Map<String, ExerciseState> s(String id, double kg) => {id: state(id, workingKg: kg)};
    final cases = <(String, Map<String, ExerciseState>, double?)>[
      ('smith_machine_bench_press', s('machine_chest_press', 50), 40), // 0.8 x
      ('smith_machine_squat', s('leg_press', 100), 40), // 0.4 x
      ('smith_machine_squat', s('leg_press', 20), 20), // max(smith bar 10 + 10, 8)
      ('barbell_romanian_deadlift', s('dumbbell_romanian_deadlift', 20), 32), // 1.6 x per dumbbell
      ('barbell_bent_over_row', s('chest_supported_db_row', 16), 24), // 1.5 x
      ('barbell_bent_over_row', s('one_arm_db_row', 20), 30), // second source
      ('seated_dumbbell_shoulder_press', s('machine_shoulder_press', 40), 14), // 0.35 x
      ('smith_machine_bench_press', const {}, null), // no source yet
      ('machine_chest_press', s('leg_press', 100), null), // not a transfer lift
    ];
    for (final (id, states, expected) in cases) {
      test('$id from ${states.keys.join()} -> $expected', () {
        final v = transferSeed(id, states, gymEq);
        if (expected == null) {
          expect(v, isNull);
        } else {
          expect(v, closeTo(expected, 1e-9));
        }
      });
    }
    test('chest-supported row is preferred over the one-arm row', () {
      final states = {
        'chest_supported_db_row': state('chest_supported_db_row', workingKg: 10),
        'one_arm_db_row': state('one_arm_db_row', workingKg: 30),
      };
      expect(transferSeed('barbell_bent_over_row', states, gymEq), 15);
    });
    test('the seed is rounded down to an available load', () {
      final v = transferSeed('seated_dumbbell_shoulder_press', s('machine_shoulder_press', 35), gymEq)!; // 12.25
      expect(seedWeight(ex('seated_dumbbell_shoulder_press'), gymEq, transferKg: v), 12);
    });
  });
}
