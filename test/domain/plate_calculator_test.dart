import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/domain/api.dart';

import 'engine_fixtures.dart';

void main() {
  const plates = <double>[25, 20, 15, 10, 5, 2.5, 1.25];

  group('calculatePlates: every 2.5 kg step from 20 to 200 kg on a 20 kg bar is exact', () {
    for (var total = 20.0; total <= 200; total += 2.5) {
      test('$total kg', () {
        final r = calculatePlates(total, 20, plates);
        expect(r.exact, isTrue);
        expect(r.totalKg, total);
        expect(20 + 2 * r.perSide.fold<double>(0, (a, b) => a + b), closeTo(total, 1e-9));
        for (var i = 1; i < r.perSide.length; i++) {
          expect(r.perSide[i], lessThanOrEqualTo(r.perSide[i - 1]), reason: 'heaviest first');
        }
        for (final p in plates) {
          expect(r.perSide.where((x) => x == p).length, lessThanOrEqualTo(4));
        }
      });
    }
  });

  group('calculatePlates: fewest plates, heaviest first', () {
    final cases = <(double, double, List<double>)>[
      (20, 20, []),
      (22.5, 20, [1.25]),
      (60, 20, [20]),
      (100, 20, [25, 15]),
      (140, 20, [25, 25, 10]),
      (200, 20, [25, 25, 25, 15]),
      (72.5, 20, [25, 1.25]),
      (40, 10, [15]), // Smith bar 10 kg
    ];
    for (final (total, bar, perSide) in cases) {
      test('$total kg on $bar kg -> each side $perSide', () {
        final r = calculatePlates(total, bar, plates);
        expect(r.exact, isTrue);
        expect(r.perSide, perSide);
      });
    }
    test('plate text', () {
      expect(plateListText(calculatePlates(72.5, 20, plates).perSide), '25 + 1.25');
      expect(plateListText(const []), 'Nothing');
    });
  });

  group('calculatePlates: impossible targets', () {
    test('between two loads: the lower one, with both neighbours', () {
      final r = calculatePlates(21, 20, plates);
      expect(r.exact, isFalse);
      expect(r.totalKg, 20);
      expect(r.perSide, isEmpty);
      expect(r.lowerKg, 20);
      expect(r.higherKg, 22.5);
    });
    test('below the bar: the empty bar, no lower option', () {
      final r = calculatePlates(15, 20, plates);
      expect(r.exact, isFalse);
      expect(r.totalKg, 20);
      expect(r.lowerKg, isNull);
      expect(r.higherKg, 20);
    });
    test('only 4 of each plate per side', () {
      final r = calculatePlates(270, 20, const [25]); // would need 5 x 25 per side
      expect(r.exact, isFalse);
      expect(r.totalKg, 220);
      expect(r.perSide, [25, 25, 25, 25]);
      expect(r.higherKg, isNull);
    });
    test('a limited plate set', () {
      final r = calculatePlates(50, 20, const [10]);
      expect(r.exact, isFalse);
      expect(r.lowerKg, 40);
      expect(r.higherKg, 60);
    });
  });

  test('platesFor uses the Smith bar weight from the equipment profile', () {
    final r = platesFor(40, ex('smith_machine_squat'), gymEq.copyWith(smithBarKg: 15));
    expect(r.exact, isFalse); // 12.5 kg a side cannot... wait: 12.5 = 10 + 2.5
  }, skip: true);

  test('platesFor: Smith bar from settings, barbell 20 kg', () {
    expect(platesFor(40, ex('smith_machine_squat'), gymEq).perSide, [15]);
    expect(platesFor(40, ex('smith_machine_squat'), gymEq.copyWith(smithBarKg: 15)).perSide, [10, 2.5]);
    expect(platesFor(40, ex('barbell_romanian_deadlift'), gymEq).perSide, [10]);
  });
}
