import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/domain/api.dart';

import 'engine_fixtures.dart';

void main() {
  final ppl = catalog.template('ppl_3day'); // 3 days, 14 weeks, restart at 5
  final fourDay = catalog.template('upper_lower_4day');

  group('trainingWeek (SPEC 6.7)', () {
    // (template, startWeek, completed non-deload sessions, expected week)
    final cases = <(ProgramTemplate, int, int, int)>[
      (ppl, 1, 0, 1),
      (ppl, 1, 2, 1),
      (ppl, 1, 3, 2),
      (ppl, 1, 38, 13),
      (ppl, 1, 39, 14),
      (ppl, 1, 42, 5), // raw 15 -> 5
      (ppl, 1, 45, 6), // raw 16 -> 6
      (ppl, 1, 69, 14), // raw 24 -> 14
      (ppl, 1, 72, 5), // raw 25 -> 5 again
      (ppl, 5, 0, 5), // "Start at Phase 2"
      (ppl, 5, 30, 15 - 14 + 4), // raw 15 -> 5
      (fourDay, 1, 4, 2),
      (fourDay, 1, 7, 2),
    ];
    for (final (t, start, done, expected) in cases) {
      test('${t.programId} start $start, $done done -> week $expected', () {
        expect(trainingWeek(t, activeFor(t, startWeek: start), done), expected);
      });
    }

    test('custom programs are always week 1', () {
      final custom = ProgramTemplate(
        programId: 'custom',
        name: 'Mine',
        splitType: 'custom',
        splitKey: SplitKey.custom,
        daysPerWeek: 3,
        dayOrder: const ['a'],
        phases: [Phase(phaseId: PhaseId.custom, name: 'Custom', weeks: const [1], unlocks: Phase.allUnlocks, days: const [])],
      );
      expect(trainingWeek(custom, activeFor(custom), 99), 1);
    });

    test('rawTrainingWeek keeps counting past the last week', () {
      expect(rawTrainingWeek(ppl, activeFor(ppl), 42), 15);
      expect(wrapTrainingWeek(ppl, 15), 5);
      expect(wrapTrainingWeek(ppl, 14), 14);
    });
  });

  group('phaseFor', () {
    final cases = <(int, PhaseId)>[
      (1, PhaseId.foundation),
      (4, PhaseId.foundation),
      (5, PhaseId.build),
      (8, PhaseId.build),
      (9, PhaseId.progress),
      (12, PhaseId.progress),
      (13, PhaseId.deload),
      (14, PhaseId.retest),
    ];
    for (final (week, id) in cases) {
      test('week $week -> ${id.wire}', () => expect(phaseFor(ppl, week).phaseId, id));
    }
  });

  group('effectiveRir', () {
    final foundation = phaseFor(ppl, 1); // week 1: +1
    final progress = phaseFor(ppl, 11); // weeks 11-12: -1, floors primary/secondary 1, accessory 0
    final cases = <(String, ProgramItem, Phase, int, int?)>[
      ('week 1 adds one', item('a', rir: 3), foundation, 1, 4),
      ('capped at 4', item('a', rir: 4), foundation, 1, 4),
      ('week 2 no offset', item('a', rir: 3), foundation, 2, 3),
      ('week 11 minus one', item('a', rir: 2), progress, 11, 1),
      ('primary floor 1', item('a', rir: 1), progress, 11, 1),
      ('accessory floor 0', item('a', rir: 1, role: ItemRole.accessory), progress, 11, 0),
      ('no target', item('a', rir: null), progress, 11, null),
    ];
    for (final (name, it, p, week, expected) in cases) {
      test(name, () => expect(effectiveRir(it, p, week), expected));
    }
  });

  group('gapRule (SPEC 6.8)', () {
    final now = DateTime(2026, 11, 20, 18);
    DateTime daysAgo(int d) => DateTime(2026, 11, 20 - d, 18);
    test('first session ever: none', () => expect(gapRule(null, now), GapRule.none));
    test('9 days: none', () => expect(gapRule(daysAgo(9), now), GapRule.none));
    for (final d in [10, 15, 21]) {
      test('$d days: 10% lighter, +1 RIR', () {
        final g = gapRule(daysAgo(d), now);
        expect(g.loadMultiplier, 0.9);
        expect(g.rirBonus, 1);
        expect(g.forceFindWeightPrimary, isFalse);
        expect(g.notice, 'Welcome back: a bit lighter today');
      });
    }
    for (final d in [22, 60]) {
      test('$d days: 20% lighter, RIR 4, primaries find their weight', () {
        final g = gapRule(daysAgo(d), now);
        expect(g.loadMultiplier, 0.8);
        expect(g.rirBonus, 4);
        expect(g.forceFindWeight(ItemRole.primary), isTrue);
        expect(g.forceFindWeight(ItemRole.secondary), isFalse);
        expect(g.notice, isNotNull);
      });
    }
    test('calendar days, not 24 h blocks: 23:30 to 00:30 ten days later is 10 days', () {
      expect(gapRule(DateTime(2026, 11, 10, 23, 30), DateTime(2026, 11, 20, 0, 30)).loadMultiplier, 0.9);
    });
    test('recent illness: an easy (deload) session, combined with the gap', () {
      final g = gapRule(daysAgo(2), now, recentIllness: true);
      expect(g.treatAsDeload, isTrue);
      expect(g.loadMultiplier, 1.0);
      final both = gapRule(daysAgo(14), now, recentIllness: true);
      expect(both.treatAsDeload, isTrue);
      expect(both.loadMultiplier, 0.9);
      expect(both.notice, contains('Welcome back'));
      expect(both.notice, contains('ill'));
    });
  });
}
