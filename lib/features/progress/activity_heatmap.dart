// Owner: WS5. 20-week training heatmap drawn with a CustomPainter (SPEC 4.7 Calendar).
import 'dart:math' as math;

import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/format.dart';

/// Intensity bucket of a day from its working sets (SPEC 6.11): 0, 1-9, 10-14, 15-19, 20+.
int heatBucket(int workingSets) => switch (workingSets) {
      <= 0 => 0,
      < 10 => 1,
      < 15 => 2,
      < 20 => 3,
      _ => 4,
    };

/// Fill colour of [bucket] (0 = empty cell).
Color heatColor(ColorTokens t, int bucket) => switch (bucket) {
      0 => t.surface2,
      1 => Color.alphaBlend(t.primary.withValues(alpha: 0.30), t.surface2),
      2 => Color.alphaBlend(t.primary.withValues(alpha: 0.55), t.surface2),
      3 => Color.alphaBlend(t.primary.withValues(alpha: 0.80), t.surface2),
      _ => t.primary,
    };

/// One column per week (Monday on top), [weeks] columns from [start] (a Monday). Tapping a day
/// calls [onTapDay] with its local midnight.
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({
    super.key,
    required this.start,
    required this.weeks,
    required this.setsByDay,
    required this.today,
    this.onTapDay,
  });

  final DateTime start;
  final int weeks;

  /// Working sets per `yyyy-MM-dd`.
  final Map<String, int> setsByDay;
  final DateTime today;
  final ValueChanged<DateTime>? onTapDay;

  static const double _labelWidth = 22, _headerHeight = 20, _gap = 3;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textScaler = MediaQuery.textScalerOf(context);
    final trained = setsByDay.values.where((v) => v > 0).length;
    return LayoutBuilder(builder: (context, constraints) {
      final cell = math.min(24.0, (constraints.maxWidth - _labelWidth) / weeks - _gap);
      final height = _headerHeight + 7 * (cell + _gap);
      final layout = _HeatLayout(start: start, cell: cell);
      return Semantics(
        label: 'Training heatmap, last $weeks weeks: $trained training days. '
            'The month calendar below lists every workout.',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: onTapDay == null
              ? null
              : (d) {
                  final day = layout.dayAt(d.localPosition);
                  if (day != null && !day.isAfter(today)) onTapDay!(day);
                },
          child: CustomPaint(
            size: Size(constraints.maxWidth, height),
            painter: _HeatmapPainter(
              layout: layout,
              weeks: weeks,
              setsByDay: setsByDay,
              today: DateTime(today.year, today.month, today.day),
              tokens: t,
              labelStyle: AppText.caption.copyWith(color: t.muted),
              textScaler: textScaler,
            ),
          ),
        ),
      );
    });
  }
}

/// "Less [] [] [] [] [] More" legend for the heatmap buckets.
class HeatmapLegend extends StatelessWidget {
  const HeatmapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = AppText.label.copyWith(color: t.muted);
    Widget swatch(int b) => Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(color: heatColor(t, b), borderRadius: BorderRadius.circular(3)),
        );
    return Semantics(
      label: 'Colour shows working sets per day: none, 1 to 9, 10 to 14, 15 to 19, 20 or more.',
      excludeSemantics: true,
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Space.s,
        runSpacing: Space.xs,
        children: [
          Text('Fewer sets', style: style),
          Row(mainAxisSize: MainAxisSize.min, children: [for (var b = 0; b <= 4; b++) swatch(b)]),
          Text('More', style: style),
        ],
      ),
    );
  }
}

class _HeatLayout {
  const _HeatLayout({required this.start, required this.cell});

  final DateTime start;
  final double cell;

  double get step => cell + ActivityHeatmap._gap;

  Offset origin(int col, int row) =>
      Offset(ActivityHeatmap._labelWidth + col * step, ActivityHeatmap._headerHeight + row * step);

  DateTime dateOf(int col, int row) => DateTime(start.year, start.month, start.day + col * 7 + row);

  DateTime? dayAt(Offset p) {
    final x = p.dx - ActivityHeatmap._labelWidth;
    final y = p.dy - ActivityHeatmap._headerHeight;
    if (x < 0 || y < 0) return null;
    final col = x ~/ step;
    final row = y ~/ step;
    if (row > 6) return null;
    return dateOf(col, row);
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.layout,
    required this.weeks,
    required this.setsByDay,
    required this.today,
    required this.tokens,
    required this.labelStyle,
    required this.textScaler,
  });

  final _HeatLayout layout;
  final int weeks;
  final Map<String, int> setsByDay;
  final DateTime today;
  final ColorTokens tokens;
  final TextStyle labelStyle;
  final TextScaler textScaler;

  void _text(Canvas canvas, String s, Offset at, {double maxWidth = 60}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler.clamp(maxScaleFactor: 1.2),
      maxLines: 1,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, at);
    tp.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = layout.cell;
    final radius = Radius.circular(math.min(4, cell / 4));
    final todayBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = tokens.onSurface;

    // Weekday labels (Mon, Wed, Fri).
    for (final (row, label) in const [(0, 'M'), (2, 'W'), (4, 'F')]) {
      _text(canvas, label, Offset(2, layout.origin(0, row).dy + (cell - 14) / 2));
    }

    int? lastMonth;
    for (var col = 0; col < weeks; col++) {
      final monday = layout.dateOf(col, 0);
      // Month label above the first column that contains the 1st of a month.
      final firstOfWeekMonth = [for (var r = 0; r < 7; r++) layout.dateOf(col, r)].where((d) => d.day == 1).firstOrNull;
      final labelMonth = col == 0 ? monday.month : firstOfWeekMonth?.month;
      if (labelMonth != null && labelMonth != lastMonth && col < weeks - 1) {
        _text(canvas, DateFormat('MMM').format(DateTime(2000, labelMonth)), Offset(layout.origin(col, 0).dx, 0));
        lastMonth = labelMonth;
      }
      for (var row = 0; row < 7; row++) {
        final day = layout.dateOf(col, row);
        if (day.isAfter(today)) continue;
        final rect = RRect.fromRectAndRadius(layout.origin(col, row) & Size(cell, cell), radius);
        final bucket = heatBucket(setsByDay[Fmt.dateKey(day)] ?? 0);
        canvas.drawRRect(rect, Paint()..color = heatColor(tokens, bucket));
        if (day == today) canvas.drawRRect(rect.deflate(1), todayBorder);
      }
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) =>
      old.setsByDay != setsByDay ||
      old.today != today ||
      old.tokens != tokens ||
      old.layout.cell != layout.cell ||
      old.layout.start != layout.start ||
      old.weeks != weeks;
}
