// Owner: WS5. The plain-language "recomp insight" on Progress > Body (SPEC 4.7).
import 'package:flutter/foundation.dart';

import '../../core/format.dart';
import '../../core/units.dart';
import '../../data/models/models.dart';

/// How the insight card is coloured.
enum InsightTone { good, neutral, watch }

/// A short verdict on the weight and waist trend.
@immutable
class RecompInsight {
  const RecompInsight({required this.title, required this.message, required this.tone});

  final String title, message;
  final InsightTone tone;
}

/// Compares the first and the last week of weigh-ins, and the first and latest waist
/// measurements, then explains the trend for a recomp goal (lose fat, build muscle).
///
/// Needs at least 3 weigh-ins spread over 14 days or more; earlier it asks to keep logging.
/// Weight changes under 0.5 kg and waist changes under 1 cm count as steady (daily noise).
RecompInsight recompInsight(List<BodyEntry> entries, {bool useLb = false, bool useInches = false}) {
  final weighIns = [for (final e in entries) if (e.weightKg != null) e]..sort((a, b) => a.date.compareTo(b.date));
  const keepLogging = RecompInsight(
    title: 'Keep logging',
    message: 'Weigh in at least 3 mornings a week and measure your waist once a week. '
        'After about 2 weeks your trend shows up here.',
    tone: InsightTone.neutral,
  );
  if (weighIns.length < 3) return keepLogging;
  final firstDay = Fmt.parseDateKey(weighIns.first.date);
  final lastDay = Fmt.parseDateKey(weighIns.last.date);
  if (lastDay.difference(firstDay).inDays < 14) return keepLogging;

  double meanWithin(DateTime from, DateTime to) {
    final w = [
      for (final e in weighIns)
        if (!Fmt.parseDateKey(e.date).isBefore(from) && !Fmt.parseDateKey(e.date).isAfter(to)) e.weightKg!,
    ];
    return w.reduce((a, b) => a + b) / w.length;
  }

  final startAvg = meanWithin(firstDay, DateTime(firstDay.year, firstDay.month, firstDay.day + 6));
  final endAvg = meanWithin(DateTime(lastDay.year, lastDay.month, lastDay.day - 6), lastDay);
  final dw = endAvg - startAvg;

  final waists = [for (final e in entries) if (e.waistCm != null) e]..sort((a, b) => a.date.compareTo(b.date));
  double? dc;
  if (waists.length >= 2) {
    final span = Fmt.parseDateKey(waists.last.date).difference(Fmt.parseDateKey(waists.first.date)).inDays;
    if (span >= 7) dc = waists.last.waistCm! - waists.first.waistCm!;
  }

  String w(double kg) => Fmt.weight(kg.abs(), useLb: useLb, maxDecimals: 1);
  String c(double cm) =>
      useInches ? '${Fmt.number(Units.cmToInches(cm.abs()), maxDecimals: 1)} in' : '${Fmt.number(cm.abs(), maxDecimals: 1)} cm';

  final waistDown = dc != null && dc <= -1;
  final waistUp = dc != null && dc >= 1;
  final weightDown = dw <= -0.5;
  final weightUp = dw >= 0.5;

  if (waistDown && !weightDown && !weightUp) {
    return RecompInsight(
      title: 'Recomp is working',
      message: 'Your waist is down ${c(dc)} while your weight held steady. '
          'That means less fat and more muscle. Keep going.',
      tone: InsightTone.good,
    );
  }
  if (waistDown && weightDown) {
    return RecompInsight(
      title: 'Losing fat',
      message: 'Weekly average down ${w(dw)} and waist down ${c(dc)}. Right on track.',
      tone: InsightTone.good,
    );
  }
  if (waistDown && weightUp) {
    return RecompInsight(
      title: 'Building muscle',
      message: 'Your waist is down ${c(dc)} even though your weight is up ${w(dw)}. '
          'The extra weight is likely muscle and water from training.',
      tone: InsightTone.good,
    );
  }
  if (weightDown && dc == null) {
    return RecompInsight(
      title: 'Weight trending down',
      message: 'Weekly average down ${w(dw)}. Measure your waist once a week too: '
          'it shows fat loss the scale can miss.',
      tone: InsightTone.good,
    );
  }
  if (weightDown) {
    return RecompInsight(
      title: 'Weight down, waist steady',
      message: 'Weekly average down ${w(dw)}. Waist changes lag behind the scale; '
          'keep measuring at the navel once a week.',
      tone: InsightTone.good,
    );
  }
  if (weightUp && waistUp) {
    return RecompInsight(
      title: 'Both creeping up',
      message: 'Weight is up ${w(dw)} and waist up ${c(dc)}. '
          'Check your protein points, portions and sugary drinks this week.',
      tone: InsightTone.watch,
    );
  }
  if (weightUp) {
    return RecompInsight(
      title: 'Weight up a little',
      message: 'Weekly average up ${w(dw)}. New training adds some water and muscle. '
          'If your waist holds steady, you are fine.',
      tone: InsightTone.neutral,
    );
  }
  return const RecompInsight(
    title: 'Holding steady',
    message: 'Your weight and waist are steady. If your lifts keep going up, you are still making progress.',
    tone: InsightTone.neutral,
  );
}
