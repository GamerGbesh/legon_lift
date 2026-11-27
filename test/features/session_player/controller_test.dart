import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/domain/api.dart';
import 'package:legon_lift/state/session_player_controller.dart';

import 'player_harness.dart';

void main() {
  late PlayerHarness h;

  tearDown(() => h.dispose());

  group('loading', () {
    test('opens at the warm-up with the screen kept awake', () async {
      h = await PlayerHarness.start();
      final c = await h.open();
      expect(c.status, PlayerStatus.playing);
      expect(c.currentStop?.kind, StopKind.warmupCardio);
      expect(c.stops.map((s) => s.kind), [
        StopKind.warmupCardio,
        StopKind.mobility,
        StopKind.exercise,
        StopKind.exercise,
        StopKind.exercise,
        StopKind.exercise,
        StopKind.exercise,
        StopKind.cooldown,
      ]);
      expect(h.app.wakelock.enabled, isTrue);
    });

    test('keepAwake off leaves the screen alone', () async {
      h = await PlayerHarness.start(settings: (s) => s.copyWith(keepAwake: false));
      await h.open();
      expect(h.app.wakelock.enableCount, 0);
    });

    test('an unknown session is reported as missing', () async {
      h = await PlayerHarness.start();
      h.app.sessions.sessions.remove(h.sessionId);
      final c = await h.open();
      expect(c.status, PlayerStatus.missing);
    });
  });

  group('logging sets', () {
    test('rows are pre-filled from the prescription with warm-ups first', () async {
      h = await PlayerHarness.start(plan: (p, app) {
        final main = Plans.firstMain(1)(p, app);
        final step = main.steps.single as ExerciseStep;
        return main.copyWith(steps: [
          step.copyWith(
            rx: step.rx.copyWith(warmups: const [
              PlannedSet(kind: SetKind.warmup, weightKg: 10, reps: 8),
            ]),
          ),
        ]);
      });
      final c = await h.open();
      final rows = c.rowsOf();
      expect(rows.first.label, 'W1');
      expect(rows.first.state, RowState.active);
      expect(rows.where((r) => r.kind == SetKind.working).length, 3);
      expect(rows[1].label, '1');
      expect(rows[1].state, RowState.pending);
    });

    test('logSet writes the set and the rest deadline together, then rests', () async {
      h = await PlayerHarness.start(plan: Plans.mainOnly);
      final c = await h.open();
      final row = c.activeRow!;
      final writesBefore = h.app.sessions.writes;
      c.setDraftWeight(row.weightKg + 5);
      c.setDraftReps(11);
      await c.logSet();

      final se = h.session.exercises.firstWhere((e) => e.id == row.se.id);
      final set = se.sets.single;
      expect(set.weightKg, row.weightKg + 5);
      expect(set.reps, 11);
      expect(set.targetKg, row.weightKg);
      expect(set.kind, SetKind.working);
      // One logSet write (set + cursor) plus the "active" status.
      expect(h.app.sessions.writes - writesBefore, lessThanOrEqualTo(2));
      expect(h.session.cursor?.restEndsAt, isNotNull);
      expect(c.rest, isNotNull);
      expect(c.rest!.questions.single.id, set.id);
      expect(h.app.restAlarm.scheduledAt, h.session.cursor!.restEndsAt);
      expect(h.app.restAlarm.permissionRequests, 1);
      expect(h.app.haptics.lights, 1);
      // The next row carries the weight actually used.
      expect(c.activeRow!.weightKg, row.weightKg + 5);
    });

    test('answerRir stores the answer; skipRest clears the deadline and the alarm', () async {
      h = await PlayerHarness.start(plan: Plans.mainOnly);
      final c = await h.open();
      await c.logSet();
      final setId = c.rest!.questions.single.id;
      await c.answerRir(setId, 2);
      expect(h.session.allSets.single.rir, 2);
      expect(c.rest!.questions, isEmpty);
      await c.skipRest();
      expect(c.rest, isNull);
      expect(h.session.cursor!.restEndsAt, isNull);
      expect(h.app.restAlarm.isScheduled, isFalse);
    });

    test('rest over in the foreground: light haptic at 10 s, then heavy pulses and the sound', () async {
      h = await PlayerHarness.start(plan: Plans.mainOnly);
      final c = await h.open();
      await c.logSet();
      final total = c.rest!.remainingSec(c.now);
      h.app.clock.advance(Duration(seconds: total - 5));
      await c.tick();
      expect(h.app.haptics.lights, 2);
      h.app.clock.advance(const Duration(seconds: 6));
      await c.tick();
      expect(h.app.haptics.heavyTriples, 1);
      expect(h.app.sound.restDones, 1);
      expect(c.rest!.isOver(c.now), isTrue);
      expect(h.app.restAlarm.isScheduled, isFalse);
      await c.tick();
      expect(h.app.sound.restDones, 1, reason: 'signalled once');
    });

    test('adjustRest moves the deadline and reschedules the alarm', () async {
      h = await PlayerHarness.start(plan: Plans.mainOnly);
      final c = await h.open();
      await c.logSet();
      final before = h.session.cursor!.restEndsAt!;
      await c.adjustRest(15);
      expect(h.session.cursor!.restEndsAt, before.add(const Duration(seconds: 15)));
      expect(h.app.restAlarm.scheduledAt, h.session.cursor!.restEndsAt);
      await c.adjustRest(-15);
      expect(h.session.cursor!.restEndsAt, before);
    });

    test('undoLast deletes the set and restores the cursor', () async {
      h = await PlayerHarness.start(plan: Plans.mainOnly);
      final c = await h.open();
      final first = c.activeRow!;
      await c.logSet();
      expect(c.canUndo, isTrue);
      await c.undoLast();
      expect(h.session.allSets, isEmpty);
      expect(c.activeRow!.setIndex, first.setIndex);
      expect(c.rest, isNull);
      expect(h.app.restAlarm.isScheduled, isFalse);
    });

    test('rirPrompt "last set only" asks only after the final working set', () async {
      h = await PlayerHarness.start(
        plan: Plans.firstMain(1),
        settings: (s) => s.copyWith(rirPrompt: RirPrompt.last),
      );
      final c = await h.open();
      await c.logSet();
      expect(c.rest!.questions, isEmpty);
      await c.skipRest();
      await c.logSet();
      await c.skipRest();
      await c.logSet();
      expect(c.rest!.questions, hasLength(1));
    });

    test('autoRest off: no countdown, the sheet only asks its question', () async {
      h = await PlayerHarness.start(plan: Plans.mainOnly, settings: (s) => s.copyWith(autoRest: false));
      final c = await h.open();
      await c.logSet();
      expect(c.rest, isNotNull);
      expect(c.rest!.endsAt, isNull);
      expect(h.app.restAlarm.scheduleCount, 0);
    });
  });

  group('dead ends', () {
    test('skipSet writes nothing and the row shows skipped', () async {
      h = await PlayerHarness.start(plan: Plans.mainOnly);
      final c = await h.open();
      await c.skipSet();
      final rows = c.rowsOf();
      expect(rows.first.state, RowState.skipped);
      expect(rows[1].state, RowState.active);
      expect(h.session.allSets, isEmpty);
    });

    test('editSet and deleteSet with restore', () async {
      h = await PlayerHarness.start(plan: Plans.mainOnly);
      final c = await h.open();
      await c.logSet();
      await c.skipRest();
      final set = h.session.allSets.single;
      await c.editSet(set.id, weightKg: 42.5, reps: 7, rir: 1);
      final edited = h.session.allSets.single;
      expect((edited.weightKg, edited.reps, edited.rir), (42.5, 7, 1));
      final removed = await c.deleteSet(set.id);
      expect(h.session.allSets, isEmpty);
      await c.restoreSet(removed!);
      expect(h.session.allSets.single.id, set.id);
    });

    test('jumpTo plays any stop; skipped stops stay reachable', () async {
      h = await PlayerHarness.start();
      final c = await h.open();
      final target = c.stops.where((s) => s.kind == StopKind.exercise).last;
      await c.jumpTo(target.id);
      expect(c.currentStop!.id, target.id);
      expect(h.session.cursor!.stepIndex, target.id);
      // The warm-up is still pending and comes back after this exercise's sets.
      expect(c.stops.first.isPending, isTrue);
    });

    test('a finished exercise can be reopened to add a forgotten set', () async {
      h = await PlayerHarness.start(plan: Plans.mainOnly);
      final c = await h.open();
      final first = c.currentStop!;
      final se = first.exercise!;
      while (c.currentStop!.id == first.id) {
        await c.logSet();
        await c.skipRest();
      }
      final logged = h.session.allSets.where((x) => x.sessionExerciseId == se.id).length;
      expect(c.stops.firstWhere((s) => s.id == first.id).isPending, isFalse);

      await c.jumpTo(first.id);
      expect(c.currentStop!.id, first.id);
      await c.addSet();
      expect(c.activeRow, isNotNull);
      expect(c.activeRow!.se.id, se.id);
      await c.logSet();
      expect(h.session.allSets.where((x) => x.sessionExerciseId == se.id), hasLength(logged + 1));
    });

    test('doNextFirst moves the exercise after the next one; a primary only once', () async {
      h = await PlayerHarness.start(plan: Plans.mainOnly);
      final c = await h.open();
      final first = c.currentStop!;
      expect(first.members.single.item.role, ItemRole.primary);
      final second = c.stops[1];
      expect(c.canDoNextFirst(), isTrue);
      await c.doNextFirst();
      expect(c.currentStop!.id, second.id);
      expect(c.stops.map((s) => s.id).take(2), [second.id, first.id]);
      // Back on the primary: it already moved one slot.
      await c.jumpTo(first.id);
      expect(c.canDoNextFirst(), isFalse);
    });

    test('swap just for today keeps the slot and the set count', () async {
      h = await PlayerHarness.start(plan: Plans.mainOnly);
      final c = await h.open();
      final se = c.currentStop!.exercise!;
      final options = c.swapOptions(se);
      expect(options, isNotEmpty);
      final alt = options.first.exercise;
      final ask = await c.swap(se, alt.id, SwapScope.today);
      expect(ask, isFalse);
      final swapped = h.session.exercises.firstWhere((e) => e.id == se.id);
      expect(swapped.exerciseId, alt.id);
      expect(swapped.originalExerciseId, se.exerciseId);
      expect(swapped.slotKey, se.slotKey);
      expect(swapped.target.working.length, se.target.working.length);
      expect(h.app.programs.overrideRows, isEmpty);
      expect(c.activeRow!.exercise.id, alt.id);
    });

    test('not at this gym hides the exercise and replaces it in the program', () async {
      h = await PlayerHarness.start(plan: Plans.mainOnly);
      final c = await h.open();
      final se = c.currentStop!.exercise!;
      final alt = c.swapOptions(se).first.exercise;
      await c.swap(se, alt.id, SwapScope.notAtGym);
      expect((await h.app.exerciseStates.prefs(se.exerciseId)).hidden, isTrue);
      final o = h.app.programs.overrideRows.single;
      expect((o.dayId, o.slotKey, o.exerciseId), ('push', se.slotKey, alt.id));
    });

    test('markPain flags the last set and remembers the date', () async {
      h = await PlayerHarness.start(plan: Plans.mainOnly);
      final c = await h.open();
      await c.logSet();
      final flagged = await c.markPain();
      expect(flagged, isTrue);
      expect(h.session.allSets.single.painFlag, isTrue);
      final se = c.rowsOf().first.se;
      expect((await h.app.exerciseStates.prefs(se.exerciseId)).lastPainAt, h.app.clock.now());
    });

    test('skipExercise(pain) moves on and the exercise is skipped', () async {
      h = await PlayerHarness.start(plan: Plans.mainOnly);
      final c = await h.open();
      final first = c.currentStop!;
      await c.skipExercise(SkipReason.pain);
      final se = h.session.exercises.firstWhere((e) => e.id == first.exercise!.id);
      expect(se.status, SessionExerciseStatus.skipped);
      expect(se.skipReason, SkipReason.pain);
      expect(c.currentStop!.id, isNot(first.id));
    });

    test('last exercise busy: a 2-minute wait timer on the rest sheet', () async {
      h = await PlayerHarness.start(plan: Plans.firstMain(1));
      final c = await h.open();
      expect(c.isLastExercise, isTrue);
      expect(c.canDoNextFirst(), isFalse);
      await c.startWait();
      expect(c.rest!.kind, RestKind.wait);
      expect(c.rest!.remainingSec(c.now), PlayerTiming.waitSec);
    });

    test('no machine free: warm-up drills run twice', () async {
      h = await PlayerHarness.start();
      final c = await h.open();
      final drills = c.stops[1];
      await c.cardioUnavailable();
      final cardio = h.session.exercises.firstWhere((e) => e.exerciseId == 'general_warmup_cardio');
      expect(cardio.status, SessionExerciseStatus.skipped);
      expect(cardio.skipReason, SkipReason.busy);
      expect(c.currentStop!.id, drills.id);
      expect(c.stopTimer!.rounds, 2);
      expect(c.stopTimer!.itemCount, drills.items.length * 2);
    });
  });

  group('add an exercise', () {
    const added = 'diverging_lat_pulldown';

    test('on a fresh exercise it plays now, before it; the main ones keep their order', () async {
      h = await PlayerHarness.start(plan: Plans.mainOnly);
      final c = await h.open();
      final first = c.currentStop!;
      final mainsBefore = [for (final s in c.stops) s.id];
      await c.addExercise(added);

      final now = c.currentStop!;
      expect(now.isAdded, isTrue);
      expect(now.exercise!.exerciseId, added);
      expect(c.stops.first.id, now.id);
      expect([for (final s in c.stops.skip(1)) s.id], mainsBefore);
      expect(c.activeRow!.exercise.id, added);
      expect(first.isAdded, isFalse);

      // Logs like any other exercise.
      await c.logSet();
      expect(h.session.allSets.where((x) => x.exerciseId == added), hasLength(1));
    });

    test('after a logged set it comes next and the current exercise stays', () async {
      h = await PlayerHarness.start(plan: Plans.mainOnly);
      final c = await h.open();
      final first = c.currentStop!;
      await c.logSet();
      await c.addExercise(added);
      expect(c.currentStop!.id, first.id);
      expect(c.stops[1].isAdded, isTrue);
      expect(c.takeMessage(), contains('comes next'));
    });

    test('during the warm-up it goes before the first exercise', () async {
      h = await PlayerHarness.start();
      final c = await h.open();
      expect(c.currentStop!.kind, StopKind.warmupCardio);
      await c.addExercise(added);
      expect(c.currentStop!.kind, StopKind.warmupCardio);
      final firstMain = c.stops.firstWhere((s) => s.kind.isMain);
      expect(firstMain.isAdded, isTrue);
      expect(c.stops.last.kind, StopKind.cooldown);
    });

    test('remove deletes it with its sets and goes back to the plan', () async {
      h = await PlayerHarness.start(plan: Plans.mainOnly);
      final c = await h.open();
      final first = c.currentStop!;
      await c.addExercise(added);
      await c.logSet();
      await c.skipRest();
      expect(c.canRemoveExercise, isTrue);
      await c.removeAddedExercise();

      expect(h.session.exercises.any((e) => e.exerciseId == added), isFalse);
      expect(h.session.allSets.any((x) => x.exerciseId == added), isFalse);
      expect(c.currentStop!.id, first.id);
      expect(c.stops.any((s) => s.isAdded), isFalse);
      expect(c.canRemoveExercise, isFalse);
    });

    test("the plan's own exercises cannot be removed", () async {
      h = await PlayerHarness.start(plan: Plans.mainOnly);
      final c = await h.open();
      expect(c.canRemoveExercise, isFalse);
      final count = h.session.exercises.length;
      await c.removeAddedExercise();
      expect(h.session.exercises, hasLength(count));
    });

    test('survives a kill and is saved with the workout', () async {
      h = await PlayerHarness.start(plan: Plans.firstMain(1));
      var c = await h.open();
      await c.addExercise(added);
      final stop = c.currentStop!.id;
      await c.logSet();
      await c.skipRest();
      c = await h.open();
      expect(c.currentStop!.id, stop);
      while (c.currentStop?.id == stop) {
        await c.logSet();
        await c.skipRest();
      }
      expect(c.stops.where((s) => s.isAdded), hasLength(1));
      await c.endWorkout(save: true);
      expect(h.session.status, SessionStatus.completed);
      final se = h.session.exercises.singleWhere((e) => e.exerciseId == added);
      expect(se.status, SessionExerciseStatus.done);
      expect(se.sets, isNotEmpty);
    });

    test("picker leaves out today's exercises and cardio", () async {
      h = await PlayerHarness.start(plan: Plans.mainOnly);
      final c = await h.open();
      final ex = c.addExerciseExcludes;
      expect(ex, containsAll(h.session.exercises.map((e) => e.exerciseId)));
      expect(ex, contains('bike_steady_state'));
      expect(ex, isNot(contains(added)));
    });
  });

  group('timed stops', () {
    test('warm-up timer is deadline based and logs the cardio when done', () async {
      h = await PlayerHarness.start();
      final c = await h.open();
      final t = c.stopTimer!;
      expect(t.totalSec, 300);
      await c.startTimer();
      expect(h.session.cursor!.restEndsAt, h.app.clock.now().add(const Duration(seconds: 300)));
      h.app.clock.advance(const Duration(seconds: 120));
      await c.pauseTimer();
      expect(c.stopTimer!.remainingSec(c.now), 180);
      await c.startTimer();
      h.app.clock.advance(const Duration(seconds: 181));
      await c.tick();
      final cardio = h.session.exercises.firstWhere((e) => e.exerciseId == 'general_warmup_cardio');
      expect(cardio.status, SessionExerciseStatus.done);
      expect(cardio.sets.single.durationSec, 300);
      expect(c.currentStop!.kind, StopKind.mobility);
      expect(h.app.sound.restDones, 1);
    });

    test('checklist drills advance item by item', () async {
      h = await PlayerHarness.start();
      final c = await h.open();
      await c.skipItem();
      expect(c.currentStop!.kind, StopKind.mobility);
      final n = c.stopTimer!.itemCount;
      for (var i = 0; i < n; i++) {
        await c.completeItem();
      }
      expect(c.currentStop!.kind, StopKind.exercise);
      expect(h.session.cursor!.visitedSteps, contains(1));
    });
  });

  group('supersets', () {
    test('members alternate and the rest comes after the round', () async {
      h = await PlayerHarness.start(plan: Plans.pair);
      final c = await h.open();
      final rows = c.rowsOf();
      expect(rows.take(4).map((r) => r.label), ['A1', 'B1', 'A2', 'B2']);
      await c.logSet();
      expect(c.rest, isNull, reason: 'no rest between members');
      expect(c.activeRow!.label, 'B1');
      await c.logSet();
      expect(c.rest, isNotNull);
      expect(c.rest!.questions, hasLength(2));
      expect(c.rest!.remainingSec(c.now), 60);
      await c.skipRest();
      expect(c.activeRow!.label, 'A2');
    });

    test('swap one member only', () async {
      h = await PlayerHarness.start(plan: Plans.pair);
      final c = await h.open();
      final members = c.currentStop!.exercises;
      final alt = c.swapOptions(members[1]).first.exercise;
      await c.swap(members[1], alt.id, SwapScope.today);
      final after = c.currentStop!.exercises;
      expect(after[0].exerciseId, members[0].exerciseId);
      expect(after[1].exerciseId, alt.id);
    });
  });

  group('find your weight', () {
    test('ramp rows come first and the ramp survives a kill', () async {
      h = await PlayerHarness.start(plan: Plans.firstMain(1, findWeight: true));
      final c = await h.open();
      final row = c.activeRow!;
      expect(row.kind, SetKind.ramp);
      expect(row.label, 'F1');
      expect(c.findingWeight, isTrue);
      c.setDraftReps(row.reps + 6);
      await c.logSet();
      await c.answerRir(c.rest!.questions.single.id, 4);
      final before = (c.activeRow!.kind, c.activeRow!.label, c.activeRow!.weightKg, h.session.cursor!.findWeight);

      // Kill and relaunch.
      final again = await h.open();
      final after = again.activeRow!;
      expect((after.kind, after.label, after.weightKg, again.cursor.findWeight), before);
      expect(again.rest, isNotNull, reason: 'the rest deadline survives');
    });

    test('every prescribed working set is planned after the find tries (not one fewer)', () async {
      h = await PlayerHarness.start(plan: Plans.firstMain(1, findWeight: true));
      final c = await h.open();
      final se = h.session.exercises.single;
      final working = c.rowsOf().where((r) => r.se.id == se.id && r.workingNumber != null);
      expect(se.target.working.length, greaterThan(1));
      expect(working, hasLength(se.target.working.length));
    });

    test('skipping a ramp set starts the working sets at the current weight', () async {
      h = await PlayerHarness.start(plan: Plans.firstMain(1, findWeight: true));
      final c = await h.open();
      c.setDraftWeight(30);
      await c.skipSet();
      final row = c.activeRow!;
      expect(row.kind, SetKind.working);
      expect(row.weightKg, 30);
      final se = h.session.exercises.single;
      expect(se.target.findWeight, isFalse);
    });
  });

  group('resume after a kill', () {
    test('same stop, same set and the rest deadline', () async {
      h = await PlayerHarness.start(plan: Plans.mainOnly);
      final c = await h.open();
      await c.logSet();
      final ends = h.session.cursor!.restEndsAt;
      final active = c.activeRow!.setIndex;

      final again = await h.open();
      expect(again.currentStop!.id, c.currentStop!.id);
      expect(again.activeRow!.setIndex, active);
      expect(again.rest!.endsAt, ends);
    });

    test('a rest that ended while the app was dead shows "Rest over" at once, silently', () async {
      h = await PlayerHarness.start(plan: Plans.mainOnly);
      final c = await h.open();
      await c.logSet();
      h.app.clock.advance(const Duration(minutes: 10));
      final again = await h.open();
      expect(again.rest!.isOver(again.now), isTrue);
      await again.tick();
      expect(h.app.sound.restDones, 0);
    });
  });

  group('completion', () {
    test('finish and save: progression, rotation, statuses and wakelock', () async {
      h = await PlayerHarness.start(plan: Plans.firstMain(2));
      final c = await h.open();
      final firstSe = c.currentStop!.exercise!;
      // Do the first exercise fully, the second partly.
      for (var i = 0; i < firstSe.target.working.length; i++) {
        await c.logSet();
        await c.skipRest();
      }
      await c.logSet();
      await c.endWorkout(save: true);

      expect(c.status, PlayerStatus.completed);
      expect(h.session.status, SessionStatus.completed);
      final ses = h.session.exercises;
      expect(ses.every((e) => e.status == SessionExerciseStatus.done), isTrue);
      final state = await h.app.exerciseStates.get(firstSe.exerciseId);
      expect(state!.lastSessionId, h.sessionId);
      expect((await h.app.programs.active())!.nextDayIndex, 1);
      expect(h.app.wakelock.enabled, isFalse);
      expect(h.app.restAlarm.isScheduled, isFalse);
    });

    test('untouched exercises are skipped for lack of time', () async {
      h = await PlayerHarness.start(plan: Plans.firstMain(2));
      final c = await h.open();
      await c.logSet();
      await c.endWorkout(save: true);
      final second = h.session.exercises[1];
      expect(second.status, SessionExerciseStatus.skipped);
      expect(second.skipReason, SkipReason.noTime);
    });

    test('logging the last set of the last stop completes the session', () async {
      h = await PlayerHarness.start(
        plan: Plans.firstMain(1),
        settings: (s) => s.copyWith(rirPrompt: RirPrompt.never),
      );
      final c = await h.open();
      final n = c.rowsOf().length;
      for (var i = 0; i < n; i++) {
        await c.logSet();
        if (c.rest != null) await c.skipRest();
      }
      expect(c.status, PlayerStatus.completed);
    });

    test('discard keeps the session out of history', () async {
      h = await PlayerHarness.start(plan: Plans.mainOnly);
      final c = await h.open();
      await c.logSet();
      await c.endWorkout(save: false);
      expect(c.status, PlayerStatus.discarded);
      expect(h.session.status, SessionStatus.discarded);
      expect(h.app.wakelock.enabled, isFalse);
    });
  });
}
