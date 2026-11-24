import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/features/program/custom_program.dart';
import 'package:legon_lift/features/program/day_editor_screen.dart';
import 'package:legon_lift/features/program/program_screen.dart';
import 'package:legon_lift/state/program_store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../fakes/fakes.dart';
import '../progress/ws5_harness.dart';

void main() {
  final page = find.byType(Scrollable).first;

  testWidgets('day cards: readable muscles, counts and time from the built session', (tester) async {
    await pumpScreen(tester, FakeApp.seeded(), const ProgramScreen());
    expect(find.textContaining('front_delts'), findsNothing);
    expect(find.textContaining('Front shoulders'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d+ exercises · about \d+ min$')), findsNWidgets(3));
    expect(find.text('Add a day'), findsNothing); // ready-made programs keep their days
    expect(tester.takeException(), isNull);
  });

  testWidgets('a day shows the set count the session uses (Settings > Sets per exercise)', (tester) async {
    await pumpScreen(tester, FakeApp.seeded(), const DayEditorScreen(dayId: 'push'));
    final incline = find.text('Incline Dumbbell Press');
    await tester.scrollUntilVisible(incline, 200, scrollable: find.byType(Scrollable).first);
    final card = find.ancestor(of: incline, matching: find.byType(Card));
    expect(find.descendant(of: card, matching: find.textContaining('3 × 10–12')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom program: add, rename and remove a day', (tester) async {
    final app = FakeApp.seeded();
    await pumpScreen(tester, app, const ProgramScreen());
    final context = tester.element(find.byType(ProgramScreen));
    final store = context.read<ProgramStore>();
    await store.createCustom(CustomPrograms.blank(app.catalog));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Add a day'), 200, scrollable: page);
    await tester.tap(find.text('Add a day'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Arms and abs');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(store.days.map((d) => d.name), contains('Arms and abs'));
    expect(find.text('No exercises yet: tap to add some'), findsWidgets);

    await tester.scrollUntilVisible(find.text('Arms and abs'), 200, scrollable: page);
    final card = find.ancestor(of: find.text('Arms and abs'), matching: find.byType(Card));
    await tester.tap(find.descendant(of: card, matching: find.byTooltip('Day options')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Arms');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(store.days.last.name, 'Arms');

    final renamed = find.ancestor(of: find.text('Arms'), matching: find.byType(Card));
    await tester.tap(find.descendant(of: renamed, matching: find.byTooltip('Day options')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove day'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(store.days, hasLength(3));
    expect(find.text('Arms'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
