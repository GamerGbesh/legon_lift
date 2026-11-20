// Owner: WS4. Onboarding step 9 (SPEC 4.2): first week's day cards and the daily targets.
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../app/copy.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/theme/typography.dart';
import '../../../core/format.dart';
import '../../../data/assets/asset_catalog.dart';
import '../../../data/models/models.dart';
import '../../../domain/api.dart';
import '../onboarding_draft.dart';
import '../widgets/form_widgets.dart';

class PreviewStep extends StatelessWidget {
  const PreviewStep({super.key, required this.draft});

  final OnboardingDraft draft;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final catalog = context.read<AssetCatalog>();
    final template = draft.template(catalog);
    final phase = template.phases.first;
    final p = draft.profile;
    final weekdays = [...p.workoutWeekdays]..sort();
    final days = [for (final id in template.dayOrder) ?phase.day(id)];
    final targets = nutritionTargets(p, catalog.personalization);
    final name = p.name;

    return StepBody(
      title: name == null ? 'Your plan is ready' : 'Your plan is ready, $name',
      subtitle: '${template.name}. ${p.sessionMinutes} minutes, ${p.daysPerWeek} days a week.',
      children: [
        if (draft.parqAnyYes && !p.parqCleared)
          const NoticeBox(
            icon: Icons.lock_outline,
            text: 'Workouts unlock once a doctor has cleared you. Tick the box in the safety step, '
                'or later on the Today tab.',
          ),
        for (final (i, day) in days.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: _DayCard(
              weekday: weekdays.isEmpty ? null : weekdays[i % weekdays.length],
              day: day,
              minutes: (estimateSeconds(day) / 60).round(),
            ),
          ),
        NoticeBox(
          icon: Icons.tune,
          color: t.primary,
          text: 'Your first sessions feel light on purpose: we find your starting weights.',
        ),
        const FieldLabel('Your daily targets', hint: 'A guide, not a diet. Adjusted as your weight changes.'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.s),
            child: Column(
              children: [
                _TargetRow(
                  icon: Icons.local_fire_department_outlined,
                  title: 'Calories',
                  value: '${_kcal(targets.calorieTargetKcal - 100)}–${_kcal(targets.calorieTargetKcal + 100)} kcal',
                ),
                _TargetRow(
                  icon: Icons.egg_outlined,
                  title: 'Protein',
                  value: '${targets.proteinPointsTarget} points (${targets.proteinTargetG} g)',
                  hint: '1 point = 20 g protein, e.g. 3 eggs or a palm of fish',
                ),
                _TargetRow(
                  icon: Icons.water_drop_outlined,
                  title: 'Water',
                  value: '${_sachets(targets.waterRestMl)} sachets, ${_sachets(targets.waterTrainingMl)} on gym days',
                  hint: '1 sachet = 500 ml',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _kcal(int v) => v >= 1000 ? '${v ~/ 1000},${(v % 1000).toString().padLeft(3, '0')}' : '$v';

  static String _sachets(int ml) => Fmt.number(ml / 500, maxDecimals: 1);
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.weekday, required this.day, required this.minutes});

  final int? weekday;
  final ProgramDay day;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final exercises = day.blocks
        .where((b) => b.blockType == BlockType.main || b.blockType == BlockType.superset)
        .expand((b) => b.items)
        .where((i) => !i.optional)
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.l),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: t.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(Radii.chip),
              ),
              alignment: Alignment.center,
              child: Text(
                weekday == null ? '' : Fmt.weekdayShort(weekday!),
                style: AppText.headline.copyWith(fontSize: 20, color: t.primary),
              ),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Copy.dayShort(day.name), style: AppText.title.copyWith(fontSize: 20, color: t.onSurface)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (day.focus.isNotEmpty) day.focus.map(Copy.focus).join(', '),
                      '$exercises exercises · about $minutes min',
                    ].join('\n'),
                    style: AppText.label.copyWith(color: t.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({required this.icon, required this.title, required this.value, this.hint});

  final IconData icon;
  final String title, value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListTile(
      leading: Icon(icon, color: t.primary),
      title: Text(title, style: AppText.label.copyWith(color: t.muted)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppText.tabular(AppText.bodyStrong).copyWith(color: t.onSurface)),
          if (hint != null) Text(hint!, style: AppText.caption.copyWith(color: t.muted)),
        ],
      ),
    );
  }
}
