import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/features/progress/session_detail_screen.dart';
import 'package:legon_lift/widgets/number_stepper.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fakes.dart';
import 'ws5_harness.dart';

void main() {
  final pushId = SampleData.sessionIds.first;

  SetLog firstWorking(FakeApp app) =>
      app.sessions.sessions[pushId]!.allSets.firstWhere((s) => s.kind == SetKind.working && s.weightKg > 0);

  testWidgets('shows the workout with its exercises and sets', (tester) async {
    final app = FakeApp.seeded();
    await pumpScreen(tester, app, SessionDetailScreen(sessionId: pushId));
    final session = app.sessions.sessions[pushId]!;
    expect(find.text(session.dayName), findsOneWidget);
    expect(find.text('Monday 9 November 2026'), findsOneWidget);
    expect(find.textContaining('17:00-18:00 (60 min)'), findsOneWidget);
    expect(find.text('Week 1'), findsOneWidget);
    expect(find.text(app.catalog.exercise(session.exercises.first.exerciseId).name), findsOneWidget);
    expect(find.text('Set 1'), findsWidgets);
    expect(find.text('Repeat this workout'), findsOneWidget);
  });

  testWidgets('unknown id shows not found', (tester) async {
    await pumpScreen(tester, FakeApp.seeded(), const SessionDetailScreen(sessionId: 'nope'));
    expect(find.text('Workout not found'), findsOneWidget);
  });

  testWidgets('edit a set: one more rep, and an answer to "how many more"', (tester) async {
    final app = FakeApp.seeded();
    final set = firstWorking(app);
    await pumpScreen(tester, app, SessionDetailScreen(sessionId: pushId));

    await tester.tap(find.bySemanticsLabel(RegExp('^Set 1, .*tap to edit')).first);
    await tester.pumpAndSettle();
    expect(find.text('Edit set'), findsOneWidget);
    expect(find.byType(NumberStepper), findsNWidgets(2));

    await tester.tap(find.byTooltip('More').last); // reps
    await tester.tap(find.widgetWithText(ChoiceChip, '1 left'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = app.sessions.sessions[pushId]!.allSets.firstWhere((s) => s.id == set.id);
    expect(saved.reps, set.reps + 1);
    expect(saved.rir, 1);
    expect(saved.weightKg, set.weightKg);
  });

  testWidgets('delete a set offers Undo and deletes after the window', (tester) async {
    final app = FakeApp.seeded();
    final set = firstWorking(app);
    final count = app.sessions.sessions[pushId]!.allSets.length;
    await pumpScreen(tester, app, SessionDetailScreen(sessionId: pushId));

    Future<void> deleteFirst() async {
      await tester.tap(find.bySemanticsLabel(RegExp('^Set 1, .*tap to edit')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete set'));
      await tester.pumpAndSettle();
    }

    await deleteFirst();
    expect(find.text('Set deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    expect(app.sessions.sessions[pushId]!.allSets, hasLength(count));

    await deleteFirst();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    final sets = app.sessions.sessions[pushId]!.allSets;
    expect(sets, hasLength(count - 1));
    expect(sets.any((s) => s.id == set.id), isFalse);
  });

  testWidgets('Repeat this workout starts that day and opens the player', (tester) async {
    final app = FakeApp.seeded();
    await pumpScreen(tester, app, SessionDetailScreen(sessionId: pushId));
    await tester.tap(find.text('Repeat this workout'));
    await tester.pumpAndSettle();
    final started = await app.sessions.findInProgress();
    expect(started, isNotNull);
    expect(started!.dayId, app.sessions.sessions[pushId]!.dayId);
    expect(find.text('player:${started.id}'), findsOneWidget);
  });

  testWidgets('Repeat is blocked while another workout is in progress', (tester) async {
    final app = FakeApp.seeded();
    final legs = app.sessions.sessions[SampleData.sessionIds.last]!;
    app.sessions.seed(legs.copyWith(id: 'running', status: SessionStatus.inProgress, endedAt: () => null));
    await pumpScreen(tester, app, SessionDetailScreen(sessionId: pushId));
    await tester.tap(find.text('Repeat this workout'));
    await tester.pumpAndSettle();
    expect(find.text('Finish or end the workout in progress first.'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(find.text('player:running'), findsOneWidget);
  });
}
