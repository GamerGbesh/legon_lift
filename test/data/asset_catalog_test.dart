import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/assets/json_asset_catalog.dart';
import 'package:legon_lift/data/models/models.dart';

import '../fakes/test_catalog.dart';

void main() {
  Object? read(String asset) => jsonDecode(File(asset).readAsStringSync());

  test('loads the three bundled files', () {
    final c = loadTestCatalog();
    expect(c.exercises, hasLength(96));
    expect(c.templates.map((t) => t.programId), containsAll([
      'ppl_3day', 'upper_lower_rotating_3day', 'chest_back_legs_arms_3day', 'upper_lower_2day', 'upper_lower_4day',
    ]));
    expect(c.defaultProgramId, 'ppl_3day');
    final ppl = c.template('ppl_3day');
    expect(ppl.dayOrder, ['push', 'pull', 'legs']);
    expect(ppl.totalWeeks, 14);
    expect(ppl.cycleRestartWeek, 5);
    expect(ppl.phases.map((p) => p.phaseId),
        [PhaseId.foundation, PhaseId.build, PhaseId.progress, PhaseId.deload, PhaseId.retest]);
    expect(ppl.phases.first.rirWeekOffsets[1], 1);
    expect(c.personalization.parq, hasLength(7));
    expect(c.personalization.milestones, isNotEmpty);
    expect(c.personalization.meals, isNotEmpty);
    expect(c.personalization.tips['rest_timer_tips'], isNotEmpty);
    expect(c.personalization.limitationRules.keys, contains('knee'));
  });

  test('exercise JSON is reproduced field for field', () {
    final raw = (read(JsonAssetCatalog.exercisesAsset)! as List).cast<Map<String, dynamic>>();
    final c = loadTestCatalog();
    for (final r in raw) {
      final json = jsonDecode(jsonEncode(c.exercise(r['id'] as String).toJson()));
      expect(json, r, reason: r['id'] as String);
    }
  });

  test('lookups and id migrations', () {
    final c = loadTestCatalog();
    expect(c.exercise('machine_chest_press').name, 'Machine Chest Press');
    expect(c.tryExercise('no_such_exercise'), isNull);
    expect(() => c.exercise('no_such_exercise'), throwsStateError);
    expect(() => c.template('nope'), throwsStateError);
    // Old research ids resolve to the library id.
    expect(c.idMigrations['db_bench_press'], 'dumbbell_bench_press');
    expect(c.exercise('db_bench_press').id, 'dumbbell_bench_press');
  });

  group('schema errors name the file and the field', () {
    final exercises = read(JsonAssetCatalog.exercisesAsset);
    final programs = read(JsonAssetCatalog.programsAsset);
    final personalization = read(JsonAssetCatalog.personalizationAsset);

    Matcher failsWith(String file, String fragment) => throwsA(isA<AssetCatalogException>()
        .having((e) => e.file, 'file', file)
        .having((e) => e.message, 'message', contains(fragment)));

    test('bad enum value in an exercise', () {
      final broken = (jsonDecode(jsonEncode(exercises)) as List)..[0]['loadType'] = 'kettlebell';
      expect(
        () => JsonAssetCatalog.fromDecoded(
            exercisesJson: broken, programsJson: programs, personalizationJson: personalization),
        failsWith(JsonAssetCatalog.exercisesAsset, 'kettlebell'),
      );
    });

    test('missing field', () {
      final broken = (jsonDecode(jsonEncode(exercises)) as List)..[3].remove('restSeconds');
      expect(
        () => JsonAssetCatalog.fromDecoded(
            exercisesJson: broken, programsJson: programs, personalizationJson: personalization),
        failsWith(JsonAssetCatalog.exercisesAsset, 'restSeconds'),
      );
    });

    test('program item pointing at an unknown exercise', () {
      final broken = jsonDecode(jsonEncode(programs)) as Map;
      broken['programs'][0]['phases'][0]['days'][0]['blocks'][1]['items'][0]['exerciseId'] = 'ghost_press';
      expect(
        () => JsonAssetCatalog.fromDecoded(
            exercisesJson: exercises, programsJson: broken, personalizationJson: personalization),
        failsWith(JsonAssetCatalog.programsAsset, 'ghost_press'),
      );
    });

    test('unsupported schema version', () {
      final broken = jsonDecode(jsonEncode(personalization)) as Map..['schemaVersion'] = 2;
      expect(
        () => JsonAssetCatalog.fromDecoded(exercisesJson: exercises, programsJson: programs, personalizationJson: broken),
        failsWith(JsonAssetCatalog.personalizationAsset, 'schemaVersion'),
      );
    });
  });
}
