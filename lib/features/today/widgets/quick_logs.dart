// Owner: WS4. Quick logs on Today (SPEC 4.3): body weight with 7-day average, protein points and
// water sachets (tap to add, 5 s undo), and rest-day cardio.
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../core/clock.dart';
import '../../../core/format.dart';
import '../../../state/body_store.dart';
import '../../../state/nutrition_store.dart';
import '../../../state/profile_store.dart';
import '../../../state/today_store.dart';
import '../../../widgets/undo_snackbar.dart';
import '../sheets/quick_log_sheets.dart';

class QuickLogs extends StatelessWidget {
  const QuickLogs({super.key});

  @override
  Widget build(BuildContext context) {
    final nutrition = context.watch<NutritionStore>();
    final today = context.watch<TodayStore>();
    final targets = nutrition.targets;
    final day = nutrition.today;
    final trainingDay = today.isWorkoutDay || today.doneToday;
    final waterTarget = ((trainingDay ? targets.waterTrainingMl : targets.waterRestMl) / 500 * 2).round() / 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _WeightTile(),
        const SizedBox(height: Space.m),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _CounterTile(
                  icon: Icons.egg_outlined,
                  title: 'Protein',
                  unit: 'points',
                  value: day.proteinPoints,
                  target: targets.proteinPointsTarget.toDouble(),
                  addLabel: 'Add a protein point',
                  onAdd: () => _add(context, 'Protein point added', () => nutrition.addProtein(1), () => nutrition.addProtein(-1)),
                ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: _CounterTile(
                  icon: Icons.water_drop_outlined,
                  title: 'Water',
                  unit: 'sachets',
                  value: day.waterSachets,
                  target: waterTarget,
                  addLabel: 'Add a water sachet',
                  onAdd: () => _add(context, 'Water sachet added', () => nutrition.addWater(1), () => nutrition.addWater(-1)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.m),
        const _CardioTile(),
      ],
    );
  }

  static Future<void> _add(BuildContext context, String message, Future<void> Function() add, Future<void> Function() undo) async {
    await add();
    if (context.mounted) showUndoSnackBar(context, message, () => undo());
  }
}

class _WeightTile extends StatelessWidget {
  const _WeightTile();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final body = context.watch<BodyStore>();
    final useLb = context.select<ProfileStore, bool>((s) => s.profile?.useLb ?? false);
    final todayKey = Fmt.dateKey(context.read<Clock>().now());
    final weighed = body.entries.where((e) => e.weightKg != null).toList();
    final latest = weighed.isEmpty ? null : weighed.last;
    final loggedToday = latest?.date == todayKey;
    final avg = body.avg7;
    return Card(
      child: InkWell(
        onTap: () => showWeightLogSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(Space.l),
          child: Row(
            children: [
              Icon(Icons.monitor_weight_outlined, color: t.primary, size: 28),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Body weight', style: AppText.label.copyWith(color: t.muted)),
                    Text(
                      avg == null ? (latest == null ? 'Not logged yet' : Fmt.weight(latest.weightKg!, useLb: useLb, maxDecimals: 1)) : Fmt.weight(avg, useLb: useLb, maxDecimals: 1),
                      style: AppText.headline.copyWith(fontSize: 26, color: t.onSurface),
                    ),
                    Text(
                      avg == null ? 'Need 3 weigh-ins for the 7-day average' : '7-day average${loggedToday ? ' · logged today' : ''}',
                      style: AppText.label.copyWith(color: t.muted),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => showWeightLogSheet(context),
                style: FilledButton.styleFrom(minimumSize: const Size(Sizes.minTap, Sizes.minTap)),
                icon: Icon(loggedToday ? Icons.edit : Icons.add),
                label: Text(loggedToday ? 'Edit' : 'Log'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CounterTile extends StatelessWidget {
  const _CounterTile({
    required this.icon,
    required this.title,
    required this.unit,
    required this.value,
    required this.target,
    required this.addLabel,
    required this.onAdd,
  });

  final IconData icon;
  final String title, unit, addLabel;
  final double value, target;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final reached = target > 0 && value >= target;
    return Card(
      child: InkWell(
        onTap: onAdd,
        child: Semantics(
          label: '$title: ${Fmt.number(value, maxDecimals: 1)} of ${Fmt.number(target, maxDecimals: 1)} $unit. $addLabel.',
          button: true,
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.all(Space.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: reached ? t.success : t.primary),
                    const SizedBox(width: Space.s),
                    Expanded(child: Text(title, style: AppText.label.copyWith(color: t.muted))),
                  ],
                ),
                const SizedBox(height: Space.s),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: Fmt.number(value, maxDecimals: 1), style: AppText.headline.copyWith(fontSize: 30)),
                      TextSpan(
                        text: ' / ${Fmt.number(target, maxDecimals: 1)}',
                        style: AppText.tabular(AppText.body).copyWith(color: t.muted),
                      ),
                    ]),
                    style: TextStyle(color: t.onSurface),
                  ),
                ),
                Text(unit, style: AppText.label.copyWith(color: t.muted)),
                const SizedBox(height: Space.s),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: target <= 0 ? 0 : (value / target).clamp(0, 1).toDouble(),
                    minHeight: 6,
                    color: reached ? t.success : t.primary,
                  ),
                ),
                const SizedBox(height: Space.m),
                SizedBox(
                  width: double.infinity,
                  height: Sizes.minTap,
                  child: OutlinedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('1')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardioTile extends StatelessWidget {
  const _CardioTile();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Card(
      child: ListTile(
        minTileHeight: Sizes.minTap + 8,
        leading: Icon(Icons.directions_walk, color: t.primary),
        title: Text('Log cardio', style: AppText.bodyStrong.copyWith(color: t.onSurface)),
        subtitle: Text('Rest-day walk or bike ride', style: AppText.label.copyWith(color: t.muted)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showCardioLogSheet(context),
      ),
    );
  }
}
