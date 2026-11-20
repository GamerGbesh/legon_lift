// Owner: WS5. Progress > Body: weight dots + 7-day average, waist, recomp insight (SPEC 4.7).
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/format.dart';
import '../../core/units.dart';
import '../../domain/api.dart';
import '../../state/body_store.dart';
import '../../widgets/big_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../body/recomp_insight.dart';
import 'charts.dart';
import 'history_format.dart';
import 'progress_widgets.dart';

/// Body trends from [BodyStore].
class ProgressBodyView extends StatelessWidget {
  const ProgressBodyView({super.key});

  static const int _chartDays = 182;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BodyStore>();
    final t = context.tokens;
    final useLb = useLbOf(context);
    final useIn = useInchesOf(context);
    final entries = store.entries;
    void openBody() => Navigator.of(context).pushNamed(Routes.body);

    if (entries.isEmpty) {
      return EmptyState(
        icon: Icons.monitor_weight_outlined,
        title: 'No weigh-ins yet',
        body: 'Weigh yourself in the morning a few times a week. The weekly average shows your real trend.',
        action: BigButton(label: 'Log weight', icon: Icons.add, onPressed: openBody),
      );
    }

    final unit = Units.weightUnit(useLb: useLb);
    // Charts show the last [_chartDays] days (plus 6 earlier days feeding the first averages).
    final last = Fmt.parseDateKey(entries.last.date);
    final from = Fmt.dateKey(DateTime(last.year, last.month, last.day - _chartDays));
    final feedFrom = Fmt.dateKey(DateTime(last.year, last.month, last.day - _chartDays - 6));
    final feed = [for (final e in entries) if (e.date.compareTo(feedFrom) >= 0) e];
    final weighIns = [for (final e in feed) if (e.weightKg != null && e.date.compareTo(from) >= 0) e];
    final daily = [
      for (final e in weighIns) (Fmt.parseDateKey(e.date), Units.displayWeight(e.weightKg!, useLb: useLb)),
    ];
    final average = [
      for (final e in weighIns)
        if (movingAverage7(feed, e.date) case final avg?)
          (Fmt.parseDateKey(e.date), Units.displayWeight(avg, useLb: useLb)),
    ];
    final waist = [
      for (final e in feed)
        if (e.waistCm != null && e.date.compareTo(from) >= 0)
          (Fmt.parseDateKey(e.date), useIn ? Units.cmToInches(e.waistCm!) : e.waistCm!),
    ];
    final waistUnit = useIn ? 'in' : 'cm';
    final insight = recompInsight(entries, useLb: useLb, useInches: useIn);
    final avg = store.avg7;
    final caption = AppText.body.copyWith(color: t.muted, fontSize: 14);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, Space.xxl),
      children: [
        _InsightCard(insight: insight),
        const SizedBox(height: Space.m),
        BigButton(label: 'Log weight or waist', icon: Icons.add, onPressed: openBody, height: Sizes.minTap),
        const SectionHeader('Weight'),
        Text(
          avg == null
              ? 'Need 3 weigh-ins in the last 7 days for an average (you have ${store.weighInsLast7}).'
              : '7-day average: ${Fmt.weight(avg, useLb: useLb, maxDecimals: 1)}. '
                  'Dots are single weigh-ins; the line is the 7-day average.',
          style: caption,
        ),
        const SizedBox(height: Space.m),
        if (daily.isEmpty)
          Text('No weigh-ins yet, only waist measurements.', style: caption)
        else
          ChartCard(child: BodyWeightChart(daily: daily, average: average, unit: unit)),
        const SectionHeader('Waist at the navel'),
        if (waist.isEmpty)
          Text('No waist measurements yet. Measure once a week, at the navel, after breathing out.', style: caption)
        else ...[
          Text(
            'Latest ${Fmt.number(waist.last.$2, maxDecimals: 1)} $waistUnit on ${dayMonth(waist.last.$1)}.',
            style: caption,
          ),
          const SizedBox(height: Space.m),
          ChartCard(
            child: TrendLineChart(
              points: waist,
              unit: waistUnit,
              color: t.secondary,
              semanticLabel: 'Waist chart: ${waist.length} measurements, latest '
                  '${Fmt.number(waist.last.$2, maxDecimals: 1)} $waistUnit.',
            ),
          ),
        ],
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final RecompInsight insight;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (icon, color) = switch (insight.tone) {
      InsightTone.good => (Icons.trending_up, t.success),
      InsightTone.neutral => (Icons.insights, t.secondary),
      InsightTone.watch => (Icons.visibility, t.warning),
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Space.l),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(insight.title, style: AppText.title.copyWith(fontSize: 18, color: t.onSurface)),
                  const SizedBox(height: Space.xs),
                  Text(insight.message, style: AppText.body.copyWith(color: t.onSurface)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
