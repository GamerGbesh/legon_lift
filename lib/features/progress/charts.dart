// Owner: WS5. fl_chart charts of the Progress tab and the exercise detail page (SPEC 4.6, 4.7).
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/format.dart';
import '../../core/units.dart';
import '../../state/history_store.dart';
import '../library/muscle_groups.dart';
import 'history_format.dart';

TextStyle _axisStyle(ColorTokens t) => AppText.tabular(AppText.caption).copyWith(color: t.muted, fontSize: 12);

FlTitlesData _titles({AxisTitles? left, AxisTitles? bottom}) => FlTitlesData(
      leftTitles: left ?? const AxisTitles(),
      bottomTitles: bottom ?? const AxisTitles(),
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
    );

/// A "nice" axis step (1, 2, 2.5 or 5 x 10^n) giving about [ticks] intervals up to [max].
double niceInterval(double max, {int ticks = 4}) {
  if (max <= 0) return 1;
  final raw = max / ticks;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  for (final m in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (raw <= m * mag) return m * mag;
  }
  return 10 * mag;
}

/// Weekly working-set volume, one bar per ISO week (SPEC 4.7 Overview).
class WeeklyVolumeChart extends StatelessWidget {
  const WeeklyVolumeChart({super.key, required this.weeks, this.useLb = false});

  final List<WeekVolume> weeks;
  final bool useLb;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final values = [for (final w in weeks) Units.displayWeight(w.volumeKg, useLb: useLb)];
    final maxV = values.fold(0.0, math.max);
    final interval = niceInterval(maxV == 0 ? 1000 : maxV);
    final maxY = (maxV / interval).ceil() * interval + (maxV == 0 ? interval * 4 : 0);
    final unit = Units.weightUnit(useLb: useLb);
    return Semantics(
      label: 'Weekly volume chart, last ${weeks.length} weeks. '
          'This week ${Fmt.number(values.isEmpty ? 0 : values.last, maxDecimals: 0)} $unit.',
      child: AspectRatio(
        aspectRatio: 1.7,
        child: BarChart(
          BarChartData(
            minY: 0,
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: interval,
              getDrawingHorizontalLine: (_) => FlLine(color: t.surface2, strokeWidth: 1),
            ),
            titlesData: _titles(
              left: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: interval,
                  getTitlesWidget: (v, meta) =>
                      SideTitleWidget(meta: meta, child: Text(compactNumber(v), style: _axisStyle(t))),
                ),
              ),
              bottom: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    final show = i >= 0 && i < weeks.length && (weeks.length - 1 - i) % 3 == 0;
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(show ? dayMonth(weeks[i].weekStart) : '', style: _axisStyle(t)),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => t.surface2,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItem: (group, _, rod, _) {
                  final w = weeks[group.x];
                  return BarTooltipItem(
                    'Week of ${dayMonth(w.weekStart)}\n'
                    '${Fmt.number(rod.toY, maxDecimals: 0)} $unit · ${w.sessions} '
                    '${w.sessions == 1 ? 'workout' : 'workouts'}',
                    AppText.tabular(AppText.label).copyWith(color: t.onSurface),
                  );
                },
              ),
            ),
            barGroups: [
              for (final (i, v) in values.indexed)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: v,
                    width: 14,
                    color: i == values.length - 1 ? t.primary : t.secondary,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hard sets per muscle group this week as horizontal bars, with the 10-20 target band shaded
/// (SPEC 4.7 Overview). Bars inside the band are green, below it blue, above it amber.
class HardSetsChart extends StatelessWidget {
  const HardSetsChart({super.key, required this.groups, required this.values});

  static const double bandLow = 10, bandHigh = 20;

  final List<MuscleGroup> groups;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final maxV = math.max(24.0, values.fold(0.0, math.max) + 2);
    Color colorFor(double v) => v < bandLow ? t.secondary : (v > bandHigh ? t.warning : t.success);
    final summary = [
      for (final (i, g) in groups.indexed) '${g.label} ${Fmt.number(values[i], maxDecimals: 1)}',
    ].join(', ');
    return Semantics(
      label: 'Hard sets per muscle this week, target 10 to 20: $summary',
      child: SizedBox(
        height: groups.length * 34.0 + 16,
        child: BarChart(
          BarChartData(
            rotationQuarterTurns: 1,
            minY: 0,
            maxY: maxV,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: 5,
              getDrawingHorizontalLine: (_) => FlLine(color: t.surface2, strokeWidth: 1),
            ),
            rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: [
              HorizontalRangeAnnotation(y1: bandLow, y2: bandHigh, color: t.success.withValues(alpha: 0.14)),
            ]),
            titlesData: _titles(
              bottom: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 112,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= groups.length) return const SizedBox.shrink();
                    return SideTitleWidget(
                      meta: meta,
                      child: SizedBox(
                        width: 104,
                        child: Text(
                          '${groups[i].label}  ${Fmt.number(values[i], maxDecimals: 1)}',
                          style: AppText.tabular(AppText.label).copyWith(color: t.onSurface),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: const BarTouchData(enabled: false),
            barGroups: [
              for (final (i, v) in values.indexed)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: v,
                    width: 16,
                    color: colorFor(v),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dated series as a line chart. [compact] draws a small sparkline without axes.
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({
    super.key,
    required this.points,
    required this.unit,
    this.color,
    this.compact = false,
    this.semanticLabel,
    this.decimals = 1,
  });

  final List<(DateTime, double)> points;
  final String unit;
  final Color? color;
  final bool compact;
  final String? semanticLabel;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.primary;
    if (points.isEmpty) return const SizedBox.shrink();
    final origin = points.first.$1;
    final spots = [for (final (d, v) in points) FlSpot(_daysBetween(origin, d), v)];
    final (minY, maxY, interval) = _range([for (final (_, v) in points) v]);
    final maxX = math.max(spots.last.x, 1.0);
    final chart = LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        borderData: FlBorderData(show: false),
        gridData: compact
            ? const FlGridData(show: false)
            : FlGridData(
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (_) => FlLine(color: t.surface2, strokeWidth: 1),
              ),
        titlesData: compact ? _titles() : _dateTitles(t, origin, maxX, interval),
        lineTouchData: compact
            ? const LineTouchData(enabled: false)
            : LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => t.surface2,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (spots) => [
                    for (final s in spots)
                      LineTooltipItem(
                        '${dayMonth(_dayAt(origin, s.x))}\n'
                        '${Fmt.number(s.y, maxDecimals: decimals)} $unit',
                        AppText.tabular(AppText.label).copyWith(color: t.onSurface),
                      ),
                  ],
                ),
              ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: c,
            barWidth: compact ? 2.5 : 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: !compact || spots.length == 1,
              getDotPainter: (_, _, _, _) =>
                  FlDotCirclePainter(radius: compact ? 3 : 4, color: c, strokeWidth: 2, strokeColor: t.surface),
            ),
            belowBarData: BarAreaData(show: true, color: c.withValues(alpha: 0.10)),
          ),
        ],
      ),
    );
    return Semantics(
      label: semanticLabel,
      child: compact ? SizedBox(height: 56, child: chart) : AspectRatio(aspectRatio: 1.7, child: chart),
    );
  }
}

/// Daily weigh-ins as dots plus the 7-day average as a line (SPEC 4.7 Body).
class BodyWeightChart extends StatelessWidget {
  const BodyWeightChart({super.key, required this.daily, required this.average, required this.unit});

