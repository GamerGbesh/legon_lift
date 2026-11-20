import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/domain/api.dart';

import 'engine_fixtures.dart';

/// The day editor's switches for the cardio finisher and the cool-down stretches: on by default
/// (the builder adds them), and switching them off removes them from the session.
void main() {
  final t = catalog.template('ppl_3day');
  final push = t.phases.first.day('push')!;
  final finisherItem = push.blocks.firstWhere((b) => b.blockType == BlockType.finisher).items.first;
  final stretch = push.blocks
      .firstWhere((b) => b.blockType == BlockType.cooldown)
      .items
      .firstWhere((i) => i.role == ItemRole.stretch);

  ProgramOverride off(ProgramItem item) => ProgramOverride(
        programId: activeFor(t).id,
        dayId: 'push',
        slotKey: item.slotKey(),
        exerciseId: item.exerciseId,
        optionalEnabled: false,
      );

  SessionPlan build({List<ProgramOverride> overrides = const []}) => buildSession(buildInput(
        t,
        dayId: 'push',
        completedNonDeload: completedForWeek(t, 3),
        states: establishedStates(t),
        overrides: overrides,
      ));

  test('finisher and stretches are in by default from week 2', () {
    final plan = build();
    expect(plan.steps.whereType<FinisherStep>(), hasLength(1));
    final cooldown = plan.steps.whereType<CooldownStep>().single;
    expect(cooldown.exerciseIds, contains(stretch.exerciseId));
  });

  test('a finisher switched off is never added', () {
    final plan = build(overrides: [off(finisherItem)]);
    expect(plan.steps.whereType<FinisherStep>(), isEmpty);
    expect(plan.includesFinisher, isFalse);
  });

  test('a stretch switched off is left out of the cool-down', () {
    final plan = build(overrides: [off(stretch)]);
    final ids = plan.steps.whereType<CooldownStep>().expand((c) => c.exerciseIds);
    expect(ids, isNot(contains(stretch.exerciseId)));
  });
}
