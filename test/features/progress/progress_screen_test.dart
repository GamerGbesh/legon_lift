import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legon_lift/features/progress/activity_heatmap.dart';
import 'package:legon_lift/features/progress/calendar_view.dart';
import 'package:legon_lift/features/progress/charts.dart';
import 'package:legon_lift/features/progress/progress_screen.dart';
import 'package:legon_lift/features/progress/session_detail_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fakes/fakes.dart';
import 'ws5_harness.dart';

void main() {
  testWidgets('empty history shows a friendly empty state', (tester) async {
    await pumpScreen(tester, FakeApp(), const ProgressScreen());
    expect(find.text('No workouts yet'), findsOneWidget);
  });

  testWidgets('Overview: month count, weekly volume and hard sets charts', (tester) async {
    await pumpScreen(tester, FakeApp.seeded(), const ProgressScreen());
    expect(find.text('Workouts this month'), findsOneWidget);
    expect(find.widgetWithText(Card, '3'), findsWidgets);
    expect(find.byType(WeeklyVolumeChart), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(HardSetsChart), 200);
    expect(find.byType(BarChart), findsNWidgets(2));
    expect(find.textContaining('Aim for 10-20 sets'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Recent records'), 200);
    expect(find.textContaining('No records yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Exercises: picks the most-trained lift and switches metric', (tester) async {
    await pumpScreen(tester, FakeApp.seeded(), const ProgressScreen());
    await tester.tap(find.text('Exercises'));
    await tester.pumpAndSettle();
    expect(find.text('Tap to choose another'), findsOneWidget);
    expect(find.text('Best single'), findsOneWidget);

    await tester.tap(find.text('Heaviest'));
    await tester.pumpAndSettle();
    expect(find.text('The heaviest weight you lifted each session.'), findsOneWidget);
    expect(find.byType(TrendLineChart), findsOneWidget);
    expect(find.text('Do this exercise again to see a trend.'), findsOneWidget);

    await tester.tap(find.text('Tap to choose another'));
    await tester.pumpAndSettle();
    expect(find.text('Choose an exercise'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Body: insight card and weight chart', (tester) async {
    await pumpScreen(tester, FakeApp.seeded(), const ProgressScreen());
    await tester.tap(find.text('Body'));
    await tester.pumpAndSettle();
    expect(find.text('Keep logging'), findsOneWidget);
    expect(find.byType(BodyWeightChart), findsOneWidget);
    expect(find.textContaining('7-day average:'), findsOneWidget);
    expect(find.text('Log weight or waist'), findsOneWidget);
  });

  testWidgets('Calendar: heatmap, month grid, tap a workout day -> session detail', (tester) async {
    await pumpScreen(tester, FakeApp.seeded(), const ProgressScreen());
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityHeatmap), findsOneWidget);
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.byType(SessionRow), findsNWidgets(3));

    final day9 = find.descendant(of: find.byType(MonthGrid), matching: find.text('9'));
    await tester.ensureVisible(day9);
    await tester.tap(day9);
    await tester.pumpAndSettle();
    expect(find.byType(SessionDetailScreen), findsOneWidget);
    expect(find.text('Monday 9 November 2026'), findsOneWidget);
  });

  testWidgets('Calendar: tapping a heatmap cell opens that day', (tester) async {
    await pumpScreen(tester, FakeApp.seeded(), const ProgressScreen());
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    // Wed 11 Nov is in the second-to-last column (week of 9 Nov), third row.
    final box = tester.getRect(find.byType(ActivityHeatmap));
    final cell = (box.width - 22) / 20;
    final at = box.topLeft + Offset(22 + 18.5 * cell, 20 + 2.5 * cell);
    await tester.tapAt(at);
    await tester.pumpAndSettle();
    expect(find.text('Wednesday 11 November 2026'), findsOneWidget);
  });

  testWidgets('works on a small phone with large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpScreen(tester, FakeApp.seeded(), const ProgressScreen(), size: const Size(360, 780));
    for (final tab in ['Exercises', 'Body', 'Calendar', 'Overview']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
  });
}
