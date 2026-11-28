import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/app/theme/app_theme.dart';
import 'package:legon_lift/app/theme/tokens.dart';
import 'package:legon_lift/widgets/number_stepper.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('tapping the value opens the keypad even without onTapValue', (tester) async {
    var value = 94.4;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(legonNight),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => NumberStepper(
            value: value,
            step: 0.1,
            unit: 'kg',
            entryTitle: 'Body weight',
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('94.4 kg', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.text('Body weight'), findsOneWidget);
    for (final k in ['9', '0', '.', '5']) {
      await tester.tap(find.text(k).last);
      await tester.pump();
    }
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(value, 90.5);
  });

  testWidgets('the keypad works out sums left to right: 25 + 11.3 × 2 = 72.6', (tester) async {
    var value = 50.0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(legonNight),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => NumberStepper(
            value: value,
            step: 2.5,
            unit: 'kg',
            decimals: 2,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('50 kg', findRichText: true));
    await tester.pumpAndSettle();
    for (final k in ['2', '5', '+', '1', '1', '.', '3', '×', '2']) {
      await tester.tap(find.text(k).last);
      await tester.pump();
    }
    expect(find.text('= 72.6 kg'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(value, 72.6);
  });

  testWidgets('an operator first works on the current value: 50 + 10 = 60', (tester) async {
    var value = 50.0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(legonNight),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => NumberStepper(
            value: value,
            step: 1,
            unit: 'reps',
            decimals: 0,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('50 reps', findRichText: true));
    await tester.pumpAndSettle();
    for (final k in ['+', '1', '0']) {
      await tester.tap(find.text(k).last);
      await tester.pump();
    }
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(value, 60);
  });
}
