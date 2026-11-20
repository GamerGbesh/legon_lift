import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/features/library/exercise_detail_screen.dart';
import 'package:legon_lift/features/library/library_screen.dart';
import 'package:legon_lift/widgets/frame_animator.dart';
import 'package:legon_lift/widgets/placeholder_figure.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fakes.dart';
import '../progress/ws5_harness.dart';

void main() {
  group('LibraryScreen', () {
    testWidgets('lists beginner exercises, searches and opens the detail page', (tester) async {
      await pumpScreen(tester, FakeApp.seeded(), const LibraryScreen());
      expect(find.text('Beginner friendly'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^\d+ exercises$')), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'chest press');
      await tester.pumpAndSettle();
      expect(find.text('Machine Chest Press'), findsOneWidget);

      await tester.tap(find.text('Machine Chest Press'));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseDetailScreen), findsOneWidget);
      expect(find.byType(FrameAnimator), findsOneWidget);
    });

    testWidgets('no match shows Reset filters, which clears the search', (tester) async {
      await pumpScreen(tester, FakeApp.seeded(), const LibraryScreen());
      await tester.enterText(find.byType(TextField), 'qqqq');
      await tester.pumpAndSettle();
      expect(find.text('No exercises match'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset filters'));
      await tester.pumpAndSettle();
      expect(find.text('No exercises match'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    });

    testWidgets('favourite star toggles and the Favourites chip filters', (tester) async {
      final app = FakeApp.seeded();
      await pumpScreen(tester, app, const LibraryScreen());
      await tester.enterText(find.byType(TextField), 'machine chest press');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add Machine Chest Press to favourites'));
      await tester.pumpAndSettle();
      expect(app.exerciseStates.prefRows['machine_chest_press']?.favorite, isTrue);

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.widgetWithText(FilterChip, 'Favourites'));
      await tester.pumpAndSettle();
      expect(find.text('1 exercise'), findsOneWidget);
    });

    testWidgets('muscle chip narrows the list', (tester) async {
      await pumpScreen(tester, FakeApp.seeded(), const LibraryScreen());
      final before = find.textContaining(RegExp(r'^\d+ exercises$'));
      final total = int.parse(tester.widget<Text>(before).data!.split(' ').first);
      // The chip row scrolls sideways and builds lazily on a phone-width screen.
      await tester.dragUntilVisible(
        find.widgetWithText(FilterChip, 'Chest'),
        find.ancestor(of: find.text('Beginner friendly'), matching: find.byType(ListView)),
        const Offset(-150, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Chest'));
      await tester.pumpAndSettle();
      final after = tester.widget<Text>(find.textContaining(RegExp(r'^\d+ exercises?$'))).data!;
      expect(int.parse(after.split(' ').first), lessThan(total));
    });
  });

  group('ExerciseDetailScreen', () {
    testWidgets('shows how-to sections and opens the video', (tester) async {
      final app = FakeApp.seeded();
      await pumpScreen(tester, app, const ExerciseDetailScreen(args: ExerciseDetailArgs(exerciseId: 'machine_chest_press')));
      expect(find.text('Muscles worked'), findsOneWidget);
      expect(find.text('Needs internet · opens YouTube'), findsOneWidget);

      await tester.tap(find.text('Watch video'));
      await tester.pumpAndSettle();
      expect(app.launcher.openedVideos, ['machine_chest_press']);

      for (final section in ['Setup', 'How to do it', 'Common mistakes', 'Breathing', 'Safety', 'My history']) {
        await tester.scrollUntilVisible(find.text(section), 200);
        expect(find.text(section), findsOneWidget, reason: section);
      }
      await tester.scrollUntilVisible(find.text('Alternatives'), 200);
      await tester.scrollUntilVisible(find.textContaining('free-exercise-db'), 200);
    });

    testWidgets('video failure explains that internet is needed', (tester) async {
      final app = FakeApp.seeded()..launcher.succeed = false;
      await pumpScreen(tester, app, const ExerciseDetailScreen(args: ExerciseDetailArgs(exerciseId: 'machine_chest_press')));
      await tester.tap(find.text('Watch video'));
      await tester.pumpAndSettle();
      expect(find.textContaining('needs an internet connection'), findsOneWidget);
    });

    testWidgets('exercise without photos shows the placeholder figure', (tester) async {
      await pumpScreen(
          tester, FakeApp.seeded(), const ExerciseDetailScreen(args: ExerciseDetailArgs(exerciseId: 'chest_doorway_stretch')));
      expect(find.byType(PlaceholderFigure), findsOneWidget);
      expect(find.byType(FrameAnimator), findsNothing);
    });

    testWidgets('my history lists the last session', (tester) async {
      final app = FakeApp.seeded();
      final push = app.sessions.sessions[SampleData.sessionIds.first]!;
      final id = push.exercises.firstWhere((e) => app.catalog.exercise(e.exerciseId).isLoaded).exerciseId;
      await pumpScreen(tester, app, ExerciseDetailScreen(args: ExerciseDetailArgs(exerciseId: id)));
      await tester.scrollUntilVisible(find.text('Last sessions'), 200);
      expect(find.textContaining('Best set: '), findsOneWidget);
      expect(find.text('Mon 9 Nov'), findsOneWidget);
    });

    testWidgets('machine note can be added', (tester) async {
      final app = FakeApp.seeded();
      await pumpScreen(tester, app, const ExerciseDetailScreen(args: ExerciseDetailArgs(exerciseId: 'leg_press')));
      await tester.scrollUntilVisible(find.text('Machine note'), 200);
      await tester.tap(find.widgetWithText(TextButton, 'Add'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Seat on 4');
      await tester.tap(find.text('Save note'));
      await tester.pumpAndSettle();
      expect(app.exerciseStates.prefRows['leg_press']?.machineNote, 'Seat on 4');
      expect(find.text('Seat on 4'), findsOneWidget);
    });

    testWidgets('pick mode: Add pops the id, also from an alternative', (tester) async {
      final results = <Object?>[];
      await pumpScreen(
        tester,
        FakeApp.seeded(),
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => results.add(await Navigator.of(context).pushNamed(
                '/exercise',
                arguments: const ExerciseDetailArgs(exerciseId: 'machine_chest_press', pickMode: true),
              )),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(results, ['machine_chest_press']);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Dumbbell Bench Press'), 200);
      await tester.tap(find.text('Dumbbell Bench Press'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(results, ['machine_chest_press', 'dumbbell_bench_press']);
      expect(find.text('open'), findsOneWidget);
    });
  });
}
