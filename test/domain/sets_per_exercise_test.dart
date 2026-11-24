import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/domain/api.dart';

import 'engine_fixtures.dart';

/// Settings > Sets per exercise: every lift gets at least that many working sets on a normal
/// training day; warm-up, cool-down and deload days keep the program's counts.
void main() {
  final t = catalog.template('ppl_3day');
  const lifts = {ItemRole.primary, ItemRole.secondary, ItemRole.accessory};

  List<ExerciseStep> lifted(SessionPlan plan) =>
      [for (final s in plan.steps.whereType<ExerciseStep>()) if (lifts.contains(s.item.role)) s];

  SessionPlan build({int sets = 3, int week = 3, int minutes = 90}) => buildSession(buildInput(
        t,
        dayId: 'push',
        minutes: minutes,
        completedNonDeload: completedForWeek(t, week),
        states: establishedStates(t),
        appSettings: settings().copyWith(setsPerExercise: sets),
      ));

  test('defaults to 3 sets per exercise', () {
    expect(AppSettings(equipment: settings().equipment).setsPerExercise, 3);
  });

  test('every lift gets 3 working sets', () {
    final steps = lifted(build());
    expect(steps, isNotEmpty);
    for (final s in steps) {
      expect(s.item.sets, 3, reason: s.item.exerciseId);
      expect(s.rx.working, hasLength(3), reason: s.item.exerciseId);
    }
  });

  test('a higher setting raises every lift', () {
    for (final s in lifted(build(sets: 4))) {
      expect(s.rx.working, hasLength(4), reason: s.item.exerciseId);
    }
  });

  test('the time ladder does not trim below the setting', () {
    for (final s in lifted(build(minutes: 45))) {
      expect(s.item.sets, greaterThanOrEqualTo(3), reason: s.item.exerciseId);
    }
  });

  test('survives a JSON round trip', () {
    final s = settings().copyWith(setsPerExercise: 4);
    expect(AppSettings.fromJson(s.toJson()).setsPerExercise, 4);
  });
}
