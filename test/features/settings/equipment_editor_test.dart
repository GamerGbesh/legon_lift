import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/app/theme/app_theme.dart';
import 'package:legon_lift/app/theme/tokens.dart';
import 'package:legon_lift/data/models/models.dart';
import 'package:legon_lift/features/settings/widgets/equipment_editor.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const gym = GymProfileDefaults.legon;

  /// Pumps the editor with live state; returns a getter for the latest value.
  Future<EquipmentProfile Function()> pump(WidgetTester tester, {EquipmentProfile? initial, bool compact = false}) async {
    tester.view.physicalSize = const Size(412, 892) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var value = initial ?? EquipmentProfile.fromDefaults(gym);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(legonNight),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              EquipmentEditor(
                value: value,
                defaults: gym,
                compact: compact,
                onChanged: (v) => setState(() => value = v),
              ),
            ],
          ),
        ),
      ),
    ));
    return () => value;
  }

  /// Taps the first widget showing [text] (plate chips come before the barbell stepper's "20 kg").
  Future<void> tapText(WidgetTester tester, String text) async {
    final f = find.text(text).first;
    await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pump();
  }

  testWidgets('equipment switches tick and untick, and hide their weight sections', (tester) async {
    final value = await pump(tester);
    expect(find.text('Dumbbells'), findsOneWidget);
    await tapText(tester, gym.labelFor(Equipment.dumbbell));
    expect(value().has(Equipment.dumbbell), isFalse);
    expect(find.text('Dumbbells'), findsNothing);

    await tapText(tester, gym.labelFor(Equipment.ankleStrap));
    expect(value().has(Equipment.ankleStrap), isTrue);

    await tapText(tester, 'Bench with uprights + spotter available');
    expect(value().hasBenchUprights, isTrue);
  });

  testWidgets('plates: tick sizes on and off, but never the last one', (tester) async {
    final value = await pump(
      tester,
      initial: EquipmentProfile.fromDefaults(gym).copyWith(platesKg: [20, 10]),
    );
    await tapText(tester, '20 kg');
    expect(value().platesKg, [10]);
    await tapText(tester, '10 kg');
    expect(value().platesKg, [10], reason: 'the last plate size stays');
    await tapText(tester, '1.25 kg');
    expect(value().platesKg, [10, 1.25]);
  });

  testWidgets('Smith bar and leg press sled: weight and "Don\'t know yet"', (tester) async {
    final value = await pump(tester);
    expect(value().smithBarKnown, isFalse);
    final knownWeight = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_KnownWeight');
    await tester.scrollUntilVisible(find.text('Leg press empty sled'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    final smithMore = find.descendant(
      of: find.ancestor(of: find.text('Smith machine bar'), matching: knownWeight),
      matching: find.byTooltip('More'),
    );
    await tester.ensureVisible(smithMore);
    await tester.pumpAndSettle();
    await tester.tap(smithMore);
    await tester.pump();
    expect(value().smithBarKg, 12.5);
    expect(value().smithBarKnown, isTrue, reason: 'setting a weight means it is known');

    await tapText(tester, "Don't know yet");
    expect(value().smithBarKnown, isFalse);
    expect(value().smithBarKg, 12.5);

    final sledMore = find.descendant(
      of: find.ancestor(of: find.text('Leg press empty sled'), matching: knownWeight),
      matching: find.byTooltip('More'),
    );
    await tester.ensureVisible(sledMore);
    await tester.pumpAndSettle();
    await tester.tap(sledMore);
    await tester.pump();
    expect(value().legPressSledKg, 5);
    expect(value().legPressSledKnown, isTrue);
  });

  testWidgets('dumbbells: spacing, heaviest and single weights', (tester) async {
    final value = await pump(tester);
    expect(value().dumbbellsKg, gym.defaultDumbbellsKg);

    final spacing = find.descendant(of: find.byType(SegmentedButton<double>), matching: find.text('2.5 kg'));
    await tester.scrollUntilVisible(spacing, 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(spacing);
    await tester.pumpAndSettle();
    await tester.tap(spacing);
    await tester.pump();
    expect(value().dumbbellsKg, [for (var i = 1; i <= 16; i++) i * 2.5]);

    final heaviest = find.descendant(
      of: find.ancestor(of: find.text('Heaviest dumbbell'), matching: find.byType(Column)).first,
      matching: find.byTooltip('Less'),
    );
    await tester.ensureVisible(heaviest.first);
    await tester.pumpAndSettle();
    await tester.tap(heaviest.first);
    await tester.pump();
    expect(value().dumbbellsKg.last, 37.5);

    await tapText(tester, '7.5');
    expect(value().dumbbellsKg, isNot(contains(7.5)));
    await tapText(tester, '7.5');
    expect(value().dumbbellsKg, contains(7.5));
  });

  testWidgets('leg curl type', (tester) async {
    final value = await pump(tester);
    await tapText(tester, 'Lying');
    expect(value().legCurlType, LegCurlType.lying);
  });

  testWidgets('compact mode hides the notes', (tester) async {
    await pump(tester, compact: true);
    expect(find.text('Untick anything that is missing or broken.'), findsNothing);
    await pump(tester);
    expect(find.text('Untick anything that is missing or broken.'), findsOneWidget);
  });
}