  /// Display-unit values.
  final List<(DateTime, double)> daily;
  final List<(DateTime, double)> average;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (daily.isEmpty) return const SizedBox.shrink();
    final origin = daily.first.$1;
    final all = [for (final (_, v) in daily) v, for (final (_, v) in average) v];
    final (minY, maxY, interval) = _range(all);
    final maxX = math.max(_daysBetween(origin, daily.last.$1), 1.0);
    return Semantics(
      label: 'Body weight chart: ${daily.length} weigh-ins as dots and the 7-day average as a line.',
      child: AspectRatio(
        aspectRatio: 1.7,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: interval,
              getDrawingHorizontalLine: (_) => FlLine(color: t.surface2, strokeWidth: 1),
            ),
            titlesData: _dateTitles(t, origin, maxX, interval),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => t.surface2,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      '${s.barIndex == 0 ? 'Weigh-in' : '7-day average'} '
                      '${dayMonth(_dayAt(origin, s.x))}\n'
                      '${Fmt.number(s.y, maxDecimals: 1)} $unit',
                      AppText.tabular(AppText.label).copyWith(color: s.barIndex == 0 ? t.muted : t.onSurface),
                    ),
                ],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [for (final (d, v) in daily) FlSpot(_daysBetween(origin, d), v)],
                barWidth: 0,
                color: Colors.transparent,
                dotData: FlDotData(
                  getDotPainter: (_, _, _, _) => FlDotCirclePainter(radius: 3.5, color: t.muted, strokeWidth: 0),
                ),
              ),
              if (average.isNotEmpty)
                LineChartBarData(
                  spots: [for (final (d, v) in average) FlSpot(_daysBetween(origin, d), v)],
                  color: t.primary,
                  barWidth: 3,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

double _daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays.toDouble() +
    (b.hour * 60 + b.minute) / (24 * 60);

DateTime _dayAt(DateTime origin, double x) => DateTime(origin.year, origin.month, origin.day + x.floor());

/// Y range with some headroom and a nice grid interval.
(double, double, double) _range(List<double> values) {
  var lo = values.reduce(math.min);
  var hi = values.reduce(math.max);
  if (hi - lo < 1) {
    lo -= 1;
    hi += 1;
  }
  final interval = niceInterval(hi - lo, ticks: 3);
  final minY = math.max(0.0, (lo / interval).floor() * interval - (lo % interval == 0 ? interval : 0));
  final maxY = (hi / interval).ceil() * interval + (hi % interval == 0 ? interval : 0);
  return (minY, maxY, interval);
}

FlTitlesData _dateTitles(ColorTokens t, DateTime origin, double maxX, double yInterval) {
  final xInterval = math.max(1.0, (maxX / 3).ceilToDouble());
  return _titles(
    left: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        interval: yInterval,
        getTitlesWidget: (v, meta) => SideTitleWidget(meta: meta, child: Text(compactNumber(v), style: _axisStyle(t))),
      ),
    ),
    bottom: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 28,
        interval: xInterval,
        getTitlesWidget: (v, meta) => SideTitleWidget(
          meta: meta,
          // Keeps the first and last dates inside the chart instead of cut off at the edge.
          fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0),
          child: Text(dayMonth(_dayAt(origin, v)), style: _axisStyle(t)),
        ),
      ),
    ),
  );
}
