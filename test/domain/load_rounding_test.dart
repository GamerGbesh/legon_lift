import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/domain/api.dart';

import 'engine_fixtures.dart';

void main() {
  group('increment (SPEC 6.1)', () {
    final chest = ex('machine_chest_press'); // exercise step 5
    final cases = <(String, ExercisePrefs?, ProgramItem?, double)>[
      ('prefs win', const ExercisePrefs(exerciseId: 'machine_chest_press', incrementKg: 2.5), item(chest.id, inc: 10), 2.5),
      ('then the item', null, item(chest.id, inc: 10), 10),
      ('then the exercise', null, item(chest.id), 5),
      ('no item', null, null, 5),
    ];
    for (final (name, prefs, it, expected) in cases) {
      test(name, () => expect(increment(chest, it, prefs), expected));
    }
    test('falls back to 2.5 kg', () {
      expect(increment(chest.copyWith(weightIncrementKg: () => null), null, null), 2.5);
    });
  });

  group('availableLoads by load type', () {
    test('dumbbell: the rack, sorted (default 2..40 in 2 kg steps)', () {
      final loads = availableLoads(ex('incline_dumbbell_press'), gymEq, null);
      expect(loads.first, 2);
      expect(loads.last, 40);
      expect(loads, hasLength(20));
      final custom = gymEq.copyWith(dumbbellsKg: [12.5, 5, 7.5]);
      expect(availableLoads(ex('incline_dumbbell_press'), custom, null), [5, 7.5, 12.5]);
      expect(availableLoads(ex('incline_dumbbell_press'), gymEq.copyWith(dumbbellsKg: []), null), hasLength(20));
    });

    test('smith: bar (10 kg) + 2 x per-side plate sums', () {
      final loads = availableLoads(ex('smith_machine_squat'), gymEq, null);
      expect(loads.take(5), [10, 12.5, 15, 17.5, 20]);
      expect(loads.last, 10 + 2 * 150);
    });

    test('barbell: 20 kg bar', () {
      final loads = availableLoads(ex('barbell_romanian_deadlift'), gymEq, null);
      expect(loads.take(3), [20, 22.5, 25]);
      expect(loads.last, 320);
    });

    test('plate loaded: added plates only, 0 allowed', () {
      final loads = availableLoads(ex('leg_press'), gymEq, null);
      expect(loads.take(4), [0, 2.5, 5, 7.5]);
      expect(loads.last, 300);
    });

    test('stack and cable: k x increment for k = 1..60', () {
      final stack = availableLoads(ex('machine_chest_press'), gymEq, null);
      expect(stack.first, 5);
      expect(stack.last, 300);
      expect(stack, hasLength(60));
      final cable = availableLoads(ex('triceps_rope_pushdown'), gymEq, null);
      expect(cable.take(3), [2.5, 5, 7.5]);
      const prefs = ExercisePrefs(exerciseId: 'triceps_rope_pushdown', incrementKg: 1.25);
      expect(availableLoads(ex('triceps_rope_pushdown'), gymEq, prefs).take(3), [1.25, 2.5, 3.75]);
    });

    test('bodyweight and time: {0}', () {
      expect(availableLoads(ex('dead_bug'), gymEq, null), [0]);
      expect(availableLoads(ex('plank'), gymEq, null), [0]);
    });

    test('loads are ascending and distinct for every exercise', () {
      for (final e in catalog.exercises) {
        final loads = availableLoads(e, gymEq, null);
        for (var i = 1; i < loads.length; i++) {
          expect(loads[i], greaterThan(loads[i - 1]), reason: e.id);
        }
      }
    });
  });

  group('achievablePerSide', () {
    test('each plate size at most 4 times per side', () {
      expect(achievablePerSide([20]), [0, 20, 40, 60, 80]);
      expect(achievablePerSide([25, 2.5]).contains(105), isTrue); // 4 x 25 + 2 x 2.5
      expect(achievablePerSide([25]).contains(125), isFalse); // would need 5 x 25
    });
    test('capped at 150 kg per side', () {
      final sums = achievablePerSide([25, 20, 15, 10, 5, 2.5, 1.25]);
      expect(sums.first, 0);
      expect(sums.last, 150);
      expect(sums.contains(1.25), isTrue);
      expect(sums.contains(3.75), isTrue);
    });
  });

  group('roundToAvailable / roundDown / nextUp (table)', () {
    // (exercise, input, nearest, down, up)
    final cases = <(String, double, double, double, double)>[
      // stack, 5 kg steps
      ('machine_chest_press', 17.5, 15, 15, 20), // tie -> lower
      ('machine_chest_press', 17.6, 20, 15, 20),
      ('machine_chest_press', 20, 20, 20, 25),
      ('machine_chest_press', 2, 5, 5, 5), // below the stack: smallest
      ('machine_chest_press', 300, 300, 300, 300), // top of the stack: nextUp stays
      // dumbbell, 2 kg steps from 2
      ('incline_dumbbell_press', 11, 10, 10, 12),
      ('incline_dumbbell_press', 11.1, 12, 10, 12),
      ('incline_dumbbell_press', 1, 2, 2, 2),
      ('incline_dumbbell_press', 40, 40, 40, 40),
      // smith, bar 10 + plates
      ('smith_machine_bench_press', 11.25, 10, 10, 12.5), // tie -> lower
      ('smith_machine_bench_press', 9, 10, 10, 10),
      ('smith_machine_bench_press', 41.3, 42.5, 40, 42.5),
      // barbell, bar 20
      ('barbell_romanian_deadlift', 43.6, 42.5, 42.5, 45),
      ('barbell_romanian_deadlift', 15, 20, 20, 20),
      // plate loaded (leg press)
      ('leg_press', 0, 0, 0, 2.5),
      ('leg_press', 61, 60, 60, 62.5),
      // bodyweight
      ('dead_bug', 12, 0, 0, 12),
    ];
    for (final (id, kg, nearest, down, up) in cases) {
      test('$id $kg -> $nearest / $down / $up', () {
        final e = ex(id);
        expect(roundToAvailable(kg, e, gymEq, null), nearest);
        expect(roundDown(kg, e, gymEq, null), down);
        expect(nextUp(kg, e, gymEq, null), up);
      });
    }

    test('a custom Smith bar weight moves every load', () {
      final eq = gymEq.copyWith(smithBarKg: 15);
      expect(roundDown(16, ex('smith_machine_squat'), eq, null), 15);
      expect(nextUp(15, ex('smith_machine_squat'), eq, null), 17.5);
    });

    test('a smaller dumbbell rack', () {
      final eq = gymEq.copyWith(dumbbellsKg: [5, 10, 15, 20]);
      expect(nextUp(10, ex('incline_dumbbell_press'), eq, null), 15);
      expect(roundDown(14, ex('incline_dumbbell_press'), eq, null), 10);
      expect(roundToAvailable(12.5, ex('incline_dumbbell_press'), eq, null), 10);
    });
  });
}
