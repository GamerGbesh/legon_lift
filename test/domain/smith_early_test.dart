import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/domain/api.dart';

import 'engine_fixtures.dart';

/// Settings > Smith machine from week 1: Smith exercises are offered as swaps in Foundation.
void main() {
  final t = catalog.template('ppl_3day');
  final foundation = t.phases.first;
  final incline = foundation.day('push')!.blocks
      .expand((b) => b.items)
      .firstWhere((i) => i.exerciseId == 'incline_dumbbell_press');

  List<String> swaps({required bool smithEarly}) => [
        for (final o in suggestSwaps(ex('incline_dumbbell_press'), incline, catalog, gymEq, foundation, const {},
            const {}, const {},
            max: 20, smithEarly: smithEarly))
          o.exercise.id,
      ];

  test('Foundation keeps Smith exercises locked by default', () {
    expect(foundation.unlocks, isNot(contains(smithUnlockKey)));
    expect(swaps(smithEarly: false), isNot(contains('smith_machine_incline_press')));
  });

  test('smithEarly offers the Smith incline press in week 1', () {
    expect(swaps(smithEarly: true), contains('smith_machine_incline_press'));
  });

  test('a limitation that locks the Smith machine still wins', () {
    final rules = {
      'test_lock': {
        'lock_unlocks': [smithUnlockKey],
      },
    };
    expect(effectiveUnlocks(foundation, ['test_lock'], rules, smithEarly: true), isNot(contains(smithUnlockKey)));
  });

  test('off by default and survives a JSON round trip', () {
    expect(settings().smithEarly, isFalse);
    expect(AppSettings.fromJson(settings().copyWith(smithEarly: true).toJson()).smithEarly, isTrue);
  });
}
