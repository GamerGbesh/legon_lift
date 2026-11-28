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
}
