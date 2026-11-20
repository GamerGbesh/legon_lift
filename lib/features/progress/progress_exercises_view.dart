// Owner: WS5. Progress > Exercises: per-exercise trend (SPEC 4.7).
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/theme/tokens.dart';
import '../../app/theme/typography.dart';
import '../../core/clock.dart';
import '../../core/format.dart';
import '../../core/units.dart';
import '../../data/models/models.dart';
import '../../state/history_store.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/exercise_thumb.dart';
import '../library/muscle_groups.dart';
import 'charts.dart';
import 'history_format.dart';
import 'progress_widgets.dart';

/// Pick an exercise, then see its estimated best single, heaviest weight or best set per session.
class ProgressExercisesView extends StatefulWidget {
  const ProgressExercisesView({super.key});

  @override
  State<ProgressExercisesView> createState() => _ProgressExercisesViewState();
}

class _ProgressExercisesViewState extends State<ProgressExercisesView> {
  String? _selectedId;
  ExerciseMetric _metric = ExerciseMetric.bestSingle;
  Future<List<Exercise>>? _exercises;
  Future<List<(DateTime, double)>>? _series;
  Object? _historyKey;
  (String, ExerciseMetric)? _seriesKey;

  void _refresh(HistoryStore h) {
    if (!identical(_historyKey, h.recent)) {
      _historyKey = h.recent;
      _exercises = h.trackedExercises();
      _seriesKey = null;
    }
    final id = _selectedId;
    if (id != null && _seriesKey != (id, _metric)) {
      _seriesKey = (id, _metric);
      _series = h.series(id, _metric);
    }
  }

  Future<void> _pick(List<Exercise> options) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xl),
          children: [
            Text('Choose an exercise', style: AppText.title.copyWith(color: sheet.tokens.onSurface)),
            const SizedBox(height: Space.s),
            for (final ex in options)
              TapRow(
                leading: ExerciseThumb(exercise: ex, size: 48),
                title: ex.name,
                subtitle: mainEquipmentLabel(ex),
                onTap: () => Navigator.of(sheet).pop(ex.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _selectedId = picked);
  }

  @override
  Widget build(BuildContext context) {
    final h = context.watch<HistoryStore>();
    _refresh(h);
    return FutureBuilder<List<Exercise>>(
      future: _exercises,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final options = snap.data!;
        if (options.isEmpty) {
          return const EmptyState(
            icon: Icons.show_chart,
            title: 'Nothing to chart yet',
            body: 'Log a few weighted exercises and their trends show up here.',
          );
        }
        final selected = options.firstWhere((e) => e.id == _selectedId, orElse: () => options.first);
        if (_selectedId != selected.id) {
          _selectedId = selected.id;
          _refresh(h);
        }
        return _ExerciseTrend(
          exercise: selected,
          metric: _metric,
          series: _series!,
          onPick: () => unawaited(_pick(options)),
          onMetric: (m) => setState(() => _metric = m),
        );
      },
    );
  }
}

class _ExerciseTrend extends StatelessWidget {
  const _ExerciseTrend({
    required this.exercise,
    required this.metric,
    required this.series,
    required this.onPick,
    required this.onMetric,
  });

  final Exercise exercise;
  final ExerciseMetric metric;
  final Future<List<(DateTime, double)>> series;
  final VoidCallback onPick;
  final ValueChanged<ExerciseMetric> onMetric;

  static String explain(ExerciseMetric m) => switch (m) {
        ExerciseMetric.bestSingle => 'Estimated best single: the most you could probably lift once, worked out '
            'from your best set of 12 reps or fewer each session.',
        ExerciseMetric.heaviest => 'The heaviest weight you lifted each session.',
        ExerciseMetric.bestSet => 'Your best single set each session: weight × reps.',
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final useLb = useLbOf(context);
    final unit = Units.weightUnit(useLb: useLb);
    final now = context.read<Clock>().now();
    final caption = AppText.body.copyWith(color: t.muted, fontSize: 14);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.s, Space.page, Space.xxl),
      children: [
        Semantics(
          button: true,
          label: 'Exercise: ${exercise.name}. Tap to choose another.',
          excludeSemantics: true,
          child: Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(Radii.card),
              child: Padding(
                padding: const EdgeInsets.all(Space.m),
                child: Row(
                  children: [
                    ExerciseThumb(exercise: exercise),
                    const SizedBox(width: Space.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(exercise.name, style: AppText.title.copyWith(fontSize: 18, color: t.onSurface)),
                          Text('Tap to choose another', style: AppText.label.copyWith(color: t.muted)),
                        ],
                      ),
                    ),
                    Icon(Icons.unfold_more, color: t.muted),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.l),
        SegmentedButton<ExerciseMetric>(
          expandedInsets: EdgeInsets.zero,
          showSelectedIcon: false,
          style: const ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(0, 48)),
            padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
            textStyle: WidgetStatePropertyAll(AppText.label),
          ),
          segments: [
            for (final (m, label) in const [
              (ExerciseMetric.bestSingle, 'Best single'),
              (ExerciseMetric.heaviest, 'Heaviest'),
              (ExerciseMetric.bestSet, 'Best set'),
            ])
              ButtonSegment(value: m, label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
          selected: {metric},
          onSelectionChanged: (s) => onMetric(s.first),
        ),
        const SizedBox(height: Space.m),
        Text(explain(metric), style: caption),
        if (exercise.loadType == LoadType.dumbbell && (exercise.dumbbellCount ?? 1) > 1)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text('Counts both dumbbells together.', style: caption),
          ),
        const SizedBox(height: Space.m),
        FutureBuilder<List<(DateTime, double)>>(
          future: series,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
            }
            final points = [for (final (d, v) in snap.data!) (d, Units.displayWeight(v, useLb: useLb))];
            if (points.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.xl),
                child: Text(
                  metric == ExerciseMetric.bestSingle
                      ? 'No sets of 12 reps or fewer yet, so there is no estimate.'
                      : 'No sets logged yet.',
                  style: caption,
                  textAlign: TextAlign.center,
                ),
              );
            }
            final first = points.first;
            final last = points.last;
            final change = last.$2 - first.$2;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Figure(
                        label: 'Latest',
                        value: '${Fmt.number(last.$2, maxDecimals: 1)} $unit',
                        sub: shortDate(last.$1, now: now),
                      ),
                    ),
                    Expanded(
                      child: _Figure(
                        label: 'Change',
                        value: points.length < 2
                            ? '–'
                            : '${change >= 0 ? '+' : '−'}${Fmt.number(change.abs(), maxDecimals: 1)} $unit',
                        sub: points.length < 2 ? 'Needs 2 sessions' : 'since ${dayMonth(first.$1)}',
                        color: change > 0 ? t.success : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.m),
                ChartCard(
                  child: TrendLineChart(
                    points: points,
                    unit: unit,
                    semanticLabel: '${exercise.name} trend over ${points.length} sessions: '
                        'from ${Fmt.number(first.$2, maxDecimals: 1)} to ${Fmt.number(last.$2, maxDecimals: 1)} $unit.',
                  ),
                ),
                if (points.length < 2)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.s),
                    child: Text('Do this exercise again to see a trend.', style: caption),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, required this.sub, this.color});

  final String label, value, sub;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label.copyWith(color: t.muted)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: AppText.value.copyWith(fontSize: 32, color: color ?? t.onSurface)),
        ),
        Text(sub, style: AppText.label.copyWith(color: t.muted)),
      ],
    );
  }
}
