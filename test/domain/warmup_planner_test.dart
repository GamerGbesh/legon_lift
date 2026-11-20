import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/domain/api.dart';

import 'engine_fixtures.dart';

void main() {
  group('planWarmups (SPEC 6.3)', () {
    // (exercise, warmupSets, working kg, expected (kg, reps) list)
    final cases = <(String, Object, double, List<(double, int)>)>[
      // stack (5 kg steps), auto
      ('machine_chest_press', 'auto', 50, [(25, 8), (35, 5)]),
      ('machine_chest_press', 'auto', 60, [(30, 8), (40, 5), (50, 2)]), // 42 -> 40, 51 -> 50
      ('machine_chest_press', 'auto', 25, [(10, 10)]), // W < 30: one set at 0.5W (12.5 -> 10)
      ('machine_chest_press', 'auto', 5, []), // nothing lighter than the lightest pin
      // warmupSets 1 and 0
      ('machine_shoulder_press', 1, 50, [(30, 6)]),
      ('machine_shoulder_press', 0, 50, []),
      // smith: never below the bar (10 kg)
      ('smith_machine_bench_press', 'auto', 40, [(20, 8), (27.5, 5)]),
      ('smith_machine_bench_press', 'auto', 20, [(10, 10)]),
      ('smith_machine_bench_press', 'auto', 12.5, [(10, 10)]), // W <= 1.5 x bar
      ('smith_machine_bench_press', 'auto', 10, []), // the empty bar is the working weight
      // barbell: 20 kg bar
      ('barbell_romanian_deadlift', 'auto', 60, [(30, 8), (40, 5), (50, 2)]),
      ('barbell_romanian_deadlift', 'auto', 25, [(20, 10)]), // 12.5 -> lifted to the bar
      // leg press: min load 0 (sled only)
      ('leg_press', 'auto', 40, [(20, 8), (27.5, 5)]),
      ('leg_press', 'auto', 100, [(50, 8), (70, 5), (85, 2)]),
      ('leg_press', 'auto', 20, [(10, 10)]),
      // dumbbell: one set at half weight, 10 reps
      ('incline_dumbbell_press', 'auto', 12, [(6, 10)]),
      ('incline_dumbbell_press', 1, 13, [(6, 10)]),
      ('incline_dumbbell_press', 'auto', 2, []),
      ('incline_dumbbell_press', 0, 12, []),
      // not loaded
      ('dead_bug', 'auto', 0, []),
    ];
    for (final (id, warmup, w, expected) in cases) {
      test('$id warmupSets=$warmup W=$w -> $expected', () {
        final e = ex(id);
        final got = planWarmups(w, e, item(id, warmupSets: warmup), gymEq);
        expect([for (final s in got) (s.weightKg, s.reps)], expected);
      });
    }

    test('duplicate loads are merged (coarse stack)', () {
      final coarse = ex('machine_chest_press').copyWith(weightIncrementKg: () => 20);
      final got = planWarmups(60, coarse, item(coarse.id), gymEq);
      expect([for (final s in got) (s.weightKg, s.reps)], [(20.0, 8), (40.0, 5)]);
    });

    test('every warm-up is lighter than the working weight, ascending', () {
      for (final e in catalog.exercises.where((e) => e.isLoaded)) {
        for (final w in availableLoads(e, gymEq, null).take(40)) {
          final got = planWarmups(w, e, item(e.id), gymEq);
          for (var i = 0; i < got.length; i++) {
            expect(got[i].weightKg, lessThan(w), reason: '${e.id} at $w');
            if (i > 0) expect(got[i].weightKg, greaterThan(got[i - 1].weightKg), reason: '${e.id} at $w');
          }
        }
      }
    });
  });
}
