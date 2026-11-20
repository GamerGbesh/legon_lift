import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/domain/api.dart';

import 'engine_fixtures.dart';

void main() {
  group('estimateSeconds equals programs.json estimatedMinutes (same model as build_data.py)', () {
    for (final t in catalog.templates) {
      for (final p in t.phases) {
        for (final d in p.days) {
          test('${t.programId} ${p.phaseId.wire} ${d.dayId}', () {
            final core = estimateSeconds(d);
            final optional = estimateSeconds(d, includeOptional: true);
            final finisher = estimateSeconds(d, includeFinisher: true);
            expect(pyRound(core / 60), d.estimatedMinutes.core, reason: 'core ${core}s');
            expect(pyRound(optional / 60), d.estimatedMinutes.withOptionalExercises, reason: 'optional ${optional}s');
            expect(pyRound(finisher / 60), d.estimatedMinutes.withFinisher, reason: 'finisher ${finisher}s');
          });
        }
      }
    }
  });

  group('the duration model (SPEC 6.10)', () {
    ProgramDay day(List<ProgramBlock> blocks) => ProgramDay(dayId: 'd', name: 'D', blocks: blocks);
    ProgramBlock main(List<ProgramItem> items) => ProgramBlock(blockType: BlockType.main, name: 'Main', items: items);

    test('main item: sets x (work + rest) - rest + 90 + warm-up sets x 75', () {
      // 3 x (40 + 120) - 120 + 90 + 2 x 75 = 600
      expect(estimateSeconds(day([main([item('x', sets: 3, rest: 120, warmupSets: 'auto')])])), 600);
      // warmupSets 1 -> 1 x 75
      expect(estimateSeconds(day([main([item('x', sets: 3, rest: 120, warmupSets: 1)])])), 525);
      // per side: 70 s of work
      final perSide = item('x', sets: 2, rest: 60, warmupSets: 0).copyWith(perSide: true);
      expect(estimateSeconds(day([main([perSide])])), 2 * 130 - 60 + 90);
    });

    test('find your weight: sets - 1, no warm-ups, + 3 ramp sets of (work + 75)', () {
      final d = day([main([item('x', sets: 3, rest: 120, warmupSets: 'auto')])]);
      // 2 x 160 - 120 + 90 + 3 x 115 = 635
      expect(estimateSeconds(d, findWeightIds: {'x'}), 635);
    });

    test('hot day: + 30 s per working set of main and superset items', () {
      final d = day([
        main([item('x', sets: 3, rest: 120, warmupSets: 0)]),
        ProgramBlock(blockType: BlockType.superset, name: 'S', supersetGroup: 'A', restBetweenRoundsSeconds: 60, items: [
          item('a', sets: 2, rest: 0, warmupSets: 0),
          item('b', sets: 2, rest: 60, warmupSets: 0),
        ]),
      ]);
      expect(estimateSeconds(d, hotDay: true) - estimateSeconds(d), 30 * (3 + 4));
    });

    test('superset: rounds x (40 x items + 20 + round rest) - round rest + 90', () {
      final d = day([
        ProgramBlock(blockType: BlockType.superset, name: 'S', supersetGroup: 'A', restBetweenRoundsSeconds: 60, items: [
          item('a', sets: 3, rest: 0, warmupSets: 0),
          item('b', sets: 2, rest: 60, warmupSets: 0),
        ]),
      ]);
      expect(estimateSeconds(d), 3 * (80 + 20 + 60) - 60 + 90);
    });

    test('warm-up: cardio + 120 s of drills (180 s for the "~8 min" warm-up); cool-down 240 s', () {
      final cardio = item('general_warmup_cardio', sets: 1, reps: null, durationSeconds: 300, rir: null, rest: 0,
          role: ItemRole.warmup, warmupSets: 0);
      final drill = item('arm_circles', sets: 1, reps: (10, 10), rir: null, rest: 0, role: ItemRole.warmup, warmupSets: 0);
      ProgramBlock warm(String name, List<ProgramItem> items) =>
          ProgramBlock(blockType: BlockType.warmup, name: name, items: items);
      expect(estimateSeconds(day([warm('Warm-up (~7 min)', [cardio, drill])])), 420);
      expect(estimateSeconds(day([warm('Warm-up (~8 min)', [cardio, drill])])), 480);
      expect(estimateSeconds(day([warm('Warm-up (~7 min)', [cardio.copyWith(durationSeconds: () => 180), drill])])), 300);
      expect(estimateSeconds(day([warm('Warm-up (~7 min)', [drill])])), 120);
      expect(estimateSeconds(day([warm('Warm-up (~7 min)', [cardio])])), 300);
      expect(
          estimateSeconds(day([
            ProgramBlock(blockType: BlockType.cooldown, name: 'Cool-down', items: [drill]),
          ])),
          240);
    });

    test('optional items and the finisher only when asked', () {
      final d = day([
        main([item('x', sets: 2, rest: 60, warmupSets: 0), item('y', sets: 2, rest: 60, warmupSets: 0).copyWith(optional: true)]),
        ProgramBlock(blockType: BlockType.finisher, name: 'F', optional: true, items: [
          item('treadmill_incline_walk', sets: 1, reps: null, durationSeconds: 480, rir: null, rest: 0,
              role: ItemRole.cardio, warmupSets: 0),
        ]),
      ]);
      const one = 2 * 100 - 60 + 90;
      expect(estimateSeconds(d), one);
      expect(estimateSeconds(d, includeOptional: true), 2 * one);
      expect(estimateSeconds(d, includeFinisher: true), one + 480);
    });
  });
}
