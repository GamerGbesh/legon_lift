import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/features/body/body_screen.dart';
import 'package:legon_lift/widgets/number_stepper.dart';

import '../../fakes/fakes.dart';
import '../progress/ws5_harness.dart';

void main() {
  testWidgets('shows the 7-day average and weigh-in guidance', (tester) async {
    await pumpScreen(tester, FakeApp.seeded(), const BodyScreen());
    expect(find.text('7-day average'), findsOneWidget);
    expect(find.text('94.6 kg'), findsOneWidget); // mean of 10-15 Nov
    expect(find.text('Your weight bounces day to day. Only the weekly average matters.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('How to weigh in'), 200);
    expect(find.text('Before food/water'), findsOneWidget);
  });

  testWidgets('without 3 weigh-ins it says so', (tester) async {
    await pumpScreen(tester, FakeApp(), const BodyScreen());
    expect(find.text('Need 3 weigh-ins'), findsOneWidget);
  });

  testWidgets("saves today's weight, prefilled from the last weigh-in", (tester) async {
    final app = FakeApp.seeded();
    await pumpScreen(tester, app, const BodyScreen());
    expect(find.descendant(of: find.byType(NumberStepper), matching: find.text('94.4 kg')), findsOneWidget); // last weigh-in
    await tester.tap(find.byTooltip('Less'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(app.body.entries['2026-11-16']?.weightKg, 94.3);
    expect(app.body.entries['2026-11-16']?.waistCm, isNull);
    expect(find.text('Saved for Mon 16 Nov'), findsOneWidget);
    expect(find.text('Update entry'), findsOneWidget);
  });

  testWidgets('waist is optional and saved in cm', (tester) async {
    final app = FakeApp.seeded();
    await pumpScreen(tester, app, const BodyScreen());
    expect(find.textContaining('Due: last measured 7 days ago'), findsOneWidget);
    await tester.tap(find.text('Waist at the navel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Less').last);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(app.body.entries['2026-11-16']?.waistCm, 103.5);
  });

  testWidgets('Yesterday edits the existing entry', (tester) async {
    final app = FakeApp.seeded();
    await pumpScreen(tester, app, const BodyScreen());
    await tester.tap(find.text('Yesterday'));
    await tester.pumpAndSettle();
    expect(find.text('You already logged this date. Saving replaces it.'), findsOneWidget);
    await tester.tap(find.byTooltip('More').first);
    await tester.pump();
    await tester.tap(find.text('Update entry'));
    await tester.pumpAndSettle();
    expect(app.body.entries['2026-11-15']?.weightKg, 94.5);
    expect(app.body.entries.length, 7);
  });

  testWidgets('delete an entry, then Undo restores it', (tester) async {
    final app = FakeApp.seeded();
    await pumpScreen(tester, app, const BodyScreen());
    final delete = find.byTooltip('Delete Sun 15 Nov');
    await tester.scrollUntilVisible(delete, 200);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(app.body.entries.containsKey('2026-11-15'), isFalse);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(app.body.entries['2026-11-15']?.weightKg, 94.4);
  });
}
