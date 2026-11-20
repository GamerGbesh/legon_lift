import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/app/shell.dart';
import 'package:legon_lift/features/onboarding/onboarding_flow.dart';
import 'package:legon_lift/main.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes/fakes.dart';

void main() {
  testWidgets('first launch shows onboarding', (tester) async {
    final app = FakeApp();
    await tester.pumpWidget(await buildRoot(app.deps));
    await tester.pump();

    expect(find.byType(OnboardingFlow), findsOneWidget);
    expect(find.byType(Shell), findsNothing);
  });

  testWidgets('"Skip, use defaults" then "Let\'s go" completes onboarding and opens the shell', (tester) async {
    final app = FakeApp();
    await tester.pumpWidget(await buildRoot(app.deps));
    await tester.pump();

    // Welcome, Safety and Body come first; "Skip, use defaults" appears after them.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Skip, use defaults'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Let's go"));
    await tester.pumpAndSettle();

    expect(find.byType(Shell), findsOneWidget);
    expect(app.settings.profile, isNotNull);
    final active = await app.programs.active();
    expect(active?.templateId, 'ppl_3day');
    expect(app.notifications.gymBagWeekdays, [1, 3, 5]);
  });

  testWidgets('an onboarded user lands on the shell with five tabs', (tester) async {
    final app = FakeApp.seeded();
    await tester.pumpWidget(await buildRoot(app.deps));
    await tester.pump();

    expect(find.byType(Shell), findsOneWidget);
    for (final tab in ['Today', 'Program', 'Library', 'Progress', 'You']) {
      expect(find.widgetWithText(NavigationDestination, tab), findsOneWidget);
    }
  });
}
